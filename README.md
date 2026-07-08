# Elixir Caddy

[![release](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml/badge.svg)](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml) [![Hex.pm](https://img.shields.io/hexpm/v/caddy.svg)](https://hex.pm/packages/caddy) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/caddy)

Run and manage a Caddy reverse proxy from an Elixir supervision tree.

The default mode is `:external`: Caddy is managed by systemd, launchd, Docker, or another process manager, and this library talks to its Admin API. Embedded mode is available when you explicitly want the BEAM to spawn and monitor a local Caddy binary.

## Installation

```elixir
def deps do
  [
    {:caddy, "~> 2.0"}
  ]
end
```

Add the application to your supervision tree:

```elixir
def application do
  [
    extra_applications: [Caddy.Application]
  ]
end
```

## External Mode

```elixir
import Config

config :caddy,
  mode: :external,
  admin_url: "http://localhost:2019",
  health_interval: 30_000,
  commands: [
    start: "systemctl start caddy",
    stop: "systemctl stop caddy",
    restart: "systemctl restart caddy",
    status: {"systemctl", ["is-active", "caddy"]}
  ]
```

Command strings are executed through `sh -c`, so quoted arguments and redirects work. Tuple commands run without shell parsing.

HTTPS and mTLS Admin API connections are supported:

```elixir
config :caddy,
  admin_url: "https://caddy-admin.example.com:2019",
  admin_tls: [
    certfile: "/etc/caddy/client.pem",
    keyfile: "/etc/caddy/client-key.pem",
    cacertfile: "/etc/caddy/ca.pem"
  ]
```

Periodic drift checks are opt-in:

```elixir
config :caddy,
  drift_interval: 60_000,
  on_drift: :report # or :resync
```

## Embedded Mode

```elixir
config :caddy,
  mode: :embedded,
  caddy_bin: "/usr/bin/caddy"
```

Embedded mode writes an adapted JSON config and starts Caddy with an Erlang port. If the port exits, the GenServer records the failure for `Caddy.Server.check_status/0` instead of exiting in a restart loop.

## Runtime Config

In-memory Caddyfile changes do not automatically apply to the running server. Sync explicitly:

```elixir
Caddy.set_caddyfile("""
{
  admin unix//tmp/caddy.sock
}

example.com {
  reverse_proxy localhost:3000
}
""")

:ok = Caddy.sync_to_caddy()
{:ok, :in_sync} = Caddy.check_sync_status()
```

Admin API helpers return tagged tuples:

```elixir
{:ok, config} = Caddy.get_runtime_config()
{:ok, servers} = Caddy.get_runtime_config("apps/http/servers")
:ok = Caddy.apply_runtime_config(%{"apps" => %{}})
{:error, reason} = Caddy.get_runtime_config("missing/path")
```

Whole-config loads replace the active config directly rather than merging into the existing runtime config.

## Operational Helpers

```elixir
{:ok, upstreams} = Caddy.upstreams()
{:ok, certs} = Caddy.certificates()
{:ok, route} = Caddy.get_by_id("route-1")
{:ok, _} = Caddy.patch_by_id("route-1", %{"terminal" => true}, if_match: "etag-value")
:ok = Caddy.delete_by_id("route-1")
{:ok, %{version: version, modules: modules}} = Caddy.version()
```

Certificate helpers emit `[:caddy, :tls, :certificate_seen]` and `[:caddy, :tls, :certificate_expiring]` events. Configure the warning window with:

```elixir
config :caddy, cert_expiry_warning_days: 30
```

## Paths

```elixir
config :caddy, :base_path, "/custom/caddy/path"
config :caddy, :etc_path, "/custom/etc/path"
config :caddy, :run_path, "/custom/run/path"
config :caddy, :tmp_path, "/custom/tmp/path"
config :caddy, :env_file, "/custom/path/envfile"
config :caddy, :pid_file, "/custom/path/caddy.pid"
```

Use `config :caddy, start: false` in tests or environments where the Caddy supervisor child should not start.

## Telemetry

The library emits telemetry for configuration, Admin API calls, server lifecycle, resources, metrics, TLS certificates, and internal logging. Use `Caddy.Telemetry.list_events/0` to see the full event list.

By default, log events are forwarded to Elixir's Logger:

```elixir
Caddy.Telemetry.log_info("Configuration loaded", config_id: 123)
Caddy.Telemetry.log_error("Failed to connect", reason: :timeout)
```

Configure logging behavior:

```elixir
config :caddy,
  attach_default_handler: true,
  log_level: :info
```
