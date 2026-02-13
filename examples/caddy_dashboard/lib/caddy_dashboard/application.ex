defmodule CaddyDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize dashboard settings (loads from file and applies to config)
    CaddyDashboard.Settings.init()

    # Note: Caddy.Supervisor is auto-started by the :caddy application
    # so we don't add it here to avoid "already started" errors
    children = [
      CaddyDashboardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:caddy_dashboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CaddyDashboard.PubSub},
      CaddyDashboard.TelemetryCollector,
      CaddyDashboardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CaddyDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CaddyDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
