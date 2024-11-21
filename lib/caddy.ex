defmodule Caddy do
  @moduledoc """
  # Caddy
  Start Caddy HTTP Server in supervisor tree
  """
  require Logger

  use Supervisor

  @spec start() :: :ignore | {:error, any()} | {:ok, pid()}
  def start() do
    caddy_bin = System.find_executable("caddy")
    start_link(caddy_bin: caddy_bin)
  end

  @spec stop(term()) :: :ok
  def stop(reason \\ :normal) do
    Supervisor.stop(__MODULE__, reason)
  end

  def saved_config() do
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    children = [
      {Caddy.Config, args},
      Caddy.Bootstrap,
      Caddy.Logger.Buffer,
      Caddy.Logger.Store,
      Caddy.Server,
      Caddy.Admin
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
