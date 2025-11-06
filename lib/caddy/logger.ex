defmodule Caddy.Logger do
  @moduledoc """
  Supervisor for Caddy logging subsystem.

  Collects caddy process logs from stdout and stderr and maintains
  a rolling buffer of up to 50,000 lines of logs.

  ## Telemetry Integration

  Automatically attaches a default handler that forwards telemetry log
  events to Elixir's Logger. Disable with:

      config :caddy, attach_default_handler: false

  Configure log level filtering:

      config :caddy, log_level: :info  # Only :info and above

  ## Usage

      # Get recent logs
      logs = Caddy.Logger.tail(100)

      # Listen to telemetry events
      :telemetry.attach("my_handler", [:caddy, :log, :stored], fn _event, _meas, metadata, _config ->
        IO.puts("Log stored: " <> metadata.message)
      end, %{})
  """

  require Logger

  use Supervisor

  @doc false
  def write(log) do
    GenServer.cast(Caddy.Logger.Store, {:write, log})
  end

  @doc false
  defdelegate write_buffer(msg), to: Caddy.Logger.Buffer, as: :write

  @doc """
  Get latest `num` logs
  """
  @spec tail(integer()) :: list(binary())
  def tail(num \\ 100) do
    GenServer.call(Caddy.Logger.Store, {:tail, num})
  end

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Caddy.Telemetry.log_debug("Caddy Logger init", module: __MODULE__)

    # Attach default telemetry handler if configured
    if Application.get_env(:caddy, :attach_default_handler, true) do
      Caddy.Logger.Handler.attach()
    end

    children = [
      Caddy.Logger.Buffer,
      Caddy.Logger.Store
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
