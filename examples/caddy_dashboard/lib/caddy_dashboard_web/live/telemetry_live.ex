defmodule CaddyDashboardWeb.TelemetryLive do
  use CaddyDashboardWeb, :live_view

  alias CaddyDashboard.TelemetryCollector
  alias CaddyDashboardWeb.Layouts

  @max_events 200

  @impl true
  def mount(_params, _session, socket) do
    events =
      if connected?(socket) do
        try do
          TelemetryCollector.subscribe()
          TelemetryCollector.recent_events(50)
        rescue
          _ -> []
        end
      else
        try do
          TelemetryCollector.recent_events(50)
        rescue
          _ -> []
        end
      end

    {:ok,
     socket
     |> assign(:events, events)
     |> assign(:filter_category, "all")
     |> assign(:paused, false)
     |> assign(:max_events, @max_events)
     |> assign(:page_title, "Telemetry Events")}
  end

  @impl true
  def handle_info({:caddy_telemetry, entry}, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      events = [entry | socket.assigns.events] |> Enum.take(@max_events)
      {:noreply, assign(socket, :events, events)}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, :events, [])}
  end

  @impl true
  def handle_event("toggle_pause", _params, socket) do
    {:noreply, assign(socket, :paused, !socket.assigns.paused)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :filter_category, category)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/telemetry"}>
      <div class="container mx-auto p-6">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold">Telemetry Events</h1>

          <div class="flex gap-2">
            <select
              class="select select-bordered select-sm"
              phx-change="filter_category"
              name="category"
            >
              <option value="all" selected={@filter_category == "all"}>All Events</option>
              <option value="config" selected={@filter_category == "config"}>Config</option>
              <option value="server" selected={@filter_category == "server"}>Server</option>
              <option value="api" selected={@filter_category == "api"}>API</option>
              <option value="file" selected={@filter_category == "file"}>File</option>
              <option value="validation" selected={@filter_category == "validation"}>
                Validation
              </option>
              <option value="adapt" selected={@filter_category == "adapt"}>Adapt</option>
              <option value="log" selected={@filter_category == "log"}>Log</option>
              <option value="metrics" selected={@filter_category == "metrics"}>Metrics</option>
            </select>

            <button class="btn btn-sm btn-primary" phx-click="toggle_pause">
              <%= if @paused, do: "Resume", else: "Pause" %>
            </button>

            <button class="btn btn-sm btn-secondary" phx-click="clear">
              Clear
            </button>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body p-0">
            <div class="overflow-x-auto max-h-[600px] overflow-y-auto">
              <table class="table table-sm table-pin-rows">
                <thead>
                  <tr>
                    <th class="w-32">Timestamp</th>
                    <th class="w-64">Event</th>
                    <th class="w-48">Measurements</th>
                    <th>Metadata</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @events == [] do %>
                    <tr>
                      <td colspan="4" class="text-center text-gray-500 py-8">
                        No events to display
                      </td>
                    </tr>
                  <% else %>
                    <%= for event <- filtered_events(@events, @filter_category) do %>
                      <tr class={event_row_class(event)}>
                        <td class="font-mono text-xs">
                          <%= format_timestamp(event.timestamp) %>
                        </td>
                        <td>
                          <span class={event_badge_class(event)}>
                            <%= format_event_name(event.event) %>
                          </span>
                        </td>
                        <td class="font-mono text-xs">
                          <%= format_measurements(event.measurements) %>
                        </td>
                        <td class="font-mono text-xs">
                          <%= format_metadata(event.metadata) %>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%= if @paused do %>
          <div class="alert alert-warning mt-4">
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
            <span>Event streaming is paused. Click "Resume" to continue receiving events.</span>
          </div>
        <% end %>

        <div class="mt-4 text-sm text-gray-600">
          Showing <%= length(filtered_events(@events, @filter_category)) %> of <%= length(@events) %> events (max <%= @max_events %>)
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp filtered_events(events, "all"), do: events

  defp filtered_events(events, category) do
    Enum.filter(events, fn event ->
      event.event
      |> Enum.at(1)
      |> to_string()
      |> String.starts_with?(category)
    end)
  end

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%H:%M:%S") <>
      ".#{String.pad_leading(Integer.to_string(timestamp.microsecond |> elem(0) |> div(1000)), 3, "0")}"
  end

  defp format_event_name(event) do
    Enum.join(event, ".")
  end

  defp format_measurements(measurements) when map_size(measurements) == 0, do: "-"

  defp format_measurements(measurements) do
    measurements
    |> inspect(limit: 3, printable_limit: 50)
    |> String.slice(0, 100)
  end

  defp format_metadata(metadata) when map_size(metadata) == 0, do: "-"

  defp format_metadata(metadata) do
    metadata
    |> inspect(limit: 3, printable_limit: 50)
    |> String.slice(0, 150)
  end

  defp event_badge_class(event) do
    base = "badge badge-sm"

    cond do
      is_error_event?(event) -> "#{base} badge-error"
      is_warning_event?(event) -> "#{base} badge-warning"
      true -> "#{base} badge-ghost"
    end
  end

  defp event_row_class(event) do
    cond do
      is_error_event?(event) -> "bg-red-50"
      is_warning_event?(event) -> "bg-yellow-50"
      true -> ""
    end
  end

  defp is_error_event?(event) do
    event_name = format_event_name(event.event)

    String.contains?(event_name, "error") or
      (String.contains?(event_name, "log") and Map.get(event.metadata, :level) == :error)
  end

  defp is_warning_event?(event) do
    event_name = format_event_name(event.event)

    String.contains?(event_name, "warning") or
      (String.contains?(event_name, "log") and Map.get(event.metadata, :level) == :warning)
  end
end
