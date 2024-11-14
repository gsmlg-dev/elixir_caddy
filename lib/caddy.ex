defmodule Caddy do
  @moduledoc """
  # Caddy
  Start Caddy HTTP Server in supervisor tree
  """
  require Logger

  use Supervisor

  @spec start() :: :ignore | {:error, any()} | {:ok, pid()}
  def start() do
    start_link([])
  end

  @spec stop(term()) :: :ok
  def stop(reason \\ :normal) do
    Supervisor.stop(__MODULE__, reason)
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    children = [
      {Caddy.Bootstrap, args},
      Caddy.Server
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end

end
