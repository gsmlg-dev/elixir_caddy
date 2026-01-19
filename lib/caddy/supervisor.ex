defmodule Caddy.Supervisor do
  @moduledoc """
  Main supervisor for the Caddy subsystem.

  Manages the Caddy configuration, logging, and server processes
  using a rest_for_one strategy to ensure proper restart ordering.

  ## Supervision Tree

  - `Caddy.ConfigProvider` - Agent for configuration management
  - `Caddy.ConfigManager` - GenServer coordinating in-memory and runtime config
  - `Caddy.Logger` - Logging subsystem with buffer and storage
  - `Caddy.Server` - GenServer managing the Caddy binary process

  The rest_for_one strategy ensures that if the ConfigProvider crashes,
  all subsequent children are restarted. If the ConfigManager crashes,
  Logger and Server are restarted.
  """

  use Supervisor

  @doc """
  Start the Caddy supervisor.

  ## Options

  - `:caddy_bin` - Path to the Caddy binary (optional)
  """
  @spec start_link(Keyword.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @dialyzer {:nowarn_function, init: 1}
  @impl true
  @spec init(any()) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init(args) do
    children = [
      {Caddy.ConfigProvider, [args]},
      {Caddy.ConfigManager, [args]},
      Caddy.Logger,
      Caddy.Server
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end

  @doc """
  Restart the Caddy Server child process.

  Returns `{:ok, pid()}` on successful restart, or `{:error, term()}` on failure.
  """
  @spec restart_server :: {:ok, pid()} | {:ok, :undefined} | {:error, term()}
  def restart_server do
    case Supervisor.restart_child(__MODULE__, Caddy.Server) do
      {:error, :running} ->
        Supervisor.terminate_child(__MODULE__, Caddy.Server)
        Supervisor.restart_child(__MODULE__, Caddy.Server)

      out ->
        out
    end
  end

  @doc """
  Stop the Caddy supervisor.
  """
  @spec stop(term()) :: :ok
  def stop(reason \\ :normal) do
    Supervisor.stop(__MODULE__, reason)
  end
end
