defmodule Caddy.Logger.Buffer do
  use GenServer

  def write(buf) do
    GenServer.cast(__MODULE__, {:write, buf})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, "", name: __MODULE__)
  end

  def init(args) do
    Logger.info("Caddy Logger Buffer init")
    {:ok, args}
  end

  def handle_cast({:write, data}, buf) do
    buffer = update_buffer(buf <> data)
    {:noreply, buffer}
  end

  def update_buffer(buffer) do
    case String.split(buffer, "\n") do
      [one] ->
        one

      ["" | rest] ->
        rest |> Enum.join("\n") |> update_buffer()

      [log | rest] ->
        Caddy.Logger.Store.write(log)
        rest |> Enum.join("\n") |> update_buffer()
    end
  end
end
