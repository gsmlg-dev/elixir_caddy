# Caddy Dashboard

A Phoenix LiveView example application demonstrating the [Caddy](https://hex.pm/packages/caddy) Elixir library. Provides a web-based dashboard for managing and monitoring a Caddy reverse proxy server.

## Features

- **Dashboard Home** — Server state, operating mode, readiness, sync status with real-time telemetry updates
- **Configuration Editor** — Edit Caddyfile with validate, save, adapt-to-JSON, and sync-to-Caddy actions
- **Metrics Dashboard** — Health status, error rate, latency, upstream health from Prometheus metrics
- **Runtime Config Browser** — Navigate Caddy's JSON config tree, apply patches, rollback
- **Server Control Panel** — Start/stop/restart, health checks, lifecycle commands (embedded & external modes)
- **Log Viewer** — Tail logs with search, configurable line count, auto-refresh
- **Telemetry Event Stream** — Real-time feed of all `[:caddy, ...]` telemetry events with filtering

## Prerequisites

- Elixir ~> 1.18 / OTP 27+
- Caddy binary installed and available in `$PATH` (or configured explicitly)
- Node.js (for asset compilation)

## Setup

```bash
cd examples/caddy_dashboard

# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) in your browser.

## Configuration

The app runs Caddy in **external mode** by default, expecting a Caddy instance at `localhost:2019`. To change this, edit `config/config.exs`:

```elixir
config :caddy,
  mode: :embedded,       # or :external
  admin_url: "http://localhost:2019"
```

## Architecture

```
lib/caddy_dashboard/
├── application.ex             # Starts Caddy + TelemetryCollector
└── telemetry_collector.ex     # Bridges telemetry events → PubSub

lib/caddy_dashboard_web/
├── router.ex                  # 7 LiveView routes
├── components/layouts.ex      # Sidebar navigation (DaisyUI)
└── live/
    ├── dashboard_live.ex      # Home dashboard
    ├── config_live.ex         # Configuration editor
    ├── metrics_live.ex        # Metrics dashboard
    ├── runtime_live.ex        # Runtime config browser
    ├── server_live.ex         # Server control panel
    ├── logs_live.ex           # Log viewer
    └── telemetry_live.ex      # Telemetry event stream
```

The `TelemetryCollector` GenServer subscribes to all Caddy telemetry events and broadcasts them via Phoenix PubSub. LiveView pages subscribe to PubSub topics for real-time updates.
