defmodule Caddy do
  @moduledoc """

  # Caddy

  Start Caddy HTTP Server in supervisor tree

  If caddy bin is set, caddy server will automate start when application start.

  - Start in extra_applications

  ```elixir
  def application do
    [
      extra_applications: [Caddy.Application]
    ]
  end
  ```

  * Notice

  If caddy_bin is not specifiy, Caddy.Server will not start.

  Set `caddy_bin` to the path of Caddy binary file and start `Caddy.Server`.

  ```
  Caddy.Config.set_bin("/usr/bin/caddy")
  Caddy.restart_server()
  ```

  This will restart server automatically

  ```
  Caddy.Config.set_bin!("/usr/bin/caddy")
  ```

  ## Config

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

  # Configuration management functions delegated to ConfigProvider
  defdelegate set_bin(bin_path), to: Caddy.ConfigProvider
  defdelegate set_bin!(bin_path), to: Caddy.ConfigProvider
  defdelegate set_global(global), to: Caddy.ConfigProvider
  defdelegate set_site(name, site), to: Caddy.ConfigProvider
  defdelegate backup_config, to: Caddy.ConfigProvider
  defdelegate restore_config, to: Caddy.ConfigProvider

  # Snippet management functions
  defdelegate set_snippet(name, snippet), to: Caddy.ConfigProvider
  defdelegate get_snippet(name), to: Caddy.ConfigProvider
  defdelegate remove_snippet(name), to: Caddy.ConfigProvider
  defdelegate get_snippets, to: Caddy.ConfigProvider

  # Deprecated functions
  @deprecated "Use set_snippet/2 instead"
  defdelegate set_additional(additionals), to: Caddy.ConfigProvider
end
