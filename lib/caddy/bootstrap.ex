defmodule Caddy.Bootstrap do
  @moduledoc """

  Caddy Bootstrap

  Start Caddy Bootstrap

  """
  require Logger

  use GenServer

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    Logger.info("Caddy Bootstrapping...")

    with bin_path <- Keyword.get(args, :bin_path),
      bin_path <- if(bin_path == nil, do: System.find_executable("caddy"), else: bin_path),
      {version, 0} <- System.cmd(bin_path, ["version"]),
      envfile <- get_envfile(),
      {modules, 0} <- get_modules(bin_path),
      {:ok, config_path} <- init_config() do
      state = %{
        version: version,
        bin_path: bin_path,
        config_path: config_path,
        envfile: envfile,
        pidfile: Application.app_dir(:caddy, "priv/run/caddy.pid"),
        admin_socket: Application.app_dir(:caddy, "priv/run/caddy.sock"),
        modules: modules
      }
      {:ok, state}
    else
      error ->
        Process.sleep(1000)
        {:stop, error}
    end
  end

  def handle_call({:get, key}, _from, state) do
    value = Map.get(state, key)
    {:reply, value, state}
  end

  def get_init_config() do
    # {"admin":{"listen":"unix//var/run/caddy.sock","origins":["caddy-admin.local"]}}
    admin_socket_path = Application.app_dir(:caddy, "priv/run/caddy.sock")
    if admin_socket_path |> Path.dirname() |> File.exists?() |> Kernel.! do
      admin_socket_path |> Path.dirname() |> File.mkdir_p()
    end

    storage_path = Application.app_dir(:caddy, "priv/storage")
    if storage_path |> File.exists?() |> Kernel.! do
      storage_path |> File.mkdir_p()
    end

    %{
      admin: %{
        listen: "unix/" <> admin_socket_path,
        origins: ["caddy-admin.local"]
      },
      storage: %{
        module: "file_system",
        root: storage_path
      }
    }
  end

  defp init_config() do
    with path <- Application.app_dir(:caddy, "priv/etc/init.json"),
      :ok <- Path.dirname(path) |> File.mkdir_p(),
      {:ok, cfg} <- Jason.encode(get_init_config()),
      :ok <- File.write(path, cfg) do
      {:ok, path}
    else
      error ->
        Logger.error("Read init.json error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_envfile() do
    envfile = Application.app_dir(:caddy, "priv/etc/envfile")
    if envfile |> Path.dirname() |> File.exists?() |> Kernel.! do
      envfile |> Path.dirname() |> File.mkdir_p()
    end
    home = Application.app_dir(:caddy, "priv")
    env = """
    HOME="#{home}"
    XDG_CONFIG_HOME="#{home}/config"
    XDG_DATA_HOME="#{home}/data"
    """
    File.write!(envfile, env)
    envfile
  end

  defp get_modules(bin_path) do
    case System.cmd(bin_path, ["list-modules"]) do
      {ms, 0} ->
        modules = ms |> String.split("\n") |> Enum.filter(fn(l) -> String.match?(l, ~r/^\S+/) end)
        {modules, 0}
      {output, code} ->
        {output, code}
    end
  end
end
