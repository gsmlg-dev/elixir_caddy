defmodule Caddy.Config do
  @moduledoc """
  Configuration structure for Caddy reverse proxy server.

  Defines the configuration structure and validation functions for Caddy.
  """

  require Logger

  @type t :: %__MODULE__{
          bin: binary() | nil,
          global: binary(),
          additional: [binary()],
          sites: map(),
          env: list({binary(), binary()})
        }

  @type caddyfile :: binary()
  @type site_name :: binary()
  @type site_listen :: binary()
  @type site_config :: caddyfile() | {site_listen(), caddyfile()}

  @derive {Jason.Encoder, only: [:bin, :global, :additional, :sites, :env]}
  defstruct bin: nil, global: "", additional: [], sites: %{}, env: []

  # Path utilities
  defdelegate user_home, to: System
  def user_share(), do: Path.join(user_home(), ".local/share")
  def priv_path(), do: Application.app_dir(:caddy, "priv")
  def share_path(), do: Path.join(user_share(), "caddy")
  def etc_path(), do: Path.join(share_path(), "etc")
  def run_path(), do: Path.join(share_path(), "run")
  def tmp_path(), do: Path.join(share_path(), "tmp")
  def xdg_config_home(), do: Path.join(share_path(), "config")
  def xdg_data_home(), do: Path.join(share_path(), "data")

  def env_file(), do: Path.join(etc_path(), "envfile")
  def init_file(), do: Path.join(etc_path(), "init.json")
  def pid_file(), do: Path.join(run_path(), "caddy.pid")
  def socket_file(), do: Path.join(run_path(), "caddy.sock")
  def saved_json_file(), do: Path.join(xdg_config_home(), "caddy/autosave.json")

  @doc false
  def paths(), do: [priv_path(), share_path(), etc_path(), run_path(), tmp_path()]

  @doc false
  def ensure_path_exists() do
    paths()
    |> Enum.reduce_while(true, fn path, _acc ->
      case File.mkdir_p(path) do
        :ok -> {:cont, true}
        {:error, reason} -> 
          Logger.error("Failed to create directory #{path}: #{inspect(reason)}")
          {:halt, false}
      end
    end)
  end


  @doc "Convert caddyfile to JSON"
  @spec adapt(caddyfile(), binary() | nil) :: {:ok, map()} | {:error, term()}
  def adapt(binary, caddy_bin \\ nil) do
    caddy_bin = caddy_bin || System.find_executable("caddy")
    start_time = System.monotonic_time()
    
    cond do
      is_nil(caddy_bin) ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: "Caddy binary path not configured"})
        {:error, "Caddy binary path not configured"}
        
      String.trim(binary) == "" ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: "Caddyfile content cannot be empty"})
        {:error, "Caddyfile content cannot be empty"}
        
      not File.exists?(caddy_bin) ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: "Caddy binary not found"})
        {:error, "Caddy binary not found: #{caddy_bin}"}
        
      true ->
        tmp_config = Path.expand("Caddyfile", tmp_path())
        
        try do
          with :ok <- ensure_dir_exists(tmp_config),
               :ok <- File.write(tmp_config, binary),
               {_fmt_output, 0} <- System.cmd(caddy_bin, ["fmt", "--overwrite", tmp_config]),
               {config_json, 0} <-
                 System.cmd(caddy_bin, ["adapt", "--adapter", "caddyfile", "--config", tmp_config]),
               {:ok, config} <- Jason.decode(config_json),
               :ok <- validate_adapted_config(config) do
            duration = System.monotonic_time() - start_time
            Caddy.Telemetry.emit_adapt_event(:success, %{duration: duration, config_size: byte_size(config_json)})
            {:ok, config}
          else
            {error_output, non_zero} when is_integer(non_zero) and non_zero != 0 ->
              duration = System.monotonic_time() - start_time
              Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: error_output, exit_code: non_zero})
              Logger.error("Caddy command failed with exit code #{non_zero}: #{error_output}")
              {:error, {:caddy_error, non_zero, error_output}}
            error ->
              duration = System.monotonic_time() - start_time
              Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: inspect(error)})
              Logger.error("Caddy adaptation failed: #{inspect(error)}")
              error
          end
        rescue
          e in File.Error ->
            duration = System.monotonic_time() - start_time
            Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: "File operation error"})
            Logger.error("File operation error: #{inspect(e)}")
            {:error, {:file_error, e}}
          e in Jason.DecodeError ->
            duration = System.monotonic_time() - start_time
            Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: "JSON decode error"})
            Logger.error("JSON decode error: #{inspect(e)}")
            {:error, {:json_error, e}}
        after
          if File.exists?(tmp_config), do: File.rm(tmp_config)
        end
    end
  end


  @doc "Get backup file path"
  @spec backup_json_file() :: Path.t()
  def backup_json_file(), do: Path.join(xdg_config_home(), "caddy/backup.json")

  @doc "Convert config to caddyfile"
  @spec to_caddyfile(t()) :: caddyfile()
  def to_caddyfile(%__MODULE__{global: global, additional: additional, sites: sites}) do
    """
    {
    #{global}
    }

    #{Enum.join(additional, "\n\n")}

    #{Enum.map(sites, fn
      {name, site} when is_binary(site) -> """
        ## #{name}
        #{name} {
          #{site}
        }
        """
      {name, {listen, site}} when is_binary(site) -> """
        ## #{name}
        #{listen} {
          #{site}
        }
        """
      _ -> ""
    end) |> Enum.join("\n\n")}
    """
  end

  @doc "Validate Caddy binary path"
  @spec validate_bin(binary()) :: :ok | {:error, binary()}
  def validate_bin(caddy_bin) when is_binary(caddy_bin) do
    cond do
      not File.exists?(caddy_bin) ->
        {:error, "Caddy binary not found at path: #{caddy_bin}"}

      not can_execute?(caddy_bin) ->
        {:error, "Caddy binary not executable: #{caddy_bin}"}

      true ->
        case check_bin(caddy_bin) do
          :ok -> :ok
          {:error, _} -> {:error, "Invalid Caddy binary or version incompatibility"}
          _ -> {:error, "Failed to validate Caddy binary"}
        end
    end
  rescue
    _ -> {:error, "Caddy binary validation failed"}
  end

  def validate_bin(_) do
    {:error, "binary path must be a string"}
  end

  @doc "Validate site configuration format"
  @spec validate_site_config(site_config()) :: :ok | {:error, binary()}
  def validate_site_config(site) when is_binary(site) do
    if String.trim(site) == "" do
      {:error, "site configuration cannot be empty"}
    else
      :ok
    end
  end

  def validate_site_config({listen, site}) when is_binary(listen) and is_binary(site) do
    cond do
      String.trim(listen) == "" ->
        {:error, "listen address cannot be empty"}
      String.trim(site) == "" ->
        {:error, "site configuration cannot be empty"}
      not String.contains?(listen, ":") ->
        {:error, "listen address must contain port (e.g., ':8080')"}
      true ->
        :ok
    end
  end

  def validate_site_config(_) do
    {:error, "invalid site configuration format"}
  end

  @doc "Validate complete configuration"
  @spec validate_config(t()) :: :ok | {:error, binary()}
  def validate_config(%__MODULE__{} = config) do
    cond do
      not is_binary(config.global) or not is_list(config.additional) or not is_map(config.sites) or not is_list(config.env) ->
        {:error, "invalid configuration structure"}
      
      not (is_binary(config.bin) or is_nil(config.bin)) ->
        {:error, "binary path must be a string or nil"}
      
      not Enum.all?(config.sites, fn {_name, site_config} -> validate_site_config(site_config) == :ok end) ->
        {:error, "invalid site configuration in sites"}
      
      true ->
        :ok
    end
  end

  @doc false
  def parse_caddyfile(caddy_bin, caddy_file) do
    with {config_json, 0} <-
           System.cmd(caddy_bin, ["adapt", "--adapter", "caddyfile", "--config", caddy_file]),
         {:ok, config} <- Jason.decode(config_json) do
      config
    else
      error ->
        Logger.error("Error parsing caddyfile: #{inspect(error)}")
        %{}
    end
  end

  @doc false
  def first_writable(paths, default \\ nil) do
    paths
    |> Enum.find(default, &has_write_permission?/1)
  end

  @doc false
  def has_write_permission?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{access: :write} = _stat} ->
        true

      {:ok, %File.Stat{access: :read_write} = _stat} ->
        true

      _ ->
        false
    end
  end

  @doc false
  def check_bin(bin) do
    if can_execute?(bin) do
      case System.cmd(bin, ["version"]) do
        {"v2" <> _, 0} ->
          :ok
        _ ->
          {:error, "Caddy binary version check failed"}
      end
    else
      {:error, "Caddy binary not found or not executable"}
    end
  end

  @doc false
  def can_execute?(path) when is_binary(path) do
    with true <- File.exists?(path),
         {:ok, %File.Stat{access: access, mode: mode}} <- File.stat(path),
         true <- access in [:read, :read_write],
         0b100 <- Bitwise.band(mode, 0b100) do
      true
    else
      _ ->
        false
    end
  end

  def can_execute?(_), do: false

  defp validate_adapted_config(config) when is_map(config) do
    if Map.has_key?(config, "apps") or Map.has_key?(config, "admin") do
      :ok
    else
      {:error, "Invalid Caddy configuration structure"}
    end
  end

  @doc false
  def load_saved_config(file_path) do
    with true <- File.exists?(file_path),
         {:ok, saved_config_string} <- File.read(file_path),
         {:ok, saved_config} <- Jason.decode(saved_config_string) do
      saved_config
    else
      false -> %{}
      {:error, reason} ->
        Logger.warning("Failed to read saved configuration: #{inspect(reason)}")
        %{}
      _ ->
        %{}
    end
  end

  @doc false
  def ensure_dir_exists(file_path) do
    dir_path = Path.dirname(file_path)
    case File.mkdir_p(dir_path) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_error, reason}}
    end
  end

  @doc false
  def init_env() do
    [
      {"HOME", share_path()},
      {"XDG_CONFIG_HOME", xdg_config_home()},
      {"XDG_DATA_HOME", xdg_data_home()}
    ]
  end
end