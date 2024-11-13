defmodule Caddy do
  @moduledoc """
  # Caddy
  Start Caddy HTTP Server in supervisor tree
  """
  require Logger

  use Supervisor

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: {:ok, {sup_flags(), [child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init(_init_arg) do
    children = [
      Caddy.Server
    ]

    opts = [strategy: :one_for_rest, name: __MODULE__]

    Supervisor.init(children, opts)
  end

end
