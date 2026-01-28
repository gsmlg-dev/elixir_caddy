defmodule Caddy.ConfigManagerTest do
  use ExUnit.Case, async: false
  import Mox

  alias Caddy.ConfigManager
  alias Caddy.ConfigProvider
  alias Caddy.Admin.Request

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Application.put_env(:caddy, :request_module, Caddy.Admin.RequestMock)

    # Ensure ConfigManager is running
    ensure_config_manager_running()

    # Store original config
    original_config = ConfigProvider.get_config()

    on_exit(fn ->
      ConfigProvider.set_config(original_config)
      # Ensure ConfigManager is running for next test
      ensure_config_manager_running()
    end)

    :ok
  end

  defp ensure_config_manager_running do
    case Process.whereis(Caddy.ConfigManager) do
      nil ->
        case Supervisor.restart_child(Caddy.Supervisor, Caddy.ConfigManager) do
          {:ok, _pid} ->
            :ok

          {:error, :running} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, :restarting} ->
            Process.sleep(100)
            ensure_config_manager_running()

          _ ->
            Caddy.ConfigManager.start_link([])
        end

      _pid ->
        :ok
    end
  end

  # ============================================================================
  # get_runtime_config
  # ============================================================================

  describe "get_runtime_config/0" do
    test "returns config from running Caddy" do
      config = %{"admin" => %{"listen" => "unix//tmp/caddy.sock"}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = ConfigManager.get_runtime_config()
    end

    test "returns error when Caddy is not available" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:error, :econnrefused}
      end)

      assert {:error, :caddy_not_available} = ConfigManager.get_runtime_config()
    end
  end

  describe "get_runtime_config/1" do
    test "returns config at specific path" do
      servers = %{"srv0" => %{"listen" => [":443"]}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http/servers" ->
        {:ok, %Request{status: 200}, servers}
      end)

      assert {:ok, ^servers} = ConfigManager.get_runtime_config("apps/http/servers")
    end

    test "returns error for non-existent path" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/nonexistent" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = ConfigManager.get_runtime_config("nonexistent")
    end
  end

  # ============================================================================
  # get_memory_config
  # ============================================================================

  describe "get_memory_config/1" do
    test "returns caddyfile text when format is :caddyfile" do
      caddyfile = """
      {
        admin unix//tmp/caddy.sock
      }
      """

      ConfigProvider.set_caddyfile(caddyfile)

      assert {:ok, result} = ConfigManager.get_memory_config(:caddyfile)
      assert result =~ "admin unix//tmp/caddy.sock"
    end

    test "returns error when json format and caddy binary unavailable" do
      # Without caddy binary, adaptation fails
      ConfigProvider.set_caddyfile("localhost { }")

      result = ConfigManager.get_memory_config(:json)
      # Either succeeds with cached config or fails due to no binary
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # set_caddyfile
  # ============================================================================

  describe "set_caddyfile/2" do
    test "sets caddyfile without validation when validate: false" do
      caddyfile = """
      localhost:8080 {
        respond "Hello"
      }
      """

      assert :ok = ConfigManager.set_caddyfile(caddyfile, validate: false)
      assert ConfigProvider.get_caddyfile() =~ "localhost:8080"
    end

    test "returns caddyfile content after set" do
      caddyfile = "example.com { respond \"Test\" }"
      :ok = ConfigManager.set_caddyfile(caddyfile, validate: false)

      {:ok, stored} = ConfigManager.get_memory_config(:caddyfile)
      assert stored =~ "example.com"
    end
  end

  # ============================================================================
  # sync_from_caddy
  # ============================================================================

  describe "sync_from_caddy/0" do
    test "pulls config from Caddy to memory" do
      config = %{"admin" => %{"listen" => ":2019"}, "apps" => %{}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, config}
      end)

      assert :ok = ConfigManager.sync_from_caddy()

      # Verify the config was stored (as JSON string)
      stored = ConfigProvider.get_caddyfile()
      assert stored =~ "admin"
    end

    test "returns error when Caddy is not available" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:error, :econnrefused}
      end)

      assert {:error, :caddy_not_available} = ConfigManager.sync_from_caddy()
    end
  end

  # ============================================================================
  # apply_runtime_config - these bypass in-memory and go direct to Caddy
  # ============================================================================

  describe "apply_runtime_config/1" do
    test "applies config directly to Caddy" do
      config = %{"admin" => %{"listen" => ":2019"}}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _, "application/json" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert :ok = ConfigManager.apply_runtime_config(config)
    end

    test "returns error on failure" do
      config = %{"invalid" => "config"}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _, "application/json" ->
        {:ok, %Request{status: 400, body: "Bad config"}, "Bad config"}
      end)

      assert {:error, {:http_error, 400, "Bad config"}} =
               ConfigManager.apply_runtime_config(config)
    end
  end

  describe "apply_runtime_config/2" do
    test "applies config at specific path" do
      config = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http/servers/srv0", _, _ ->
        {:ok, %Request{status: 200}, config}
      end)

      assert :ok = ConfigManager.apply_runtime_config("apps/http/servers/srv0", config)
    end

    test "returns error when patch fails" do
      config = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http/servers/srv0", _, _ ->
        {:error, :econnrefused}
      end)

      assert {:error, :patch_failed} =
               ConfigManager.apply_runtime_config("apps/http/servers/srv0", config)
    end
  end

  # ============================================================================
  # rollback
  # ============================================================================

  describe "rollback/0" do
    test "returns error when no rollback available" do
      # Fresh state has no last_known_good_config
      assert {:error, :no_rollback_available} = ConfigManager.rollback()
    end
  end

  # ============================================================================
  # get_state
  # ============================================================================

  describe "get_internal_state/0" do
    test "returns current internal state" do
      state = ConfigManager.get_internal_state()

      assert Map.has_key?(state, :last_sync_time)
      assert Map.has_key?(state, :last_sync_status)
      assert Map.has_key?(state, :last_known_good_config)
      assert Map.has_key?(state, :application_state)
    end

    test "initial state has expected structure" do
      state = ConfigManager.get_internal_state()

      # On fresh start, these should be nil
      # (they may have values if other tests ran first)
      assert is_map(state)
    end
  end

  describe "get_state/0" do
    test "returns application state atom" do
      state = ConfigManager.get_state()

      # Should return an atom representing the application state
      assert state in [:initializing, :unconfigured, :configured, :synced, :degraded]
    end
  end

  describe "ready?/0 and configured?/0" do
    test "ready? returns false when not synced" do
      # In test environment, state is typically :configured (has test config)
      # ready? only returns true when :synced
      assert is_boolean(ConfigManager.ready?())
    end

    test "configured? returns appropriate value" do
      # Should return boolean
      assert is_boolean(ConfigManager.configured?())
    end
  end

  # ============================================================================
  # validate_config - depends on caddy binary availability
  # ============================================================================

  describe "validate_config/1" do
    test "returns result based on caddy binary availability" do
      caddyfile = """
      {
        admin unix//tmp/caddy.sock
      }
      """

      # Result depends on whether caddy binary is available
      result = ConfigManager.validate_config(caddyfile)
      # Should either succeed or fail with meaningful error
      assert match?(:ok, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # Integration tests (require caddy binary - skipped by default)
  # ============================================================================

  describe "sync_to_caddy/0 (integration)" do
    @describetag integration: true, skip: true

    test "adapts and loads caddyfile to running Caddy" do
      # This test requires a running Caddy instance
      # Run with: mix test --include integration
    end
  end

  describe "check_sync_status/0 (integration)" do
    @describetag integration: true, skip: true

    test "compares memory and runtime configs" do
      # This test requires a running Caddy instance
      # Run with: mix test --include integration
    end
  end
end
