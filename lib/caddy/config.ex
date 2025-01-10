defmodule Caddy.Config do
  @moduledoc """

  Caddy Config

  Start Caddy Config

  """
  require Logger

  use GenServer

  defdelegate user_home, to: System
  def user_share(), do: Path.join(user_home(), ".local/share")

  def priv_path(), do: Application.app_dir(:caddy, "priv")
  def share_path(), do: Path.join(user_share(), "caddy")
  def etc_path(), do: Path.join(share_path(), "etc")
  def run_path(), do: Path.join(share_path(), "run")
  def tmp_path(), do: Path.join(share_path(), "tmp")
  def xdg_config_home(), do: Path.join(share_path(), "config")
  def xdg_data_home(), do: Path.join(share_path(), "data")

  def env_file(), do: Path.join(etc_path(), "envfile")
  def init_file(), do: Path.join(etc_path(), "init.json")
  def pid_file(), do: Path.join(run_path(), "caddy.pid")
  def socket_file(), do: Path.join(run_path(), "caddy.sock")
  def saved_json_file(), do: Path.join(xdg_config_home(), "caddy/autosave.json")

  def paths(), do: [priv_path(), share_path(), etc_path(), run_path(), tmp_path()]

  def ensure_path_exists() do
    paths()
    |> Enum.filter(&(!File.exists?(&1)))
    |> Enum.each(&File.mkdir_p/1)

    paths() |> Enum.filter(&File.exists?(&1)) |> Kernel.==(paths())
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @spec adapt(binary(), binary()) :: {:ok, map()} | {:error, any()}
  def adapt(binary, adapter \\ "caddyfile") do
    GenServer.call(__MODULE__, {:adapt, {binary, adapter}})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    caddy_bin = Keyword.get(args, :caddy_bin)
    caddy_file = Keyword.get(args, :caddy_file)
    merge_saved = Keyword.get(args, :merge_saved, false)

    config =
      if caddy_file == nil do
        passed_config = Keyword.get(args, :config, %{})
        config = initial()

        config =
          if merge_saved do
            config |> Map.merge(saved())
          else
            config
          end

        config |> Map.merge(passed_config)
      else
        passed_config = parse_caddyfile(caddy_bin, caddy_file)
        config = initial()

        config =
          if merge_saved do
            config |> Map.merge(saved())
          else
            config
          end

        config |> Map.merge(passed_config)
      end

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
      }
    }
  end

  def env() do
    """
    HOME="#{share_path()}"
    XDG_CONFIG_HOME="#{xdg_config_home()}"
    XDG_DATA_HOME="#{xdg_data_home()}"
    """
  end

  @spec parse_caddyfile(binary(), Path.t()) :: map()
  def parse_caddyfile(caddy_bin, caddy_file) do
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

  def first_writable_or(paths, default) do
    paths
    |> Enum.find(default, &has_write_permission?/1)
  end

  def first_writable(paths) do
    paths
    |> Enum.find(&has_write_permission?/1)
  end

  def has_write_permission?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{access: :write} = _stat} ->
        true

      {:ok, %File.Stat{access: :read_write} = _stat} ->
        true

      _ ->
        false
    end
  end
end
