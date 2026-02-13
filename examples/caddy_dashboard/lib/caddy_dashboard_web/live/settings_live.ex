defmodule CaddyDashboardWeb.SettingsLive do
  @moduledoc """
  LiveView for configuring Caddy operating mode and related settings.

  Allows switching between:
  - **External mode**: Caddy is managed externally (systemd, Docker, etc.)
  - **Embedded mode**: Caddy binary is managed by this application
  """
  use CaddyDashboardWeb, :live_view

  alias CaddyDashboard.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.current()

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:mode, settings["mode"])
      # External mode settings
      |> assign(:admin_url, settings["admin_url"])
      |> assign(:health_interval, settings["health_interval"])
      |> assign(:commands, settings["commands"])
      # Embedded mode settings
      |> assign(:embedded, settings["embedded"])
      |> assign(:save_status, nil)

    {:ok, socket}
  end

  # Mode selection
  @impl true
  def handle_event("select_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, mode)}
  end

  # External mode events
  @impl true
  def handle_event("update_admin_url", %{"admin_url" => url}, socket) do
    {:noreply, assign(socket, :admin_url, url)}
  end

  @impl true
  def handle_event("update_health_interval", %{"interval" => interval_str}, socket) do
    interval =
      case Integer.parse(interval_str) do
        {n, _} when n > 0 -> n
        _ -> 30_000
      end

    {:noreply, assign(socket, :health_interval, interval)}
  end

  @impl true
  def handle_event("update_command", %{"name" => name, "value" => value}, socket) do
    commands = Map.put(socket.assigns.commands, name, value)
    {:noreply, assign(socket, :commands, commands)}
  end

  # Embedded mode events
  @impl true
  def handle_event("update_embedded", %{"field" => field, "value" => value}, socket) do
    embedded = Map.put(socket.assigns.embedded, field, value)
    {:noreply, assign(socket, :embedded, embedded)}
  end

  @impl true
  def handle_event("toggle_embedded", %{"field" => field}, socket) do
    current_value = socket.assigns.embedded[field] || false
    embedded = Map.put(socket.assigns.embedded, field, !current_value)
    {:noreply, assign(socket, :embedded, embedded)}
  end

  @impl true
  def handle_event("detect_caddy", _params, socket) do
    caddy_bin = System.find_executable("caddy") || detect_default_bin()

    embedded = Map.put(socket.assigns.embedded, "caddy_bin", caddy_bin || "")

    socket =
      if caddy_bin do
        socket
        |> assign(:embedded, embedded)
        |> put_flash(:info, "Detected Caddy at: #{caddy_bin}")
      else
        put_flash(socket, :error, "Could not detect Caddy binary. Please enter path manually.")
      end

    {:noreply, socket}
  end

  defp detect_default_bin do
    cond do
      File.exists?("/usr/bin/caddy") -> "/usr/bin/caddy"
      File.exists?("/opt/homebrew/bin/caddy") -> "/opt/homebrew/bin/caddy"
      File.exists?("/usr/local/bin/caddy") -> "/usr/local/bin/caddy"
      true -> nil
    end
  end

  defp get_caddy_bin do
    try do
      Caddy.get_config().bin || "Not set"
    rescue
      _ -> "Not available"
    end
  end

  # Save and reset
  @impl true
  def handle_event("save_settings", _params, socket) do
    settings = %{
      "mode" => socket.assigns.mode,
      "admin_url" => socket.assigns.admin_url,
      "health_interval" => socket.assigns.health_interval,
      "commands" => socket.assigns.commands,
      "embedded" => socket.assigns.embedded
    }

    socket =
      case Settings.update(settings) do
        :ok ->
          # If in embedded mode, also update the Caddy config binary path
          if socket.assigns.mode == "embedded" do
            caddy_bin = socket.assigns.embedded["caddy_bin"]

            if caddy_bin && caddy_bin != "" do
              try do
                Caddy.ConfigProvider.set_bin(caddy_bin)
              rescue
                _ -> :ok
              end
            end
          end

          socket
          |> put_flash(:info, "Settings saved successfully. Mode changes take effect immediately.")
          |> assign(:save_status, :success)

        {:error, reason} ->
          socket
          |> put_flash(:error, "Failed to save settings: #{inspect(reason)}")
          |> assign(:save_status, :error)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_defaults", _params, socket) do
    defaults = Settings.default_settings()

    socket =
      socket
      |> assign(:mode, defaults["mode"])
      |> assign(:admin_url, defaults["admin_url"])
      |> assign(:health_interval, defaults["health_interval"])
      |> assign(:commands, defaults["commands"])
      |> assign(:embedded, defaults["embedded"])
      |> put_flash(:info, "Settings reset to defaults. Click Save to apply.")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/settings"}>
      <div class="space-y-6">
        <!-- Header -->
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold">Settings</h1>
            <p class="text-base-content/60 mt-1">
              Configure Caddy operating mode and connection settings
            </p>
          </div>
          <div class="flex gap-2">
            <button phx-click="reset_defaults" class="btn btn-outline btn-sm">
              <.icon name="hero-arrow-path" class="size-4" />
              Reset Defaults
            </button>
            <button phx-click="save_settings" class="btn btn-primary btn-sm">
              <.icon name="hero-check" class="size-4" />
              Save Settings
            </button>
          </div>
        </div>

        <!-- Mode Selection -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-cog-8-tooth" class="size-5" />
              Operating Mode
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Choose how Caddy is managed. This affects how the dashboard interacts with Caddy.
            </p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- External Mode Card -->
              <div
                class={[
                  "card border-2 cursor-pointer transition-all hover:shadow-md",
                  @mode == "external" && "border-primary bg-primary/5",
                  @mode != "external" && "border-base-300 hover:border-primary/50"
                ]}
                phx-click="select_mode"
                phx-value-mode="external"
              >
                <div class="card-body">
                  <div class="flex items-start justify-between">
                    <div class="flex items-center gap-2">
                      <.icon name="hero-cloud" class={["size-6", @mode == "external" && "text-primary"]} />
                      <h3 class="card-title text-lg">External Mode</h3>
                    </div>
                    <div :if={@mode == "external"} class="badge badge-primary">Active</div>
                  </div>
                  <p class="text-sm text-base-content/70 mt-2">
                    Caddy is managed externally (systemd, Docker, etc.).
                    The dashboard communicates via the Admin API.
                  </p>
                  <ul class="text-xs text-base-content/60 mt-3 space-y-1">
                    <li class="flex items-center gap-1">
                      <.icon name="hero-check" class="size-3 text-success" />
                      No process management
                    </li>
                    <li class="flex items-center gap-1">
                      <.icon name="hero-check" class="size-3 text-success" />
                      Works with existing Caddy setups
                    </li>
                    <li class="flex items-center gap-1">
                      <.icon name="hero-check" class="size-3 text-success" />
                      Production-friendly
                    </li>
                  </ul>
                </div>
              </div>

              <!-- Embedded Mode Card -->
              <div
                class={[
                  "card border-2 cursor-pointer transition-all hover:shadow-md",
                  @mode == "embedded" && "border-warning bg-warning/5",
                  @mode != "embedded" && "border-base-300 hover:border-warning/50"
                ]}
                phx-click="select_mode"
                phx-value-mode="embedded"
              >
                <div class="card-body">
                  <div class="flex items-start justify-between">
                    <div class="flex items-center gap-2">
                      <.icon name="hero-cpu-chip" class={["size-6", @mode == "embedded" && "text-warning"]} />
                      <h3 class="card-title text-lg">Embedded Mode</h3>
                    </div>
                    <div :if={@mode == "embedded"} class="badge badge-warning">Active</div>
                  </div>
                  <p class="text-sm text-base-content/70 mt-2">
                    Caddy binary is managed by this application.
                    Full lifecycle control from the dashboard.
                  </p>
                  <ul class="text-xs text-base-content/60 mt-3 space-y-1">
                    <li class="flex items-center gap-1">
                      <.icon name="hero-check" class="size-3 text-success" />
                      Start/stop/restart from dashboard
                    </li>
                    <li class="flex items-center gap-1">
                      <.icon name="hero-check" class="size-3 text-success" />
                      Configuration management
                    </li>
                    <li class="flex items-center gap-1">
                      <.icon name="hero-check" class="size-3 text-success" />
                      Development-friendly
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- External Mode Settings -->
        <div :if={@mode == "external"} class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-signal" class="size-5" />
              External Mode Settings
            </h2>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Admin API URL</span>
                </label>
                <input
                  type="text"
                  value={@admin_url}
                  class="input input-bordered font-mono"
                  placeholder="http://localhost:2019"
                  phx-change="update_admin_url"
                  phx-debounce="300"
                  name="admin_url"
                />
                <label class="label">
                  <span class="label-text-alt text-base-content/50">
                    URL to Caddy's Admin API endpoint
                  </span>
                </label>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Health Check Interval (ms)</span>
                </label>
                <input
                  type="number"
                  value={@health_interval}
                  class="input input-bordered font-mono"
                  placeholder="30000"
                  min="1000"
                  phx-change="update_health_interval"
                  phx-debounce="300"
                  name="interval"
                />
                <label class="label">
                  <span class="label-text-alt text-base-content/50">
                    How often to check Caddy health (minimum 1000ms)
                  </span>
                </label>
              </div>
            </div>

            <!-- System Commands -->
            <div class="divider">System Commands</div>
            <p class="text-sm text-base-content/60 mb-4">
              Shell commands for managing the external Caddy process. Leave empty if not needed.
            </p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Start Command</span>
                </label>
                <input
                  type="text"
                  value={@commands["start"]}
                  class="input input-bordered input-sm font-mono"
                  placeholder="systemctl start caddy"
                  phx-change="update_command"
                  phx-value-name="start"
                  phx-debounce="300"
                  name="value"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Stop Command</span>
                </label>
                <input
                  type="text"
                  value={@commands["stop"]}
                  class="input input-bordered input-sm font-mono"
                  placeholder="systemctl stop caddy"
                  phx-change="update_command"
                  phx-value-name="stop"
                  phx-debounce="300"
                  name="value"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Restart Command</span>
                </label>
                <input
                  type="text"
                  value={@commands["restart"]}
                  class="input input-bordered input-sm font-mono"
                  placeholder="systemctl restart caddy"
                  phx-change="update_command"
                  phx-value-name="restart"
                  phx-debounce="300"
                  name="value"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Status Command</span>
                </label>
                <input
                  type="text"
                  value={@commands["status"]}
                  class="input input-bordered input-sm font-mono"
                  placeholder="systemctl is-active caddy"
                  phx-change="update_command"
                  phx-value-name="status"
                  phx-debounce="300"
                  name="value"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Embedded Mode Settings -->
        <div :if={@mode == "embedded"} class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-cpu-chip" class="size-5" />
              Embedded Mode Settings
            </h2>

            <div class="space-y-4 mt-4">
              <!-- Caddy Binary Path -->
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Caddy Binary Path</span>
                </label>
                <div class="flex gap-2">
                  <input
                    type="text"
                    value={@embedded["caddy_bin"]}
                    class="input input-bordered font-mono flex-1"
                    placeholder="/usr/bin/caddy"
                    phx-change="update_embedded"
                    phx-value-field="caddy_bin"
                    phx-debounce="300"
                    name="value"
                  />
                  <button phx-click="detect_caddy" class="btn btn-secondary">
                    <.icon name="hero-magnifying-glass" class="size-4" />
                    Detect
                  </button>
                </div>
                <label class="label">
                  <span class="label-text-alt text-base-content/50">
                    Path to the Caddy executable
                  </span>
                </label>
              </div>

              <!-- Base Path -->
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Base Path</span>
                </label>
                <input
                  type="text"
                  value={@embedded["base_path"]}
                  class="input input-bordered font-mono"
                  placeholder="~/.local/share/caddy"
                  phx-change="update_embedded"
                  phx-value-field="base_path"
                  phx-debounce="300"
                  name="value"
                />
                <label class="label">
                  <span class="label-text-alt text-base-content/50">
                    Directory for Caddy configuration, data, and runtime files
                  </span>
                </label>
              </div>

              <!-- Toggles -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-4">
                    <input
                      type="checkbox"
                      class="toggle toggle-primary"
                      checked={@embedded["auto_start"]}
                      phx-click="toggle_embedded"
                      phx-value-field="auto_start"
                    />
                    <div>
                      <span class="label-text font-medium">Auto Start</span>
                      <p class="text-xs text-base-content/50">Start Caddy when application starts</p>
                    </div>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-4">
                    <input
                      type="checkbox"
                      class="toggle toggle-primary"
                      checked={@embedded["dump_log"]}
                      phx-click="toggle_embedded"
                      phx-value-field="dump_log"
                    />
                    <div>
                      <span class="label-text font-medium">Dump Log</span>
                      <p class="text-xs text-base-content/50">Output Caddy logs to stdout</p>
                    </div>
                  </label>
                </div>
              </div>

              <!-- Path Info -->
              <div class="divider">Computed Paths</div>
              <div class="bg-base-200 rounded-lg p-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                  <div>
                    <span class="font-medium text-base-content/70">Socket File:</span>
                    <code class="ml-2 text-xs">{Caddy.Config.socket_file()}</code>
                  </div>
                  <div>
                    <span class="font-medium text-base-content/70">PID File:</span>
                    <code class="ml-2 text-xs">{Caddy.Config.pid_file()}</code>
                  </div>
                  <div>
                    <span class="font-medium text-base-content/70">Config Path:</span>
                    <code class="ml-2 text-xs">{Caddy.Config.etc_path()}</code>
                  </div>
                  <div>
                    <span class="font-medium text-base-content/70">Data Path:</span>
                    <code class="ml-2 text-xs">{Caddy.Config.xdg_data_home()}</code>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Current Config Info -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-document-text" class="size-5" />
              Current Active Configuration
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              This shows the currently active configuration. Save settings above to update.
            </p>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <tbody>
                  <tr>
                    <td class="font-semibold w-48">Mode</td>
                    <td>
                      <span class={[
                        "badge",
                        Caddy.Config.mode() == :external && "badge-info",
                        Caddy.Config.mode() == :embedded && "badge-warning"
                      ]}>
                        {Caddy.Config.mode()}
                      </span>
                    </td>
                  </tr>
                  <%= if Caddy.Config.mode() == :external do %>
                    <tr>
                      <td class="font-semibold">Admin URL</td>
                      <td class="font-mono text-sm">{Caddy.Config.admin_url()}</td>
                    </tr>
                    <tr>
                      <td class="font-semibold">Health Interval</td>
                      <td>{div(Caddy.Config.health_interval(), 1000)} seconds</td>
                    </tr>
                    <tr>
                      <td class="font-semibold">Commands</td>
                      <td>
                        <%= if Caddy.Config.commands() == [] do %>
                          <span class="text-base-content/50">None configured</span>
                        <% else %>
                          <%= for {name, cmd} <- Caddy.Config.commands() do %>
                            <div class="text-sm">
                              <span class="font-medium">{name}:</span>
                              <code class="text-xs ml-1">{cmd}</code>
                            </div>
                          <% end %>
                        <% end %>
                      </td>
                    </tr>
                  <% else %>
                    <tr>
                      <td class="font-semibold">Caddy Binary</td>
                      <td class="font-mono text-sm">{get_caddy_bin()}</td>
                    </tr>
                    <tr>
                      <td class="font-semibold">Base Path</td>
                      <td class="font-mono text-sm">{Caddy.Config.base_path()}</td>
                    </tr>
                    <tr>
                      <td class="font-semibold">Admin URL</td>
                      <td class="font-mono text-sm">{Caddy.Config.admin_url()}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
