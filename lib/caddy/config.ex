defmodule Caddy.Config do
  @moduledoc """

  Start Caddy Config process to manage Caddy configuration.

  Configuration is stored in `%Caddy.Config{}` struct in `Caddy.Config` process.

  ```
  %Caddy.Config{
    bin: binary() | nil,
    global: binary(),
    additional: [binary()],
    sites: map(),
    env: list({binary(), binary()})
  }
  ```

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

  @type caddyfile :: binary()
  @type site_name :: binary()
  @type site_listen :: binary()
  @type site_config :: caddyfile() | {site_listen(), caddyfile()}

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

  @doc false
  def paths(), do: [priv_path(), share_path(), etc_path(), run_path(), tmp_path()]

  @doc false
  def ensure_path_exists() do
    paths()
    |> Enum.filter(&(!File.exists?(&1)))
    |> Enum.each(&File.mkdir_p/1)

    paths() |> Enum.filter(&File.exists?(&1)) |> Kernel.==(paths())
  end

  @doc """
  Replace the current configuration in `Caddy.Config`
  """
  @spec set_config(t()) :: {:ok, t()} | {:error, term()}
  def set_config(%__MODULE__{} = config) do
    GenServer.call(__MODULE__, {:set_config, config})
  end

  @doc """
  Return the current configuration in `Caddy.Config`
  """
  @spec get_config() :: t()
  def get_config() do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Get the :key in Caddy Cofnig
  """
  @spec get(atom()) :: binary() | nil
  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @doc """
  Convert caddyfile to json format.
  """
  @spec adapt(caddyfile()) :: {:ok, map()} | {:error, term()}
  def adapt(binary) do
    GenServer.call(__MODULE__, {:adapt, binary})
  end

  @doc """
  Set the Caddy binary path
  """
  @spec set_bin(binary()) :: {:ok, binary()} | {:error, term()}
  def set_bin(caddy_bin) do
    GenServer.call(__MODULE__, {:set_bin, caddy_bin})
  end

  @doc """
  Set the caddy binary path and restart Caddy.Server
  """
  @spec set_bin!(binary()) :: :ok | {:error, term()}
  def set_bin!(caddy_bin) do
    {:ok, _} = GenServer.call(__MODULE__, {:set_bin, caddy_bin})

    case Caddy.restart_server() do
      {:ok, _, _} -> :ok
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Set the global configuration

  ```
  Caddy.Config.set_global(\"\"\"
  debug
  auto_https off
  \"\"\")
  ```
  """
  @spec set_global(caddyfile()) :: {:ok, caddyfile()} | {:error, term()}
  def set_global(global) do
    GenServer.call(__MODULE__, {:set_global, global})
  end

  def set_additional(additionals)do
    GenServer.call(__MODULE__, {:set_additional, additionals})
  end

  @doc """
  Set the site configuration

  ```
  Caddy.Config.set_site("www.gsmlg.com", \"\"\"
  reverse_proxy {
    to localhost:4000
    header_up host www.gsmlg.com
    header_up X-Real-IP {remote_host}
  }
  \"\"\")
  # or
  Caddy.Config.set_site("proxy", {":8080", \"\"\"
  reverse_proxy {
    to localhost:3128
  }
  \"\"\"})
  ```
  """
  @spec set_site(site_name(), site_config()) ::
          {:ok, site_name(), site_config()} | {:error, term()}
  def set_site(name, site) when is_atom(name), do: set_site(to_string(name), site)

  def set_site(name, site) do
    GenServer.call(__MODULE__, {:set_site, name, site})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(args) do
    bin =
      with true <- Keyword.keyword?(args),
           true <- Keyword.has_key?(args, :caddy_bin) do
        Keyword.get(args, :caddy_bin)
      else
        _ -> nil
      end

    confg = %__MODULE__{
      env: init_env(),
      bin: bin,
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

  def handle_call({:set_bin, caddy_bin}, _from, state) do
    state = state |> Map.put(:bin, caddy_bin)
    {:reply, {:ok, caddy_bin}, state}
  end

  def handle_call({:set_global, global}, _from, state) do
    {:reply, {:ok, global}, state |> Map.put(:global, global)}
  end

  def handle_call({:set_additional, additionals}, _from, state) do
    {:reply, {:ok, additionals}, state |> Map.put(:additional, additionals)}
  end

  def handle_call({:set_site, name, site}, _from, state) do
    state = state |> Map.update(:sites, %{}, fn sites -> Map.put(sites, name, site) end)
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

  @doc """
  Confirt `%Caddy.Config{}` to `caddyfile()`
  """
  @spec to_caddyfile(t()) :: caddyfile()
  def to_caddyfile(%__MODULE__{global: global, additional: additional, sites: sites}) do
    """
    {
    #{global}
    }

    #{Enum.join(additional, "\n\n")}

    #{Enum.map(sites, fn
      {name, site} when is_binary(site) -> """
        ## #{name}
        #{name} {
          #{site}
        }
        """
      {name, {listen, site}} when is_binary(site) -> """
        ## #{name}
        #{listen} {
          #{site}
        }
        """
      _ -> ""
    end) |> Enum.join("\n\n")}
    """
  end

  @doc false
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

  @doc false
  def first_writable(paths, default \\ nil) do
    paths
    |> Enum.find(default, &has_write_permission?/1)
  end

  @doc false
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

  @doc false
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

  @doc false
  def can_execute?(path) when is_binary(path) do
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

  def can_execute?(_), do: false

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
