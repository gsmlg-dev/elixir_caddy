defmodule Caddy.Logger.Store do
  @moduledoc """
  GenServer that stores Caddy server log history.

  Maintains a rolling buffer of up to 50,000 log lines from the Caddy
  server. Provides access to recent logs via the `tail/1` function.

  ## Telemetry Events

  This module emits the following telemetry events:

    * `[:caddy, :log, :stored]` - When a log line is stored.
      Measurements: `%{store_size: integer(), duration: integer()}`
      Metadata: `%{message: binary(), trimmed: boolean()}`

    * `[:caddy, :log, :retrieved]` - When logs are retrieved via tail.
      Measurements: `%{lines: integer(), duration: integer()}`
      Metadata: `%{requested: integer(), available: integer()}`
  """

  require Logger

  @keep_lines 50_000

  use GenServer

  def write(log) do
    GenServer.cast(__MODULE__, {:write, log})
  end

  def tail(num \\ 100) do
    GenServer.call(__MODULE__, {:tail, num})
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def handle_cast({:write, log}, state) do
    start_time = System.monotonic_time()

    new_state = [log | state] |> Enum.take(@keep_lines)
    trimmed = length(state) + 1 > @keep_lines

    duration = System.monotonic_time() - start_time

    # Emit stored event
    Caddy.Telemetry.emit_log_event(
      :stored,
      %{
        store_size: length(new_state),
        duration: duration
      },
      %{message: log, trimmed: trimmed}
    )

    {:noreply, new_state}
  end

  def handle_call({:tail, n}, _from, state) do
    start_time = System.monotonic_time()

    logs = state |> Enum.take(n) |> Enum.reverse()

    duration = System.monotonic_time() - start_time

    # Emit retrieved event
    Caddy.Telemetry.emit_log_event(
      :retrieved,
      %{
        lines: length(logs),
        duration: duration
      },
      %{requested: n, available: length(state)}
    )

    {:reply, logs, state}
  end
end
