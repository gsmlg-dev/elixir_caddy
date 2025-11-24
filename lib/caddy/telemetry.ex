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
      [:caddy, :system, :uptime]
    ]
  end
end
