defmodule Caddy.Server.External do
  @moduledoc """
  External Caddy Server management.

  Manages a Caddy instance that is started and controlled externally
  (e.g., by systemd, launchd, or another process manager).

  This GenServer:
  - Monitors Caddy health via the Admin API
  - Executes system commands for lifecycle operations
  - Pushes configuration when Caddy becomes available
  - Emits telemetry events for observability

  ## Configuration

      config :caddy, mode: :external
      config :caddy, admin_url: "http://localhost:2019"
      config :caddy, health_interval: 30_000
      config :caddy, commands: [
        start: "systemctl start caddy",
        stop: "systemctl stop caddy",
        restart: "systemctl restart caddy",
        status: "systemctl is-active caddy"
      ]

  ## State

  The server maintains:
  - `caddy_status` - Current known status (`:running`, `:stopped`, `:unknown`)
  - `config_pushed` - Whether initial config has been pushed
  - `last_health_check` - Timestamp of last successful health check
  """

  use GenServer

  alias Caddy.Config
  alias Caddy.Admin.Api

  @type state :: %{
          caddy_status: :running | :stopped | :unknown,
          config_pushed: boolean(),
          last_health_check: DateTime.t() | nil,
          health_interval: pos_integer()
        }

  # Client API

  @doc """
  Start the external server GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check the current status of the external Caddy instance.
  """
  @spec check_status() :: :running | :stopped | :unknown
  def check_status do
    GenServer.call(__MODULE__, :check_status)
  end

  @doc """
  Execute a lifecycle command.

  Available commands: `:start`, `:stop`, `:restart`, `:status`
  """
  @spec execute_command(atom()) :: {:ok, binary()} | {:error, term()}
  def execute_command(command) when command in [:start, :stop, :restart, :status] do
    GenServer.call(__MODULE__, {:execute_command, command})
  end

  def execute_command(command) do
    {:error, {:invalid_command, command}}
  end

  @doc """
  Start the external Caddy instance using the configured start command.
  """
  @spec start_caddy() :: {:ok, binary()} | {:error, term()}
  def start_caddy, do: execute_command(:start)

  @doc """
  Stop the external Caddy instance using the configured stop command.
  """
  @spec stop_caddy() :: {:ok, binary()} | {:error, term()}
  def stop_caddy, do: execute_command(:stop)

  @doc """
  Restart the external Caddy instance using the configured restart command.
  """
  @spec restart_caddy() :: {:ok, binary()} | {:error, term()}
  def restart_caddy, do: execute_command(:restart)

  @doc """
  Push configuration to the running Caddy instance.
  """
  @spec push_config() :: :ok | {:error, term()}
  def push_config do
    GenServer.call(__MODULE__, :push_config)
  end

  @doc """
  Get Caddyfile content via Admin API.
  """
  @spec get_caddyfile() :: binary()
  def get_caddyfile do
    case Api.get_config() do
      {:ok, _resp, config} when is_map(config) ->
        # Return JSON representation since external Caddy uses JSON config
        Jason.encode!(config, pretty: true)

      _ ->
        ""
    end
  end

  @doc """
  Trigger an immediate health check.
  """
  @spec health_check() :: :ok
  def health_check do
    send(__MODULE__, :health_check)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    case Application.get_env(:caddy, :start, true) do
      false ->
        :ignore

      true ->
        health_interval = Config.health_interval()

        state = %{
          caddy_status: :unknown,
          config_pushed: false,
          last_health_check: nil,
          health_interval: health_interval
        }

        Caddy.Telemetry.log_info("External Caddy server starting",
          module: __MODULE__,
          admin_url: Config.admin_url(),
          health_interval: health_interval
        )

        Caddy.Telemetry.emit_external_event(:init, %{}, %{
          admin_url: Config.admin_url(),
          health_interval: health_interval
        })

        {:ok, state, {:continue, :initial_setup}}
    end
  end

  @impl true
  def handle_continue(:initial_setup, state) do
    # Check initial status
    {new_status, state} = do_health_check(state)

    # If running and config not pushed, push it
    state =
      if new_status == :running and not state.config_pushed do
        case push_initial_config() do
          :ok ->
            Caddy.Telemetry.emit_external_event(:config_pushed, %{}, %{on_startup: true})
            %{state | config_pushed: true}

          {:error, reason} ->
            Caddy.Telemetry.log_warning("Failed to push initial config: #{inspect(reason)}",
              module: __MODULE__,
              error: reason
            )

            state
        end
      else
        state
      end

    # Schedule periodic health check
    schedule_health_check(state.health_interval)

    {:noreply, state}
  end

  @impl true
  def handle_call(:check_status, _from, state) do
    {:reply, state.caddy_status, state}
  end

  def handle_call({:execute_command, command}, _from, state) do
    start_time = System.monotonic_time()
    result = do_execute_command(command)
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_external_event(:command_executed, %{duration: duration}, %{
      command: command,
      result: elem(result, 0)
    })

    # If command was start/restart, trigger health check
    state =
      if command in [:start, :restart] and elem(result, 0) == :ok do
        # Give Caddy a moment to start, then check
        Process.send_after(self(), :health_check, 1_000)
        state
      else
        state
      end

    {:reply, result, state}
  end

  def handle_call(:push_config, _from, state) do
    case push_initial_config() do
      :ok ->
        Caddy.Telemetry.emit_external_event(:config_pushed, %{}, %{manual: true})
        {:reply, :ok, %{state | config_pushed: true}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    {new_status, state} = do_health_check(state)

    # If just became running and config not pushed, push it
    state =
      if new_status == :running and not state.config_pushed do
        case push_initial_config() do
          :ok ->
            Caddy.Telemetry.emit_external_event(:config_pushed, %{}, %{on_health_check: true})
            %{state | config_pushed: true}

          {:error, _reason} ->
            state
        end
      else
        state
      end

    # Schedule next health check
    schedule_health_check(state.health_interval)

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    Caddy.Telemetry.log_debug("External Caddy server terminating",
      module: __MODULE__,
      reason: reason
    )

    Caddy.Telemetry.emit_external_event(:terminate, %{}, %{reason: reason})
    :ok
  end

  # Private Functions

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  defp do_health_check(state) do
    start_time = System.monotonic_time()
    old_status = state.caddy_status

    new_status =
      case Api.health_check() do
        {:ok, %{status: :healthy}} ->
          :running

        {:ok, _} ->
          :running

        {:error, "Connection failed: " <> reason} ->
          # Check if it's a connection refused error
          if String.contains?(reason, "econnrefused") do
            :stopped
          else
            :unknown
          end

        {:error, _reason} ->
          :unknown
      end

    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_external_event(:health_check, %{duration: duration}, %{
      status: new_status,
      previous_status: old_status
    })

    # Emit status change event if status changed
    if new_status != old_status do
      Caddy.Telemetry.emit_external_event(:status_changed, %{}, %{
        from: old_status,
        to: new_status
      })

      Caddy.Telemetry.log_info("Caddy status changed: #{old_status} -> #{new_status}",
        module: __MODULE__,
        from: old_status,
        to: new_status
      )
    end

    state = %{
      state
      | caddy_status: new_status,
        last_health_check: DateTime.utc_now()
    }

    {new_status, state}
  end

  defp do_execute_command(command) do
    case Config.command(command) do
      nil ->
        {:error, {:command_not_configured, command}}

      cmd_string when is_binary(cmd_string) ->
        execute_shell_command(cmd_string)
    end
  end

  defp execute_shell_command(cmd_string) do
    # Parse command string into executable and args
    [executable | args] = String.split(cmd_string)

    Caddy.Telemetry.log_debug("Executing command: #{cmd_string}",
      module: __MODULE__,
      executable: executable,
      args: args
    )

    case System.cmd(executable, args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, exit_code} ->
        Caddy.Telemetry.log_warning("Command failed: #{cmd_string}",
          module: __MODULE__,
          exit_code: exit_code,
          output: output
        )

        {:error, {:command_failed, exit_code, output}}
    end
  rescue
    e in ErlangError ->
      {:error, {:command_error, e.original}}
  end

  defp push_initial_config do
    # Get the in-memory configuration
    config = Caddy.ConfigProvider.get_config()
    caddyfile = Config.to_caddyfile(config)

    if String.trim(caddyfile) == "" do
      Caddy.Telemetry.log_debug("No Caddyfile configured, skipping config push",
        module: __MODULE__
      )

      :ok
    else
      # Adapt and push via API
      case Api.adapt(caddyfile) do
        {:ok, _resp, json_config} when is_map(json_config) ->
          case Api.load(json_config) do
            {:ok, _resp, _body} ->
              Caddy.Telemetry.log_info("Configuration pushed to external Caddy",
                module: __MODULE__
              )

              :ok

            {:error, reason} ->
              {:error, {:load_failed, reason}}
          end

        {:ok, _resp, _non_map} ->
          {:error, :invalid_adapt_response}

        {:error, reason} ->
          {:error, {:adapt_failed, reason}}
      end
    end
  end
end
