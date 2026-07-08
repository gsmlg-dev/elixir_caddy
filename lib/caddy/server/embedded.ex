defmodule Caddy.Server.Embedded do
  @moduledoc """
  Embedded Caddy Server.

  Manages the Caddy binary process directly using Erlang ports.
  This is used only when `config :caddy, mode: :embedded`. The default mode is
  `:external`, where Caddy is managed outside the BEAM and accessed via the
  Admin API.

  The server:
  - Spawns and monitors the Caddy binary process
  - Handles process output and logs
  - Manages process lifecycle (start/stop/restart)
  - Cleans up on termination

  Won't start if Caddy binary is not found or not executable.
  Can be restarted via `Caddy.restart_server()` after setting the binary path.
  """

  alias Caddy.Config
  alias Caddy.ConfigProvider

  use GenServer

  @graceful_shutdown_timeout 5_000
  @shutdown_check_interval 50

  @type status :: :running | :stopped | {:error, term()}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    case Application.get_env(:caddy, :start, true) do
      false ->
        :ignore

      true ->
        case bootstrap() do
          {:ok, _} ->
            dump_log = Application.get_env(:caddy, :dump_log, false)

            state = %{
              port: nil,
              dump_log: dump_log,
              caddy_status: :stopped,
              last_exit_status: nil
            }

            Process.flag(:trap_exit, true)
            {:ok, state, {:continue, :start}}

          {:error, reason} ->
            Caddy.Telemetry.log_warning(
              "Caddy Server initialization failed: #{reason}\n\nTo fix this issue:\n- If binary not found: `Caddy.ConfigProvider.set_bin(\"/path/to/caddy\")`\n- Then restart: `Caddy.restart_server()`\n- Check configuration for syntax errors",
              module: __MODULE__,
              error: reason
            )

            :ignore
        end
    end
  end

  @doc false
  @impl true
  def handle_continue(:start, state) do
    Caddy.Telemetry.log_debug("Caddy Server Starting", module: __MODULE__)
    start_time = System.monotonic_time()
    config = ConfigProvider.get_config()

    case port_start(config) do
      {:ok, port} ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_server_event(:start, %{duration: duration}, %{pid: port})
        state = %{state | port: port, caddy_status: :running, last_exit_status: nil}
        {:noreply, state}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_server_event(:start_error, %{duration: duration}, %{
          error: reason
        })

        {:noreply, %{state | caddy_status: {:error, reason}, last_exit_status: reason}}
    end
  end

  @impl true
  def handle_info({_port, {:data, msg}}, %{dump_log: dump_log} = state) do
    # Emit log received event
    Caddy.Telemetry.emit_log_event(
      :received,
      %{size: byte_size(msg)},
      %{source: :caddy_process}
    )

    Caddy.Logger.write_buffer(msg)
    if dump_log, do: IO.puts(msg)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, exit_status}}, %{port: port} = state) do
    Caddy.Telemetry.log_warning("Caddy#{inspect(port)}: exit_status: #{exit_status}",
      module: __MODULE__,
      exit_status: exit_status,
      port: inspect(port)
    )

    Caddy.Telemetry.emit_server_event(:exit, %{}, %{exit_status: exit_status, port: inspect(port)})

    state = %{
      state
      | port: nil,
        caddy_status: {:error, exit_status},
        last_exit_status: exit_status
    }

    {:noreply, state}
  end

  def handle_info({port, {:exit_status, exit_status}}, state) do
    Caddy.Telemetry.emit_server_event(:exit, %{}, %{exit_status: exit_status, port: inspect(port)})

    {:noreply, %{state | caddy_status: {:error, exit_status}, last_exit_status: exit_status}}
  end

  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Caddy.Telemetry.log_warning("Caddy port exited: #{inspect(reason)}",
      module: __MODULE__,
      reason: reason,
      port: inspect(port)
    )

    Caddy.Telemetry.emit_server_event(:exit, %{}, %{reason: reason, port: inspect(port)})

    state = %{
      state
      | port: nil,
        caddy_status: exit_reason_status(reason),
        last_exit_status: reason
    }

    {:noreply, state}
  end

  # handle trapped exits from non-Caddy linked processes
  def handle_info({:EXIT, _from, reason}, state) do
    Caddy.Telemetry.log_debug("Caddy.Server.Embedded exiting", module: __MODULE__, reason: reason)
    Caddy.Telemetry.emit_server_event(:shutdown, %{}, %{reason: reason})
    cleanup(reason, state)
    {:stop, reason, state}
  end

  # handle termination
  @impl true
  def terminate(reason, state) do
    Caddy.Telemetry.log_debug("Caddy.Server.Embedded terminating",
      module: __MODULE__,
      reason: reason
    )

    start_time = System.monotonic_time()
    cleanup(reason, state)
    duration = System.monotonic_time() - start_time
    Caddy.Telemetry.emit_server_event(:terminate, %{duration: duration}, %{reason: reason})
    Caddy.Logger.Store.tail() |> Enum.each(&IO.puts("    " <> &1))
  end

  @doc """
  Get Caddyfile content of the current running server
  """
  @spec get_caddyfile() :: binary()
  def get_caddyfile do
    Path.expand("Caddyfile", Config.etc_path()) |> File.read!()
  end

  @doc "Check the embedded Caddy process status."
  @spec check_status() :: status()
  def check_status do
    case Process.whereis(__MODULE__) do
      nil -> :stopped
      _pid -> GenServer.call(__MODULE__, :check_status)
    end
  end

  @doc "Return embedded Caddy binary version and module info."
  @spec version() :: {:ok, map()} | {:error, term()}
  def version do
    ConfigProvider.get_config()
    |> Map.get(:bin)
    |> Config.version_info()
  end

  @impl true
  def handle_call(:check_status, _from, state) do
    {:reply, state.caddy_status, state}
  end

  defp bootstrap do
    Caddy.Telemetry.log_debug("Caddy Server bootstrap", module: __MODULE__)
    start_time = System.monotonic_time()

    with {:ensure_path_exists, true} <- {:ensure_path_exists, Config.ensure_path_exists()},
         {:cleanup_pidfile, :ok} <- {:cleanup_pidfile, cleanup_pidfile()},
         {:get_config, config} <- {:get_config, ConfigProvider.get_config()},
         {:validate_bin, :ok} <- {:validate_bin, validate_binary(config.bin)},
         {:validate_config, :ok} <- {:validate_config, validate_configuration(config)},
         {:ok, config_path} <- init_config_file(config) do
      duration = System.monotonic_time() - start_time

      Caddy.Telemetry.emit_server_event(:bootstrap_success, %{duration: duration}, %{
        config_path: config_path
      })

      {:ok, config_path}
    else
      {:ensure_path_exists, false} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_server_event(:bootstrap_error, %{duration: duration}, %{
          error: "Failed to create required directories"
        })

        {:error, "Failed to create required directories"}

      {:validate_bin, {:error, reason}} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_server_event(:bootstrap_error, %{duration: duration}, %{
          error: reason
        })

        {:error, reason}

      {:validate_config, {:error, reason}} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_server_event(:bootstrap_error, %{duration: duration}, %{
          error: reason
        })

        {:error, reason}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_server_event(:bootstrap_error, %{duration: duration}, %{
          error: "Configuration file error: #{inspect(reason)}"
        })

        {:error, "Configuration file error: #{inspect(reason)}"}

      error ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_server_event(:bootstrap_error, %{duration: duration}, %{
          error: inspect(error)
        })

        Caddy.Telemetry.log_error("Caddy Server bootstrap error: #{inspect(error)}",
          module: __MODULE__,
          error: error
        )

        {:error, error}
    end
  end

  defp validate_binary(nil) do
    {:error, "Caddy binary path not configured"}
  end

  defp validate_binary(bin) do
    case Config.validate_bin(bin) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_configuration(config) do
    caddyfile = Config.to_caddyfile(config)

    case Config.adapt(caddyfile, config.bin) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Invalid configuration: #{inspect(reason)}"}
    end
  rescue
    error -> {:error, "Configuration validation failed: #{inspect(error)}"}
  end

  defp init_config_file(%Config{} = config) do
    caddyfile = Config.to_caddyfile(config)

    with {:ok, config_map} <- Config.adapt(caddyfile, config.bin),
         {:ok, cfg} <- {:ok, JSON.encode!(config_map)},
         :ok <- File.write(Config.init_file(), cfg) do
      {:ok, Config.init_file()}
    else
      error ->
        Caddy.Telemetry.log_error("[init_config_file] error: #{inspect(error)}",
          module: __MODULE__,
          error: error
        )

        {:error, error}
    end
  end

  defp cleanup_pidfile do
    pidfile = Config.pid_file()

    if pidfile |> File.exists?() do
      pid = pidfile |> File.read!() |> String.trim()

      if Regex.match?(~r/\d+/, pid) do
        Caddy.Telemetry.log_debug("Caddy pidfile exists: terminating #{pid}",
          module: __MODULE__,
          pid: pid
        )

        terminate_pid(pid)
      end

      File.rm(pidfile)
      :ok
    else
      :ok
    end
  end

  defp cleanup(reason, %{port: nil}) do
    cleanup_pidfile()
    Caddy.Telemetry.emit_server_event(:cleanup, %{duration: 0}, %{reason: reason})
    reason
  end

  defp cleanup(reason, %{port: port} = _state) do
    start_time = System.monotonic_time()

    case port |> Port.info(:os_pid) do
      {:os_pid, pid} ->
        terminate_port(port, pid)

      _ ->
        0
    end

    cleanup_pidfile()
    duration = System.monotonic_time() - start_time
    Caddy.Telemetry.emit_server_event(:cleanup, %{duration: duration}, %{reason: reason})

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

    start_time = System.monotonic_time()

    port =
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

    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_server_event(:process_start, %{duration: duration}, %{
      binary_path: bin_path,
      args: args
    })

    {:ok, port}
  rescue
    error in ErlangError -> {:error, {:port_start_failed, error.original}}
  end

  defp fixup_env(env) when is_list(env) do
    env
    |> Enum.map(fn
      {_k, v} when is_nil(v) -> nil
      {k, v} -> {k |> to_charlist(), v |> to_charlist()}
    end)
    |> Enum.filter(&is_tuple/1)
  end

  defp terminate_port(port, pid) do
    case kill(pid, "TERM") do
      0 ->
        wait_for_port_exit(port, @graceful_shutdown_timeout) || kill(pid, "KILL")

      code ->
        code
    end
  end

  defp terminate_pid(pid) do
    case kill(pid, "TERM") do
      0 ->
        wait_for_pid_exit(pid, @graceful_shutdown_timeout) || kill(pid, "KILL")

      code ->
        code
    end
  end

  defp kill(pid, signal) do
    {_output, code} = System.cmd("kill", ["-#{signal}", "#{pid}"], stderr_to_stdout: true)
    code
  end

  defp wait_for_port_exit(port, timeout) when timeout <= 0 do
    case Port.info(port) do
      nil -> 0
      _ -> false
    end
  end

  defp wait_for_port_exit(port, timeout) do
    case Port.info(port) do
      nil ->
        0

      _ ->
        Process.sleep(@shutdown_check_interval)
        wait_for_port_exit(port, timeout - @shutdown_check_interval)
    end
  end

  defp wait_for_pid_exit(pid, timeout) when timeout <= 0 do
    if pid_running?(pid), do: false, else: 0
  end

  defp wait_for_pid_exit(pid, timeout) do
    if pid_running?(pid) do
      Process.sleep(@shutdown_check_interval)
      wait_for_pid_exit(pid, timeout - @shutdown_check_interval)
    else
      0
    end
  end

  defp pid_running?(pid) do
    {_output, code} = System.cmd("kill", ["-0", "#{pid}"], stderr_to_stdout: true)
    code == 0
  end

  defp exit_reason_status(:normal), do: :stopped
  defp exit_reason_status(reason), do: {:error, reason}
end
