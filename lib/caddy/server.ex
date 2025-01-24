defmodule Caddy.Server do
  @moduledoc """

  Caddy Server

  Start Caddy Server

  """
  require Logger
  alias Caddy.Config

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Caddy.Bootstrap.init()
    state = %{port: nil}
    Process.flag(:trap_exit, true)
    {:ok, state, {:continue, :start}}
  end

  def handle_continue(:start, state) do
    Logger.debug("Caddy Server Starting")
    config = Config.get_config()

    port = port_start(config)
    state = state |> Map.put(:port, port)
    {:noreply, state}
  end

  def handle_info({_port, {:data, msg}}, state) do
    Caddy.Logger.Buffer.write(msg)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, exit_status}}, state) do
    Logger.warning("Caddy#{inspect(port)}: exit_status: #{exit_status}")
    Process.exit(self(), :normal)
    {:noreply, state}
  end

  # handle the trapped exit call
  def handle_info({:EXIT, _from, reason}, state) do
    Logger.debug("Caddy.Server exiting")
    cleanup(reason, state)
    {:stop, reason, state}
  end

  # handle termination
  def terminate(reason, state) do
    Logger.debug("Caddy.Server terminating")
    cleanup(reason, state)
    Caddy.Logger.Store.tail() |> Enum.each(&IO.puts("    " <> &1))
  end

  defp cleanup(reason, %{port: port} = _state) do
    case port |> Port.info(:os_pid) do
      {:os_pid, pid} ->
        {_, code} = System.cmd("kill", ["-9", "#{pid}"])
        code

      _ ->
        0
    end

    pidfile = Config.pid_file()

    if pidfile |> File.exists?() do
      File.rm(pidfile)
    end

    case reason do
      :normal -> :normal
      :shutdown -> :shutdown
      term -> {:shutdown, term}
    end
  end

  defp port_start(%Config{bin: bin_path, env: env}) do
    args = [
      "run",
      "--config",
      Config.init_file(),
      "--pidfile",
      Config.pid_file()
    ]

    Port.open(
      {:spawn_executable, bin_path},
      [
        {:args, args},
        # {:env, env},
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
