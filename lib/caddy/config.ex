defmodule Caddy.Config do
  @moduledoc """
  Simple text-based configuration for Caddy reverse proxy server.

  Configuration is stored as raw Caddyfile text. This design keeps things
  stupid simple - users write native Caddyfile syntax directly.

  ## Example

      config = %Caddy.Config{
        bin: "/usr/bin/caddy",
        caddyfile: \"\"\"
        {
          debug
          admin unix//tmp/caddy.sock
        }

        example.com {
          reverse_proxy localhost:3000
        }
        \"\"\"
      }

  ## Validation

  Configuration is validated by calling the Caddy binary's `adapt` command,
  which converts Caddyfile to JSON and catches syntax errors.
  """

  @type t :: %__MODULE__{
          bin: binary() | nil,
          caddyfile: binary(),
          env: list({binary(), binary()})
        }

  @derive {Jason.Encoder, only: [:bin, :caddyfile, :env]}
  defstruct bin: nil, caddyfile: "", env: []

  # Path utilities
  defdelegate user_home, to: System

  @doc "Get configurable base path for caddy files"
  def base_path do
    Application.get_env(:caddy, :base_path, Path.join(user_home(), ".local/share/caddy"))
  end

  @doc "Get configurable priv path"
  def priv_path do
    Application.get_env(:caddy, :priv_path, Application.app_dir(:caddy, "priv"))
  end

  @doc "Get share path (base path)"
  def share_path, do: base_path()

  @doc "Get etc path for configuration files"
  def etc_path do
    Application.get_env(:caddy, :etc_path, Path.join(base_path(), "etc"))
  end

  @doc "Get run path for runtime files"
  def run_path do
    Application.get_env(:caddy, :run_path, Path.join(base_path(), "run"))
  end

  @doc "Get tmp path for temporary files"
  def tmp_path do
    Application.get_env(:caddy, :tmp_path, Path.join(base_path(), "tmp"))
  end

  @doc "Get XDG config home path"
  def xdg_config_home do
    Application.get_env(:caddy, :xdg_config_home, Path.join(base_path(), "config"))
  end

  @doc "Get XDG data home path"
  def xdg_data_home do
    Application.get_env(:caddy, :xdg_data_home, Path.join(base_path(), "data"))
  end

  @doc "Get environment file path"
  def env_file do
    Application.get_env(:caddy, :env_file, Path.join(etc_path(), "envfile"))
  end

  @doc "Get init configuration file path"
  def init_file do
    Application.get_env(:caddy, :init_file, Path.join(etc_path(), "init.json"))
  end

  @doc "Get PID file path"
  def pid_file do
    Application.get_env(:caddy, :pid_file, Path.join(run_path(), "caddy.pid"))
  end

  @doc "Get socket file path"
  def socket_file do
    Application.get_env(:caddy, :socket_file, Path.join(run_path(), "caddy.sock"))
  end

  @doc "Get saved JSON configuration file path"
  def saved_json_file do
    Application.get_env(
      :caddy,
      :saved_json_file,
      Path.join(xdg_config_home(), "caddy/autosave.json")
    )
  end

  @doc "Get backup file path"
  @spec backup_json_file() :: Path.t()
  def backup_json_file do
    Application.get_env(
      :caddy,
      :backup_json_file,
      Path.join(xdg_config_home(), "caddy/backup.json")
    )
  end

  # External mode configuration

  @doc """
  Get the operating mode for Caddy management.

  - `:embedded` (default) - Caddy binary is managed by this application
  - `:external` - Caddy is managed externally (e.g., systemd), communicate via Admin API

  ## Example

      config :caddy, mode: :external
  """
  @spec mode() :: :embedded | :external
  def mode, do: Application.get_env(:caddy, :mode, :embedded)

  @doc """
  Check if running in external mode.
  """
  @spec external_mode?() :: boolean()
  def external_mode?, do: mode() == :external

  @doc """
  Get the admin API URL for external mode.

  Supports both TCP and Unix socket connections:
  - `"http://localhost:2019"` - TCP connection
  - `"unix:///path/to/caddy.sock"` - Unix domain socket

  Falls back to the configured socket_file in embedded mode.

  ## Example

      config :caddy, admin_url: "http://localhost:2019"
  """
  @spec admin_url() :: binary()
  def admin_url do
    case Application.get_env(:caddy, :admin_url) do
      nil -> "unix://#{socket_file()}"
      url -> url
    end
  end

  @doc """
  Get system commands for external mode operations.

  Commands are executed via System.cmd when managing an externally-controlled Caddy.

  ## Example

      config :caddy, commands: [
        start: "systemctl start caddy",
        stop: "systemctl stop caddy",
        restart: "systemctl restart caddy",
        status: "systemctl is-active caddy"
      ]
  """
  @spec commands() :: keyword(binary())
  def commands, do: Application.get_env(:caddy, :commands, [])

  @doc """
  Get a specific command for external mode.

  Returns nil if the command is not configured.
  """
  @spec command(atom()) :: binary() | nil
  def command(name) when is_atom(name), do: Keyword.get(commands(), name)

  @doc """
  Get the health check interval in milliseconds for external mode.

  Defaults to 30 seconds.

  ## Example

      config :caddy, health_interval: 60_000
  """
  @spec health_interval() :: pos_integer()
  def health_interval, do: Application.get_env(:caddy, :health_interval, 30_000)

  @doc false
  def paths, do: [priv_path(), share_path(), etc_path(), run_path(), tmp_path()]

  @doc false
  def ensure_path_exists do
    paths()
    |> Enum.reduce_while(true, fn path, _acc ->
      case File.mkdir_p(path) do
        :ok ->
          {:cont, true}

        {:error, reason} ->
          Caddy.Telemetry.log_error("Failed to create directory #{path}: #{inspect(reason)}",
            module: __MODULE__,
            path: path,
            error: reason
          )

          {:halt, false}
      end
    end)
  end

  @doc """
  Get the Caddyfile content from the config.

  Simply returns the stored caddyfile text.
  """
  @spec to_caddyfile(t()) :: binary()
  def to_caddyfile(%__MODULE__{caddyfile: caddyfile}), do: caddyfile

  @doc """
  Convert Caddyfile text to JSON using Caddy binary.

  This validates the Caddyfile syntax and returns the JSON configuration
  that Caddy will use internally.
  """
  @spec adapt(binary(), binary() | nil) :: {:ok, map()} | {:error, term()}
  def adapt(caddyfile_text, caddy_bin \\ nil) do
    caddy_bin = caddy_bin || System.find_executable("caddy")
    start_time = System.monotonic_time()

    cond do
      is_nil(caddy_bin) ->
        emit_adapt_error(start_time, "Caddy binary path not configured")

      String.trim(caddyfile_text) == "" ->
        emit_adapt_error(start_time, "Caddyfile content cannot be empty")

      not File.exists?(caddy_bin) ->
        emit_adapt_error(start_time, "Caddy binary not found: #{caddy_bin}")

      true ->
        do_adapt(caddyfile_text, caddy_bin, start_time)
    end
  end

  defp do_adapt(caddyfile_text, caddy_bin, start_time) do
    tmp_config = Path.expand("Caddyfile", tmp_path())

    try do
      with :ok <- ensure_dir_exists(tmp_config),
           :ok <- File.write(tmp_config, caddyfile_text),
           {_fmt_output, 0} <- System.cmd(caddy_bin, ["fmt", "--overwrite", tmp_config]),
           {config_json, 0} <-
             System.cmd(caddy_bin, ["adapt", "--adapter", "caddyfile", "--config", tmp_config]),
           {:ok, config} <- Jason.decode(config_json),
           :ok <- validate_adapted_config(config) do
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_adapt_event(:success, %{
          duration: duration,
          config_size: byte_size(config_json)
        })

        {:ok, config}
      else
        {error_output, non_zero} when is_integer(non_zero) and non_zero != 0 ->
          duration = System.monotonic_time() - start_time

          Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{
            error: error_output,
            exit_code: non_zero
          })

          Caddy.Telemetry.log_error(
            "Caddy command failed with exit code #{non_zero}: #{error_output}",
            module: __MODULE__,
            exit_code: non_zero,
            error_output: error_output
          )

          {:error, {:caddy_error, non_zero, error_output}}

        error ->
          duration = System.monotonic_time() - start_time

          Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{
            error: inspect(error)
          })

          Caddy.Telemetry.log_error("Caddy adaptation failed: #{inspect(error)}",
            module: __MODULE__,
            error: error
          )

          error
      end
    rescue
      e in File.Error ->
        emit_adapt_error(start_time, "File operation error", e)

      e in Jason.DecodeError ->
        emit_adapt_error(start_time, "JSON decode error", e)
    after
      if File.exists?(tmp_config), do: File.rm(tmp_config)
    end
  end

  defp emit_adapt_error(start_time, message, exception \\ nil) do
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_adapt_event(:error, %{duration: duration}, %{error: message})

    if exception do
      Caddy.Telemetry.log_error("#{message}: #{inspect(exception)}",
        module: __MODULE__,
        error: exception
      )

      {:error, {String.to_atom(String.replace(String.downcase(message), " ", "_")), exception}}
    else
      {:error, message}
    end
  end

  defp validate_adapted_config(config) when is_map(config) do
    if Map.has_key?(config, "apps") or Map.has_key?(config, "admin") do
      :ok
    else
      {:error, "Invalid Caddy configuration structure"}
    end
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
        end
    end
  rescue
    _ -> {:error, "Caddy binary validation failed"}
  end

  def validate_bin(_) do
    {:error, "binary path must be a string"}
  end

  @doc "Validate complete configuration"
  @spec validate_config(t()) :: :ok | {:error, binary()}
  def validate_config(%__MODULE__{} = config) do
    cond do
      not is_binary(config.caddyfile) ->
        {:error, "caddyfile must be a string"}

      not is_list(config.env) ->
        {:error, "env must be a list"}

      not (is_binary(config.bin) or is_nil(config.bin)) ->
        {:error, "bin must be a string or nil"}

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
        Caddy.Telemetry.log_error("Error parsing caddyfile: #{inspect(error)}",
          module: __MODULE__,
          error: error
        )

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
      {:ok, %File.Stat{access: :write}} -> true
      {:ok, %File.Stat{access: :read_write}} -> true
      _ -> false
    end
  end

  @doc false
  def check_bin(bin) do
    if can_execute?(bin) do
      case System.cmd(bin, ["version"]) do
        {"v2" <> _, 0} -> :ok
        _ -> {:error, "Caddy binary version check failed"}
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
      _ -> false
    end
  end

  def can_execute?(_), do: false

  @doc false
  def load_saved_config(file_path) do
    with true <- File.exists?(file_path),
         {:ok, saved_config_string} <- File.read(file_path),
         {:ok, saved_config} <- Jason.decode(saved_config_string) do
      saved_config
    else
      false ->
        %{}

      {:error, reason} ->
        Caddy.Telemetry.log_warning("Failed to read saved configuration: #{inspect(reason)}",
          module: __MODULE__,
          error: reason
        )

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
  def init_env do
    [
      {"HOME", share_path()},
      {"XDG_CONFIG_HOME", xdg_config_home()},
      {"XDG_DATA_HOME", xdg_data_home()}
    ]
  end

  @doc """
  Create a default Caddyfile with admin socket configuration.
  """
  @spec default_caddyfile() :: binary()
  def default_caddyfile do
    """
    {
      admin unix/#{socket_file()}
    }
    """
    |> String.trim()
  end
end
