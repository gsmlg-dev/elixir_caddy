defmodule Caddy.Metrics.Poller do
  @moduledoc """
  Periodic metrics collection from Caddy's Prometheus endpoint.

  This GenServer periodically fetches metrics from Caddy and emits
  telemetry events with the collected data.

  ## Configuration

      config :caddy,
        metrics_enabled: true,
        metrics_interval: 15_000  # milliseconds

  ## Starting the Poller

      # Manual start
      Caddy.Metrics.Poller.start_link(interval: 15_000)

      # Check if running
      Caddy.Metrics.Poller.running?()

      # Stop the poller
      Caddy.Metrics.Poller.stop()

  ## Telemetry Events

  When metrics are collected, the following event is emitted:

      [:caddy, :metrics, :collected]

  With measurements containing all parsed metric values.
  """

  use GenServer

  alias Caddy.Metrics
  alias Caddy.Telemetry

  @default_interval 15_000

  # Client API

  @doc """
  Start the metrics poller.

  ## Options

  - `:interval` - Polling interval in milliseconds (default: 15000)
  - `:name` - Process name (default: `Caddy.Metrics.Poller`)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Stop the metrics poller.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server \\ __MODULE__) do
    GenServer.stop(server, :normal)
  end

  @doc """
  Check if the poller is running.
  """
  @spec running?(GenServer.server()) :: boolean()
  def running?(server \\ __MODULE__) do
    case Process.whereis(server) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  Get the current interval setting.
  """
  @spec interval(GenServer.server()) :: pos_integer()
  def interval(server \\ __MODULE__) do
    GenServer.call(server, :get_interval)
  end

  @doc """
  Update the polling interval.
  """
  @spec set_interval(pos_integer(), GenServer.server()) :: :ok
  def set_interval(new_interval, server \\ __MODULE__)
      when is_integer(new_interval) and new_interval > 0 do
    GenServer.call(server, {:set_interval, new_interval})
  end

  @doc """
  Trigger an immediate metrics collection.
  """
  @spec poll_now(GenServer.server()) :: :ok
  def poll_now(server \\ __MODULE__) do
    send(server, :poll)
    :ok
  end

  @doc """
  Get the last collected metrics.
  """
  @spec last_metrics(GenServer.server()) :: Metrics.t() | nil
  def last_metrics(server \\ __MODULE__) do
    GenServer.call(server, :last_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, Metrics.metrics_interval() || @default_interval)

    state = %{
      interval: interval,
      last_metrics: nil,
      last_error: nil,
      poll_count: 0,
      error_count: 0
    }

    Telemetry.emit_metrics_event(:poller_started, %{}, %{interval: interval})

    # Schedule first poll
    schedule_poll(interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_interval, _from, state) do
    {:reply, state.interval, state}
  end

  def handle_call({:set_interval, new_interval}, _from, state) do
    {:reply, :ok, %{state | interval: new_interval}}
  end

  def handle_call(:last_metrics, _from, state) do
    {:reply, state.last_metrics, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state =
      case Metrics.fetch() do
        {:ok, metrics} ->
          emit_metrics_telemetry(metrics)

          %{state | last_metrics: metrics, last_error: nil, poll_count: state.poll_count + 1}

        {:error, reason} ->
          Telemetry.log_warning("Metrics fetch failed: #{inspect(reason)}",
            module: __MODULE__,
            error: reason
          )

          %{state | last_error: reason, error_count: state.error_count + 1}
      end

    # Schedule next poll
    schedule_poll(state.interval)

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Telemetry.emit_metrics_event(:poller_stopped, %{}, %{
      poll_count: state.poll_count,
      error_count: state.error_count
    })

    :ok
  end

  # Private Functions

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp emit_metrics_telemetry(%Metrics{} = metrics) do
    measurements = %{
      http_requests_total: Metrics.total_requests(metrics),
      error_rate: Metrics.error_rate(metrics),
      latency_p50: Metrics.latency_p50(metrics) || 0.0,
      latency_p99: Metrics.latency_p99(metrics) || 0.0,
      upstreams_healthy: if(Metrics.healthy?(metrics), do: 1, else: 0),
      process_cpu_seconds: metrics.process_cpu_seconds_total || 0.0,
      process_memory_bytes: metrics.process_resident_memory_bytes || 0,
      process_open_fds: metrics.process_open_fds || 0
    }

    :telemetry.execute(
      [:caddy, :metrics, :collected],
      measurements,
      %{timestamp: metrics.timestamp}
    )
  end
end
