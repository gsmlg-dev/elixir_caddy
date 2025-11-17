defmodule Caddy.Logger.Handler do
  @moduledoc """
  Default telemetry handler that forwards log events to Elixir's Logger.

  Automatically attached by Caddy.Logger unless disabled via configuration:

      config :caddy, attach_default_handler: false

  Respects configured log level:

      config :caddy, log_level: :info  # Only :info and above

  ## Telemetry Events Handled

  This handler listens to:
  - `[:caddy, :log, :debug]`
  - `[:caddy, :log, :info]`
  - `[:caddy, :log, :warning]`
  - `[:caddy, :log, :error]`
  - `[:caddy, :log, :received]` - Caddy process output

  ## Performance

  This handler is designed to be lightweight with minimal memory allocation.
  It forwards events synchronously to Elixir's Logger, which handles
  buffering and I/O asynchronously.
  """

  require Logger

  @log_levels [:debug, :info, :warning, :error]

  @doc """
  Attaches the default handler to all Caddy log events.

  Returns `:ok` if successful, or `{:error, :already_exists}` if the
  handler is already attached.
  """
  @spec attach() :: :ok | {:error, term()}
  def attach do
    events = [
      [:caddy, :log, :debug],
      [:caddy, :log, :info],
      [:caddy, :log, :warning],
      [:caddy, :log, :error],
      [:caddy, :log, :received]
    ]

    :telemetry.attach_many(
      :caddy_default_log_handler,
      events,
      &handle_event/4,
      %{}
    )
  end

  @doc """
  Detaches the default handler.
  """
  @spec detach() :: :ok | {:error, :not_found}
  def detach do
    :telemetry.detach(:caddy_default_log_handler)
  end

  @doc false
  def handle_event([:caddy, :log, level], _measurements, metadata, _config)
      when level in @log_levels do
    if should_log?(level) do
      log_to_logger(level, metadata)
    end
  end

  def handle_event([:caddy, :log, :received], _measurements, metadata, _config) do
    # Log Caddy process output at debug level
    if should_log?(:debug) do
      message = metadata[:message] || "(no message)"
      Logger.debug("[Caddy] #{message}")
    end
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  # Private functions

  defp should_log?(level) do
    configured_level = Application.get_env(:caddy, :log_level, :debug)
    level_value(level) >= level_value(configured_level)
  end

  defp level_value(:debug), do: 0
  defp level_value(:info), do: 1
  defp level_value(:warning), do: 2
  defp level_value(:error), do: 3

  defp log_to_logger(level, metadata) do
    message = metadata[:message] || "(no message)"

    case level do
      :debug -> Logger.debug(message, caddy: true)
      :info -> Logger.info(message, caddy: true)
      :warning -> Logger.warning(message, caddy: true)
      :error -> Logger.error(message, caddy: true)
    end
  end
end
