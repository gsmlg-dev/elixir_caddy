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
    Logger.info("Caddy Server init")
    state = %{port: nil}
    Process.flag(:trap_exit, true)
    {:ok, state, {:continue, :start}}
  end

  def handle_continue(:start, state) do
    Logger.info("Caddy Server Starting")

    with bin_path <- Caddy.Bootstrap.get(:bin_path),
         port <- port_start(bin_path) do
      state = state |> Map.put(:port, port)
      {:noreply, state}
    else
      error ->
        {:stop, error}
    end
  end

  def handle_info({_port, {:data, msg}}, state) do
    Caddy.Logger.Buffer.write(msg)
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
    Caddy.Logger.Store.tail() |> Enum.each(&(IO.puts("    " <> &1)))
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

  defp port_start(bin_path) do
    args = [
      "run",
      "--envfile",
      Config.env_file(),
      "--config",
      Config.init_file(),
      "--pidfile",
      Config.pid_file()
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
