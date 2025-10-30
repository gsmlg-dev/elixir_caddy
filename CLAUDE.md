# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

An Elixir library that manages Caddy reverse proxy server as part of your Elixir application's supervision tree. Provides configuration management, API access, telemetry, and logging capabilities.

## Architecture

The application follows a supervisor-worker pattern with these key components:

- **Caddy**: Main supervisor managing the entire Caddy subsystem
- **Caddy.Application**: Application entry point (only starts in non-test environments)
- **Caddy.Server**: GenServer that manages the actual Caddy binary process
- **Caddy.Config**: Agent that stores and manages Caddy configuration
- **Caddy.Admin.Api**: HTTP API client for Caddy admin interface
- **Caddy.Logger**: Logging subsystem with buffer and storage
- **Caddy.Telemetry**: Comprehensive telemetry for monitoring operations

## Key Components

### Configuration Management (`Caddy.Config`)
- Agent-based configuration storage in `%Caddy.Config{}` struct
- Manages binary path, global settings, site configurations, and environment variables
- Provides file-based configuration persistence in `~/.local/share/caddy/` (configurable via `:base_path`)
- Supports Caddyfile → JSON adaptation via admin API
- Thread-safe configuration updates with `set_bin!` for automatic restart

### Server Management (`Caddy.Server`)
- GenServer that starts/stops Caddy binary process
- Handles process lifecycle, cleanup, and restart logic
- Manages Caddyfile generation and JSON configuration
- Uses Unix domain sockets for admin interface at `/tmp/caddy-{port}.sock`
- Automatic PID file management for process tracking

### API Access (`Caddy.Admin.Api`)
- RESTful API wrapper for Caddy admin endpoints
- Supports GET/POST/PUT/PATCH/DELETE operations
- Configuration loading and adaptation with validation
- Mock support for testing via `Caddy.Admin.RequestBehaviour`
- Unix socket communication for local admin interface

## Development Commands

### Build & Test
```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run specific test file
mix test test/caddy/admin/api_test.exs

# Run specific test
mix test test/caddy/admin/api_test.exs:10

# Format code
mix format

# Check formatting
mix format --check-formatted

# Static code analysis with Credo
mix credo

# Strict mode (shows all issues including low priority)
mix credo --strict

# Type checking with Dialyzer (first run builds PLT file, may take time)
mix dialyzer

# Run all linting (Credo + Dialyzer)
mix lint

# Publish package to Hex (includes cleanup)
mix publish
```

### Interactive Development
```bash
# Start IEx with the project
iex -S mix

# In IEx, manually start Caddy
Caddy.start("/usr/bin/caddy")

# Or use auto-discovery
Caddy.start()
```

### Configuration Paths
```elixir
# Configure custom paths in config.exs
config :caddy, :base_path, "/custom/caddy/path"
config :caddy, :etc_path, "/custom/etc/path"
config :caddy, :run_path, "/custom/run/path"
config :caddy, :tmp_path, "/custom/tmp/path"
config :caddy, :env_file, "/custom/path/envfile"
config :caddy, :pid_file, "/custom/path/caddy.pid"

# Test mode configuration
config :caddy, dump_log: false  # Don't log to stdout
config :caddy, start: false     # Disable auto-start for testing
```

### Usage Examples
```elixir
# Set Caddy binary path (without restart)
Caddy.Config.set_bin("/usr/bin/caddy")
Caddy.restart_server()

# Set binary and auto-restart
Caddy.Config.set_bin!("/usr/bin/caddy")

# Configure global settings
Caddy.Config.set_global("""
debug
auto_https off
""")

# Add site configuration
Caddy.Config.set_site("myapp", "localhost:4000", """
reverse_proxy {
  to localhost:3000
}
""")

# Use admin API
{:ok, config} = Caddy.Admin.Api.get_config()
Caddy.Admin.Api.load(new_config)
Caddy.Admin.Api.adapt(caddyfile_content)

# Telemetry integration
:telemetry.attach("my_handler",
  [:caddy, :server, :start],
  &MyApp.handle_telemetry/4,
  %{})
```

## Testing Strategy

Uses ExUnit with Mox for mocking HTTP requests:
- Mock HTTP client: `Caddy.Admin.RequestMock`
- Define mock expectations in tests using `Mox.expect/4`
- Application doesn't auto-start in test environment
- Test helper configures mocks and application

## Telemetry Events

The library emits telemetry events for monitoring:
- Configuration: `[:caddy, :config, :set]`, `[:caddy, :config, :get]`
- Server lifecycle: `[:caddy, :server, :start]`, `[:caddy, :server, :stop]`
- API operations: `[:caddy, :api, :request]`, `[:caddy, :api, :response]`
- File operations: `[:caddy, :file, :read]`, `[:caddy, :file, :write]`
- Validation: `[:caddy, :validation, :success]`, `[:caddy, :validation, :error]`
- Adaptation: `[:caddy, :adapt, :success]`, `[:caddy, :adapt, :error]`

Use `Caddy.Telemetry.list_events/0` to see all available events.