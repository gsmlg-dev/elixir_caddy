defmodule Caddy.Metrics do
  @moduledoc """
  Prometheus metrics integration for Caddy reverse proxy.

  Provides access to Caddy's Prometheus metrics endpoint, parsing the
  exposition format into Elixir data structures.

  ## Enabling Metrics in Caddy

  Add the `servers` metrics directive to your Caddyfile:

      {
        servers {
          metrics
        }
      }

  ## Usage

      # One-time fetch
      {:ok, metrics} = Caddy.Metrics.fetch()
      {:ok, raw_text} = Caddy.Metrics.fetch_raw()

      # Access specific metrics
      requests = Caddy.Metrics.get(metrics, :http_requests_total)

      # Health derivation
      Caddy.Metrics.healthy?(metrics)
      Caddy.Metrics.error_rate(metrics)
      Caddy.Metrics.latency_p99(metrics)

  ## Configuration

      config :caddy,
        metrics_enabled: true,
        metrics_interval: 15_000,
        metrics_endpoint: "/metrics"
  """

  alias Caddy.Admin.Api
  alias Caddy.Metrics.Parser
  alias Caddy.Telemetry

  @type label_set :: %{optional(atom()) => String.t()}

  @type t :: %__MODULE__{
          timestamp: DateTime.t(),
          http_requests_total: %{optional(label_set()) => number()},
          http_request_duration_seconds: %{optional(label_set()) => number()},
          http_request_size_bytes: %{optional(label_set()) => number()},
          http_response_size_bytes: %{optional(label_set()) => number()},
          tls_handshake_duration_seconds: %{optional(label_set()) => number()},
          tls_handshakes_total: %{optional(label_set()) => number()},
          reverse_proxy_upstreams_healthy: %{optional(label_set()) => number()},
          process_cpu_seconds_total: number() | nil,
          process_resident_memory_bytes: integer() | nil,
          process_open_fds: integer() | nil,
          raw: binary()
        }

  defstruct timestamp: nil,
            http_requests_total: %{},
            http_request_duration_seconds: %{},
            http_request_size_bytes: %{},
            http_response_size_bytes: %{},
            tls_handshake_duration_seconds: %{},
            tls_handshakes_total: %{},
            reverse_proxy_upstreams_healthy: %{},
            process_cpu_seconds_total: nil,
            process_resident_memory_bytes: nil,
            process_open_fds: nil,
            raw: ""

  @doc """
  Fetch and parse metrics from Caddy's Prometheus endpoint.

  Returns a structured `%Caddy.Metrics{}` struct with parsed metric values.

  ## Examples

      {:ok, metrics} = Caddy.Metrics.fetch()
      metrics.http_requests_total
      #=> %{%{server: "srv0", handler: "reverse_proxy", method: "GET", code: "200"} => 12345}
  """
  @spec fetch() :: {:ok, t()} | {:error, term()}
  def fetch do
    start_time = System.monotonic_time()

    case fetch_raw() do
      {:ok, raw_text} ->
        metrics = Parser.parse(raw_text)
        duration = System.monotonic_time() - start_time

        Telemetry.emit_metrics_event(:collected, %{duration: duration}, %{
          metric_count: count_metrics(metrics)
        })

        {:ok, metrics}

      {:error, reason} = error ->
        duration = System.monotonic_time() - start_time

        Telemetry.emit_metrics_event(:fetch_error, %{duration: duration}, %{
          error: reason
        })

        error
    end
  end

  @doc """
  Fetch raw Prometheus text from Caddy's metrics endpoint.

  Returns the raw Prometheus exposition format text.

  ## Examples

      {:ok, text} = Caddy.Metrics.fetch_raw()
      # Returns multi-line Prometheus format text
  """
  @spec fetch_raw() :: {:ok, binary()} | {:error, term()}
  def fetch_raw do
    endpoint = metrics_endpoint()

    case Api.get_metrics(endpoint) do
      {:ok, body} when is_binary(body) ->
        {:ok, body}

      {:error, reason} ->
        {:error, reason}

      nil ->
        {:error, :metrics_not_available}
    end
  end

  @doc """
  Get a specific metric value from parsed metrics.

  ## Supported Metrics

  - `:http_requests_total` - Total HTTP requests by labels
  - `:http_request_duration_seconds` - Request latency histograms
  - `:http_request_size_bytes` - Request body sizes
  - `:http_response_size_bytes` - Response body sizes
  - `:tls_handshake_duration_seconds` - TLS handshake latency
  - `:tls_handshakes_total` - Total TLS handshakes
  - `:reverse_proxy_upstreams_healthy` - Upstream health status
  - `:process_cpu_seconds_total` - Process CPU time
  - `:process_resident_memory_bytes` - Process memory usage
  - `:process_open_fds` - Open file descriptors

  ## Examples

      {:ok, metrics} = Caddy.Metrics.fetch()
      Caddy.Metrics.get(metrics, :http_requests_total)
      #=> %{%{server: "srv0", code: "200"} => 1234}
  """
  @spec get(t(), atom()) :: term()
  def get(%__MODULE__{} = metrics, metric_name) when is_atom(metric_name) do
    Map.get(metrics, metric_name)
  end

  @doc """
  Check if Caddy and upstreams are healthy based on metrics.

  Returns `true` if all reverse proxy upstreams report healthy status (value = 1).
  Returns `true` if no upstream metrics are available (no upstreams configured).

  ## Examples

      {:ok, metrics} = Caddy.Metrics.fetch()
      Caddy.Metrics.healthy?(metrics)
      #=> true
  """
  @spec healthy?(t()) :: boolean()
  def healthy?(%__MODULE__{reverse_proxy_upstreams_healthy: upstreams}) do
    if map_size(upstreams) == 0 do
      true
    else
      Enum.all?(upstreams, fn {_labels, value} -> value == 1 end)
    end
  end

  @doc """
  Calculate the error rate from HTTP request metrics.

  Returns the ratio of 5xx responses to total responses (0.0 to 1.0).
  Returns `0.0` if no request metrics are available.

  ## Examples

      {:ok, metrics} = Caddy.Metrics.fetch()
      Caddy.Metrics.error_rate(metrics)
      #=> 0.02  # 2% error rate
  """
  @spec error_rate(t()) :: float()
  def error_rate(%__MODULE__{http_requests_total: requests}) do
    if map_size(requests) == 0 do
      0.0
    else
      {errors, total} =
        Enum.reduce(requests, {0, 0}, fn {labels, count}, {err_acc, total_acc} ->
          code = Map.get(labels, :code, "")

          if String.starts_with?(code, "5") do
            {err_acc + count, total_acc + count}
          else
            {err_acc, total_acc + count}
          end
        end)

      if total > 0, do: errors / total, else: 0.0
    end
  end

  @doc """
  Get the p99 latency from request duration metrics.

  Returns the 99th percentile latency in seconds, or `nil` if not available.

  ## Examples

      {:ok, metrics} = Caddy.Metrics.fetch()
      Caddy.Metrics.latency_p99(metrics)
      #=> 0.234
  """
  @spec latency_p99(t()) :: float() | nil
  def latency_p99(%__MODULE__{http_request_duration_seconds: durations}) do
    # Find the 0.99 quantile value
    p99_entries =
      Enum.filter(durations, fn {labels, _value} ->
        Map.get(labels, :quantile) == "0.99"
      end)

    case p99_entries do
      [] -> nil
      entries -> entries |> Enum.map(fn {_k, v} -> v end) |> Enum.max()
    end
  end

  @doc """
  Get the median (p50) latency from request duration metrics.

  Returns the 50th percentile latency in seconds, or `nil` if not available.
  """
  @spec latency_p50(t()) :: float() | nil
  def latency_p50(%__MODULE__{http_request_duration_seconds: durations}) do
    p50_entries =
      Enum.filter(durations, fn {labels, _value} ->
        Map.get(labels, :quantile) == "0.5"
      end)

    case p50_entries do
      [] -> nil
      entries -> entries |> Enum.map(fn {_k, v} -> v end) |> Enum.max()
    end
  end

  @doc """
  Get total request count from metrics.
  """
  @spec total_requests(t()) :: integer()
  def total_requests(%__MODULE__{http_requests_total: requests}) do
    requests
    |> Map.values()
    |> Enum.sum()
    |> trunc()
  end

  # Configuration helpers

  @doc false
  def metrics_enabled? do
    Application.get_env(:caddy, :metrics_enabled, false)
  end

  @doc false
  def metrics_interval do
    Application.get_env(:caddy, :metrics_interval, 15_000)
  end

  @doc false
  def metrics_endpoint do
    Application.get_env(:caddy, :metrics_endpoint, "/metrics")
  end

  defp count_metrics(%__MODULE__{} = metrics) do
    [
      map_size(metrics.http_requests_total),
      map_size(metrics.http_request_duration_seconds),
      map_size(metrics.http_request_size_bytes),
      map_size(metrics.http_response_size_bytes),
      map_size(metrics.tls_handshake_duration_seconds),
      map_size(metrics.tls_handshakes_total),
      map_size(metrics.reverse_proxy_upstreams_healthy),
      if(metrics.process_cpu_seconds_total, do: 1, else: 0),
      if(metrics.process_resident_memory_bytes, do: 1, else: 0),
      if(metrics.process_open_fds, do: 1, else: 0)
    ]
    |> Enum.sum()
  end
end
