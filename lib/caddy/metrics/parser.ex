defmodule Caddy.Metrics.Parser do
  @moduledoc """
  Prometheus text format parser.

  Parses Prometheus exposition format into `%Caddy.Metrics{}` structs.

  ## Prometheus Format

  The Prometheus text format consists of:
  - Comments starting with `#`
  - HELP lines: `# HELP metric_name description`
  - TYPE lines: `# TYPE metric_name type`
  - Metric lines: `metric_name{label="value"} number timestamp?`

  ## Supported Metric Types

  - `counter` - Monotonically increasing value
  - `gauge` - Value that can go up or down
  - `histogram` - Buckets + sum + count
  - `summary` - Quantiles + sum + count
  """

  alias Caddy.Metrics

  @known_metrics %{
    "caddy_http_requests_total" => :http_requests_total,
    "caddy_http_request_duration_seconds" => :http_request_duration_seconds,
    "caddy_http_request_size_bytes" => :http_request_size_bytes,
    "caddy_http_response_size_bytes" => :http_response_size_bytes,
    "caddy_tls_handshake_duration_seconds" => :tls_handshake_duration_seconds,
    "caddy_tls_handshakes_total" => :tls_handshakes_total,
    "caddy_reverse_proxy_upstreams_healthy" => :reverse_proxy_upstreams_healthy,
    "process_cpu_seconds_total" => :process_cpu_seconds_total,
    "process_resident_memory_bytes" => :process_resident_memory_bytes,
    "process_open_fds" => :process_open_fds
  }

  @doc """
  Parse Prometheus text format into a Metrics struct.

  ## Examples

      text = \"\"\"
      # HELP caddy_http_requests_total Total HTTP requests
      # TYPE caddy_http_requests_total counter
      caddy_http_requests_total{server="srv0",code="200"} 1234
      \"\"\"

      metrics = Caddy.Metrics.Parser.parse(text)
      metrics.http_requests_total
      #=> %{%{server: "srv0", code: "200"} => 1234}
  """
  @spec parse(binary()) :: Metrics.t()
  def parse(text) when is_binary(text) do
    metrics = %Metrics{
      timestamp: DateTime.utc_now(),
      raw: text
    }

    text
    |> String.split("\n")
    |> Enum.reject(&comment_or_empty?/1)
    |> Enum.reduce(metrics, &parse_line/2)
  end

  defp comment_or_empty?(line) do
    trimmed = String.trim(line)
    trimmed == "" or String.starts_with?(trimmed, "#")
  end

  defp parse_line(line, metrics) do
    case parse_metric_line(line) do
      {:ok, metric_name, labels, value} ->
        update_metrics(metrics, metric_name, labels, value)

      :ignore ->
        metrics
    end
  end

  defp parse_metric_line(line) do
    # Match: metric_name{label="value",...} value [timestamp]
    # Or: metric_name value [timestamp]
    case Regex.run(~r/^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{[^}]*\})?\s+([^\s]+)/, line) do
      [_, metric_name, labels_str, value_str] ->
        labels = parse_labels(labels_str || "")
        value = parse_value(value_str)
        {:ok, metric_name, labels, value}

      _ ->
        :ignore
    end
  end

  defp parse_labels(""), do: %{}

  defp parse_labels("{" <> rest) do
    # Remove trailing }
    content = String.trim_trailing(rest, "}")

    content
    |> String.split(",")
    |> Enum.map(&parse_label/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp parse_labels(_), do: %{}

  defp parse_label(label_str) do
    case Regex.run(~r/([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"/, label_str) do
      [_, key, value] ->
        {String.to_atom(key), value}

      _ ->
        nil
    end
  end

  defp parse_value(value_str) do
    case Float.parse(value_str) do
      {float_val, ""} ->
        float_val

      {float_val, _} ->
        float_val

      :error ->
        case Integer.parse(value_str) do
          {int_val, ""} -> int_val
          {int_val, _} -> int_val
          :error -> 0
        end
    end
  end

  defp update_metrics(metrics, metric_name, labels, value) do
    case Map.get(@known_metrics, metric_name) do
      nil ->
        # Unknown metric, skip
        metrics

      :process_cpu_seconds_total ->
        %{metrics | process_cpu_seconds_total: value}

      :process_resident_memory_bytes ->
        %{metrics | process_resident_memory_bytes: trunc(value)}

      :process_open_fds ->
        %{metrics | process_open_fds: trunc(value)}

      field when is_atom(field) ->
        # Multi-value metric with labels
        current = Map.get(metrics, field, %{})
        updated = Map.put(current, labels, value)
        Map.put(metrics, field, updated)
    end
  end
end
