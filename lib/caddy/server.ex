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
    # remove pidfile if exists
    if Caddy.Bootstrap.get(:pidfile) |> File.exists? do
      pid = Caddy.Bootstrap.get(:pidfile) |> File.read!() |> String.trim()
      Logger.info("Caddy Server init: pidfile exists: #{pid}")
      File.rm(Caddy.Bootstrap.get(:pidfile))
      System.cmd("kill", ["-9", "#{pid}"])
    end
    Logger.info("Caddy Server init")
    state = %{port: nil}
    Process.flag(:trap_exit, true)
    {:ok, state, {:continue, :start}}
  end

  def handle_continue(:start, state) do
    Logger.info("Staring Caddy Server...")
    with bin_path <- Caddy.Bootstrap.get(:bin_path),
      init_config <- Caddy.Bootstrap.get(:config_path),
      pidfile <- Caddy.Bootstrap.get(:pidfile),
      envfile <- Caddy.Bootstrap.get(:envfile),
      port <- port_start(bin_path, %{file: init_config, pid: pidfile, env: envfile}) do
        state = state |> Map.put(:port, port)
        {:noreply, state}
      else
        error ->
          {:stop, error}
    end
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
  end

  defp cleanup(reason, %{port: port} = _state) do
    case port |> Port.info(:os_pid) do
      {:os_pid, pid} ->
        {_, code} = System.cmd("kill", ["-9", "#{pid}"])
        code

      _ ->
        0
    end
    Port.close(port)
    case reason do
      :normal -> :normal
      :shutdown -> :shutdown
      term -> {:shutdown, term}
    end
  end

  defp port_start(bin_path, config) do
    args = [
      "run",
      "--environ",
      "--envfile", config[:env],
      "--config", config[:file],
      "--pidfile", config[:pid]
    ]
    Port.open(
        {:spawn_executable, bin_path},
        [
          {:args, args},
          :stream,
          :binary,
          :exit_status,
          :hide,
          :use_stdio,
          :stderr_to_stdout
        ]
      )
  end
end
