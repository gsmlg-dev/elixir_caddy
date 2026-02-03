defmodule CaddyDashboardWeb.Layouts do
  @moduledoc """
  Layouts with sidebar navigation for the Caddy Dashboard.
  """
  use CaddyDashboardWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_path, :string, default: "/"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex h-screen bg-base-200">
      <aside class="w-64 bg-base-100 border-r border-base-300 flex flex-col">
        <div class="p-4 border-b border-base-300">
          <h1 class="text-xl font-bold flex items-center gap-2">
            <.icon name="hero-server-stack" class="size-6 text-primary" />
            Caddy Dashboard
          </h1>
          <p class="text-xs text-base-content/60 mt-1">Elixir Caddy Management</p>
        </div>
        <nav class="flex-1 p-2 space-y-1">
          <.nav_link path="/" icon="hero-home" label="Dashboard" current={@current_path} />
          <.nav_link path="/config" icon="hero-document-text" label="Configuration" current={@current_path} />
          <.nav_link path="/metrics" icon="hero-chart-bar" label="Metrics" current={@current_path} />
          <.nav_link path="/runtime" icon="hero-code-bracket" label="Runtime Config" current={@current_path} />
          <.nav_link path="/server" icon="hero-cog-6-tooth" label="Server Control" current={@current_path} />
          <.nav_link path="/logs" icon="hero-document-magnifying-glass" label="Logs" current={@current_path} />
          <.nav_link path="/telemetry" icon="hero-signal" label="Telemetry" current={@current_path} />
        </nav>
        <div class="p-4 border-t border-base-300">
          <div class="flex items-center justify-between">
            <span class="text-xs text-base-content/60">Theme</span>
            <.theme_toggle />
          </div>
        </div>
      </aside>

      <main class="flex-1 overflow-auto">
        <div class="p-6">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :path, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :current, :string, required: true

  defp nav_link(assigns) do
    active = assigns.path == assigns.current

    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@path}
      class={[
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors",
        @active && "bg-primary text-primary-content font-medium",
        !@active && "text-base-content/70 hover:bg-base-200 hover:text-base-content"
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {@label}
    </a>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="fixed top-4 right-4 z-50 space-y-2">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Connection lost"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
      <button class="flex p-1.5 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
        <.icon name="hero-computer-desktop-micro" class="size-3 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-1.5 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light">
        <.icon name="hero-sun-micro" class="size-3 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-1.5 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark">
        <.icon name="hero-moon-micro" class="size-3 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
