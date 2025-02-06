defmodule Caddy.Logger.Buffer do
  @moduledoc false

  use GenServer
  require Logger

  def write(buf) do
    GenServer.cast(__MODULE__, {:write, buf})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, "", name: __MODULE__)
  end

  def init(args) do
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
        write_to_console(log)
        rest |> Enum.join("\n") |> update_buffer()
    end
  end

  defp write_to_console(log) do
    case Application.get_env(:caddy, Caddy.Logger.Buffer, :write_console) do
      true ->
        IO.puts(log)

      _ ->
        nil
    end
  end
end
