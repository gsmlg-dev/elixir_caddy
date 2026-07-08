defmodule Caddy.SupervisorTest do
  use ExUnit.Case, async: false

  setup do
    original_metrics_enabled = Application.get_env(:caddy, :metrics_enabled)
    original_metrics_interval = Application.get_env(:caddy, :metrics_interval)

    on_exit(fn ->
      restore_env(:metrics_enabled, original_metrics_enabled)
      restore_env(:metrics_interval, original_metrics_interval)
    end)

    :ok
  end

  test "does not supervise metrics poller by default" do
    Application.delete_env(:caddy, :metrics_enabled)

    assert {:ok, {_opts, children}} = Caddy.Supervisor.init([])

    refute Caddy.Metrics.Poller in child_ids(children)
  end

  test "supervises metrics poller when metrics are enabled" do
    Application.put_env(:caddy, :metrics_enabled, true)
    Application.put_env(:caddy, :metrics_interval, 1_234)

    assert {:ok, {_opts, children}} = Caddy.Supervisor.init([])

    assert Caddy.Metrics.Poller in child_ids(children)

    poller = Enum.find(children, &(&1.id == Caddy.Metrics.Poller))
    assert {Caddy.Metrics.Poller, :start_link, [[interval: 1_234]]} = poller.start
  end

  defp child_ids(children), do: Enum.map(children, & &1.id)

  defp restore_env(key, nil), do: Application.delete_env(:caddy, key)
  defp restore_env(key, value), do: Application.put_env(:caddy, key, value)
end
