defmodule Caddy.ConfigProvider do
  @moduledoc """
  Agent-based configuration provider for Caddy reverse proxy server.

  Manages Caddy configuration using simple text-based Caddyfile format.
  The configuration is stored as raw Caddyfile text, keeping things simple.
  """

  use Agent

  alias Caddy.Config

  @doc "Start config agent"
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(args) do
    # Handle nested list from supervisor child spec {Module, [args]}
    args = if is_list(args) and length(args) == 1 and is_list(hd(args)), do: hd(args), else: args
    Agent.start_link(fn -> init(args) end, name: __MODULE__)
  end

  @doc "Replace current configuration"
  @spec set_config(Config.t()) :: :ok | {:error, term()}
  def set_config(%Config{} = config) do
    case Config.validate_config(config) do
      :ok ->
        start_time = System.monotonic_time()
        Agent.update(__MODULE__, fn _ -> config end)
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:set, %{duration: duration}, %{})

        :ok

      {:error, reason} ->
        Caddy.Telemetry.emit_config_change(:set_error, %{}, %{error: reason})
        {:error, reason}
    end
  end

  @doc "Get current configuration"
  @spec get_config() :: Config.t()
  def get_config do
    start_time = System.monotonic_time()
    config = Agent.get(__MODULE__, & &1)
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:get, %{duration: duration}, %{})

    config
  end

  @doc "Get config value by key"
  @spec get(atom()) :: term()
  def get(name) do
    Agent.get(__MODULE__, &Map.get(&1, name))
  end

  @doc "Set Caddy binary path"
  @spec set_bin(binary()) :: :ok | {:error, binary()}
  def set_bin(caddy_bin) do
    case Config.validate_bin(caddy_bin) do
      :ok ->
        Agent.update(__MODULE__, &%{&1 | bin: caddy_bin})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Set binary path and restart server"
  @spec set_bin!(binary()) :: :ok | {:error, term()}
  def set_bin!(caddy_bin) do
    Agent.update(__MODULE__, &%{&1 | bin: caddy_bin})
    Caddy.Supervisor.restart_server()
  end

  @doc "Set the Caddyfile content"
  @spec set_caddyfile(binary()) :: :ok
  def set_caddyfile(caddyfile) when is_binary(caddyfile) do
    Agent.update(__MODULE__, &%{&1 | caddyfile: caddyfile})
  end

  @doc "Get the Caddyfile content"
  @spec get_caddyfile() :: binary()
  def get_caddyfile do
    Agent.get(__MODULE__, & &1.caddyfile)
  end

  @doc "Append content to the Caddyfile"
  @spec append_caddyfile(binary()) :: :ok
  def append_caddyfile(content) when is_binary(content) do
    Agent.update(__MODULE__, fn config ->
      new_caddyfile = config.caddyfile <> "\n\n" <> content
      %{config | caddyfile: String.trim(new_caddyfile)}
    end)
  end

  @doc "Backup current configuration"
  @spec backup_config() :: :ok | {:error, term()}
  def backup_config do
    config = get_config()
    backup_file = Config.backup_json_file()
    start_time = System.monotonic_time()

    with :ok <- Config.ensure_dir_exists(backup_file),
         {:ok, json} <- Jason.encode(config, pretty: true),
         :ok <- File.write(backup_file, json) do
      duration = System.monotonic_time() - start_time

      Caddy.Telemetry.emit_config_change(
        :backup,
        %{duration: duration, file_size: byte_size(json)},
        %{file_path: backup_file}
      )

      :ok
    else
      error ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:backup_error, %{duration: duration}, %{
          error: inspect(error)
        })

        error
    end
  end

  @doc "Restore configuration from backup"
  @spec restore_config() :: {:ok, Config.t()} | {:error, term()}
  def restore_config do
    backup_file = Config.backup_json_file()
    start_time = System.monotonic_time()

    case load_saved_config(backup_file) do
      %{} = config_map when map_size(config_map) > 0 ->
        config = map_to_config(config_map)
        _result = set_config(config)
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:restore, %{duration: duration}, %{
          file_path: backup_file,
          success: true
        })

        {:ok, config}

      _ ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:restore_error, %{duration: duration}, %{
          file_path: backup_file,
          error: "No backup found"
        })

        {:error, :no_backup}
    end
  end

  @doc "Save current configuration"
  @spec save_config() :: :ok | {:error, term()}
  def save_config do
    config = get_config()
    start_time = System.monotonic_time()

    with :ok <- Config.ensure_dir_exists(Config.saved_json_file()),
         {:ok, json} <- Jason.encode(config, pretty: true),
         :ok <- File.write(Config.saved_json_file(), json) do
      duration = System.monotonic_time() - start_time

      Caddy.Telemetry.emit_config_change(
        :save,
        %{duration: duration, file_size: byte_size(json)},
        %{file_path: Config.saved_json_file()}
      )

      :ok
    else
      error ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:save_error, %{duration: duration}, %{
          error: inspect(error)
        })

        error
    end
  end

  @doc "Initialize configuration"
  @spec init(keyword()) :: Config.t()
  def init(args) do
    bin =
      cond do
        Keyword.keyword?(args) and Keyword.has_key?(args, :caddy_bin) ->
          Keyword.get(args, :caddy_bin)

        :os.type() == {:unix, :linux} ->
          "/usr/bin/caddy"

        :os.type() == {:unix, :darwin} ->
          "/opt/homebrew/bin/caddy"

        true ->
          System.find_executable("caddy")
      end

    Config.ensure_path_exists()

    base_config =
      case load_saved_config(Config.saved_json_file()) do
        %{} = saved_config when map_size(saved_config) > 0 ->
          map_to_config(saved_config)

        _ ->
          %Config{
            env: Config.init_env(),
            bin: bin,
            caddyfile: Config.default_caddyfile()
          }
      end

    # Override bin if provided in args (args take precedence over saved config)
    config = if bin, do: %Config{base_config | bin: bin}, else: base_config

    case Config.validate_config(config) do
      :ok ->
        config

      {:error, reason} ->
        Caddy.Telemetry.log_warning("Invalid saved configuration: #{reason}, using defaults",
          module: __MODULE__,
          error: reason
        )

        %Config{
          env: Config.init_env(),
          bin: bin,
          caddyfile: Config.default_caddyfile()
        }
    end
  end

  @doc "Convert caddyfile to JSON"
  @spec adapt(binary()) :: {:ok, map()} | {:error, term()}
  def adapt(caddyfile_text) do
    caddy_bin = get(:bin)
    Config.adapt(caddyfile_text, caddy_bin)
  end

  # Private functions

  defp load_saved_config(file_path) do
    Config.load_saved_config(file_path)
  end

  defp map_to_config(map) when is_map(map) do
    %Config{
      bin: Map.get(map, "bin") || Map.get(map, :bin),
      caddyfile: Map.get(map, "caddyfile") || Map.get(map, :caddyfile) || "",
      env: normalize_env(Map.get(map, "env") || Map.get(map, :env) || [])
    }
  end

  defp normalize_env(env) when is_list(env) do
    Enum.map(env, fn
      [k, v] -> {k, v}
      {k, v} -> {k, v}
      other -> other
    end)
  end

  defp normalize_env(_), do: []
end
