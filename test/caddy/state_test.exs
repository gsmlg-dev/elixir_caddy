defmodule Caddy.StateTest do
  use ExUnit.Case, async: true

  alias Caddy.State

  describe "initial_state/1" do
    test "returns :configured when has_config is true" do
      assert State.initial_state(true) == :configured
    end

    test "returns :unconfigured when has_config is false" do
      assert State.initial_state(false) == :unconfigured
    end
  end

  describe "transition/2" do
    test "initializing -> unconfigured on startup_empty" do
      assert {:ok, :unconfigured} = State.transition(:initializing, :startup_empty)
    end

    test "initializing -> configured on startup_with_config" do
      assert {:ok, :configured} = State.transition(:initializing, :startup_with_config)
    end

    test "unconfigured -> configured on config_set" do
      assert {:ok, :configured} = State.transition(:unconfigured, :config_set)
    end

    test "configured -> synced on sync_success" do
      assert {:ok, :synced} = State.transition(:configured, :sync_success)
    end

    test "configured stays configured on sync_failure" do
      assert {:ok, :configured} = State.transition(:configured, :sync_failure)
    end

    test "configured -> unconfigured on config_cleared" do
      assert {:ok, :unconfigured} = State.transition(:configured, :config_cleared)
    end

    test "synced -> configured on config_set" do
      assert {:ok, :synced} = State.transition(:synced, :sync_success)
      assert {:ok, :configured} = State.transition(:synced, :config_set)
    end

    test "synced -> degraded on health_fail" do
      assert {:ok, :degraded} = State.transition(:synced, :health_fail)
    end

    test "synced stays synced on health_ok" do
      assert {:ok, :synced} = State.transition(:synced, :health_ok)
    end

    test "degraded -> synced on health_ok" do
      assert {:ok, :synced} = State.transition(:degraded, :health_ok)
    end

    test "degraded -> synced on sync_success" do
      assert {:ok, :synced} = State.transition(:degraded, :sync_success)
    end

    test "degraded stays degraded on sync_failure" do
      assert {:ok, :degraded} = State.transition(:degraded, :sync_failure)
    end

    test "returns error for invalid transitions" do
      assert {:error, :invalid_transition} = State.transition(:unconfigured, :sync_success)
      assert {:error, :invalid_transition} = State.transition(:synced, :startup_empty)
      assert {:error, :invalid_transition} = State.transition(:degraded, :config_cleared)
    end
  end

  describe "transition!/2" do
    test "returns new state for valid transitions" do
      assert :unconfigured = State.transition!(:initializing, :startup_empty)
      assert :configured = State.transition!(:unconfigured, :config_set)
    end

    test "raises for invalid transitions" do
      assert_raise ArgumentError, ~r/Invalid state transition/, fn ->
        State.transition!(:unconfigured, :sync_success)
      end
    end
  end

  describe "valid_transition?/2" do
    test "returns true for valid transitions" do
      assert State.valid_transition?(:initializing, :unconfigured)
      assert State.valid_transition?(:initializing, :configured)
      assert State.valid_transition?(:unconfigured, :configured)
      assert State.valid_transition?(:configured, :synced)
      assert State.valid_transition?(:synced, :degraded)
      assert State.valid_transition?(:degraded, :synced)
    end

    test "returns false for invalid transitions" do
      refute State.valid_transition?(:unconfigured, :synced)
      refute State.valid_transition?(:unconfigured, :degraded)
      refute State.valid_transition?(:synced, :unconfigured)
      refute State.valid_transition?(:degraded, :unconfigured)
    end
  end

  describe "ready?/1" do
    test "returns true only for :synced" do
      assert State.ready?(:synced)
      refute State.ready?(:initializing)
      refute State.ready?(:unconfigured)
      refute State.ready?(:configured)
      refute State.ready?(:degraded)
    end
  end

  describe "configured?/1" do
    test "returns true for configured, synced, degraded" do
      assert State.configured?(:configured)
      assert State.configured?(:synced)
      assert State.configured?(:degraded)
      refute State.configured?(:initializing)
      refute State.configured?(:unconfigured)
    end
  end

  describe "degraded?/1" do
    test "returns true only for :degraded" do
      assert State.degraded?(:degraded)
      refute State.degraded?(:synced)
      refute State.degraded?(:configured)
    end
  end

  describe "describe/1" do
    test "returns human-readable descriptions" do
      assert State.describe(:initializing) =~ "starting"
      assert State.describe(:unconfigured) =~ "No Caddyfile"
      assert State.describe(:configured) =~ "pending sync"
      assert State.describe(:synced) =~ "operational"
      assert State.describe(:degraded) =~ "not responding"
    end
  end

  describe "full lifecycle" do
    test "complete happy path" do
      # Start empty
      assert {:ok, state} = State.transition(:initializing, :startup_empty)
      assert state == :unconfigured
      refute State.configured?(state)

      # Set config
      assert {:ok, state} = State.transition(state, :config_set)
      assert state == :configured
      assert State.configured?(state)
      refute State.ready?(state)

      # Sync to Caddy
      assert {:ok, state} = State.transition(state, :sync_success)
      assert state == :synced
      assert State.ready?(state)

      # Health check passes
      assert {:ok, state} = State.transition(state, :health_ok)
      assert state == :synced
    end

    test "degraded recovery path" do
      # Start synced
      state = :synced

      # Health check fails
      assert {:ok, state} = State.transition(state, :health_fail)
      assert state == :degraded
      assert State.degraded?(state)
      refute State.ready?(state)

      # Retry sync succeeds
      assert {:ok, state} = State.transition(state, :sync_success)
      assert state == :synced
      assert State.ready?(state)
    end

    test "config update path" do
      # Start synced
      state = :synced

      # New config set
      assert {:ok, state} = State.transition(state, :config_set)
      assert state == :configured
      refute State.ready?(state)

      # Sync new config
      assert {:ok, state} = State.transition(state, :sync_success)
      assert state == :synced
      assert State.ready?(state)
    end
  end
end
