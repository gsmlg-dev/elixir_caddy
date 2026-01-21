defmodule Caddy.Server do
  @moduledoc """
  Caddy Server - Mode-based server selection.

  This module delegates to the appropriate server implementation based on the
  configured mode:

  - `:embedded` (default) - Uses `Caddy.Server.Embedded` to manage a local Caddy process
  - `:external` - Uses `Caddy.Server.External` to communicate with an externally managed Caddy

  ## Embedded Mode

  In embedded mode, the Caddy binary is spawned and managed directly by this application.
  The server handles process lifecycle, output logging, and cleanup.

  ## External Mode

  In external mode, Caddy is managed by an external system (e.g., systemd).
  This server communicates via the Admin API and can execute system commands
  for lifecycle operations.

  ## Configuration

      # Embedded mode (default)
      config :caddy, mode: :embedded
      config :caddy, caddy_bin: "/usr/bin/caddy"

      # External mode
      config :caddy, mode: :external
      config :caddy, admin_url: "http://localhost:2019"
      config :caddy, commands: [
        start: "systemctl start caddy",
        stop: "systemctl stop caddy",
        restart: "systemctl restart caddy",
        status: "systemctl is-active caddy"
      ]
  """

  alias Caddy.Config

  @doc """
  Returns a child specification for the supervisor.

  This delegates to the appropriate implementation based on mode.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Start the appropriate server based on the configured mode.
  """
  def start_link(opts \\ []) do
    impl_module().start_link(opts)
  end

  @doc """
  Returns the current server implementation module.
  """
  @spec impl_module() :: module()
  def impl_module do
    case Config.mode() do
      :embedded -> Caddy.Server.Embedded
      :external -> Caddy.Server.External
    end
  end

  @doc """
  Get Caddyfile content of the current running server.

  In embedded mode, reads from the local etc directory.
  In external mode, fetches via Admin API.
  """
  @spec get_caddyfile() :: binary()
  def get_caddyfile do
    case Config.mode() do
      :embedded -> Caddy.Server.Embedded.get_caddyfile()
      :external -> Caddy.Server.External.get_caddyfile()
    end
  end

  @doc """
  Check the status of the Caddy server.

  Returns:
  - `:running` - Caddy is running and responding
  - `:stopped` - Caddy is not running
  - `:unknown` - Status cannot be determined
  """
  @spec check_status() :: :running | :stopped | :unknown
  def check_status do
    case Config.mode() do
      :embedded -> check_embedded_status()
      :external -> Caddy.Server.External.check_status()
    end
  end

  @doc """
  Execute a lifecycle command (external mode only).

  Available commands: `:start`, `:stop`, `:restart`, `:status`

  Returns `{:error, :embedded_mode}` if called in embedded mode.
  """
  @spec execute_command(atom()) :: {:ok, binary()} | {:error, term()}
  def execute_command(command) do
    case Config.mode() do
      :embedded -> {:error, :embedded_mode}
      :external -> Caddy.Server.External.execute_command(command)
    end
  end

  # Check embedded status by verifying the process is alive
  defp check_embedded_status do
    case Process.whereis(Caddy.Server.Embedded) do
      nil -> :stopped
      _pid -> :running
    end
  end
end
