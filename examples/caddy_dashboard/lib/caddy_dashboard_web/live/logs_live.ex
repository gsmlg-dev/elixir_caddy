defmodule CaddyDashboardWeb.LogsLive do
  use CaddyDashboardWeb, :live_view

  alias CaddyDashboardWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:logs, [])
      |> assign(:filtered_logs, [])
      |> assign(:tail_lines, 100)
      |> assign(:search_query, "")
      |> assign(:auto_refresh, false)
      |> assign(:refresh_timer, nil)
      |> assign(:error, nil)
      |> load_logs()

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_logs(socket)}
  end

  @impl true
  def handle_event("update_tail_lines", %{"tail_lines" => tail_lines}, socket) do
    case Integer.parse(tail_lines) do
      {lines, _} when lines > 0 ->
        socket =
          socket
          |> assign(:tail_lines, lines)
          |> load_logs()

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Please enter a valid positive number")}
    end
  end

  @impl true
  def handle_event("toggle_auto_refresh", %{"value" => value}, socket) do
    auto_refresh = value == "on"

    socket =
      socket
      |> cancel_refresh_timer()
      |> assign(:auto_refresh, auto_refresh)

    socket =
      if auto_refresh do
        schedule_refresh(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> filter_logs()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> load_logs()
      |> schedule_refresh()

    {:noreply, socket}
  end

  defp load_logs(socket) do
    tail_lines = socket.assigns.tail_lines

    {logs, error} =
      try do
        case Caddy.Logger.tail(tail_lines) do
          logs when is_list(logs) -> {logs, nil}
          _ -> {[], "Invalid response from Logger"}
        end
      rescue
        e ->
          {[], Exception.message(e)}
      end

    socket
    |> assign(:logs, logs)
    |> assign(:error, error)
    |> filter_logs()
  end

  defp filter_logs(socket) do
    %{logs: logs, search_query: query} = socket.assigns

    filtered_logs =
      if query == "" do
        logs
      else
        query_lower = String.downcase(query)

        Enum.filter(logs, fn log ->
          log
          |> to_string()
          |> String.downcase()
          |> String.contains?(query_lower)
        end)
      end

    assign(socket, :filtered_logs, filtered_logs)
  end

  defp schedule_refresh(socket) do
    if socket.assigns.auto_refresh do
      timer = Process.send_after(self(), :refresh, 5000)
      assign(socket, :refresh_timer, timer)
    else
      socket
    end
  end

  defp cancel_refresh_timer(socket) do
    if socket.assigns.refresh_timer do
      Process.cancel_timer(socket.assigns.refresh_timer)
    end

    assign(socket, :refresh_timer, nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/logs"}>
      <div class="container mx-auto p-6 space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">Logs</h1>
          <div class="badge badge-lg badge-primary">
            <%= length(@logs) %> total / <%= length(@filtered_logs) %> displayed
          </div>
        </div>

        <%= if @error do %>
          <div class="alert alert-warning">
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
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
            <span>Logger unavailable: <%= @error %></span>
          </div>
        <% end %>

        <!-- Controls Card -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Controls</h2>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- Left Column -->
              <div class="space-y-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Tail Lines</span>
                  </label>
                  <div class="join">
                    <input
                      type="number"
                      name="tail_lines"
                      value={@tail_lines}
                      min="1"
                      max="10000"
                      class="input input-bordered join-item flex-1"
                      phx-change="update_tail_lines"
                    />
                    <button class="btn btn-primary join-item" phx-click="refresh">
                      Refresh
                    </button>
                  </div>
                </div>

                <div class="form-control">
                  <label class="label cursor-pointer">
                    <span class="label-text">Auto-refresh (every 5s)</span>
                    <input
                      type="checkbox"
                      class="toggle toggle-primary"
                      checked={@auto_refresh}
                      phx-change="toggle_auto_refresh"
                    />
                  </label>
                </div>
              </div>

              <!-- Right Column -->
              <div class="space-y-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Search Logs</span>
                  </label>
                  <form phx-change="search">
                    <input
                      type="text"
                      name="search[query]"
                      value={@search_query}
                      placeholder="Filter by text..."
                      class="input input-bordered w-full"
                    />
                  </form>
                  <%= if @search_query != "" do %>
                    <label class="label">
                      <span class="label-text-alt">
                        Showing <%= length(@filtered_logs) %> of <%= length(@logs) %> logs
                      </span>
                    </label>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Logs Display Card -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Log Output</h2>

            <%= if Enum.empty?(@filtered_logs) do %>
              <div class="text-center py-12 text-base-content/50">
                <%= if @error do %>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-12 w-12 mx-auto mb-4 opacity-50"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  <p class="text-lg font-semibold">No logs available</p>
                  <p class="text-sm mt-2">The Logger process may not be running</p>
                <% else %>
                  <%= if @search_query != "" do %>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-12 w-12 mx-auto mb-4 opacity-50"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                      />
                    </svg>
                    <p class="text-lg font-semibold">No matching logs found</p>
                    <p class="text-sm mt-2">Try adjusting your search query</p>
                  <% else %>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-12 w-12 mx-auto mb-4 opacity-50"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                    <p class="text-lg font-semibold">No logs available</p>
                    <p class="text-sm mt-2">Logs will appear here when generated</p>
                  <% end %>
                <% end %>
              </div>
            <% else %>
              <div class="bg-base-300 rounded-lg p-4 overflow-auto" style="max-height: 600px;">
                <pre class="font-mono text-sm whitespace-pre-wrap break-words"><code><%= Enum.join(@filtered_logs, "\n") %></code></pre>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
