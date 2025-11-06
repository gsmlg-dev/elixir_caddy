defmodule Caddy.ConfigProvider do
  @moduledoc """
  Agent-based configuration provider for Caddy reverse proxy server.

  Manages Caddy configuration including binary path, global settings,
  site configurations, and environment variables using an Agent process.
  """

  require Logger

  use Agent

  alias Caddy.Config

  @doc "Start config agent"
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(args) do
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

        Caddy.Telemetry.emit_config_change(:set, %{duration: duration}, %{
          config_size: map_size(config.sites)
        })

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

    Caddy.Telemetry.emit_config_change(:get, %{duration: duration}, %{
      config_size: map_size(config.sites)
    })

    config
  end

  @doc "Get config value by key"
  @spec get(atom()) :: binary() | nil
  def get(name) do
    Agent.get(__MODULE__, &Map.get(&1, name))
  end

  @doc "Set Caddy binary path"
  @spec set_bin(binary()) :: :ok | {:error, binary()}
  def set_bin(caddy_bin) do
    case Config.validate_bin(caddy_bin) do
      :ok ->
        Agent.update(__MODULE__, &Map.put(&1, :bin, caddy_bin))

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Set binary path and restart server"
  @spec set_bin!(binary()) :: :ok | {:error, term()}
  def set_bin!(caddy_bin) do
    Agent.update(__MODULE__, &Map.put(&1, :bin, caddy_bin))
    Caddy.Supervisor.restart_server()
  end

  @doc "Set global configuration"
  @spec set_global(Config.caddyfile()) :: :ok
  def set_global(global) do
    Agent.update(__MODULE__, &Map.put(&1, :global, global))
  end

  @doc "Set a snippet configuration"
  @spec set_snippet(binary(), Caddy.Config.Snippet.t()) :: :ok
  def set_snippet(name, %Caddy.Config.Snippet{} = snippet) when is_binary(name) do
    Agent.update(
      __MODULE__,
      &Map.update(&1, :snippets, %{}, fn snippets -> Map.put(snippets, name, snippet) end)
    )
  end

  @doc "Get a snippet by name"
  @spec get_snippet(binary()) :: Caddy.Config.Snippet.t() | nil
  def get_snippet(name) when is_binary(name) do
    Agent.get(__MODULE__, fn config -> Map.get(config.snippets, name) end)
  end

  @doc "Remove a snippet by name"
  @spec remove_snippet(binary()) :: :ok
  def remove_snippet(name) when is_binary(name) do
    Agent.update(__MODULE__, fn config ->
      Map.update(config, :snippets, %{}, fn snippets -> Map.delete(snippets, name) end)
    end)
  end

  @doc "Get all snippets"
  @spec get_snippets() :: %{binary() => Caddy.Config.Snippet.t()}
  def get_snippets do
    Agent.get(__MODULE__, fn config -> config.snippets end)
  end

  @doc """
  Set additional configuration blocks.

  Deprecated: Use set_snippet/2 instead for snippet-based configuration.
  """
  @deprecated "Use set_snippet/2 instead"
  @spec set_additional([Config.caddyfile()]) :: :ok
  def set_additional(_additionals) do
    Caddy.Telemetry.log_warning("set_additional/1 is deprecated. Use set_snippet/2 instead.",
      module: __MODULE__
    )

    :ok
  end

  @doc "Set site configuration"
  @spec set_site(Config.site_name(), Config.site_config()) :: :ok | {:error, binary()}
  def set_site(name, site) when is_atom(name), do: set_site(to_string(name), site)

  def set_site(name, site) when is_binary(name) do
    case Config.validate_site_config(site) do
      :ok ->
        Agent.update(
          __MODULE__,
          &Map.update(&1, :sites, %{}, fn sites -> Map.put(sites, name, site) end)
        )

      {:error, reason} ->
        {:error, reason}
    end
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
      %{} = config_map ->
        config = struct(Config, config_map)
        _result = set_config(config)
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:restore, %{duration: duration}, %{
          file_path: backup_file,
          success: true
        })

        {:ok, config}

      error ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:restore_error, %{duration: duration}, %{
          file_path: backup_file,
          error: inspect(error)
        })

        error
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
  @spec init(keyword()) :: %Config{}
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

    config =
      case load_saved_config(Config.saved_json_file()) do
        %{} = saved_config when map_size(saved_config) > 0 ->
          struct(Config, saved_config)

        _ ->
          %Config{
            env: Config.init_env(),
            bin: bin,
            global: "admin unix/#{Config.socket_file()}"
          }
      end

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
          global: "admin unix/#{Config.socket_file()}"
        }
    end
  end

  @doc "Convert caddyfile to JSON"
  @spec adapt(Config.caddyfile()) :: {:ok, map()} | {:error, term()}
  def adapt(binary) do
    caddy_bin = get(:bin)
    Config.adapt(binary, caddy_bin)
  end

  # Private functions
  defp load_saved_config(file_path) do
    Config.load_saved_config(file_path)
  end
end
