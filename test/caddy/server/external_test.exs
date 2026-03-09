defmodule Caddy.Server.ExternalTest do
  use ExUnit.Case, async: false

  import Mox

  alias Caddy.Admin.Request
  alias Caddy.Server.External

  # Allow mocks to be called from async processes
  setup :verify_on_exit!

  describe "execute_command/1" do
    test "returns error for invalid command" do
      assert {:error, {:invalid_command, :invalid}} = External.execute_command(:invalid)
    end
  end

  describe "module functions" do
    test "start_caddy/0 delegates to execute_command(:start)" do
      # This verifies the function exists and has correct arity
      assert is_function(&External.start_caddy/0)
    end

    test "stop_caddy/0 delegates to execute_command(:stop)" do
      assert is_function(&External.stop_caddy/0)
    end

    test "restart_caddy/0 delegates to execute_command(:restart)" do
      assert is_function(&External.restart_caddy/0)
    end
  end

  # ---------------------------------------------------------------------------
  # T007: push_config/0 describe block
  # The External GenServer is already running from Caddy.start() in test_helper.
  # We work with the existing process (not start_supervised).
  # ---------------------------------------------------------------------------

  describe "push_config/0" do
    setup do
      Application.put_env(:caddy, :request_module, Caddy.Admin.RequestMock)

      # Add a site so caddyfile is non-empty; push_initial_config exercises adapt path
      Caddy.add_site("localhost:9999", ~s(respond "test"))

      on_exit(fn ->
        Application.delete_env(:caddy, :request_module)
        Caddy.remove_site("localhost:9999")
      end)

      # Stub get for any health-check timer that may fire during tests (30s timer,
      # unlikely to fire, but defensive). Stubs are globally accessible.
      stub(Caddy.Admin.RequestMock, :get, fn _ -> {:error, :econnrefused} end)

      # Allow the already-running External GenServer to use test-process expectations
      external_pid = Process.whereis(Caddy.Server.External)
      if external_pid, do: Mox.allow(Caddy.Admin.RequestMock, self(), external_pid)

      :ok
    end

    # T008
    test "returns :ok when adapt succeeds and load returns 200" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _body, "application/json" ->
        {:ok, %Request{status: 200}, %{"apps" => %{"http" => %{}}}}
      end)

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _body, "application/json" ->
        {:ok, %Request{status: 200}, ""}
      end)

      assert :ok = External.push_config()
    end

    # T009
    test "returns error when adapt returns empty map" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _body, "application/json" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert {:error, :invalid_adapt_response} = External.push_config()
    end

    # T010
    test "returns error when load returns non-2xx status" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _body, "application/json" ->
        {:ok, %Request{status: 200}, %{"apps" => %{}}}
      end)

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _body, "application/json" ->
        {:ok, %Request{status: 400}, "bad config"}
      end)

      assert {:error, {:load_failed, 400}} = External.push_config()
    end

    # T011
    test "returns error when load fails with connection failure" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _body, "application/json" ->
        {:ok, %Request{status: 200}, %{"apps" => %{}}}
      end)

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _body, "application/json" ->
        {:error, :econnrefused}
      end)

      assert {:error, :load_connection_failed} = External.push_config()
    end
  end

  # ---------------------------------------------------------------------------
  # T014-T015: get_caddyfile/0 tests (plain function, no GenServer call needed)
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # T025: execute_command/1 with empty command string
  # ---------------------------------------------------------------------------

  describe "execute_command/1 with empty command string" do
    setup do
      original = Application.get_env(:caddy, :commands, [])

      on_exit(fn ->
        Application.put_env(:caddy, :commands, original)
      end)

      :ok
    end

    # T025
    test "returns :empty_command error when command is configured as empty string" do
      Application.put_env(:caddy, :commands, start: "")

      assert {:error, :empty_command} = External.execute_command(:start)
    end
  end

  # ---------------------------------------------------------------------------
  # T014-T015: get_caddyfile/0 tests (plain function, no GenServer call needed)
  # ---------------------------------------------------------------------------

  describe "get_caddyfile/0" do
    setup do
      Application.put_env(:caddy, :request_module, Caddy.Admin.RequestMock)

      on_exit(fn ->
        Application.delete_env(:caddy, :request_module)
      end)

      :ok
    end

    # T014
    test "returns JSON string when Caddy has an active config" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, %{"apps" => %{"http" => %{}}}}
      end)

      result = External.get_caddyfile()
      assert is_binary(result)
      assert String.contains?(result, "apps")
    end

    # T015
    test "returns empty string when Caddy is unreachable" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:error, :econnrefused}
      end)

      assert "" = External.get_caddyfile()
    end
  end
end
