defmodule CaddyDashboardWeb.Router do
  use CaddyDashboardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CaddyDashboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CaddyDashboardWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/config", ConfigLive, :index
    live "/metrics", MetricsLive, :index
    live "/runtime", RuntimeLive, :index
    live "/server", ServerLive, :index
    live "/logs", LogsLive, :index
    live "/telemetry", TelemetryLive, :index
    live "/settings", SettingsLive, :index
  end
end
