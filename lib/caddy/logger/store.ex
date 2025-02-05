defmodule Caddy.Logger.Store do
  @moduledoc false

  require Logger

  use GenServer

  def write(log) do
    GenServer.cast(__MODULE__, {:write, log})
  end

  def tail(num \\ 100) do
    GenServer.call(__MODULE__, {:tail, num})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def handle_cast({:write, log}, state) do
    {:noreply, [log | state] |> Enum.take(50_000)}
  end

  def handle_call({:tail, n}, _from, state) do
    logs = state |> Enum.take(n) |> Enum.reverse()
    {:reply, logs, state}
  end
end
