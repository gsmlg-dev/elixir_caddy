defmodule CaddyServer do
  @moduledoc """
  Documentation for `CaddyServer`.
  """

  alias CaddyServer.Downloader
  alias CaddyServer.AdminSocket
  require Logger
  use GenServer

  @default_version "2.8.4"

  @doc """
  Start caddy server by using config return in `caddyfile()`
  """
  @spec start :: :ignore | {:error, any} | {:ok, pid}
  def start() do
    GenServer.start(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Return GenServer state, %{port: Port.t()}
  """
  @spec get_state :: %{port: Port.t() | nil}
  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Stop caddy server using system kill command
  """
  @spec stop :: non_neg_integer
  def stop() do
    {:os_pid, pid} = CaddyServer.get_state() |> Map.get(:port) |> Port.info(:os_pid)
    {_, code} = System.cmd("kill", ["#{pid}"])
    code
  end

  @spec version :: binary()
  @doc """
  Return Caddy Version from ` Application.get_env(:caddy_server, CaddyServer) |> Keyword.get(:version)`

  if not defined, use `@default_version` instead

  """
  def version() do
    case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:version) do
      {:ok, version} -> version
      :error -> @default_version
    end
  end

  @spec caddyfile :: binary()
  @doc """
  Return Caddyfile content
  """
  def caddyfile() do
    """

    {
      #{global_conf()}

      admin #{control_socket()} {
        origins caddy-admin.local
      }
    }

    #{site_conf()}

    """
  end

  defp global_conf() do
    case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:global_conf) do
      {:ok, conf} -> conf
      :error -> ""
    end
  end

  defp site_conf() do
    case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:site_conf) do
      {:ok, conf} -> conf
      :error -> ""
    end
  end

  @doc """
  Return path of caddy server binary
  """
  @spec cmd :: binary
  def cmd() do
    path =
      if Downloader.downloaded_bin() |> File.exists?() do
        Downloader.downloaded_bin()
      else
        case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:bin_path) do
          {:ok, bin_path} when is_binary(bin_path) ->
            Logger.debug("using bin_path setted in application env: #{bin_path}")
            bin_path

          _ ->
            if Downloader.auto?() do
              0 = Downloader.download()
              Downloader.downloaded_bin()
            else
              ""
            end
        end
      end

    if File.exists?(path) do
      path
    else
      raise "No Caddy command found"
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init) do
    state = %{port: nil}
    # your trap_exit call should be here
    Process.flag(:trap_exit, true)
    {:ok, state, {:continue, :start_server}}
  end

  def handle_continue(:start_server, state) do
    File.mkdir_p(priv_dir("/etc"))
    f = priv_dir("/etc/Caddyfile")

    Logger.info("Write Caddyfile to #{f}")
    Logger.debug("Caddyfile:\n#{caddyfile()}")
    File.write!(f, caddyfile())

    Logger.info("Staring Caddy Server...")

    port =
      Port.open(
        {:spawn_executable, cmd()},
        [
          {:args, ["run", "--adapter", "caddyfile", "--config", f]},
          :stream,
          :binary,
          :exit_status,
          :hide,
          :use_stdio,
          :stderr_to_stdout
        ]
      )

    state = Map.put(state, :port, port)
    {:noreply, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info({port, {:data, msg}}, state) do
    Logger.info("Caddy#{inspect(port)}: #{msg |> String.trim_trailing()}")
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, exit_status}}, state) do
    Logger.info("Caddy#{inspect(port)}: exit_status: #{exit_status}")
    {:noreply, state}
  end

  # handle the trapped exit call
  def handle_info({:EXIT, _from, reason}, state) do
    Logger.info("Caddy exiting: #{cleanup(reason, state)}")
    # see GenServer docs for other return types
    {:stop, reason, state}
  end

  # handle termination
  def terminate(reason, state) do
    Logger.info("Caddy terminating: #{cleanup(reason, state)}")

    state
  end

  defp cleanup(_reason, state) do
    case state |> Map.get(:port) |> Port.info(:os_pid) do
      {:os_pid, pid} ->
        {_, code} = System.cmd("kill", ["#{pid}"])
        code

      _ ->
        0
    end
  end

  defp control_socket() do
    AdminSocket.socket_path()
  end

  defp priv_dir(p) do
    Application.app_dir(:caddy_server, "priv#{p}")
  end
end
