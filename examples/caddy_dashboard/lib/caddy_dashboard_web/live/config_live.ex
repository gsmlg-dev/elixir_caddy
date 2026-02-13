defmodule CaddyDashboardWeb.ConfigLive do
  @moduledoc """
  LiveView for editing Caddy configuration.

  Shows different UI based on operating mode:
  - External mode: Admin URL configuration and connection status
  - Embedded mode: 3-part Caddyfile editor (global, additionals, sites)
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
    # External mode - connection info + config management
    config = load_config()

    socket
    |> assign(:health_interval, Caddy.Config.health_interval())
    |> assign(:global, config.global || "")
    |> assign(:additionals, config.additionals || [])
    |> assign(:sites, config.sites || [])
    |> assign(:new_additional_name, "")
    |> assign(:new_additional_content, "")
    |> assign(:editing_additional, nil)
    |> assign(:new_site_address, "")
    |> assign(:new_site_config, "")
    |> assign(:editing_site, nil)
    |> assign(:active_tab, "global")
    |> assign(:validation_result, nil)
    |> assign(:adaptation_result, nil)
  end

  defp assign_mode_specific(socket, :embedded) do
    # Embedded mode - full config management with 3-part structure
    config = load_config()

    socket
    |> assign(:global, config.global || "")
    |> assign(:additionals, config.additionals || [])
    |> assign(:sites, config.sites || [])
    |> assign(:new_additional_name, "")
    |> assign(:new_additional_content, "")
    |> assign(:editing_additional, nil)
    |> assign(:new_site_address, "")
    |> assign(:new_site_config, "")
    |> assign(:editing_site, nil)
    |> assign(:active_tab, "global")
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

  # Global config events
  @impl true
  def handle_event("update_global", %{"global" => global}, socket) do
    {:noreply, assign(socket, :global, global)}
  end

  @impl true
  def handle_event("save_global", %{"global" => global_content}, socket) do
    # Read from form params to ensure we have the current textarea value
    socket =
      try do
        Caddy.set_global(global_content)
        Caddy.save_config()

        # Re-read from server to ensure consistency
        saved_global = Caddy.get_global()

        socket
        |> assign(:global, saved_global)
        |> put_flash(:info, "Global options saved")
        |> assign(:validation_result, nil)
        |> assign(:adaptation_result, nil)
      rescue
        error ->
          socket
          |> assign(:global, global_content)
          |> put_flash(:error, "Failed to save: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  # Additionals management events
  @impl true
  def handle_event("update_new_additional", %{"name" => name, "content" => content}, socket) do
    {:noreply,
     socket
     |> assign(:new_additional_name, name)
     |> assign(:new_additional_content, content)}
  end

  @impl true
  def handle_event("add_additional", %{"name" => name, "content" => content}, socket) do
    name = String.trim(name)

    socket =
      if name != "" do
        try do
          Caddy.add_additional(name, content)
          Caddy.save_config()
          additionals = Caddy.get_additionals()

          socket
          |> assign(:additionals, additionals)
          |> assign(:new_additional_name, "")
          |> assign(:new_additional_content, "")
          |> put_flash(:info, "Additional '#{name}' added")
        rescue
          error ->
            put_flash(socket, :error, "Failed to add additional: #{Exception.message(error)}")
        end
      else
        put_flash(socket, :error, "Additional name cannot be empty")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_additional", %{"name" => name}, socket) do
    additional = Enum.find(socket.assigns.additionals, &(&1.name == name))
    {:noreply, assign(socket, :editing_additional, additional)}
  end

  @impl true
  def handle_event("cancel_edit_additional", _params, socket) do
    {:noreply, assign(socket, :editing_additional, nil)}
  end

  @impl true
  def handle_event("update_editing_additional", %{"content" => content}, socket) do
    editing_additional = socket.assigns.editing_additional
    {:noreply, assign(socket, :editing_additional, %{editing_additional | content: content})}
  end

  @impl true
  def handle_event("save_additional", %{"content" => content}, socket) do
    editing_additional = socket.assigns.editing_additional
    name = editing_additional.name

    socket =
      try do
        Caddy.update_additional(name, content)
        Caddy.save_config()
        additionals = Caddy.get_additionals()

        socket
        |> assign(:additionals, additionals)
        |> assign(:editing_additional, nil)
        |> put_flash(:info, "Additional '#{name}' updated")
      rescue
        error ->
          put_flash(socket, :error, "Failed to update additional: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_additional", %{"name" => name}, socket) do
    socket =
      try do
        Caddy.remove_additional(name)
        Caddy.save_config()
        additionals = Caddy.get_additionals()

        socket
        |> assign(:additionals, additionals)
        |> put_flash(:info, "Additional '#{name}' removed")
      rescue
        error ->
          put_flash(socket, :error, "Failed to remove additional: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  # Site management events
  @impl true
  def handle_event("update_new_site", %{"address" => address, "config" => config}, socket) do
    {:noreply,
     socket
     |> assign(:new_site_address, address)
     |> assign(:new_site_config, config)}
  end

  @impl true
  def handle_event("add_site", %{"address" => address, "config" => config}, socket) do
    address = String.trim(address)

    socket =
      if address != "" do
        try do
          Caddy.add_site(address, config)
          Caddy.save_config()
          sites = Caddy.get_sites()

          socket
          |> assign(:sites, sites)
          |> assign(:new_site_address, "")
          |> assign(:new_site_config, "")
          |> put_flash(:info, "Site '#{address}' added")
        rescue
          error ->
            put_flash(socket, :error, "Failed to add site: #{Exception.message(error)}")
        end
      else
        put_flash(socket, :error, "Site address cannot be empty")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_site", %{"address" => address}, socket) do
    site = Enum.find(socket.assigns.sites, &(&1.address == address))
    {:noreply, assign(socket, :editing_site, site)}
  end

  @impl true
  def handle_event("cancel_edit_site", _params, socket) do
    {:noreply, assign(socket, :editing_site, nil)}
  end

  @impl true
  def handle_event("update_editing_site", %{"config" => config}, socket) do
    editing_site = socket.assigns.editing_site
    {:noreply, assign(socket, :editing_site, %{editing_site | config: config})}
  end

  @impl true
  def handle_event("save_site", %{"config" => config}, socket) do
    editing_site = socket.assigns.editing_site
    address = editing_site.address

    socket =
      try do
        Caddy.update_site(address, config)
        Caddy.save_config()
        sites = Caddy.get_sites()

        socket
        |> assign(:sites, sites)
        |> assign(:editing_site, nil)
        |> put_flash(:info, "Site '#{address}' updated")
      rescue
        error ->
          put_flash(socket, :error, "Failed to update site: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_site", %{"address" => address}, socket) do
    socket =
      try do
        Caddy.remove_site(address)
        Caddy.save_config()
        sites = Caddy.get_sites()

        socket
        |> assign(:sites, sites)
        |> put_flash(:info, "Site '#{address}' removed")
      rescue
        error ->
          put_flash(socket, :error, "Failed to remove site: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  # Validation and sync events
  @impl true
  def handle_event("validate", _params, socket) do
    caddyfile = Caddy.get_caddyfile()

    socket =
      try do
        case Caddy.validate_caddyfile(caddyfile) do
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
    caddyfile = Caddy.get_caddyfile()

    socket =
      try do
        case Caddy.adapt(caddyfile) do
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
            |> assign(:global, config.global || "")
            |> assign(:additionals, config.additionals || [])
            |> assign(:sites, config.sites || [])
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

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error({:adaptation_failed, msg}), do: "Adaptation failed: #{msg}"
  defp format_error(reason), do: inspect(reason)

  # Assemble Caddyfile from the 3 parts (local preview, not from server)
  defp assemble_caddyfile(global, additionals, sites) do
    parts = []

    # Global options block
    parts =
      if global && String.trim(global) != "" do
        parts ++ ["{\n" <> indent_content(global) <> "\n}"]
      else
        parts
      end

    # Additional directives
    parts =
      Enum.reduce(additionals, parts, fn %{content: content}, acc ->
        if String.trim(content) != "" do
          acc ++ [String.trim(content)]
        else
          acc
        end
      end)

    # Site blocks
    site_blocks =
      Enum.map(sites, fn site ->
        config = site.config || ""

        if String.trim(config) == "" do
          "#{site.address} {\n}"
        else
          "#{site.address} {\n" <> indent_content(config) <> "\n}"
        end
      end)

    parts = parts ++ site_blocks

    if parts == [] do
      "# Empty Caddyfile\n# Add global options, additionals, or sites to see the preview."
    else
      Enum.join(parts, "\n\n")
    end
  end

  defp indent_content(content) do
    content
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&("  " <> &1))
    |> Enum.join("\n")
  end

  defp line_count(content) when is_binary(content) do
    content
    |> String.trim()
    |> String.split("\n")
    |> length()
  end

  defp line_count(_), do: 0

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
      <!-- Connection Info (collapsible) -->
      <div class="collapse collapse-arrow bg-base-100 shadow-xl">
        <input type="checkbox" checked />
        <div class="collapse-title">
          <h2 class="card-title">
            <.icon name="hero-signal" class="size-5" /> External Caddy Connection
          </h2>
        </div>
        <div class="collapse-content">
          <p class="text-base-content/60 mb-4">
            Caddy is managed externally (e.g., systemd, Docker). This library communicates with it via the Admin API.
          </p>

          <div class="stats shadow">
            <div class="stat">
              <div class="stat-title">Admin API URL</div>
              <div class="stat-value text-lg font-mono">{@admin_url}</div>
              <div class="stat-desc">Configure via <code>config :caddy, admin_url: "..."</code></div>
            </div>
            <div class="stat">
              <div class="stat-title">Health Check Interval</div>
              <div class="stat-value text-lg">{div(@health_interval, 1000)}s</div>
              <div class="stat-desc">
                Configure via <code>config :caddy, health_interval: ...</code>
              </div>
            </div>
          </div>

          <!-- System Commands -->
          <%= if @commands != [] do %>
            <div class="mt-4">
              <h3 class="font-semibold mb-2">
                <.icon name="hero-command-line" class="size-4" /> System Commands
              </h3>
              <div class="overflow-x-auto">
                <table class="table table-sm">
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
            </div>
          <% end %>
        </div>
      </div>

      <!-- Config Editor (same as embedded mode) -->
      <.config_editor {assigns} />
    </div>
    """
  end

  # ============================================================================
  # Embedded Mode UI
  # ============================================================================

  defp embedded_mode_config(assigns) do
    ~H"""
    <div class="space-y-6">
      <.config_editor {assigns} />
    </div>
    """
  end

  # ============================================================================
  # Shared Config Editor Component
  # ============================================================================

  defp config_editor(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header Actions -->
      <div class="flex justify-end gap-2">
        <button phx-click="backup" class="btn btn-outline btn-sm">
          <.icon name="hero-archive-box-arrow-down" class="size-4" /> Backup
        </button>
        <button phx-click="restore" class="btn btn-outline btn-sm">
          <.icon name="hero-arrow-uturn-left" class="size-4" /> Restore
        </button>
        <button phx-click="save_all" class="btn btn-primary btn-sm">
          <.icon name="hero-arrow-down-tray" class="size-4" /> Save to Disk
        </button>
      </div>

      <!-- Tab Navigation -->
      <div role="tablist" class="tabs tabs-boxed">
        <button
          role="tab"
          class={["tab", @active_tab == "global" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="global"
        >
          <.icon name="hero-cog-6-tooth" class="size-4 mr-2" /> Global Options
        </button>
        <button
          role="tab"
          class={["tab", @active_tab == "additionals" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="additionals"
        >
          <.icon name="hero-puzzle-piece" class="size-4 mr-2" /> Additionals
          <span class="badge badge-sm ml-1">{length(@additionals)}</span>
        </button>
        <button
          role="tab"
          class={["tab", @active_tab == "sites" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="sites"
        >
          <.icon name="hero-globe-alt" class="size-4 mr-2" /> Sites
          <span class="badge badge-sm ml-1">{length(@sites)}</span>
        </button>
        <button
          role="tab"
          class={["tab", @active_tab == "preview" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="preview"
        >
          <.icon name="hero-eye" class="size-4 mr-2" /> Preview
        </button>
      </div>

      <!-- Global Options Tab -->
      <div :if={@active_tab == "global"} class="space-y-4">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-cog-6-tooth" class="size-5" /> Global Options
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Global options are placed inside the top-level <code>{"{ }"}</code> block.
              Enter the content without the outer braces.
            </p>

            <form phx-submit="save_global" phx-change="update_global">
              <textarea
                name="global"
                rows="10"
                class="textarea textarea-bordered w-full font-mono text-sm leading-relaxed"
                placeholder="debug&#10;admin unix//tmp/caddy.sock&#10;auto_https off"
                phx-debounce="300"
              ><%= @global %></textarea>

              <div class="flex flex-wrap gap-2 mt-4">
                <button type="submit" class="btn btn-primary">
                  <.icon name="hero-check" class="size-5" /> Save Global Options
                </button>

                <button type="button" phx-click="validate" class="btn btn-secondary">
                  <.icon name="hero-clipboard-document-check" class="size-5" /> Validate All
                </button>

                <button type="button" phx-click="adapt" class="btn btn-accent">
                  <.icon name="hero-code-bracket" class="size-5" /> Adapt to JSON
                </button>

                <button type="button" phx-click="sync" class="btn btn-info">
                  <.icon name="hero-arrow-path" class="size-5" /> Sync to Caddy
                </button>
              </div>
            </form>
          </div>
        </div>

        <.validation_results
          validation_result={@validation_result}
          adaptation_result={@adaptation_result}
        />
      </div>

      <!-- Additionals Tab -->
      <div :if={@active_tab == "additionals"} class="space-y-4">
        <!-- Add New Additional -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-plus-circle" class="size-5" /> Add New Additional
            </h2>
            <p class="text-sm text-base-content/60 mb-4">
              Snippets, matchers, and other reusable configurations.
            </p>

            <form phx-submit="add_additional" phx-change="update_new_additional">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Name</span>
                </label>
                <input
                  type="text"
                  name="name"
                  value={@new_additional_name}
                  class="input input-bordered font-mono"
                  placeholder="common-headers, security-snippet, etc."
                  phx-debounce="300"
                />
              </div>

              <div class="form-control mt-2">
                <label class="label">
                  <span class="label-text">Content</span>
                </label>
                <textarea
                  name="content"
                  rows="4"
                  class="textarea textarea-bordered w-full font-mono text-sm"
                  placeholder="(common) {&#10;  header X-Frame-Options DENY&#10;  header X-Content-Type-Options nosniff&#10;}"
                  phx-debounce="300"
                ><%= @new_additional_content %></textarea>
              </div>

              <div class="mt-4">
                <button type="submit" class="btn btn-primary">
                  <.icon name="hero-plus" class="size-5" /> Add Additional
                </button>
              </div>
            </form>
          </div>
        </div>

        <!-- Additionals List -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-puzzle-piece" class="size-5" /> Configured Additionals
            </h2>

            <%= if @additionals == [] do %>
              <div class="alert alert-info">
                <.icon name="hero-information-circle" class="size-5" />
                <span>No additionals configured yet. Add your first snippet above.</span>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for additional <- @additionals do %>
                  <div class="border border-base-300 rounded-lg p-4">
                    <%= if @editing_additional && @editing_additional.name == additional.name do %>
                      <!-- Edit Mode -->
                      <form phx-submit="save_additional" class="space-y-3">
                        <div class="font-mono font-semibold text-primary">{additional.name}</div>
                        <textarea
                          name="content"
                          rows="4"
                          class="textarea textarea-bordered w-full font-mono text-sm"
                          phx-debounce="300"
                        ><%= @editing_additional.content %></textarea>
                        <div class="flex gap-2">
                          <button type="submit" class="btn btn-primary btn-sm">
                            <.icon name="hero-check" class="size-4" /> Save
                          </button>
                          <button type="button" phx-click="cancel_edit_additional" class="btn btn-ghost btn-sm">
                            Cancel
                          </button>
                        </div>
                      </form>
                    <% else %>
                      <!-- View Mode -->
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <div class="font-mono font-semibold text-primary">{additional.name}</div>
                          <pre class="text-xs font-mono text-base-content/70 mt-2 bg-base-200 p-2 rounded overflow-x-auto">{additional.content}</pre>
                        </div>
                        <div class="flex gap-1 ml-4">
                          <button
                            phx-click="edit_additional"
                            phx-value-name={additional.name}
                            class="btn btn-ghost btn-xs"
                          >
                            <.icon name="hero-pencil" class="size-4" />
                          </button>
                          <button
                            phx-click="remove_additional"
                            phx-value-name={additional.name}
                            class="btn btn-ghost btn-xs text-error"
                            data-confirm={"Are you sure you want to remove #{additional.name}?"}
                          >
                            <.icon name="hero-trash" class="size-4" />
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <.validation_results
          validation_result={@validation_result}
          adaptation_result={@adaptation_result}
        />
      </div>

      <!-- Sites Tab -->
      <div :if={@active_tab == "sites"} class="space-y-4">
        <!-- Add New Site -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-plus-circle" class="size-5" /> Add New Site
            </h2>

            <form phx-submit="add_site" phx-change="update_new_site">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Site Address</span>
                </label>
                <input
                  type="text"
                  name="address"
                  value={@new_site_address}
                  class="input input-bordered font-mono"
                  placeholder="example.com, localhost:8080, :443"
                  phx-debounce="300"
                />
              </div>

              <div class="form-control mt-2">
                <label class="label">
                  <span class="label-text">Site Configuration</span>
                </label>
                <textarea
                  name="config"
                  rows="4"
                  class="textarea textarea-bordered w-full font-mono text-sm"
                  placeholder="reverse_proxy localhost:3000&#10;encode gzip"
                  phx-debounce="300"
                ><%= @new_site_config %></textarea>
              </div>

              <div class="mt-4">
                <button type="submit" class="btn btn-primary">
                  <.icon name="hero-plus" class="size-5" /> Add Site
                </button>
              </div>
            </form>
          </div>
        </div>

        <!-- Sites List -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-globe-alt" class="size-5" /> Configured Sites
            </h2>

            <%= if @sites == [] do %>
              <div class="alert alert-info">
                <.icon name="hero-information-circle" class="size-5" />
                <span>No sites configured yet. Add your first site above.</span>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for site <- @sites do %>
                  <div class="border border-base-300 rounded-lg p-4">
                    <%= if @editing_site && @editing_site.address == site.address do %>
                      <!-- Edit Mode -->
                      <form phx-submit="save_site" class="space-y-3">
                        <div class="font-mono font-semibold text-primary">{site.address}</div>
                        <textarea
                          name="config"
                          rows="4"
                          class="textarea textarea-bordered w-full font-mono text-sm"
                          phx-debounce="300"
                        ><%= @editing_site.config %></textarea>
                        <div class="flex gap-2">
                          <button type="submit" class="btn btn-primary btn-sm">
                            <.icon name="hero-check" class="size-4" /> Save
                          </button>
                          <button type="button" phx-click="cancel_edit_site" class="btn btn-ghost btn-sm">
                            Cancel
                          </button>
                        </div>
                      </form>
                    <% else %>
                      <!-- View Mode -->
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <div class="font-mono font-semibold text-primary">{site.address}</div>
                          <pre class="text-xs font-mono text-base-content/70 mt-2 bg-base-200 p-2 rounded overflow-x-auto">{site.config}</pre>
                        </div>
                        <div class="flex gap-1 ml-4">
                          <button
                            phx-click="edit_site"
                            phx-value-address={site.address}
                            class="btn btn-ghost btn-xs"
                          >
                            <.icon name="hero-pencil" class="size-4" />
                          </button>
                          <button
                            phx-click="remove_site"
                            phx-value-address={site.address}
                            class="btn btn-ghost btn-xs text-error"
                            data-confirm={"Are you sure you want to remove #{site.address}?"}
                          >
                            <.icon name="hero-trash" class="size-4" />
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <.validation_results
          validation_result={@validation_result}
          adaptation_result={@adaptation_result}
        />
      </div>

      <!-- Preview Tab -->
      <div :if={@active_tab == "preview"} class="space-y-4">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">
                <.icon name="hero-eye" class="size-5" /> Combined Caddyfile Preview
              </h2>
              <div class="flex gap-2">
                <button phx-click="validate" class="btn btn-secondary btn-sm">
                  <.icon name="hero-clipboard-document-check" class="size-4" /> Validate
                </button>
                <button phx-click="adapt" class="btn btn-accent btn-sm">
                  <.icon name="hero-code-bracket" class="size-4" /> Adapt to JSON
                </button>
                <button phx-click="sync" class="btn btn-info btn-sm">
                  <.icon name="hero-arrow-path" class="size-4" /> Sync to Caddy
                </button>
              </div>
            </div>
            <p class="text-sm text-base-content/60 mb-4">
              This is the combined Caddyfile that will be used by Caddy, assembled from Global
              Options, Additionals, and Sites.
              Changes shown here reflect your current edits (before saving).
            </p>

            <div class="bg-base-200 rounded-lg p-4 overflow-auto max-h-[600px]">
              <pre class="text-sm font-mono whitespace-pre-wrap"><%= assemble_caddyfile(@global, @additionals, @sites) %></pre>
            </div>

            <div class="mt-4 flex items-center gap-4 text-sm text-base-content/60">
              <div class="flex items-center gap-2">
                <span class="badge badge-outline badge-sm">Global</span>
                <span>{line_count(@global)} lines</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="badge badge-outline badge-sm">Additionals</span>
                <span>{length(@additionals)} item(s)</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="badge badge-outline badge-sm">Sites</span>
                <span>{length(@sites)} site(s)</span>
              </div>
            </div>
          </div>
        </div>

        <.validation_results
          validation_result={@validation_result}
          adaptation_result={@adaptation_result}
        />
      </div>
    </div>
    """
  end

  defp validation_results(assigns) do
    ~H"""
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
    """
  end
end
