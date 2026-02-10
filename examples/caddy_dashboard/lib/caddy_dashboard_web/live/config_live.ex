defmodule CaddyDashboardWeb.ConfigLive do
  @moduledoc """
  LiveView for editing Caddy configuration.

  Shows different UI based on operating mode:
  - External mode: Admin URL configuration and connection status
  - Embedded mode: Caddyfile editor, binary path, environment variables
  """
  use CaddyDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    mode = Caddy.Config.mode()

    socket =
      socket
      |> assign(:page_title, "Configuration")
      |> assign(:mode, mode)
      |> assign(:admin_url, Caddy.Config.admin_url())
      |> assign(:commands, Caddy.Config.commands())
      |> assign_mode_specific(mode)

    {:ok, socket}
  end

  defp assign_mode_specific(socket, :external) do
    # External mode - just need connection info
    socket
    |> assign(:health_interval, Caddy.Config.health_interval())
  end

  defp assign_mode_specific(socket, :embedded) do
    # Embedded mode - full config management
    config = load_config()

    socket
    |> assign(:bin, config.bin || "")
    |> assign(:caddyfile, config.caddyfile || "")
    |> assign(:env, config.env || [])
    |> assign(:new_env_key, "")
    |> assign(:new_env_value, "")
    |> assign(:active_tab, "caddyfile")
    |> assign(:validation_result, nil)
    |> assign(:adaptation_result, nil)
  end

  defp load_config do
    try do
      Caddy.get_config()
    rescue
      _ -> %Caddy.Config{}
    end
  end

  # ============================================================================
  # Embedded Mode Events
  # ============================================================================

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("update_bin", %{"bin" => bin}, socket) do
    {:noreply, assign(socket, :bin, bin)}
  end

  @impl true
  def handle_event("save_bin", _params, socket) do
    socket =
      try do
        case Caddy.set_bin(socket.assigns.bin) do
          :ok ->
            put_flash(socket, :info, "Binary path updated successfully")

          {:error, reason} ->
            put_flash(socket, :error, "Failed to set binary: #{format_error(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Error: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_bin_restart", _params, socket) do
    socket =
      try do
        case Caddy.set_bin!(socket.assigns.bin) do
          :ok ->
            put_flash(socket, :info, "Binary path updated and server restarted")

          {:error, reason} ->
            put_flash(socket, :error, "Failed: #{format_error(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Error: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_caddyfile", %{"caddyfile" => caddyfile}, socket) do
    {:noreply, assign(socket, :caddyfile, caddyfile)}
  end

  @impl true
  def handle_event("save_caddyfile", _params, socket) do
    socket =
      try do
        Caddy.set_caddyfile(socket.assigns.caddyfile)

        socket
        |> put_flash(:info, "Caddyfile saved to memory")
        |> assign(:validation_result, nil)
        |> assign(:adaptation_result, nil)
      rescue
        error ->
          put_flash(socket, :error, "Failed to save: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket =
      try do
        case Caddy.validate_caddyfile(socket.assigns.caddyfile) do
          {:ok, _} ->
            assign(socket, :validation_result, {:success, "Configuration is valid"})

          {:error, reason} ->
            assign(socket, :validation_result, {:error, format_error(reason)})
        end
      rescue
        error ->
          assign(socket, :validation_result, {:error, Exception.message(error)})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("adapt", _params, socket) do
    socket =
      try do
        case Caddy.adapt(socket.assigns.caddyfile) do
          {:ok, json} ->
            formatted_json = Jason.encode!(json, pretty: true)
            assign(socket, :adaptation_result, {:success, formatted_json})

          {:error, reason} ->
            assign(socket, :adaptation_result, {:error, format_error(reason)})
        end
      rescue
        error ->
          assign(socket, :adaptation_result, {:error, Exception.message(error)})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("sync", _params, socket) do
    socket =
      try do
        case Caddy.sync_to_caddy(backup: true) do
          :ok ->
            put_flash(socket, :info, "Configuration synced to Caddy (backup created)")

          {:error, reason} ->
            put_flash(socket, :error, "Sync failed: #{format_error(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Sync failed: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_new_env", %{"key" => key, "value" => value}, socket) do
    {:noreply, socket |> assign(:new_env_key, key) |> assign(:new_env_value, value)}
  end

  @impl true
  def handle_event("add_env", _params, socket) do
    key = String.trim(socket.assigns.new_env_key)
    value = String.trim(socket.assigns.new_env_value)

    socket =
      if key != "" do
        env = socket.assigns.env ++ [{key, value}]

        socket
        |> assign(:env, env)
        |> assign(:new_env_key, "")
        |> assign(:new_env_value, "")
        |> save_env_to_config(env)
      else
        put_flash(socket, :error, "Environment variable key cannot be empty")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_env", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    env = List.delete_at(socket.assigns.env, index)

    socket =
      socket
      |> assign(:env, env)
      |> save_env_to_config(env)

    {:noreply, socket}
  end

  defp save_env_to_config(socket, env) do
    try do
      config = Caddy.get_config()
      new_config = %{config | env: env}
      Caddy.set_config(new_config)
      put_flash(socket, :info, "Environment variables updated")
    rescue
      error ->
        put_flash(socket, :error, "Failed to save env: #{Exception.message(error)}")
    end
  end

  @impl true
  def handle_event("backup", _params, socket) do
    socket =
      try do
        case Caddy.backup_config() do
          :ok ->
            put_flash(socket, :info, "Configuration backed up successfully")

          {:error, reason} ->
            put_flash(socket, :error, "Backup failed: #{format_error(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Backup failed: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore", _params, socket) do
    socket =
      try do
        case Caddy.restore_config() do
          {:ok, config} ->
            socket
            |> put_flash(:info, "Configuration restored from backup")
            |> assign(:bin, config.bin || "")
            |> assign(:caddyfile, config.caddyfile || "")
            |> assign(:env, config.env || [])
            |> assign(:validation_result, nil)
            |> assign(:adaptation_result, nil)

          {:error, reason} ->
            put_flash(socket, :error, "Restore failed: #{format_error(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Restore failed: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_all", _params, socket) do
    socket =
      try do
        case Caddy.save_config() do
          :ok ->
            put_flash(socket, :info, "Configuration saved to disk")

          {:error, reason} ->
            put_flash(socket, :error, "Save failed: #{format_error(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Save failed: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error({:adaptation_failed, msg}), do: "Adaptation failed: #{msg}"
  defp format_error(reason), do: inspect(reason)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/config"}>
      <div class="space-y-6">
        <!-- Header -->
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold">Configuration</h1>
            <p class="text-base-content/60 mt-1">
              Operating Mode:
              <span class={[
                "badge",
                @mode == :external && "badge-info",
                @mode == :embedded && "badge-warning"
              ]}>
                {@mode}
              </span>
            </p>
          </div>
        </div>

        <!-- Mode-specific content -->
        <%= if @mode == :external do %>
          <.external_mode_config {assigns} />
        <% else %>
          <.embedded_mode_config {assigns} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # External Mode UI
  # ============================================================================

  defp external_mode_config(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Connection Info -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-signal" class="size-5" />
            External Caddy Connection
          </h2>
          <p class="text-base-content/60">
            Caddy is managed externally (e.g., systemd, Docker). This library communicates with it via the Admin API.
          </p>

          <div class="stats shadow mt-4">
            <div class="stat">
              <div class="stat-title">Admin API URL</div>
              <div class="stat-value text-lg font-mono">{@admin_url}</div>
              <div class="stat-desc">Configure via <code>config :caddy, admin_url: "..."</code></div>
            </div>
            <div class="stat">
              <div class="stat-title">Health Check Interval</div>
              <div class="stat-value text-lg">{div(@health_interval, 1000)}s</div>
              <div class="stat-desc">Configure via <code>config :caddy, health_interval: ...</code></div>
            </div>
          </div>
        </div>
      </div>

      <!-- System Commands -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-command-line" class="size-5" />
            System Commands
          </h2>
          <p class="text-base-content/60">
            Commands used for lifecycle management of the external Caddy process.
          </p>

          <%= if @commands == [] do %>
            <div class="alert alert-info mt-4">
              <.icon name="hero-information-circle" class="size-5" />
              <div>
                <p class="font-semibold">No commands configured</p>
                <p class="text-sm">
                  Configure commands in your application config:
                </p>
                <pre class="text-xs mt-2 bg-base-200 p-2 rounded whitespace-pre-wrap">config :caddy, commands: [start: "systemctl start caddy", stop: "systemctl stop caddy", restart: "systemctl restart caddy"]</pre>
              </div>
            </div>
          <% else %>
            <div class="overflow-x-auto mt-4">
              <table class="table">
                <thead>
                  <tr>
                    <th>Command</th>
                    <th>Shell Command</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {name, cmd} <- @commands do %>
                    <tr>
                      <td class="font-semibold">{name}</td>
                      <td class="font-mono text-sm">{cmd}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Configuration Note -->
      <div class="alert">
        <.icon name="hero-light-bulb" class="size-5" />
        <div>
          <p class="font-semibold">External Mode</p>
          <p class="text-sm">
            In external mode, Caddy's configuration is managed separately (e.g., via /etc/caddy/Caddyfile).
            Use the <a href="/runtime" class="link link-primary">Runtime Config</a> page to view and modify
            the running Caddy's configuration via the Admin API.
          </p>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Embedded Mode UI
  # ============================================================================

  defp embedded_mode_config(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header Actions -->
      <div class="flex justify-end gap-2">
        <button phx-click="backup" class="btn btn-outline btn-sm">
          <.icon name="hero-archive-box-arrow-down" class="size-4" />
          Backup
        </button>
        <button phx-click="restore" class="btn btn-outline btn-sm">
          <.icon name="hero-arrow-uturn-left" class="size-4" />
          Restore
        </button>
        <button phx-click="save_all" class="btn btn-primary btn-sm">
          <.icon name="hero-arrow-down-tray" class="size-4" />
          Save to Disk
        </button>
      </div>

      <!-- Tab Navigation -->
      <div role="tablist" class="tabs tabs-boxed">
        <button
          role="tab"
          class={["tab", @active_tab == "caddyfile" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="caddyfile"
        >
          <.icon name="hero-document-text" class="size-4 mr-2" />
          Caddyfile
        </button>
        <button
          role="tab"
          class={["tab", @active_tab == "binary" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="binary"
        >
          <.icon name="hero-command-line" class="size-4 mr-2" />
          Binary Path
        </button>
        <button
          role="tab"
          class={["tab", @active_tab == "env" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="env"
        >
          <.icon name="hero-variable" class="size-4 mr-2" />
          Environment
        </button>
      </div>

      <!-- Caddyfile Tab -->
      <div :if={@active_tab == "caddyfile"} class="space-y-4">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-document-text" class="size-5" />
              Caddyfile Editor
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Write your Caddyfile configuration using native Caddyfile syntax.
            </p>

            <textarea
              name="caddyfile"
              rows="18"
              class="textarea textarea-bordered w-full font-mono text-sm leading-relaxed"
              placeholder="Enter your Caddyfile configuration..."
              phx-change="update_caddyfile"
              phx-debounce="300"
            >{@caddyfile}</textarea>

            <div class="flex flex-wrap gap-2 mt-4">
              <button phx-click="save_caddyfile" class="btn btn-primary">
                <.icon name="hero-check" class="size-5" />
                Save to Memory
              </button>

              <button phx-click="validate" class="btn btn-secondary">
                <.icon name="hero-clipboard-document-check" class="size-5" />
                Validate
              </button>

              <button phx-click="adapt" class="btn btn-accent">
                <.icon name="hero-code-bracket" class="size-5" />
                Adapt to JSON
              </button>

              <button phx-click="sync" class="btn btn-info">
                <.icon name="hero-arrow-path" class="size-5" />
                Sync to Caddy
              </button>
            </div>
          </div>
        </div>

        <!-- Validation Result -->
        <div :if={@validation_result} class="card bg-base-100 shadow">
          <div class="card-body">
            <h3 class="card-title text-lg">Validation Result</h3>
            <div :if={elem(@validation_result, 0) == :success} class="alert alert-success">
              <.icon name="hero-check-circle" class="size-5" />
              <span>{elem(@validation_result, 1)}</span>
            </div>
            <div :if={elem(@validation_result, 0) == :error} class="alert alert-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              <pre class="text-xs overflow-x-auto">{elem(@validation_result, 1)}</pre>
            </div>
          </div>
        </div>

        <!-- Adaptation Result -->
        <div :if={@adaptation_result} class="card bg-base-100 shadow">
          <div class="card-body">
            <h3 class="card-title text-lg">Adapted JSON</h3>
            <div :if={elem(@adaptation_result, 0) == :success}>
              <div class="alert alert-success mb-4">
                <.icon name="hero-check-circle" class="size-5" />
                <span>Successfully adapted to JSON</span>
              </div>
              <div class="bg-base-200 rounded-lg p-4 overflow-x-auto max-h-96">
                <pre class="text-xs font-mono">{elem(@adaptation_result, 1)}</pre>
              </div>
            </div>
            <div :if={elem(@adaptation_result, 0) == :error} class="alert alert-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              <pre class="text-xs overflow-x-auto">{elem(@adaptation_result, 1)}</pre>
            </div>
          </div>
        </div>
      </div>

      <!-- Binary Path Tab -->
      <div :if={@active_tab == "binary"} class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-command-line" class="size-5" />
            Caddy Binary Path
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            Path to the Caddy executable that will be managed by this application.
          </p>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Binary Path</span>
            </label>
            <input
              type="text"
              name="bin"
              value={@bin}
              class="input input-bordered font-mono"
              placeholder="/usr/bin/caddy"
              phx-change="update_bin"
              phx-debounce="300"
            />
            <label class="label">
              <span class="label-text-alt text-base-content/50">
                Common paths: /usr/bin/caddy, /opt/homebrew/bin/caddy
              </span>
            </label>
          </div>

          <div class="flex gap-2 mt-4">
            <button phx-click="save_bin" class="btn btn-primary">
              <.icon name="hero-check" class="size-5" />
              Save Path
            </button>
            <button phx-click="save_bin_restart" class="btn btn-warning">
              <.icon name="hero-arrow-path" class="size-5" />
              Save & Restart Server
            </button>
          </div>
        </div>
      </div>

      <!-- Environment Variables Tab -->
      <div :if={@active_tab == "env"} class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-variable" class="size-5" />
            Environment Variables
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            Environment variables passed to the Caddy process when starting.
          </p>

          <!-- Add new env var -->
          <div class="flex gap-2 mb-4">
            <input
              type="text"
              placeholder="KEY"
              value={@new_env_key}
              class="input input-bordered input-sm flex-1 font-mono"
              phx-change="update_new_env"
              phx-value-value={@new_env_value}
              name="key"
            />
            <input
              type="text"
              placeholder="value"
              value={@new_env_value}
              class="input input-bordered input-sm flex-1 font-mono"
              phx-change="update_new_env"
              phx-value-key={@new_env_key}
              name="value"
            />
            <button phx-click="add_env" class="btn btn-primary btn-sm">
              <.icon name="hero-plus" class="size-4" />
              Add
            </button>
          </div>

          <!-- Env vars list -->
          <div class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>Key</th>
                  <th>Value</th>
                  <th class="w-20">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= if @env == [] do %>
                  <tr>
                    <td colspan="3" class="text-center text-base-content/50 py-8">
                      No environment variables configured
                    </td>
                  </tr>
                <% else %>
                  <%= for {{key, value}, index} <- Enum.with_index(@env) do %>
                    <tr>
                      <td class="font-mono text-sm">{key}</td>
                      <td class="font-mono text-sm">{value}</td>
                      <td>
                        <button
                          phx-click="remove_env"
                          phx-value-index={index}
                          class="btn btn-ghost btn-xs text-error"
                        >
                          <.icon name="hero-trash" class="size-4" />
                        </button>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
