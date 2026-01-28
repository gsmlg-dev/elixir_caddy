defmodule Caddy.Telemetry do
  @moduledoc """
  Telemetry integration for Caddy reverse proxy server monitoring.

  Provides metrics and events for configuration changes, server lifecycle,
  API operations, and performance monitoring.
  """

  require Logger

  @doc """
  Emits a telemetry event for configuration changes.
  """
  @spec emit_config_change(atom(), map(), keyword() | map()) :: :ok
  def emit_config_change(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :config, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for server lifecycle events.
  """
  @spec emit_server_event(atom(), map(), keyword() | map()) :: :ok
  def emit_server_event(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :server, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for API operations.
  """
  @spec emit_api_event(atom(), map(), keyword() | map()) :: :ok
  def emit_api_event(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :api, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for configuration validation.
  """
  @spec emit_validation_event(atom(), map(), keyword() | map()) :: :ok
  def emit_validation_event(result, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :validation, result], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for file operations.
  """
  @spec emit_file_event(atom(), map(), keyword()) :: :ok
  def emit_file_event(operation, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :file, operation], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for adaptation operations.
  """
  @spec emit_adapt_event(atom(), map(), keyword() | map()) :: :ok
  def emit_adapt_event(result, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :adapt, result], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for ConfigManager operations.

  ## Event Types

  - `:sync_to_caddy` - When syncing in-memory config to running Caddy
  - `:sync_from_caddy` - When pulling config from running Caddy
  - `:drift_check` - When checking for config drift
  - `:rollback` - When rolling back to previous config
  - `:apply` - When applying runtime config directly
  - `:validate` - When validating config

  ## Examples

      Caddy.Telemetry.emit_config_manager_event(:sync_to_caddy, %{duration: 100}, %{success: true})
  """
  @spec emit_config_manager_event(atom(), map(), keyword() | map()) :: :ok
  def emit_config_manager_event(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :config_manager, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for Resources operations.

  ## Event Types

  - `:get` - When reading a resource
  - `:set` - When updating a resource
  - `:delete` - When deleting a resource
  - `:error` - When an operation fails

  ## Examples

      Caddy.Telemetry.emit_resources_event(:get, %{duration: 50}, %{resource: :http_servers})
  """
  @spec emit_resources_event(atom(), map(), keyword() | map()) :: :ok
  def emit_resources_event(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :resources, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for metrics operations.

  ## Event Types

  - `:collected` - When metrics are successfully fetched and parsed
  - `:fetch_error` - When fetching metrics fails
  - `:poller_started` - When the metrics poller starts
  - `:poller_stopped` - When the metrics poller stops

  ## Examples

      Caddy.Telemetry.emit_metrics_event(:collected, %{duration: 50}, %{metric_count: 25})
  """
  @spec emit_metrics_event(atom(), map(), keyword() | map()) :: :ok
  def emit_metrics_event(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :metrics, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for application state changes.

  ## Event: [:caddy, :state, :changed]

  This event is emitted whenever the application state machine transitions
  from one state to another.

  ## Metadata

  - `:from` - The previous state
  - `:to` - The new state

  ## Examples

      Caddy.Telemetry.emit_state_change_event(:unconfigured, :configured)
  """
  @spec emit_state_change_event(atom(), atom()) :: :ok
  def emit_state_change_event(from_state, to_state) do
    :telemetry.execute(
      [:caddy, :state, :changed],
      %{timestamp: System.system_time()},
      %{from: from_state, to: to_state}
    )
  end

  @doc """
  Emits a telemetry event for external mode operations.

  ## Event Types

  - `:init` - When external server initializes
  - `:health_check` - When health check is performed
  - `:command_executed` - When a system command is executed
  - `:config_pushed` - When configuration is pushed to external Caddy
  - `:status_changed` - When Caddy status changes (running/stopped/unknown)
  - `:terminate` - When external server terminates

  ## Examples

      Caddy.Telemetry.emit_external_event(:health_check, %{duration: 50}, %{status: :running})
      Caddy.Telemetry.emit_external_event(:command_executed, %{duration: 100}, %{command: :restart})
  """
  @spec emit_external_event(atom(), map(), keyword() | map()) :: :ok
  def emit_external_event(event_type, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :external, event_type], measurements, metadata)
  end

  @doc """
  Emits a telemetry event for logging operations.
  """
  @spec emit_log_event(atom(), map(), keyword() | map()) :: :ok
  def emit_log_event(level, measurements \\ %{}, metadata \\ []) do
    metadata = Map.new(metadata)
    :telemetry.execute([:caddy, :log, level], measurements, metadata)
  end

  @doc """
  Emits a debug level log event.

  ## Examples

      Caddy.Telemetry.log_debug("Server starting", module: __MODULE__)
  """
  @spec log_debug(String.t(), keyword() | map()) :: :ok
  def log_debug(message, metadata \\ []) do
    metadata =
      metadata
      |> Map.new()
      |> Map.put(:message, message)
      |> Map.put(:level, :debug)

    emit_log_event(:debug, %{timestamp: System.system_time()}, metadata)
  end

  @doc """
  Emits an info level log event.

  ## Examples

      Caddy.Telemetry.log_info("Configuration loaded", config_size: 10)
  """
  @spec log_info(String.t(), keyword() | map()) :: :ok
  def log_info(message, metadata \\ []) do
    metadata =
      metadata
      |> Map.new()
      |> Map.put(:message, message)
      |> Map.put(:level, :info)

    emit_log_event(:info, %{timestamp: System.system_time()}, metadata)
  end

  @doc """
  Emits a warning level log event.

  ## Examples

      Caddy.Telemetry.log_warning("Deprecated function used", function: :old_api)
  """
  @spec log_warning(String.t(), keyword() | map()) :: :ok
  def log_warning(message, metadata \\ []) do
    metadata =
      metadata
      |> Map.new()
      |> Map.put(:message, message)
      |> Map.put(:level, :warning)

    emit_log_event(:warning, %{timestamp: System.system_time()}, metadata)
  end

  @doc """
  Emits an error level log event.

  ## Examples

      Caddy.Telemetry.log_error("Failed to start server", error: reason)
  """
  @spec log_error(String.t(), keyword() | map()) :: :ok
  def log_error(message, metadata \\ []) do
    metadata =
      metadata
      |> Map.new()
      |> Map.put(:message, message)
      |> Map.put(:level, :error)

    emit_log_event(:error, %{timestamp: System.system_time()}, metadata)
  end

  @doc """
  Starts telemetry poller for periodic metrics.
  """
  @dialyzer {:nowarn_function, start_poller: 0, start_poller: 1}
  @spec start_poller(non_neg_integer()) :: {:ok, pid()} | {:error, term()} | :ignore
  def start_poller(interval_ms \\ 30_000) do
    measurements = %{
      memory: fn -> :erlang.memory() end,
      process_count: fn -> :erlang.system_info(:process_count) end,
      uptime: fn -> :erlang.system_time(:second) - :erlang.system_info(:start_time) end
    }

    :telemetry_poller.start_link(
      name: :caddy_telemetry_poller,
      measurements: measurements,
      period: interval_ms,
      telemetry_event_prefix: [:caddy, :system]
    )
  end

  @doc """
  Attaches a telemetry handler for common Caddy events.
  """
  @spec attach_handler(atom(), list(), function()) :: :ok | {:error, term()}
  def attach_handler(handler_name, events, fun) do
    :telemetry.attach_many(handler_name, events, fun, %{})
  end

  @doc """
  Detaches a telemetry handler.
  """
  @spec detach_handler(atom()) :: :ok
  def detach_handler(handler_name) do
    :telemetry.detach(handler_name)
  end

  @doc """
  Returns list of all Caddy telemetry events.
  """
  @spec list_events() :: list()
  def list_events do
    [
      [:caddy, :config, :set],
      [:caddy, :config, :get],
      [:caddy, :config, :save],
      [:caddy, :config, :load],
      [:caddy, :config, :backup],
      [:caddy, :config, :restore],
      [:caddy, :server, :start],
      [:caddy, :server, :stop],
      [:caddy, :server, :restart],
      [:caddy, :server, :status],
      [:caddy, :api, :request],
      [:caddy, :api, :response],
      [:caddy, :api, :error],
      [:caddy, :validation, :success],
      [:caddy, :validation, :error],
      [:caddy, :file, :read],
      [:caddy, :file, :write],
      [:caddy, :file, :delete],
      [:caddy, :adapt, :success],
      [:caddy, :adapt, :error],
      [:caddy, :log, :received],
      [:caddy, :log, :buffered],
      [:caddy, :log, :buffer_flush],
      [:caddy, :log, :stored],
      [:caddy, :log, :retrieved],
      [:caddy, :log, :debug],
      [:caddy, :log, :info],
      [:caddy, :log, :warning],
      [:caddy, :log, :error],
      [:caddy, :system, :memory],
      [:caddy, :system, :process_count],
      [:caddy, :system, :uptime],
      # ConfigManager events
      [:caddy, :config_manager, :sync_to_caddy],
      [:caddy, :config_manager, :sync_from_caddy],
      [:caddy, :config_manager, :drift_check],
      [:caddy, :config_manager, :rollback],
      [:caddy, :config_manager, :apply],
      [:caddy, :config_manager, :validate],
      # Resources events
      [:caddy, :resources, :get],
      [:caddy, :resources, :set],
      [:caddy, :resources, :delete],
      [:caddy, :resources, :error],
      # External mode events
      [:caddy, :external, :init],
      [:caddy, :external, :health_check],
      [:caddy, :external, :command_executed],
      [:caddy, :external, :config_pushed],
      [:caddy, :external, :status_changed],
      [:caddy, :external, :terminate],
      # State machine events
      [:caddy, :state, :changed],
      # Metrics events
      [:caddy, :metrics, :collected],
      [:caddy, :metrics, :fetch_error],
      [:caddy, :metrics, :poller_started],
      [:caddy, :metrics, :poller_stopped]
    ]
  end
end
