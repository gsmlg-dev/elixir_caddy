defmodule Caddy.Config do
  @moduledoc """

  Caddy Config

  Start Caddy Config

  """
  require Logger

  use GenServer

  @type t :: %__MODULE__{
          bin: binary() | nil,
          global: binary(),
          additional: [binary()],
          sites: map(),
          env: list({binary(), binary()})
        }

  defstruct bin: nil, global: "", additional: [], sites: %{}, env: []

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

  def set_config(%__MODULE__{} = config) do
    GenServer.call(__MODULE__, {:set_config, config})
  end

  def get_config() do
    GenServer.call(__MODULE__, :get_config)
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @spec adapt(binary()) :: {:ok, map()} | {:error, any()}
  def adapt(binary) do
    GenServer.call(__MODULE__, {:adapt, binary})
  end

  def set_global(global) do
    GenServer.call(__MODULE__, {:set_global, global})
  end

  def set_site(name, site) when is_atom(name), do: set_site(to_string(name), site)
  def set_site(name, site) do
    GenServer.call(__MODULE__, {:set_site, name, site})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(args) do
    bin = Keyword.get(args, :caddy_bin)

    confg = %__MODULE__{
      env: init_env(),
      bin: bin || System.find_executable("caddy"),
      global: "admin unix/#{socket_file()}"
    }

    {:ok, confg}
  end

  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    value = Map.get(state, key)
    {:reply, value, state}
  end

  def handle_call({:set_config, config}, _from, state) do
    {:reply, {:ok, state}, config}
  end

  def handle_call({:set_global, global}, _from, state) do
    {:reply, {:ok, global}, state |> Map.put(:global, global)}
  end

  def handle_call({:set_site, name, site}, _from, state) do
    state = state |> Map.update(:sites, %{}, fn(sites) -> Map.put(sites, name, site) end)
    {:reply, {:ok, name, site}, state}
  end

  def handle_call({:adapt, binary}, _from, %__MODULE__{bin: caddy_bin} = state) do
    with tmp_config <- Path.expand("Caddyfile", etc_path()),
         :ok <- File.write(tmp_config, binary),
         {_, 0} <- System.cmd(caddy_bin, ["fmt", "--overwrite", tmp_config]),
         {config_json, 0} <-
           System.cmd(caddy_bin, ["adapt", "--adapter", "caddyfile", "--config", tmp_config]),
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

  def to_caddyfile(%__MODULE__{global: global, additional: additional, sites: sites}) do
    """
    {
    #{global}
    }

    #{Enum.join(additional, "\n\n")}

    #{Enum.map(sites, fn
      ({name, site}) when is_binary(site) -> """
        ## #{name}
        #{name} {
          #{site}
        }
        """
      ({name, {listen, site}}) when is_binary(site) -> """
        ## #{name}
        #{listen} {
          #{site}
        }
        """
      (_) -> ""
    end) |> Enum.join("\n\n")}
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

  def first_writable(paths, default \\ nil) do
    paths
    |> Enum.find(default, &has_write_permission?/1)
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

  def check_bin(bin) do
    if can_execute?(bin) do
      case System.cmd(bin, ["version"]) do
        {"v2" <> _, 0} ->
          :ok

        _ ->
          {:error, "Caddy binary version check failed"}
      end
    else
      {:error, "Caddy binary not found or not executable"}
    end
  end

  def can_execute?(path) do
    with true <- File.exists?(path),
         {:ok, %File.Stat{access: access, mode: mode}} <- File.stat(path),
         true <- access in [:read, :read_write],
         0b100 <- Bitwise.band(mode, 0b100) do
      true
    else
      _ ->
        false
    end
  end

  defp init_env() do
    [
      {"HOME", share_path()},
      {"XDG_CONFIG_HOME", xdg_config_home()},
      {"XDG_DATA_HOME", xdg_data_home()}
    ]
  end

  # defp command_stdin(command, binary_input) do
  #   IO.inspect({"command_stdin", command, binary_input})
  #   port = Port.open({:spawn, command}, [:binary, :exit_status, :use_stdio])
  #   Port.command(port, binary_input)

  #   binary_output =
  #     receive do
  #       {^port, {:data, data}} ->
  #         data
  #     after
  #       5000 ->
  #         Logger.debug("No response received within timeout")
  #         nil
  #     end

  #   # Handle port exit status (optional but recommended)
  #   status =
  #     receive do
  #       {^port, {:exit_status, status}} ->
  #         IO.puts("Port exited with status: #{status}")
  #         status
  #     after
  #       1000 ->
  #         :timeout
  #     end

  #   Port.close(port)
  #   {binary_output, status}
  # end
end
