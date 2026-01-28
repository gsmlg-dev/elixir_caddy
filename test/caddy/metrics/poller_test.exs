defmodule Caddy.Metrics.PollerTest do
  use ExUnit.Case

  alias Caddy.Metrics.Poller

  describe "start_link/1" do
    test "starts with default interval" do
      name = :"poller_test_#{:erlang.unique_integer()}"
      {:ok, pid} = Poller.start_link(name: name)

      assert Process.alive?(pid)
      assert Poller.interval(name) == 15_000

      Poller.stop(name)
    end

    test "starts with custom interval" do
      name = :"poller_test_#{:erlang.unique_integer()}"
      {:ok, pid} = Poller.start_link(name: name, interval: 5_000)

      assert Process.alive?(pid)
      assert Poller.interval(name) == 5_000

      Poller.stop(name)
    end
  end

  describe "running?/1" do
    test "returns false when not started" do
      refute Poller.running?(:"nonexistent_poller_#{:erlang.unique_integer()}")
    end

    test "returns true when running" do
      name = :"poller_test_#{:erlang.unique_integer()}"
      {:ok, _pid} = Poller.start_link(name: name)

      assert Poller.running?(name)

      Poller.stop(name)
    end

    test "returns false after stopped" do
      name = :"poller_test_#{:erlang.unique_integer()}"
      {:ok, _pid} = Poller.start_link(name: name)
      Poller.stop(name)

      # Give it a moment to stop
      Process.sleep(10)
      refute Poller.running?(name)
    end
  end

  describe "set_interval/2" do
    test "updates the polling interval" do
      name = :"poller_test_#{:erlang.unique_integer()}"
      {:ok, _pid} = Poller.start_link(name: name, interval: 10_000)

      assert Poller.interval(name) == 10_000

      :ok = Poller.set_interval(5_000, name)
      assert Poller.interval(name) == 5_000

      Poller.stop(name)
    end
  end

  describe "last_metrics/1" do
    test "returns nil initially" do
      name = :"poller_test_#{:erlang.unique_integer()}"
      {:ok, _pid} = Poller.start_link(name: name, interval: 60_000)

      assert Poller.last_metrics(name) == nil

      Poller.stop(name)
    end
  end
end
