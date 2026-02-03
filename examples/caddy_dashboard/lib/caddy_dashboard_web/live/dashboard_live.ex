defmodule CaddyDashboardWeb.DashboardLive do
  @moduledoc """
  LiveView for the Caddy reverse proxy management dashboard.

  Displays real-time application state, operating mode, readiness,
  configuration status, and sync status with live updates via telemetry.
  """
  use CaddyDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      CaddyDashboard.TelemetryCollector.subscribe()
    end

    {:ok, assign_caddy_state(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign_caddy_state(socket)}
  end

  @impl true
  def handle_info({:caddy_telemetry, entry}, socket) do
    socket =
      if entry.event == [:caddy, :config_manager, :state_changed] do
        assign_caddy_state(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  defp assign_caddy_state(socket) do
    socket
    |> assign(:state, safe_get_state())
    |> assign(:mode, get_mode())
    |> assign(:ready, safe_check_ready())
    |> assign(:configured, safe_check_configured())
    |> assign(:sync_status, safe_check_sync_status())
    |> assign(:page_title, "Dashboard")
  end

  defp safe_get_state do
    try do
      Caddy.get_state()
    rescue
      _ -> :unavailable
    end
  end

  defp get_mode do
    Application.get_env(:caddy, :mode, :external)
  end

  defp safe_check_ready do
    try do
      Caddy.ready?()
    rescue
      _ -> false
    end
  end

  defp safe_check_configured do
    try do
      Caddy.configured?()
    rescue
      _ -> false
    end
  end

  defp safe_check_sync_status do
    try do
      Caddy.check_sync_status()
    rescue
      _ -> {:error, :unavailable}
    end
  end

  defp state_badge_class(:unconfigured), do: "badge-warning"
  defp state_badge_class(:configured), do: "badge-info"
  defp state_badge_class(:synced), do: "badge-success"
  defp state_badge_class(:degraded), do: "badge-error"
  defp state_badge_class(:unavailable), do: "badge-ghost"
  defp state_badge_class(_), do: "badge-ghost"

  defp state_label(:unconfigured), do: "Unconfigured"
  defp state_label(:configured), do: "Configured"
  defp state_label(:synced), do: "Synced"
  defp state_label(:degraded), do: "Degraded"
  defp state_label(:unavailable), do: "Unavailable"
  defp state_label(state), do: to_string(state)

  defp format_mode(:embedded), do: "Embedded"
  defp format_mode(:external), do: "External"
  defp format_mode(mode), do: to_string(mode)

  defp format_sync_status({:ok, :in_sync}), do: {:ok, "In sync"}
  defp format_sync_status({:ok, {:drift_detected, diff}}) do
    {:drift, "Drift detected (#{map_size(diff)} differences)"}
  end
  defp format_sync_status({:error, :unavailable}), do: {:error, "Unavailable"}
  defp format_sync_status({:error, reason}), do: {:error, "Error: #{inspect(reason)}"}
  defp format_sync_status(_), do: {:error, "Unknown"}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/"}>
      <div class="space-y-6">
        <!-- Page Header -->
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold flex items-center gap-3">
              <.icon name="hero-home" class="size-8 text-primary" />
              Dashboard
            </h1>
            <p class="text-base-content/60 mt-1">Caddy reverse proxy status and monitoring</p>
          </div>
          <button
            phx-click="refresh"
            class="btn btn-primary gap-2"
            title="Refresh all data"
          >
            <.icon name="hero-arrow-path" class="size-5" />
            Refresh
          </button>
        </div>

        <!-- Status Overview Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- Application State -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-base">Application State</h2>
              <div class="flex items-center gap-3 mt-2">
                <div class={["badge badge-lg", state_badge_class(@state)]}>
                  {state_label(@state)}
                </div>
              </div>
              <p class="text-xs text-base-content/60 mt-2">
                Current operational state
              </p>
            </div>
          </div>

          <!-- Operating Mode -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-base">Operating Mode</h2>
              <div class="flex items-center gap-3 mt-2">
                <.icon
                  name={if @mode == :embedded, do: "hero-cube", else: "hero-cloud"}
                  class="size-8 text-primary"
                />
                <span class="text-2xl font-bold">{format_mode(@mode)}</span>
              </div>
              <p class="text-xs text-base-content/60 mt-2">
                Server management mode
              </p>
            </div>
          </div>

          <!-- Ready Status -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-base">Ready Status</h2>
              <div class="flex items-center gap-3 mt-2">
                <div class={[
                  "badge badge-lg",
                  if(@ready, do: "badge-success", else: "badge-error")
                ]}>
                  <.icon
                    name={if @ready, do: "hero-check-circle", else: "hero-x-circle"}
                    class="size-4 mr-1"
                  />
                  {if @ready, do: "Ready", else: "Not Ready"}
                </div>
              </div>
              <p class="text-xs text-base-content/60 mt-2">
                Server readiness check
              </p>
            </div>
          </div>

          <!-- Configuration Status -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-base">Configuration</h2>
              <div class="flex items-center gap-3 mt-2">
                <div class={[
                  "badge badge-lg",
                  if(@configured, do: "badge-success", else: "badge-warning")
                ]}>
                  <.icon
                    name={if @configured, do: "hero-check-circle", else: "hero-exclamation-triangle"}
                    class="size-4 mr-1"
                  />
                  {if @configured, do: "Configured", else: "Not Configured"}
                </div>
              </div>
              <p class="text-xs text-base-content/60 mt-2">
                Configuration status
              </p>
            </div>
          </div>
        </div>

        <!-- Sync Status Card -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title flex items-center gap-2">
              <.icon name="hero-arrow-path-rounded-square" class="size-5 text-primary" />
              Synchronization Status
            </h2>

            <%= case format_sync_status(@sync_status) do %>
              <% {:ok, message} -> %>
                <div class="alert alert-success">
                  <.icon name="hero-check-circle" class="size-5" />
                  <span>{message}</span>
                </div>
              <% {:drift, message} -> %>
                <div class="alert alert-warning">
                  <.icon name="hero-exclamation-triangle" class="size-5" />
                  <span>{message}</span>
                </div>
              <% {:error, message} -> %>
                <div class="alert alert-error">
                  <.icon name="hero-x-circle" class="size-5" />
                  <span>{message}</span>
                </div>
            <% end %>

            <p class="text-sm text-base-content/70 mt-2">
              Comparison between expected configuration and running Caddy state
            </p>
          </div>
        </div>

        <!-- System Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title flex items-center gap-2">
              <.icon name="hero-information-circle" class="size-5 text-primary" />
              System Information
            </h2>

            <div class="stats stats-vertical lg:stats-horizontal shadow-sm bg-base-200">
              <div class="stat">
                <div class="stat-title">State</div>
                <div class="stat-value text-2xl">{state_label(@state)}</div>
                <div class="stat-desc">Current application state</div>
              </div>

              <div class="stat">
                <div class="stat-title">Mode</div>
                <div class="stat-value text-2xl">{format_mode(@mode)}</div>
                <div class="stat-desc">Server management mode</div>
              </div>

              <div class="stat">
                <div class="stat-title">Status</div>
                <div class="stat-value text-2xl">
                  {if @ready and @configured, do: "Operational", else: "Pending"}
                </div>
                <div class="stat-desc">Overall system status</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title flex items-center gap-2">
              <.icon name="hero-bolt" class="size-5 text-primary" />
              Quick Actions
            </h2>

            <div class="flex flex-wrap gap-3 mt-3">
              <a href={~p"/config"} class="btn btn-outline gap-2">
                <.icon name="hero-document-text" class="size-5" />
                View Configuration
              </a>
              <a href={~p"/metrics"} class="btn btn-outline gap-2">
                <.icon name="hero-chart-bar" class="size-5" />
                View Metrics
              </a>
              <a href={~p"/server"} class="btn btn-outline gap-2">
                <.icon name="hero-cog-6-tooth" class="size-5" />
                Server Control
              </a>
              <a href={~p"/logs"} class="btn btn-outline gap-2">
                <.icon name="hero-document-magnifying-glass" class="size-5" />
                View Logs
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
