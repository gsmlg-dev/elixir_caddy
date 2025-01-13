defmodule Caddy.Bootstrap do
  @moduledoc """

  Caddy Bootstrap

  Start Caddy Bootstrap

  """
  require Logger
  alias Caddy.Config

  use GenServer

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def restart() do
    GenServer.stop(__MODULE__)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug("Caddy Bootstrap init")

    with true <- Config.ensure_path_exists(),
         :ok <- stop_exists_server(),
         bin_path <- Config.get(:caddy_bin),
         {version, 0} <- System.cmd(bin_path, ["version"]),
         {modules, 0} <- get_modules(bin_path),
         {:ok, envfile} <- init_env_file(),
         {env, 0} <- get_env(bin_path),
         {:ok, config_path} <- init_config_file() do
      state = %{
        version: version,
        bin_path: bin_path,
        config_path: config_path,
        envfile: envfile,
        env: env,
        pidfile: Config.pid_file(),
        modules: modules
      }

      {:ok, state}
    else
      error ->
        Logger.error("Caddy Bootstrap [init] error: #{inspect(error)}")
        {:stop, error}
    end
  end

  def handle_call({:get, key}, _from, state) do
    value = Map.get(state, key)
    {:reply, value, state}
  end

  def stop_exists_server() do
    pidfile = Config.pid_file()

    if pidfile |> File.exists?() do
      pid = pidfile |> File.read!() |> String.trim()
      Logger.debug("Caddy Bootstrap pidfile exists: #{pid}")
      File.rm(pidfile)
      System.cmd("kill", ["-9", "#{pid}"])
      :ok
    else
      :ok
    end
  end

  defp init_config_file() do
    with config <- Config.get(:config),
         {:ok, cfg} <- Jason.encode(config),
         :ok <- File.write(Config.init_file(), cfg) do
      {:ok, Config.init_file()}
    else
      error ->
        Logger.error("[init_config_file] error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp init_env_file() do
    envfile = Caddy.Config.env_file()

    case File.write(envfile, Caddy.Config.env()) do
      :ok ->
        {:ok, envfile}

      {:error, posix} ->
        {:error, posix}
    end
  end

  defp get_modules(bin_path) do
    case System.cmd(bin_path, ["list-modules"]) do
      {ms, 0} ->
        modules = ms |> String.split("\n") |> Enum.filter(fn l -> String.match?(l, ~r/^\S+/) end)
        {modules, 0}

      {output, code} ->
        {output, code}
    end
  end

  defp get_env(bin_path) do
    case System.cmd(bin_path, ["environ", "--envfile", Config.env_file()]) do
      {env, 0} ->
        {env, 0}

      {output, code} ->
        {output, code}
    end
  end
end
