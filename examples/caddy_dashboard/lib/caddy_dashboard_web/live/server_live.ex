defmodule CaddyDashboardWeb.ServerLive do
  use CaddyDashboardWeb, :live_view

  alias CaddyDashboardWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    mode = Application.get_env(:caddy, :mode, :external)
    admin_url = Application.get_env(:caddy, :admin_url, "http://localhost:2019")

    socket =
      socket
      |> assign(:mode, mode)
      |> assign(:admin_url, admin_url)
      |> assign(:status, :unknown)
      |> assign(:server_info, nil)
      |> assign(:error, nil)
      |> load_server_status()
      |> load_server_info()

    {:ok, socket}
  end

  @impl true
  def handle_event("check_status", _params, socket) do
    {:noreply, load_server_status(socket)}
  end

  @impl true
  def handle_event("health_check", _params, socket) do
    socket =
      try do
        result = Caddy.Server.External.health_check()
        assign(socket, :error, "Health check result: #{inspect(result)}")
      rescue
        e ->
          assign(socket, :error, "Health check failed: #{Exception.message(e)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_command", %{"command" => command}, socket) do
    command_atom = String.to_existing_atom(command)

    socket =
      try do
        case Caddy.Server.execute_command(command_atom) do
          :ok ->
            socket
            |> assign(:error, nil)
            |> put_flash(:info, "Command '#{command}' executed successfully")
            |> load_server_status()

          {:ok, _result} ->
            socket
            |> assign(:error, nil)
            |> put_flash(:info, "Command '#{command}' executed successfully")
            |> load_server_status()

          {:error, reason} ->
            assign(socket, :error, "Command failed: #{inspect(reason)}")
        end
      rescue
        e ->
          assign(socket, :error, "Command execution failed: #{Exception.message(e)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("restart_server", _params, socket) do
    socket =
      try do
        case Caddy.restart_server() do
          :ok ->
            socket
            |> assign(:error, nil)
            |> put_flash(:info, "Server restarted successfully")
            |> load_server_status()
            |> load_server_info()

          {:ok, _pid} ->
            socket
            |> assign(:error, nil)
            |> put_flash(:info, "Server restarted successfully")
            |> load_server_status()
            |> load_server_info()

          {:error, reason} ->
            assign(socket, :error, "Restart failed: #{inspect(reason)}")
        end
      rescue
        e ->
          assign(socket, :error, "Restart failed: #{Exception.message(e)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_server", _params, socket) do
    socket =
      try do
        case Caddy.stop() do
          :ok ->
            socket
            |> assign(:error, nil)
            |> put_flash(:info, "Server stopped successfully")
            |> load_server_status()

          {:error, reason} ->
            assign(socket, :error, "Stop failed: #{inspect(reason)}")
        end
      rescue
        e ->
          assign(socket, :error, "Stop failed: #{Exception.message(e)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_server_info", _params, socket) do
    {:noreply, load_server_info(socket)}
  end

  defp load_server_status(socket) do
    status =
      try do
        Caddy.Server.check_status()
      rescue
        _ -> :unknown
      end

    assign(socket, :status, status)
  end

  defp load_server_info(socket) do
    server_info =
      try do
        case Caddy.Admin.Api.server_info() do
          {:ok, info} -> info
          {:error, _reason} -> nil
        end
      rescue
        _ -> nil
      end

    assign(socket, :server_info, server_info)
  end

  defp status_badge_class(:running), do: "badge-success"
  defp status_badge_class(:stopped), do: "badge-error"
  defp status_badge_class(:unknown), do: "badge-warning"

  defp mode_badge_class(:external), do: "badge-primary"
  defp mode_badge_class(:embedded), do: "badge-secondary"

  defp get_binary_path do
    try do
      Caddy.get_config().bin || "not set"
    rescue
      _ -> "unavailable"
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :binary_path, get_binary_path())
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/server"}>
      <div class="container mx-auto p-6 space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">Server Control</h1>
          <div class={"badge badge-lg #{mode_badge_class(@mode)}"}>
            Mode: <%= @mode %>
          </div>
        </div>

        <%= if @error do %>
          <div class="alert alert-error">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="stroke-current shrink-0 h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <span><%= @error %></span>
          </div>
        <% end %>

        <!-- Server Status Card -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Server Status</h2>
            <div class="flex items-center gap-4">
              <div class={"badge badge-lg #{status_badge_class(@status)}"}>
                <%= String.upcase(to_string(@status)) %>
              </div>
              <button class="btn btn-sm btn-outline" phx-click="check_status">
                Refresh Status
              </button>
            </div>
          </div>
        </div>

        <%= if @mode == :external do %>
          <!-- External Mode Controls -->
          <div class="card bg-base-200 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">External Mode Controls</h2>

              <div class="space-y-4">
                <div>
                  <div class="text-sm font-semibold mb-2">Admin URL</div>
                  <div class="badge badge-outline"><%= @admin_url %></div>
                </div>

                <div class="divider">Lifecycle Commands</div>

                <div class="flex gap-2 flex-wrap">
                  <button
                    class="btn btn-success"
                    phx-click="execute_command"
                    phx-value-command="start"
                  >
                    Start Server
                  </button>
                  <button
                    class="btn btn-error"
                    phx-click="execute_command"
                    phx-value-command="stop"
                  >
                    Stop Server
                  </button>
                  <button
                    class="btn btn-warning"
                    phx-click="execute_command"
                    phx-value-command="restart"
                  >
                    Restart Server
                  </button>
                </div>

                <div class="divider">Health & Diagnostics</div>

                <div class="flex gap-2 flex-wrap">
                  <button class="btn btn-info" phx-click="health_check">
                    Health Check
                  </button>
                  <button class="btn btn-outline" phx-click="check_status">
                    Check Status
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% else %>
          <!-- Embedded Mode Controls -->
          <div class="card bg-base-200 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Embedded Mode Controls</h2>

              <div class="space-y-4">
                <div>
                  <div class="text-sm font-semibold mb-2">Binary Path</div>
                  <div class="badge badge-outline font-mono"><%= @binary_path %></div>
                </div>

                <div class="divider">Server Controls</div>

                <div class="flex gap-2 flex-wrap">
                  <button class="btn btn-warning" phx-click="restart_server">
                    Restart Server
                  </button>
                  <button class="btn btn-error" phx-click="stop_server">
                    Stop Server
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Server Info Card -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Server Information</h2>
              <button class="btn btn-sm btn-outline" phx-click="refresh_server_info">
                Refresh
              </button>
            </div>

            <%= if @server_info do %>
              <div class="overflow-x-auto">
                <pre class="bg-base-300 p-4 rounded-lg text-xs overflow-auto max-h-96"><%= Jason.encode!(@server_info, pretty: true) %></pre>
              </div>
            <% else %>
              <div class="text-center py-8 text-base-content/50">
                <p>No server information available</p>
                <p class="text-sm">Server may not be running or API may be unavailable</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
