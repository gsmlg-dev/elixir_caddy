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
  Caddy.Cofnig.set_bin("/usr/bin/caddy")
  Caddy.restart_server()
  ```

  This will restart server automatically

  ```
  Caddy.Cofnig.set_bin!("/usr/bin/caddy")
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
  require Logger

  use Supervisor

  @doc """
  Restart Caddy Server
  """
  def restart_server() do
    case Supervisor.restart_child(__MODULE__, Caddy.Server) do
      {:error, :running} ->
        Supervisor.terminate_child(__MODULE__, Caddy.Server)
        Supervisor.restart_child(__MODULE__, Caddy.Server)

      out ->
        out
    end
  end

  @doc """
  Manually Start Caddy Server.

  This is useful when you want to start Caddy Server in `iex` console.

  """
  @spec start(binary()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start(caddy_bin), do: start_link(caddy_bin: caddy_bin)

  @spec start() :: :ignore | {:error, any()} | {:ok, pid()}
  def start() do
    caddy_bin = System.find_executable("caddy")
    start_link(caddy_bin: caddy_bin)
  end

  @spec stop(term()) :: :ok
  def stop(reason \\ :normal) do
    Supervisor.stop(__MODULE__, reason)
  end

  @spec start_link(Keyword.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  @spec init(any()) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init(args) do
    children = [
      {Caddy.Config, [args]},
      Caddy.Logger,
      Caddy.Server
      # Caddy.Admin
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
