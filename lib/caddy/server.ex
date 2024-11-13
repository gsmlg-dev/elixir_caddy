defmodule Caddy.Server do
  @moduledoc """

  Caddy Server

  Start Caddy Server

  """
  require Logger

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.info("Caddy Server init")
    state = %{port: nil}
    Process.flag(:trap_exit, true)
    {:ok, state, {:continue, :start}}
  end

  def handle_continue(:start, state) do
    Logger.info("Staring Caddy Server...")
    cmd = "/usr/bin/caddy"
    cfg_path = Application.app_dir(:caddy, "priv/etc/init.json")
    port =
      Port.open(
        {:spawn_executable, cmd},
        [
          {:args, ["run", "--adapter", "json", "--config", cfg_path]},
          :stream,
          :binary,
          :exit_status,
          :hide,
          :use_stdio,
          :stderr_to_stdout
        ]
      )

    state = state |> Map.put(:port, port)
    {:noreply, state}
  end

  def handle_info({port, {:data, msg}}, state) do
    Logger.info("Caddy#{inspect(port)}: #{msg |> String.trim_trailing()}")
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, exit_status}}, state) do
    Logger.info("Caddy#{inspect(port)}: exit_status: #{exit_status}")
    Process.exit(self(), :normal)
    {:noreply, state}
  end

  # handle the trapped exit call
  def handle_info({:EXIT, _from, reason}, state) do
    Logger.info("Caddy.Server exiting")
    cleanup(reason, state)
    {:stop, reason, state}
  end

  # handle termination
  def terminate(reason, state) do
    Logger.info("Caddy.Server terminating")
    cleanup(reason, state)
    state
  end

  defp cleanup(_reason, state) do
    case state |> Map.get(:port) |> Port.info(:os_pid) do
      {:os_pid, pid} ->
        {_, code} = System.cmd("kill", ["-9", "#{pid}"])
        code

      _ ->
        0
    end
  end
end
