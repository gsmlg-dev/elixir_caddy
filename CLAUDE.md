# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

An Elixir library that manages Caddy reverse proxy server as part of your Elixir application's supervision tree. Provides configuration management, API access, and logging capabilities.

## Architecture

The application follows a supervisor-worker pattern with these key components:

- **Caddy**: Main supervisor managing the entire Caddy subsystem
- **Caddy.Application**: Application entry point
- **Caddy.Server**: GenServer that manages the actual Caddy binary process
- **Caddy.Config**: Agent that stores and manages Caddy configuration
- **Caddy.Admin.Api**: HTTP API client for Caddy admin interface
- **Caddy.Logger**: Logging subsystem with buffer and storage

## Key Components

### Configuration Management (`Caddy.Config`)
- Agent-based configuration storage in `%Caddy.Config{}` struct
- Manages binary path, global settings, site configurations, and environment variables
- Provides file-based configuration persistence in `~/.local/share/caddy/`
- Supports Caddyfile → JSON adaptation

### Server Management (`Caddy.Server`)
- GenServer that starts/stops Caddy binary process
- Handles process lifecycle, cleanup, and restart logic
- Manages Caddyfile generation and JSON configuration
- Uses Unix domain sockets for admin interface

### API Access (`Caddy.Admin.Api`)
- RESTful API wrapper for Caddy admin endpoints
- Supports GET/POST/PUT/PATCH/DELETE operations
- Configuration loading and adaptation
- Mock support for testing via `Caddy.Admin.RequestBehaviour`

## Development Commands

### Build & Test
```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run specific test
mix test test/caddy/admin/api_test.exs

# Format code
mix format

# Publish package
mix publish
```

### Configuration
```elixir
# Add to mix.exs dependencies
{:caddy, "~> 2.0"}

# Add to application.ex
extra_applications: [Caddy.Application]

# Configure in config.exs
config :caddy, dump_log: false  # Log to stdout
config :caddy, start: false     # Disable auto-start for testing
```

### Usage Examples
```elixir
# Set Caddy binary path
Caddy.Config.set_bin("/usr/bin/caddy")

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

# Restart server
Caddy.restart_server()

# Use admin API
Caddy.Admin.Api.get_config()
Caddy.Admin.Api.load(new_config)
```

## File Structure

- `lib/caddy.ex`: Main supervisor and public API
- `lib/caddy/application.ex`: Application entry point
- `lib/caddy/server.ex`: Caddy process management
- `lib/caddy/config.ex`: Configuration management
- `lib/caddy/admin/api.ex`: Admin API client
- `lib/caddy/logger/`: Logging subsystem
- `test/`: Test suite with Mox mocks

## Testing

Uses ExUnit with Mox for mocking HTTP requests. Test setup includes:
- Mock HTTP client: `Caddy.Admin.RequestMock`
- Application startup in test_helper.exs
- Sample configuration tests

## Environment Setup

- Requires Caddy binary (v2+) in PATH or manually specified
- Uses `~/.local/share/caddy/` for configuration storage
- Creates necessary directories on startup
- Supports environment variable configuration via Agent