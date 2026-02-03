defmodule CaddyDashboardWeb.RuntimeLive do
  use CaddyDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {config, error} = fetch_config("")

    {:ok,
     assign(socket,
       page_title: "Runtime Configuration",
       current_path: "",
       config: config,
       error: error,
       apply_json: "",
       apply_result: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/runtime"}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-bold">Runtime Configuration</h2>
          <div class="flex gap-2">
            <button phx-click="rollback" class="btn btn-warning btn-sm">
              <.icon name="hero-arrow-uturn-left" class="size-4" /> Rollback
            </button>
            <button phx-click="refresh" class="btn btn-primary btn-sm">
              <.icon name="hero-arrow-path" class="size-4" /> Refresh
            </button>
          </div>
        </div>

        <%!-- Path Navigation --%>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-4">
            <form phx-submit="browse" class="flex gap-2">
              <input
                type="text"
                name="path"
                value={@current_path}
                placeholder="e.g. apps/http/servers"
                class="input input-bordered flex-1 font-mono text-sm"
              />
              <button type="submit" class="btn btn-primary btn-sm">Browse</button>
              <button type="button" phx-click="browse_root" class="btn btn-ghost btn-sm">Root</button>
            </form>

            <%!-- Breadcrumbs --%>
            <div :if={@current_path != ""} class="flex items-center gap-1 text-sm mt-2">
              <button phx-click="browse_root" class="link link-primary">/</button>
              <%= for {segment, path} <- breadcrumbs(@current_path) do %>
                <span class="text-base-content/40">/</span>
                <button phx-click="navigate" phx-value-path={path} class="link link-primary">
                  {segment}
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Error Display --%>
        <div :if={@error} class="alert alert-error">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>{inspect(@error)}</span>
        </div>

        <%!-- Config Display --%>
        <div :if={@config} class="card bg-base-100 shadow-sm">
          <div class="card-body p-4">
            <h3 class="card-title text-sm">
              Configuration
              <span :if={@current_path != ""} class="font-mono text-primary">/{@current_path}</span>
              <span :if={@current_path == ""} class="font-mono text-primary">/</span>
            </h3>
            <pre class="bg-base-200 rounded-lg p-4 overflow-auto max-h-96 text-sm font-mono">{format_json(@config)}</pre>
          </div>
        </div>

        <%!-- Apply JSON --%>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-4">
            <h3 class="card-title text-sm">Apply JSON Config</h3>
            <p class="text-xs text-base-content/60">
              Paste JSON to apply directly to the running Caddy instance
              <span :if={@current_path != ""}>at path <code class="font-mono text-primary">/{@current_path}</code></span>
            </p>
            <form phx-submit="apply_json">
              <textarea
                name="json"
                rows="6"
                class="textarea textarea-bordered w-full font-mono text-sm"
                placeholder='{"key": "value"}'
              >{@apply_json}</textarea>
              <div class="flex gap-2 mt-2">
                <button type="submit" class="btn btn-warning btn-sm">Apply to Caddy</button>
              </div>
            </form>

            <div :if={@apply_result} class={[
              "alert mt-2",
              @apply_result == :ok && "alert-success",
              @apply_result != :ok && "alert-error"
            ]}>
              <span>{inspect(@apply_result)}</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("browse", %{"path" => path}, socket) do
    path = String.trim(path, "/")
    {config, error} = fetch_config(path)

    {:noreply,
     assign(socket,
       current_path: path,
       config: config,
       error: error,
       apply_result: nil
     )}
  end

  def handle_event("browse_root", _params, socket) do
    {config, error} = fetch_config("")
    {:noreply, assign(socket, current_path: "", config: config, error: error, apply_result: nil)}
  end

  def handle_event("navigate", %{"path" => path}, socket) do
    {config, error} = fetch_config(path)
    {:noreply, assign(socket, current_path: path, config: config, error: error, apply_result: nil)}
  end

  def handle_event("refresh", _params, socket) do
    {config, error} = fetch_config(socket.assigns.current_path)
    {:noreply, assign(socket, config: config, error: error)}
  end

  def handle_event("rollback", _params, socket) do
    result =
      try do
        Caddy.rollback()
      rescue
        e -> {:error, Exception.message(e)}
      end

    {config, error} = fetch_config(socket.assigns.current_path)

    socket =
      case result do
        :ok -> put_flash(socket, :info, "Rollback successful")
        {:error, reason} -> put_flash(socket, :error, "Rollback failed: #{inspect(reason)}")
      end

    {:noreply, assign(socket, config: config, error: error)}
  end

  def handle_event("apply_json", %{"json" => json_text}, socket) do
    result =
      try do
        decoded = Jason.decode!(json_text)
        path = socket.assigns.current_path

        if path == "" do
          Caddy.apply_runtime_config(decoded)
        else
          Caddy.apply_runtime_config(path, decoded)
        end
      rescue
        e -> {:error, Exception.message(e)}
      end

    {config, error} = fetch_config(socket.assigns.current_path)

    {:noreply,
     assign(socket,
       apply_json: json_text,
       apply_result: result,
       config: config,
       error: error
     )}
  end

  defp fetch_config("") do
    try do
      case Caddy.get_runtime_config() do
        {:ok, config} -> {config, nil}
        {:error, reason} -> {nil, reason}
      end
    rescue
      e -> {nil, Exception.message(e)}
    end
  end

  defp fetch_config(path) do
    try do
      case Caddy.get_runtime_config(path) do
        {:ok, config} -> {config, nil}
        {:error, reason} -> {nil, reason}
      end
    rescue
      e -> {nil, Exception.message(e)}
    end
  end

  defp breadcrumbs(path) do
    segments = String.split(path, "/", trim: true)

    segments
    |> Enum.scan("", fn segment, acc ->
      if acc == "", do: segment, else: acc <> "/" <> segment
    end)
    |> Enum.zip(segments)
    |> Enum.map(fn {full_path, segment} -> {segment, full_path} end)
  end

  defp format_json(data) when is_map(data) or is_list(data) do
    Jason.encode!(data, pretty: true)
  end

  defp format_json(data), do: inspect(data, pretty: true)
end
