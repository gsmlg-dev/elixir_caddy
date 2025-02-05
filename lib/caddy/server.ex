defmodule Caddy.Server do
  @moduledoc """

  Caddy Server

  Start Caddy Server

  """
  require Logger
  alias Caddy.Config

  use GenServer

  def stop(), do: GenServer.stop(__MODULE__)

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def bootstrap() do
    Logger.debug("Caddy Server is bootstrapping...")

    with true <- Config.ensure_path_exists(),
         :ok <- cleanup_pidfile(),
         config <- Config.get_config(),
         true <- Config.can_execute?(config.bin),
         {:ok, config_path} <- init_config_file(config) do
      {:ok, config_path}
    else
      error ->
        Logger.error("Caddy Server bootstrap error: #{inspect(error)}")
        {:error, error}
    end
  end

  def init(_) do
    {:ok, _} = bootstrap()
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

  defp init_config_file(%Config{} = config) do
    with caddyfile <- Config.to_caddyfile(config),
         {:ok, config_map} <- Config.adapt(caddyfile),
         {:ok, cfg} <- Jason.encode(config_map),
         :ok <- File.write(Config.init_file(), cfg) do
      {:ok, Config.init_file()}
    else
      error ->
        Logger.error("[init_config_file] error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp cleanup_pidfile() do
    pidfile = Config.pid_file()

    if pidfile |> File.exists?() do
      pid = pidfile |> File.read!() |> String.trim()

      if Regex.match?(~r/\d+/, pid) do
        Logger.debug("Caddy Bootstrap pidfile exists: `kill -9 #{pid}`")
        System.cmd("kill", ["-9", "#{pid}"])
      end

      File.rm(pidfile)
      :ok
    else
      :ok
    end
  end

  defp cleanup(reason, %{port: port} = _state) do
    case port |> Port.info(:os_pid) do
      {:os_pid, pid} ->
        {_, code} = System.cmd("kill", ["-9", "#{pid}"])
        code

      _ ->
        0
    end

    cleanup_pidfile()

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
        {:env, [{~c"name", ~c"caddy"}]},
        {:env, fixup_env(env)},
        :stream,
        :binary,
        :exit_status,
        :hide,
        :use_stdio,
        :stderr_to_stdout
      ]
    )
  end

  defp fixup_env(env) when is_list(env) do
    env
    |> Enum.map(fn
      {k, v} when is_nil(v) -> nil
      {k, v} -> {k |> to_charlist(), v |> to_charlist()}
    end)
    |> Enum.filter(&is_tuple/1)
  end

  defp fixup_env(_), do: []
end
