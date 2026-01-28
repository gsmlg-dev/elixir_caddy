defmodule Caddy.MetricsTest do
  use ExUnit.Case, async: true

  alias Caddy.Metrics
  alias Caddy.Metrics.Parser

  describe "Parser.parse/1" do
    test "parses empty input" do
      metrics = Parser.parse("")
      assert %Metrics{} = metrics
      assert metrics.http_requests_total == %{}
    end

    test "parses comments and empty lines" do
      input = """
      # HELP caddy_http_requests_total Total HTTP requests
      # TYPE caddy_http_requests_total counter

      # Another comment
      """

      metrics = Parser.parse(input)
      assert %Metrics{} = metrics
    end

    test "parses counter metric with labels" do
      input = """
      caddy_http_requests_total{server="srv0",handler="reverse_proxy",method="GET",code="200"} 1234
      """

      metrics = Parser.parse(input)

      expected_labels = %{server: "srv0", handler: "reverse_proxy", method: "GET", code: "200"}
      assert Map.get(metrics.http_requests_total, expected_labels) == 1234
    end

    test "parses multiple label combinations" do
      input = """
      caddy_http_requests_total{server="srv0",code="200"} 1000
      caddy_http_requests_total{server="srv0",code="404"} 50
      caddy_http_requests_total{server="srv0",code="500"} 10
      """

      metrics = Parser.parse(input)

      assert Map.get(metrics.http_requests_total, %{server: "srv0", code: "200"}) == 1000
      assert Map.get(metrics.http_requests_total, %{server: "srv0", code: "404"}) == 50
      assert Map.get(metrics.http_requests_total, %{server: "srv0", code: "500"}) == 10
    end

    test "parses histogram quantiles" do
      input = """
      caddy_http_request_duration_seconds{server="srv0",quantile="0.5"} 0.023
      caddy_http_request_duration_seconds{server="srv0",quantile="0.9"} 0.089
      caddy_http_request_duration_seconds{server="srv0",quantile="0.99"} 0.234
      """

      metrics = Parser.parse(input)

      assert Map.get(metrics.http_request_duration_seconds, %{server: "srv0", quantile: "0.5"}) ==
               0.023

      assert Map.get(metrics.http_request_duration_seconds, %{server: "srv0", quantile: "0.99"}) ==
               0.234
    end

    test "parses process metrics without labels" do
      input = """
      process_cpu_seconds_total 123.45
      process_resident_memory_bytes 67890123
      process_open_fds 42
      """

      metrics = Parser.parse(input)

      assert metrics.process_cpu_seconds_total == 123.45
      assert metrics.process_resident_memory_bytes == 67_890_123
      assert metrics.process_open_fds == 42
    end

    test "parses reverse proxy upstream health" do
      input = """
      caddy_reverse_proxy_upstreams_healthy{upstream="localhost:4000"} 1
      caddy_reverse_proxy_upstreams_healthy{upstream="localhost:4001"} 0
      """

      metrics = Parser.parse(input)

      assert Map.get(metrics.reverse_proxy_upstreams_healthy, %{upstream: "localhost:4000"}) == 1
      assert Map.get(metrics.reverse_proxy_upstreams_healthy, %{upstream: "localhost:4001"}) == 0
    end

    test "stores raw text" do
      input = "caddy_http_requests_total 100"
      metrics = Parser.parse(input)
      assert metrics.raw == input
    end

    test "sets timestamp" do
      metrics = Parser.parse("")
      assert %DateTime{} = metrics.timestamp
    end
  end

  describe "healthy?/1" do
    test "returns true when no upstreams configured" do
      metrics = %Metrics{reverse_proxy_upstreams_healthy: %{}}
      assert Metrics.healthy?(metrics)
    end

    test "returns true when all upstreams healthy" do
      metrics = %Metrics{
        reverse_proxy_upstreams_healthy: %{
          %{upstream: "localhost:4000"} => 1,
          %{upstream: "localhost:4001"} => 1
        }
      }

      assert Metrics.healthy?(metrics)
    end

    test "returns false when any upstream unhealthy" do
      metrics = %Metrics{
        reverse_proxy_upstreams_healthy: %{
          %{upstream: "localhost:4000"} => 1,
          %{upstream: "localhost:4001"} => 0
        }
      }

      refute Metrics.healthy?(metrics)
    end
  end

  describe "error_rate/1" do
    test "returns 0.0 when no requests" do
      metrics = %Metrics{http_requests_total: %{}}
      assert Metrics.error_rate(metrics) == 0.0
    end

    test "returns 0.0 when no 5xx errors" do
      metrics = %Metrics{
        http_requests_total: %{
          %{code: "200"} => 100,
          %{code: "404"} => 10
        }
      }

      assert Metrics.error_rate(metrics) == 0.0
    end

    test "calculates error rate correctly" do
      metrics = %Metrics{
        http_requests_total: %{
          %{code: "200"} => 90,
          %{code: "500"} => 5,
          %{code: "502"} => 5
        }
      }

      # 10/100 = 10%
      assert Metrics.error_rate(metrics) == 0.1
    end
  end

  describe "latency_p99/1" do
    test "returns nil when no latency data" do
      metrics = %Metrics{http_request_duration_seconds: %{}}
      assert Metrics.latency_p99(metrics) == nil
    end

    test "returns p99 value when available" do
      metrics = %Metrics{
        http_request_duration_seconds: %{
          %{quantile: "0.5"} => 0.023,
          %{quantile: "0.99"} => 0.234
        }
      }

      assert Metrics.latency_p99(metrics) == 0.234
    end
  end

  describe "latency_p50/1" do
    test "returns p50 value when available" do
      metrics = %Metrics{
        http_request_duration_seconds: %{
          %{quantile: "0.5"} => 0.023,
          %{quantile: "0.99"} => 0.234
        }
      }

      assert Metrics.latency_p50(metrics) == 0.023
    end
  end

  describe "total_requests/1" do
    test "returns 0 when no requests" do
      metrics = %Metrics{http_requests_total: %{}}
      assert Metrics.total_requests(metrics) == 0
    end

    test "sums all request counts" do
      metrics = %Metrics{
        http_requests_total: %{
          %{code: "200"} => 100,
          %{code: "404"} => 20,
          %{code: "500"} => 5
        }
      }

      assert Metrics.total_requests(metrics) == 125
    end
  end

  describe "get/2" do
    test "returns metric value by name" do
      metrics = %Metrics{
        process_cpu_seconds_total: 123.45,
        http_requests_total: %{%{code: "200"} => 100}
      }

      assert Metrics.get(metrics, :process_cpu_seconds_total) == 123.45
      assert Metrics.get(metrics, :http_requests_total) == %{%{code: "200"} => 100}
    end
  end
end
