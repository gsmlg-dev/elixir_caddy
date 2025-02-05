defmodule Caddy.Logger do
  @moduledoc """

  Caddy Logger

  Start Caddy Logger

  """

  require Logger

  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Caddy.Logger.Buffer,
      Caddy.Logger.Store
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
