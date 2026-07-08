# AGENTS.md

This file provides guidance to when working with code in this repository.

## Overview

An Elixir library (Hex package `caddy`) that manages a Caddy reverse proxy server as part of an Elixir application's supervision tree. Requires Elixir ~> 1.18, OTP 27+. Uses built-in JSON, `http_fetch` for HTTP, and Telemetry for observability.

## Development Commands

```bash
mix deps.get                    # Install dependencies
mix compile --warnings-as-errors # Compile with CI-level strictness

mix test                        # Run all tests
mix test test/caddy/admin/api_test.exs        # Run one test file
mix test test/caddy/admin/api_test.exs:10     # Run one test by line
mix coveralls                   # Test coverage (ExCoveralls); coveralls.html for local review

mix format                      # Format code
mix format --check-formatted    # Verify formatting (CI)
mix credo --strict              # Static analysis
mix dialyzer                    # Type checking (PLT in priv/plts; first run is slow)
mix lint                        # Alias: credo --strict + dialyzer

mix publish                     # Publish to Hex (formats, cleans priv/, hex.publish)
```

Commits follow Conventional Commit style: `feat(config): ...`, `fix(example): ...`, `docs: ...`, `chore: ...`.

## Architecture

`Caddy` (lib/caddy.ex) is the public facade — nearly all functions are `defdelegate`s to the modules below. `Caddy.Supervisor` runs children with `rest_for_one` in this order:

1. **`Caddy.ConfigProvider`** — Agent holding the in-memory `%Caddy.Config{}` struct
2. **`Caddy.ConfigManager`** — GenServer coordinating in-memory ↔ runtime config (sync, drift detection, rollback) and owning the application state machine
3. **`Caddy.Logger`** — logging subsystem (buffer, store, telemetry handler)
4. **`Caddy.Server`** — mode-based dispatcher to the actual server implementation

### Two server modes

`Caddy.Server.impl_module/0` selects the implementation from `config :caddy, mode:`:

- **`:external` (default)** — `Caddy.Server.External`. Caddy is managed outside the BEAM (e.g., systemd). Communicates via Admin API (`config :caddy, admin_url:` — TCP or `unix://` socket) and optional lifecycle shell commands (`config :caddy, commands: [start: ..., stop: ...]`).
- **`:embedded`** — `Caddy.Server.Embedded`. Spawns and manages the Caddy binary directly (requires `caddy_bin`); handles process lifecycle, PID file, output logging, cleanup.

### Configuration model (3-part structure)

`Caddy.Config` is a pure struct/functions module (NOT a process — the Agent is `ConfigProvider`). A Caddyfile is assembled from three parts:

1. `global` — global options block content (without braces)
2. `additionals` — named snippets/matchers: `%{name: ..., content: ...}`
3. `sites` — `%{address: ..., config: ...}`

Public API mirrors this: `Caddy.set_global/1`, `Caddy.add_additional/2`, `Caddy.add_site/2`, `Caddy.update_site/2`, `Caddy.remove_site/1`, plus whole-file `Caddy.set_caddyfile/1` (parses text into the 3 parts) and `Caddy.get_caddyfile/0`. Validation happens by shelling out to `caddy adapt` (Caddyfile → JSON).

### Config sync & state machine

In-memory config does NOT auto-apply to running Caddy. `Caddy.sync_to_caddy/0` adapts and pushes it; `Caddy.check_sync_status/0` detects drift; `Caddy.rollback/0` restores last known good config. `Caddy.apply_runtime_config/1,2` bypasses in-memory config for runtime-only changes.

`Caddy.State` defines the lifecycle: `:initializing → :unconfigured → :configured → :synced ⇄ :degraded`. Query via `Caddy.get_state/0`, `Caddy.ready?/0` (true only when `:synced`), `Caddy.configured?/0`.

### Admin API

`Caddy.Admin.Api` wraps Caddy's admin endpoints (GET/POST/PUT/PATCH/DELETE, load, adapt) over `Caddy.Admin.Transport` (TCP or Unix socket). HTTP is abstracted behind `Caddy.Admin.RequestBehaviour` for mocking.

### Telemetry-based logging

All internal logging goes through telemetry events, not direct Logger calls:

```elixir
Caddy.Telemetry.log_info("Configuration loaded", config_id: 123)
Caddy.Telemetry.log_error("Operation failed", reason: :timeout)
```

`Caddy.Logger.Handler` forwards `[:caddy, :log, *]` events to Elixir's Logger (disable with `config :caddy, attach_default_handler: false`). Events cover config, server lifecycle, API, file ops, validation, adaptation, and log buffer/store — see `Caddy.Telemetry.list_events/0`. `Caddy.Metrics` (parser + poller) scrapes Caddy's Prometheus metrics.

## Testing

- ExUnit + Mox. Mocks defined in `test/test_helper.exs`: `Caddy.Admin.RequestMock` (for `Caddy.Admin.RequestBehaviour`) and `Caddy.ConfigManagerMock` (for `Caddy.ConfigManager.Behaviour`).
- The application does not auto-start in `:test` env (see `mix.exs` `application/0`); `test_helper.exs` calls `Caddy.start()` explicitly.
- Tests mirror source layout: `lib/caddy/admin/api.ex` → `test/caddy/admin/api_test.exs`.
- Useful test config: `config :caddy, start: false` (disable auto-start), `config :caddy, dump_log: false`.

## Key Application Config

```elixir
config :caddy, mode: :external | :embedded   # default :external
config :caddy, admin_url: "http://localhost:2019"  # or "unix:///path/caddy.sock"
config :caddy, caddy_bin: "/usr/bin/caddy"   # embedded mode
config :caddy, commands: [start: "systemctl start caddy", ...]  # external mode
config :caddy, :base_path, "/custom/caddy/path"  # also :etc_path, :run_path, :tmp_path, :env_file, :pid_file, :socket_file
```

Default paths live under `~/.local/share/caddy/`; admin socket defaults to `unix://<run_path>/caddy.sock`.

## Repository Layout Notes

- `examples/` — runnable demos, including a full Phoenix dashboard app (`examples/caddy_dashboard/`); UI changes there warrant screenshots in PRs
- `specs/` — design artifacts and implementation plans
- AGENTS.md — repository guidelines (commands, style, PR conventions); keep consistent with this file
