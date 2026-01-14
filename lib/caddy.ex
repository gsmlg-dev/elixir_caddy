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
end
