defmodule CaddyDashboardWeb.ConfigLive do
  @moduledoc """
  LiveView for editing Caddyfile configuration.
  Provides interface for editing, validating, adapting, and syncing Caddy configuration.
  """
  use CaddyDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    caddyfile =
      try do
        Caddy.get_caddyfile()
      rescue
        _error -> ""
      end

    socket =
      socket
      |> assign(:caddyfile, caddyfile)
      |> assign(:validation_result, nil)
      |> assign(:adaptation_result, nil)
      |> assign(:page_title, "Configuration Editor")

    {:ok, socket}
  end

  @impl true
  def handle_event("update_caddyfile", %{"caddyfile" => caddyfile}, socket) do
    {:noreply, assign(socket, :caddyfile, caddyfile)}
  end

  @impl true
  def handle_event("save", %{"caddyfile" => caddyfile}, socket) do
    socket =
      try do
        Caddy.set_caddyfile(caddyfile)

        socket
        |> put_flash(:info, "Caddyfile saved successfully")
        |> assign(:caddyfile, caddyfile)
      rescue
        error ->
          put_flash(socket, :error, "Failed to save: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"caddyfile" => caddyfile}, socket) do
    socket =
      try do
        case Caddy.validate_caddyfile(caddyfile) do
          {:ok, _} ->
            assign(socket, :validation_result, {:success, "Configuration is valid"})

          {:error, reason} ->
            assign(socket, :validation_result, {:error, inspect(reason)})
        end
      rescue
        error ->
          assign(socket, :validation_result, {:error, Exception.message(error)})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("adapt", %{"caddyfile" => caddyfile}, socket) do
    socket =
      try do
        case Caddy.adapt(caddyfile) do
          {:ok, json} ->
            formatted_json =
              json
              |> Jason.decode!()
              |> Jason.encode!(pretty: true)

            assign(socket, :adaptation_result, {:success, formatted_json})

          {:error, reason} ->
            assign(socket, :adaptation_result, {:error, inspect(reason)})
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
            put_flash(socket, :info, "Configuration synced to Caddy successfully (backup created)")

          {:error, reason} ->
            put_flash(socket, :error, "Sync failed: #{inspect(reason)}")
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
          {:ok, path} ->
            put_flash(socket, :info, "Configuration backed up to: #{path}")

          {:error, reason} ->
            put_flash(socket, :error, "Backup failed: #{inspect(reason)}")
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
          {:ok, _config} ->
            caddyfile =
              try do
                Caddy.get_caddyfile()
              rescue
                _error -> ""
              end

            socket
            |> put_flash(:info, "Configuration restored from backup")
            |> assign(:caddyfile, caddyfile)
            |> assign(:validation_result, nil)
            |> assign(:adaptation_result, nil)

          {:error, reason} ->
            put_flash(socket, :error, "Restore failed: #{inspect(reason)}")
        end
      rescue
        error ->
          put_flash(socket, :error, "Restore failed: #{Exception.message(error)}")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/config"}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold">Configuration Editor</h1>
            <p class="text-base-content/60 mt-1">Edit and manage your Caddyfile configuration</p>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title mb-4">Caddyfile Editor</h2>

            <form phx-submit="save" phx-change="update_caddyfile">
              <textarea
                name="caddyfile"
                rows="20"
                class="textarea textarea-bordered w-full font-mono text-sm leading-relaxed"
                placeholder="Enter your Caddyfile configuration..."
                phx-debounce="500"
              >{@caddyfile}</textarea>

              <div class="flex flex-wrap gap-2 mt-4">
                <button type="submit" class="btn btn-primary">
                  <.icon name="hero-check" class="size-5" />
                  Save
                </button>

                <button
                  type="button"
                  phx-click="validate"
                  phx-value-caddyfile={@caddyfile}
                  class="btn btn-secondary"
                >
                  <.icon name="hero-clipboard-document-check" class="size-5" />
                  Validate
                </button>

                <button
                  type="button"
                  phx-click="adapt"
                  phx-value-caddyfile={@caddyfile}
                  class="btn btn-accent"
                >
                  <.icon name="hero-code-bracket" class="size-5" />
                  Adapt to JSON
                </button>

                <button type="button" phx-click="sync" class="btn btn-info">
                  <.icon name="hero-arrow-path" class="size-5" />
                  Sync to Caddy
                </button>

                <div class="divider divider-horizontal"></div>

                <button type="button" phx-click="backup" class="btn btn-outline">
                  <.icon name="hero-archive-box-arrow-down" class="size-5" />
                  Backup
                </button>

                <button type="button" phx-click="restore" class="btn btn-outline">
                  <.icon name="hero-arrow-uturn-left" class="size-5" />
                  Restore
                </button>
              </div>
            </form>
          </div>
        </div>

        <div :if={@validation_result} class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h3 class="card-title">Validation Result</h3>
            <div :if={elem(@validation_result, 0) == :success} class="alert alert-success">
              <.icon name="hero-check-circle" class="size-5" />
              <span>{elem(@validation_result, 1)}</span>
            </div>
            <div :if={elem(@validation_result, 0) == :error} class="alert alert-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              <div class="flex-1">
                <p class="font-semibold">Validation Error</p>
                <pre class="text-xs mt-2 overflow-x-auto">{elem(@validation_result, 1)}</pre>
              </div>
            </div>
          </div>
        </div>

        <div :if={@adaptation_result} class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h3 class="card-title">Adaptation Result</h3>
            <div :if={elem(@adaptation_result, 0) == :success}>
              <div class="alert alert-success mb-4">
                <.icon name="hero-check-circle" class="size-5" />
                <span>Successfully adapted to JSON</span>
              </div>
              <div class="bg-base-200 rounded-lg p-4 overflow-x-auto">
                <pre class="text-xs font-mono">{elem(@adaptation_result, 1)}</pre>
              </div>
            </div>
            <div :if={elem(@adaptation_result, 0) == :error} class="alert alert-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              <div class="flex-1">
                <p class="font-semibold">Adaptation Error</p>
                <pre class="text-xs mt-2 overflow-x-auto">{elem(@adaptation_result, 1)}</pre>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
