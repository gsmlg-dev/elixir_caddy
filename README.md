# Elixir Caddy

[![release](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml/badge.svg)](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml) [![Hex.pm](https://img.shields.io/hexpm/v/caddy.svg)](https://hex.pm/packages/caddy) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/caddy)

Start `Caddy` reverse proxy server in `Elixir` project.

Manage caddy configuration in `Elixir`.

Add this in `deps` in `mix.exs` to install

```elixir
{:caddy, "~> 2.0"}
```

If caddy bin is set, caddy server will automate start when application start.


Start in extra_applications

```elixir
def application do
  [
    extra_applications: [Caddy.Application]
  ]
end
```

* Notice

If caddy_bin is not specifiy, Caddy.Server will not start.

## Set `Caddy` binary when needed.

Set `caddy_bin` to the path of Caddy binary file and start `Caddy.Server`.

```elixir
Caddy.Cofnig.set_bin("/usr/bin/caddy")
Caddy.restart_server()
```

This will restart server automatically

```elixir
Caddy.Cofnig.set_bin!("/usr/bin/caddy")
```

## Config

```elixir
import Config

# dump caddy server log to stdout
config :caddy, dump_log: false

# caddy server will not start, this is useful for testing
config :caddy, start: false
```

## Telemetry

The library includes comprehensive telemetry support for monitoring Caddy operations. Telemetry events are emitted for:

- **Configuration changes**: `[:caddy, :config, :set]`, `[:caddy, :config, :get]`, etc.
- **Server lifecycle**: `[:caddy, :server, :start]`, `[:caddy, :server, :stop]`
- **API operations**: `[:caddy, :api, :request]`, `[:caddy, :api, :response]`
- **File operations**: `[:caddy, :file, :read]`, `[:caddy, :file, :write]`
- **Validation**: `[:caddy, :validation, :success]`, `[:caddy, :validation, :error]`
- **Adaptation**: `[:caddy, :adapt, :success]`, `[:caddy, :adapt, :error]`

### Usage Example

```elixir
# Attach telemetry handler
:telemetry.attach_many("caddy_handler", [
  [:caddy, :config, :set],
  [:caddy, :server, :start]
], fn event_name, measurements, metadata, _config ->
  IO.inspect({event_name, measurements, metadata})
end, %{})

# Start telemetry poller
Caddy.Telemetry.start_poller(30_000)
```

### Available Functions

- `Caddy.Telemetry.emit_config_change/3` - Configuration change events
- `Caddy.Telemetry.emit_server_event/3` - Server lifecycle events
- `Caddy.Telemetry.emit_api_event/3` - API operation events
- `Caddy.Telemetry.list_events/0` - List all available events
- `Caddy.Telemetry.attach_handler/3` - Attach telemetry handler
- `Caddy.Telemetry.detach_handler/1` - Detach telemetry handler
