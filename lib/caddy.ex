defmodule Caddy do
  @moduledoc """
  # Caddy

  Start Caddy HTTP Server in supervisor tree.

  If caddy bin is set, caddy server will automatically start when application starts.

  ## Starting Caddy

  Add to your supervision tree:

  ```elixir
  def application do
    [
      extra_applications: [Caddy.Application]
    ]
  end
  ```

  ## Configuration

  Configuration is stored as raw Caddyfile text. Write native Caddyfile syntax directly:

  ```elixir
  Caddy.set_caddyfile(\"\"\"
  {
    debug
    admin unix//tmp/caddy.sock
  }

  example.com {
    reverse_proxy localhost:3000
  }
  \"\"\")
  ```

  If caddy_bin is not specified, Caddy.Server will not start.
  Set `caddy_bin` to the path of Caddy binary file and start `Caddy.Server`:

  ```elixir
  Caddy.set_bin("/usr/bin/caddy")
  Caddy.restart_server()
  ```

  This will restart server automatically:

  ```elixir
  Caddy.set_bin!("/usr/bin/caddy")
  ```

  ## Application Config

  ```elixir
  import Config

  # dump caddy server log to stdout
  config :caddy, dump_log: false

  # caddy server will not start, this is useful for testing
  config :caddy, start: false
  ```
  """

  @doc """
  Start the Caddy supervisor as part of a supervision tree.
  """
  @spec start_link(Keyword.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  defdelegate start_link(args), to: Caddy.Supervisor

  @doc """
  Restart Caddy Server
  """
  @spec restart_server :: {:ok, pid()} | {:ok, :undefined} | {:error, term()}
  defdelegate restart_server, to: Caddy.Supervisor

  @doc """
  Manually Start Caddy Server.

  This is useful when you want to start Caddy Server in `iex` console.
  """
  @spec start(binary()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start(caddy_bin), do: start_link(caddy_bin: caddy_bin)

  @spec start :: :ignore | {:error, any()} | {:ok, pid()}
  def start do
    caddy_bin = System.find_executable("caddy")
    start_link(caddy_bin: caddy_bin)
  end

  @doc """
  Stop Caddy Server
  """
  @spec stop(term()) :: :ok
  defdelegate stop(reason \\ :normal), to: Caddy.Supervisor

  # Binary path management
  @doc "Set Caddy binary path"
  defdelegate set_bin(bin_path), to: Caddy.ConfigProvider

  @doc "Set Caddy binary path and restart server"
  defdelegate set_bin!(bin_path), to: Caddy.ConfigProvider

  # Configuration management - text-based Caddyfile
  @doc "Set the Caddyfile configuration (raw text)"
  defdelegate set_caddyfile(caddyfile), to: Caddy.ConfigProvider

  @doc "Get the current Caddyfile configuration"
  defdelegate get_caddyfile(), to: Caddy.ConfigProvider

  @doc "Append content to the Caddyfile"
  defdelegate append_caddyfile(content), to: Caddy.ConfigProvider

  # Backup and restore
  @doc "Backup current configuration to file"
  defdelegate backup_config, to: Caddy.ConfigProvider

  @doc "Restore configuration from backup"
  defdelegate restore_config, to: Caddy.ConfigProvider

  @doc "Save current configuration"
  defdelegate save_config, to: Caddy.ConfigProvider

  @doc "Get current configuration struct"
  defdelegate get_config, to: Caddy.ConfigProvider

  @doc "Set configuration struct"
  defdelegate set_config(config), to: Caddy.ConfigProvider

  @doc "Adapt Caddyfile text to JSON (validates syntax)"
  defdelegate adapt(caddyfile), to: Caddy.ConfigProvider

  # ============================================================================
  # ConfigManager - Runtime Config Coordination
  # ============================================================================

  @doc """
  Get JSON config from running Caddy.

  Returns the current configuration from the running Caddy process via Admin API.
  """
  defdelegate get_runtime_config, to: Caddy.ConfigManager

  @doc """
  Get JSON config from running Caddy at specific path.

  ## Examples

      {:ok, servers} = Caddy.get_runtime_config("apps/http/servers")
  """
  defdelegate get_runtime_config(path), to: Caddy.ConfigManager

  @doc """
  Sync in-memory config to running Caddy.

  Adapts the Caddyfile and loads it into the running Caddy instance.

  ## Options

  - `:backup` - If true, backup current runtime config before sync (default: true)
  - `:force` - If true, skip validation (default: false)

  ## Examples

      :ok = Caddy.sync_to_caddy()
      :ok = Caddy.sync_to_caddy(backup: false)
  """
  defdelegate sync_to_caddy, to: Caddy.ConfigManager
  defdelegate sync_to_caddy(opts), to: Caddy.ConfigManager

  @doc """
  Pull runtime config from Caddy to memory.

  **DEPRECATED**: This function stores JSON in the Caddyfile field, which breaks
  the text-first design principle. It will be removed in v3.0.0.

  The Caddy Admin API returns JSON configuration, but there is no reverse
  conversion from JSON back to Caddyfile format. Use `get_runtime_config/0`
  to inspect the running configuration instead.
  """
  @compile {:no_warn_undefined, [{Caddy.ConfigManager, :sync_from_caddy, 0}]}
  @deprecated "Use get_runtime_config/0 instead. Will be removed in v3.0.0"
  def sync_from_caddy do
    # Suppress deprecation warning - intentional call to deprecated internal function
    apply(Caddy.ConfigManager, :sync_from_caddy, [])
  end

  @doc """
  Check if in-memory and runtime configs are in sync.

  Returns `{:ok, :in_sync}` if configs match, or `{:ok, {:drift_detected, diff}}`
  with information about the differences.
  """
  defdelegate check_sync_status, to: Caddy.ConfigManager

  @doc """
  Apply JSON config directly to running Caddy.

  Bypasses in-memory config - use for runtime-only changes.
  """
  defdelegate apply_runtime_config(config), to: Caddy.ConfigManager
  defdelegate apply_runtime_config(path, config), to: Caddy.ConfigManager

  @doc """
  Validate Caddyfile without applying.
  """
  defdelegate validate_caddyfile(caddyfile), to: Caddy.ConfigManager, as: :validate_config

  @doc """
  Rollback to last known good config.
  """
  defdelegate rollback, to: Caddy.ConfigManager

  # ============================================================================
  # State Machine
  # ============================================================================

  @doc """
  Get the current application state.

  Returns one of:
  - `:initializing` - Library starting up
  - `:unconfigured` - No Caddyfile set, waiting for configuration
  - `:configured` - Caddyfile set, pending sync to Caddy
  - `:synced` - Configuration synced to Caddy, operational
  - `:degraded` - Configuration synced but Caddy not responding

  ## Examples

      iex> Caddy.get_state()
      :unconfigured

      iex> Caddy.set_caddyfile("localhost { respond 200 }")
      :ok
      iex> Caddy.get_state()
      :configured
  """
  defdelegate get_state, to: Caddy.ConfigManager

  @doc """
  Check if the system is ready to serve requests.

  Returns `true` only when in `:synced` state (configuration has been
  successfully pushed to Caddy).

  ## Examples

      iex> Caddy.ready?()
      false

      iex> Caddy.sync_to_caddy()
      :ok
      iex> Caddy.ready?()
      true
  """
  defdelegate ready?, to: Caddy.ConfigManager

  @doc """
  Check if a Caddyfile configuration is set.

  Returns `true` when in `:configured`, `:synced`, or `:degraded` state.

  ## Examples

      iex> Caddy.configured?()
      false

      iex> Caddy.set_caddyfile("localhost { respond 200 }")
      :ok
      iex> Caddy.configured?()
      true
  """
  defdelegate configured?, to: Caddy.ConfigManager

  @doc """
  Clear the current configuration, returning to `:unconfigured` state.

  Can only be called from `:configured` state. Returns an error if called
  from other states.

  ## Examples

      iex> Caddy.clear_config()
      :ok
      iex> Caddy.get_state()
      :unconfigured
  """
  defdelegate clear_config, to: Caddy.ConfigManager
end
