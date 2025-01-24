defmodule Caddy.Bootstrap do
  @moduledoc false
  require Logger
  alias Caddy.Config

  def init() do
    Logger.debug("Caddy Bootstrap")

    with true <- Config.ensure_path_exists(),
         :ok <- stop_exists_server(),
         config <- Config.get_config(),
         true <- Config.can_execute?(config.bin),
         {:ok, config_path} <- init_config_file(config) do

      {:ok, config_path}
    else
      error ->
        Logger.error("Caddy Bootstrap [init] error: #{inspect(error)}")
        {:error, error}
    end
  end

  def stop_exists_server() do
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
end
