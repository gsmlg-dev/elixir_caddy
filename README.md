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
Caddy.Config.set_bin("/usr/bin/caddy")
Caddy.restart_server()
```

This will restart server automatically

```elixir
Caddy.Config.set_bin!("/usr/bin/caddy")
```

## Config

```elixir
import Config

# dump caddy server log to stdout
config :caddy, dump_log: false

# caddy server will not start, this is useful for testing
config :caddy, start: false

# configure caddy paths
config :caddy, :base_path, "/custom/caddy/path"
config :caddy, :etc_path, "/custom/etc/path"
config :caddy, :run_path, "/custom/run/path"
config :caddy, :tmp_path, "/custom/tmp/path"
config :caddy, :env_file, "/custom/path/envfile"
config :caddy, :pid_file, "/custom/path/caddy.pid"
```

## Telemetry

The library includes comprehensive telemetry support for monitoring Caddy operations. Telemetry events are emitted for:

- **Configuration changes**: `[:caddy, :config, :set]`, `[:caddy, :config, :get]`, etc.
- **Server lifecycle**: `[:caddy, :server, :start]`, `[:caddy, :server, :stop]`
- **API operations**: `[:caddy, :api, :request]`, `[:caddy, :api, :response]`
- **File operations**: `[:caddy, :file, :read]`, `[:caddy, :file, :write]`
- **Validation**: `[:caddy, :validation, :success]`, `[:caddy, :validation, :error]`
- **Adaptation**: `[:caddy, :adapt, :success]`, `[:caddy, :adapt, :error]`
- **Logging operations**: `[:caddy, :log, :debug]`, `[:caddy, :log, :info]`, `[:caddy, :log, :warning]`, `[:caddy, :log, :error]`
- **Log buffer/store**: `[:caddy, :log, :received]`, `[:caddy, :log, :buffered]`, `[:caddy, :log, :buffer_flush]`, `[:caddy, :log, :stored]`, `[:caddy, :log, :retrieved]`

### Logging with Telemetry

All logging operations emit telemetry events. By default, a handler automatically forwards log events to Elixir's Logger:

```elixir
# Use telemetry-based logging (instead of Logger directly)
Caddy.Telemetry.log_debug("Server starting", module: MyApp)
Caddy.Telemetry.log_info("Configuration loaded", config_id: 123)
Caddy.Telemetry.log_warning("Deprecation warning", function: "old_api")
Caddy.Telemetry.log_error("Failed to connect", reason: :timeout)
```

Configure logging behavior:

```elixir
config :caddy,
  attach_default_handler: true,  # Auto-forward logs to Logger (default: true)
  log_level: :info               # Minimum level to log (default: :debug)
```

### Custom Telemetry Handlers

Attach custom handlers to process log events:

```elixir
# Send errors to external monitoring service
:telemetry.attach("error_reporter", [:caddy, :log, :error],
  fn _event, _measurements, metadata, _config ->
    MyApp.ErrorReporter.report(metadata.message, metadata)
  end, %{})

# Monitor log buffer performance
:telemetry.attach("buffer_monitor", [:caddy, :log, :buffered],
  fn _event, measurements, _metadata, _config ->
    MyApp.Metrics.track_buffer_size(measurements.buffer_size)
  end, %{})
```

### Usage Example

```elixir
# Attach telemetry handler
:telemetry.attach_many("caddy_handler", [
  [:caddy, :config, :set],
  [:caddy, :server, :start],
  [:caddy, :log, :error]
], fn event_name, measurements, metadata, _config ->
  IO.inspect({event_name, measurements, metadata})
end, %{})

# Start telemetry poller for system metrics
Caddy.Telemetry.start_poller(30_000)
```

### Available Functions

- `Caddy.Telemetry.log_debug/2` - Emit debug log event
- `Caddy.Telemetry.log_info/2` - Emit info log event
- `Caddy.Telemetry.log_warning/2` - Emit warning log event
- `Caddy.Telemetry.log_error/2` - Emit error log event
- `Caddy.Telemetry.emit_config_change/3` - Configuration change events
- `Caddy.Telemetry.emit_server_event/3` - Server lifecycle events
- `Caddy.Telemetry.emit_api_event/3` - API operation events
- `Caddy.Telemetry.list_events/0` - List all available events
- `Caddy.Telemetry.attach_handler/3` - Attach telemetry handler
- `Caddy.Telemetry.detach_handler/1` - Detach telemetry handler
