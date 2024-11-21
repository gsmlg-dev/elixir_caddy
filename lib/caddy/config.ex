defmodule Caddy.Config do
  @moduledoc """

  Caddy Config

  Start Caddy Config

  """
  require Logger

  use GenServer

  def home_path(), do: Application.app_dir(:caddy, "priv")
  def etc_path(), do: home_path() <> "/etc"
  def storage_path(), do: home_path() <> "/storage"
  def run_path(), do: home_path() <> "/run"
  def tmp_path(), do: home_path() <> "/tmp"
  def xdg_config_home(), do: home_path() <> "/config"
  def xdg_data_home(), do: home_path() <> "/data"

  def env_file(), do: etc_path() <> "/envfile"
  def init_file(), do: etc_path() <> "/init.json"
  def pid_file(), do: run_path() <> "/caddy.pid"
  def socket_file(), do: run_path() <> "/caddy.sock"
  def saved_json_file(), do: home_path() <> "/config/caddy/autosave.json"

  def paths(), do: [home_path(), etc_path(), storage_path(), run_path(), tmp_path()]

  def ensure_path_exists() do
    paths()
    |> Enum.filter(&(!File.exists?(&1)))
    |> Enum.each(&File.mkdir_p/1)

    paths() |> Enum.filter(&File.exists?(&1)) |> Kernel.==(paths())
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @spec adapt(binary(), binary()) :: {:ok, Map.t()} | {:error, any()}
  def adapt(binary, adapter \\ "caddyfile") do
    GenServer.call(__MODULE__, {:adapt, {binary, adapter}})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    caddy_bin = Keyword.get(args, :caddy_bin)
    caddy_file = Keyword.get(args, :caddy_file)

    passed_config =
      if caddy_file == nil do
        Keyword.get(args, :config, %{})
      else
        parse_caddyfile(caddy_bin, caddy_file)
      end

    config = initial() |> Map.merge(saved()) |> Map.merge(passed_config)

    {:ok, %{config: config, caddy_bin: caddy_bin}}
  end

  def handle_call({:get, key}, _from, state) do
    value = Map.get(state, key)
    {:reply, value, state}
  end

  def handle_call({:adapt, {binary, adapter}}, _from, %{caddy_bin: caddy_bin} = state) do
    with tmp_config <- tmp_path() <> "/" <> adapter,
         :ok <- File.write(tmp_config, binary),
         {config_json, 0} <-
           System.cmd(caddy_bin, ["adapt", "--adapter", adapter, "--config", tmp_config]),
         {:ok, config} <- Jason.decode(config_json) do
      {:reply, {:ok, config}, state}
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def saved() do
    with file <- saved_json_file(),
         true <- File.exists?(file),
         {:ok, saved_config_string} <- File.read(file),
         {:ok, saved_config} <- Jason.decode(saved_config_string) do
      saved_config
    else
      _ ->
        %{}
    end
  end

  def initial() do
    admin_socket_path = "unix/" <> socket_file()

    %{
      "admin" => %{
        "listen" => admin_socket_path,
        "origins" => ["caddy-admin.local"]
      },
      "storage" => %{
        "module" => "file_system",
        "root" => storage_path()
      }
    }
  end

  def env() do
    """
    HOME="#{home_path()}"
    XDG_CONFIG_HOME="#{xdg_config_home()}"
    XDG_DATA_HOME="#{xdg_data_home()}"
    """
  end

  defp parse_caddyfile(caddy_bin, caddy_file) do
    with {config_json, 0} <-
           System.cmd(caddy_bin, ["adapt", "--adapter", "caddyfile", "--config", caddy_file]),
         {:ok, config} <- Jason.decode(config_json) do
      config
    else
      error ->
        Logger.error("Error parsing caddyfile: #{inspect(error)}")
        %{}
    end
  end
end
