defmodule Caddy.Logger.Buffer do
  @moduledoc """
  GenServer that buffers log messages before writing to storage.

  Collects log output from the Caddy server process and buffers
  messages until complete lines are received. When newlines are
  detected, complete log lines are flushed to the Logger.Store.

  ## Telemetry Events

  This module emits the following telemetry events:

    * `[:caddy, :log, :buffered]` - When data is received and buffered.
      Measurements: `%{size: integer(), buffer_size: integer()}`
      Metadata: `%{source: :caddy_process}`

    * `[:caddy, :log, :buffer_flush]` - When complete lines are flushed to Store.
      Measurements: `%{lines: integer()}`
      Metadata: `%{}`
  """

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
    new_buffer = buf <> data

    # Emit buffered event
    Caddy.Telemetry.emit_log_event(
      :buffered,
      %{
        size: byte_size(data),
        buffer_size: byte_size(new_buffer)
      },
      %{source: :caddy_process}
    )

    buffer = update_buffer(new_buffer)
    {:noreply, buffer}
  end

  def update_buffer(buffer) do
    case String.split(buffer, "\n") do
      [one] ->
        one

      ["" | rest] ->
        rest |> Enum.join("\n") |> update_buffer()

      lines when length(lines) > 1 ->
        complete_lines = Enum.drop(lines, -1)
        remaining = List.last(lines)

        # Emit buffer_flush event
        Caddy.Telemetry.emit_log_event(
          :buffer_flush,
          %{lines: length(complete_lines)},
          %{}
        )

        # Write complete lines to store
        Enum.each(complete_lines, &Caddy.Logger.Store.write/1)

        remaining
    end
  end
end
