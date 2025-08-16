defmodule Caddy.TelemetryTest do
  use ExUnit.Case
  alias Caddy.Telemetry

  setup do
    :ok
  end

  describe "telemetry events" do
    test "emit_config_change/3 emits configuration events" do
      :telemetry_test.attach_event_handlers(self(), [
        [:caddy, :config, :set]
      ])

      Telemetry.emit_config_change(:set, %{duration: 1000}, %{config_size: 5})
      assert_received {[:caddy, :config, :set], _, %{duration: 1000}, %{config_size: 5}}
    end

    test "emit_server_event/3 emits server events" do
      :telemetry_test.attach_event_handlers(self(), [
        [:caddy, :server, :start]
      ])

      Telemetry.emit_server_event(:start, %{duration: 2000}, %{pid: "#Port<0.123>"})
      assert_received {[:caddy, :server, :start], _, %{duration: 2000}, %{pid: "#Port<0.123>"}}
    end

    test "emit_api_event/3 emits API events" do
      :telemetry_test.attach_event_handlers(self(), [
        [:caddy, :api, :request]
      ])

      Telemetry.emit_api_event(:request, %{duration: 300, status: 200}, %{method: :get, path: "/config"})
      assert_received {[:caddy, :api, :request], _, %{duration: 300, status: 200}, %{method: :get, path: "/config"}}
    end

    test "emit_validation_event/3 emits validation events" do
      :telemetry_test.attach_event_handlers(self(), [
        [:caddy, :validation, :success]
      ])

      Telemetry.emit_validation_event(:success, %{duration: 50}, %{field: :global})
      assert_received {[:caddy, :validation, :success], _, %{duration: 50}, %{field: :global}}
    end

    test "emit_file_event/3 emits file events" do
      :telemetry_test.attach_event_handlers(self(), [
        [:caddy, :file, :read]
      ])

      Telemetry.emit_file_event(:read, %{duration: 25, size: 1024}, %{path: "/tmp/caddy.json"})
      assert_received {[:caddy, :file, :read], _, %{duration: 25, size: 1024}, %{path: "/tmp/caddy.json"}}
    end

    test "emit_adapt_event/3 emits adaptation events" do
      :telemetry_test.attach_event_handlers(self(), [
        [:caddy, :adapt, :success]
      ])

      Telemetry.emit_adapt_event(:success, %{duration: 500, config_size: 1024}, %{format: :caddyfile})
      assert_received {[:caddy, :adapt, :success], _, %{duration: 500, config_size: 1024}, %{format: :caddyfile}}
    end
  end

  describe "telemetry utilities" do
    test "list_events/0 returns list of all events" do
      events = Telemetry.list_events()
      assert is_list(events)
      assert [:caddy, :config, :set] in events
      assert [:caddy, :server, :start] in events
      assert [:caddy, :api, :request] in events
    end

    test "attach_handler/3 attaches telemetry handler" do
      handler = :test_handler
      events = [[:caddy, :config, :set]]
      
      :ok = Telemetry.attach_handler(handler, events, fn _event_name, _measurements, _metadata, _config ->
        send(self(), :telemetry_received)
      end)

      Telemetry.emit_config_change(:set, %{duration: 100}, %{test: true})
      assert_received :telemetry_received

      :ok = Telemetry.detach_handler(handler)
    end

    test "detach_handler/1 removes telemetry handler" do
      handler = :test_detach_handler
      events = [[:caddy, :config, :set]]
      
      :ok = Telemetry.attach_handler(handler, events, fn _event_name, _measurements, _metadata, _config ->
        send(self(), :telemetry_received)
      end)

      :ok = Telemetry.detach_handler(handler)
      
      Telemetry.emit_config_change(:set, %{duration: 200}, %{test: true})
      refute_received :telemetry_received
    end
  end
end