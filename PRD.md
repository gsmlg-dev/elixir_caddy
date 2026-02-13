# Product Requirements Document: Elixir Caddy

**Version:** 2.3.0
**Last Updated:** 2026-02-03
**Status:** Production
**Repository:** https://github.com/gsmlg-dev/elixir_caddy

---

## 1. Executive Summary

Elixir Caddy is an OTP-compliant library that integrates the [Caddy](https://caddyserver.com) reverse proxy server into Elixir application supervision trees. It provides programmatic control over Caddy configuration, lifecycle management, and runtime operations through a native Elixir API.

### Key Value Propositions

1. **Zero-Config Startup** - Starts immediately in external mode, waits for configuration
2. **Text-First Configuration** - Write native Caddyfile syntax directly, not JSON
3. **Dual Operating Modes** - Manage embedded or externally-controlled Caddy instances
4. **State-Aware Operations** - Clear state machine tracks configuration and sync status
5. **Comprehensive Observability** - 50+ telemetry events for monitoring and debugging

---

## 2. Problem Statement

### Current Challenges

**For Elixir Developers:**
- No native way to manage Caddy from Elixir applications
- Manual configuration file management disconnected from application lifecycle
- Difficulty coordinating reverse proxy changes with application deployments
- Lack of visibility into Caddy operations from Elixir observability tooling

**For DevOps/SRE Teams:**
- Configuration drift between desired and actual Caddy state
- No programmatic interface for infrastructure-as-code patterns
- Inconsistent management across embedded vs. external Caddy deployments
- Missing audit trail for configuration changes

### Target Users

| User Type | Primary Need |
|-----------|--------------|
| **Elixir Developers** | Integrate reverse proxy into application supervision tree |
| **DevOps Engineers** | Programmatic Caddy management and configuration automation |
| **SRE Teams** | Observability, drift detection, and operational control |
| **Platform Teams** | Standardized Caddy integration pattern for microservices |

---

## 3. Product Vision

### Mission Statement

Enable Elixir applications to treat Caddy as a first-class OTP component with the same lifecycle guarantees, configuration management, and observability as any other supervised process.

### Design Principles

1. **Text-First Configuration** - Native Caddyfile syntax over JSON abstractions
2. **One-Way Data Flow** - Caddyfile → JSON → Caddy (no reverse conversion possible)
3. **Supervision Semantics** - Proper OTP process management with fault tolerance
4. **Explicit Synchronization** - Clear separation between in-memory and runtime config
5. **Observable by Default** - Telemetry events for all significant operations
6. **Mode Flexibility** - Support both embedded and external Caddy deployments
7. **Library, Not Application** - Pure OTP library with no UI; visual management is provided through a separate example application

### Scope Boundary: No UI in Core Package

The `caddy` hex package is a **pure OTP library**. It must not include:

- Phoenix, LiveView, or any web framework dependency
- HTML templates, CSS, or JavaScript assets
- HTTP endpoints or router definitions
- Any visual interface code

The library exposes only Elixir functions, GenServers, telemetry events, and OTP behaviors. All UI and visual management functionality belongs in a **separate example application** (see Section 10).

---

## 4. Feature Specifications

### 4.1 Configuration Management

#### 4.1.1 Text-Based Configuration

**Description:** Store and manage Caddy configuration as native Caddyfile text.

**Requirements:**
- [ ] Store Caddyfile content in-memory via Agent process
- [ ] Validate syntax via `caddy adapt` command before applying
- [ ] Auto-format Caddyfile via `caddy fmt` during adaptation
- [ ] Convert Caddyfile to JSON for Admin API operations
- [ ] Support full Caddyfile syntax including global options, snippets, and matchers

**API:**
```elixir
Caddy.set_caddyfile(caddyfile_text)    # Set configuration
Caddy.get_caddyfile()                  # Retrieve configuration
Caddy.append_caddyfile(text)           # Append to configuration
Caddy.adapt(caddyfile_text)            # Validate and convert to JSON
```

#### 4.1.2 Configuration Persistence

**Description:** Save and restore configurations to/from disk.

**Requirements:**
- [ ] Automatic save to `~/.local/share/caddy/config/caddy/autosave.json`
- [ ] Manual backup to `backup.json`
- [ ] Restore from backup on demand
- [ ] Configurable storage paths via application environment

**API:**
```elixir
Caddy.save_config()                    # Save current config
Caddy.backup_config()                  # Create backup
Caddy.restore_config()                 # Restore from backup
```

#### 4.1.3 Runtime Synchronization

**Description:** Push in-memory Caddyfile to running Caddy and detect drift.

**Architecture Constraint:**
> **One-Way Sync Only:** Caddy stores configuration as JSON internally. The
> `caddy adapt` command converts Caddyfile → JSON, but there is no reverse
> conversion. Therefore, synchronization is **push-only** from Caddyfile to Caddy.

**Requirements:**
- [ ] Push in-memory config to running Caddy (`sync_to_caddy`)
- [ ] Detect configuration drift (`check_sync_status`) - compares adapted JSON
- [ ] Optional backup of runtime JSON before sync operations
- [ ] Rollback to last known-good JSON configuration
- [ ] Skip validation with force option

**API:**
```elixir
Caddy.sync_to_caddy()                  # Push memory → runtime
Caddy.sync_to_caddy(backup: true)      # With backup
Caddy.check_sync_status()              # Detect drift (compares JSON)
Caddy.rollback()                       # Restore last good JSON config
Caddy.get_runtime_config()             # Get runtime JSON (read-only)
```

**Sync Status Returns:**
- `:in_sync` - Adapted Caddyfile matches runtime JSON
- `{:drift_detected, diff}` - Differences found with diff details

**Not Supported:**
- `sync_from_caddy()` - **Deprecated/Remove**: Cannot convert runtime JSON back to Caddyfile text. The current implementation incorrectly stores JSON in the caddyfile field.

---

### 4.2 Operating Modes

#### 4.2.1 External Mode (Default)

**Description:** Communicate with externally-managed Caddy (systemd, Docker, etc.).

> **Default Mode:** External mode is the default because it's safer - it doesn't
> spawn processes and works with empty configuration (waiting state).

**Requirements:**
- [ ] Connect via Admin API (TCP or Unix socket)
- [ ] Periodic health checks with configurable interval
- [ ] Execute system commands for lifecycle operations
- [ ] Support empty/unconfigured state (waiting for config)
- [ ] Track status changes (running/stopped/unknown)
- [ ] Auto-push configuration when both configured AND Caddy is running

**Configuration:**
```elixir
# External mode (default - no config needed)
config :caddy, mode: :external
config :caddy, admin_url: "http://localhost:2019"
config :caddy, health_interval: 30_000
config :caddy, commands: [
  start: "systemctl start caddy",
  stop: "systemctl stop caddy",
  restart: "systemctl restart caddy",
  status: "systemctl is-active caddy"
]
```

**API:**
```elixir
Caddy.Server.check_status()            # Get current status
Caddy.Server.execute_command(:start)   # Execute lifecycle command
Caddy.Server.External.health_check()   # Trigger immediate health check
```

#### 4.2.2 Embedded Mode

**Description:** Application spawns and manages Caddy binary directly.

**Requirements:**
- [ ] Spawn Caddy binary via Erlang port
- [ ] Monitor process and capture output
- [ ] Manage PID file for process tracking
- [ ] Clean up on termination (kill process, remove PID file)
- [ ] Validate binary exists and is executable before starting
- [ ] Support environment variable injection
- [ ] Require valid Caddyfile before starting (cannot start empty)

**Configuration:**
```elixir
config :caddy, mode: :embedded
config :caddy, caddy_bin: "/usr/bin/caddy"
```

**Process Arguments:**
```
caddy run --config <init.json> --pidfile <caddy.pid>
```

---

### 4.3 Admin API Integration

#### 4.3.1 Transport Layer

**Description:** Abstract connection handling for Unix sockets and TCP.

**Requirements:**
- [ ] Parse URL schemes: `unix:///path` and `http://host:port`
- [ ] Default to port 2019 for HTTP connections
- [ ] Configurable connection timeout (default: 5000ms)
- [ ] Proper Host header for both transport types

**URL Formats:**
```
unix:///var/run/caddy.sock     → Unix domain socket
http://localhost:2019          → TCP connection
http://192.168.1.1:8080        → TCP with custom port
```

#### 4.3.2 REST Operations

**Description:** Full REST API access to Caddy Admin interface.

**Requirements:**
- [ ] GET, POST, PUT, PATCH, DELETE methods
- [ ] JSON encoding/decoding for request/response bodies
- [ ] Chunked transfer encoding support
- [ ] Error handling with descriptive messages

**API:**
```elixir
Caddy.Admin.Api.get_config()           # GET /config/
Caddy.Admin.Api.get_config("/apps")    # GET /config/apps
Caddy.Admin.Api.load(config)           # POST /load
Caddy.Admin.Api.adapt(caddyfile)       # POST /adapt
Caddy.Admin.Api.health_check()         # GET /config/ (health)
Caddy.Admin.Api.server_info()          # GET /
Caddy.Admin.Api.stop()                 # POST /stop
```

#### 4.3.3 Resource Helpers

**Description:** Domain-specific helpers for common configuration tasks.

**Requirements:**
- [ ] HTTP server management
- [ ] Route configuration
- [ ] TLS settings
- [ ] App-level configuration
- [ ] Storage configuration

**API:**
```elixir
# HTTP Servers
Resources.get_http_servers()
Resources.get_server("srv0")
Resources.update_server("srv0", config)

# Routes
Resources.get_routes("srv0")
Resources.add_route("srv0", route_config)
Resources.update_route("srv0", route_index, config)

# TLS
Resources.get_tls()
Resources.set_tls(tls_config)

# Apps
Resources.get_apps()
Resources.get_app("http")
Resources.set_app("http", config)
```

---

### 4.4 Logging Subsystem

#### 4.4.1 Output Capture

**Description:** Capture and buffer Caddy process output.

**Requirements:**
- [ ] Capture stdout and stderr from Caddy process
- [ ] Line-based buffering before storage
- [ ] Configurable buffer flush threshold
- [ ] Optional dump to stdout (`dump_log: true`)

#### 4.4.2 Log Storage

**Description:** Circular buffer storage for log retrieval.

**Requirements:**
- [ ] Store up to 50,000 log lines
- [ ] FIFO eviction when limit reached
- [ ] Tail retrieval with configurable count
- [ ] Thread-safe access

**API:**
```elixir
Caddy.Logger.tail(100)                 # Get last 100 lines
Caddy.Logger.Store.tail()              # Get default tail
```

---

### 4.5 Telemetry & Observability

#### 4.5.1 Event Categories

**Requirements:**
- [ ] Emit telemetry events for all significant operations
- [ ] Include duration measurements where applicable
- [ ] Attach relevant metadata to each event
- [ ] Support custom handler attachment

**Event Namespace:** `[:caddy, <category>, <event>]`

| Category | Events |
|----------|--------|
| `config` | `:set`, `:get`, `:save`, `:load`, `:backup`, `:restore` |
| `server` | `:start`, `:stop`, `:restart`, `:status`, `:exit`, `:shutdown`, `:terminate`, `:cleanup`, `:bootstrap_success`, `:bootstrap_error`, `:process_start` |
| `api` | `:request`, `:response`, `:error`, `:load`, `:get_config`, `:post_config`, `:put_config`, `:patch_config`, `:delete_config`, `:adapt`, `:health_check`, `:server_info` |
| `validation` | `:success`, `:error` |
| `adapt` | `:success`, `:error` |
| `file` | `:read`, `:write`, `:delete` |
| `log` | `:debug`, `:info`, `:warning`, `:error`, `:received`, `:buffered`, `:buffer_flush`, `:stored`, `:retrieved` |
| `config_manager` | `:sync_to_caddy`, `:drift_check`, `:rollback`, `:apply`, `:validate` |
| `resources` | `:get`, `:set`, `:delete`, `:error` |
| `external` | `:init`, `:health_check`, `:command_executed`, `:config_pushed`, `:status_changed`, `:terminate` |
| `metrics` | `:collected`, `:fetch_error`, `:poller_started`, `:poller_stopped` |
| `system` | `:memory`, `:process_count`, `:uptime` |

#### 4.5.2 Logging Integration

**Description:** Forward log events to Elixir Logger.

**Requirements:**
- [ ] Default handler forwards `:log` events to Logger
- [ ] Configurable minimum log level
- [ ] Option to disable default handler
- [ ] Include module, timestamp, and custom metadata

**Configuration:**
```elixir
config :caddy, attach_default_handler: true
config :caddy, log_level: :info
```

**API:**
```elixir
Caddy.Telemetry.log_debug("message", metadata)
Caddy.Telemetry.log_info("message", metadata)
Caddy.Telemetry.log_warning("message", metadata)
Caddy.Telemetry.log_error("message", metadata)
```

#### 4.5.3 System Metrics

**Description:** Periodic system metrics via telemetry poller.

**Requirements:**
- [ ] Memory usage statistics
- [ ] Process count
- [ ] Application uptime
- [ ] Configurable polling interval (default: 30s)

**API:**
```elixir
Caddy.Telemetry.start_poller()         # Start with defaults
Caddy.Telemetry.start_poller(60_000)   # Custom interval
```

---

### 4.6 Supervision & Lifecycle

#### 4.6.1 Supervision Tree

**Description:** OTP-compliant supervision structure.

**Architecture:**
```
Caddy.Supervisor (rest_for_one)
├── Caddy.ConfigProvider (Agent)
├── Caddy.ConfigManager (GenServer)
├── Caddy.Logger (Supervisor)
│   ├── Caddy.Logger.Buffer (GenServer)
│   └── Caddy.Logger.Store (GenServer)
└── Caddy.Server (Mode-based)
    ├── Caddy.Server.Embedded (GenServer)
    └── Caddy.Server.External (GenServer)
```

**Strategy:** `rest_for_one` - If ConfigProvider crashes, all downstream processes restart.

#### 4.6.2 Startup Behavior

**Requirements:**
- [ ] Configurable auto-start (`config :caddy, start: true`)
- [ ] Binary auto-discovery with OS-specific defaults
- [ ] Bootstrap validation before server start
- [ ] Graceful degradation on validation failure

**Auto-Discovery Paths:**
- Linux: `/usr/bin/caddy`, `/usr/local/bin/caddy`
- macOS: `/opt/homebrew/bin/caddy`, `/usr/local/bin/caddy`
- Fallback: `System.find_executable("caddy")`

#### 4.6.3 Shutdown Behavior

**Requirements:**
- [ ] Trap exit signals for graceful cleanup
- [ ] Kill Caddy process on termination
- [ ] Remove PID file
- [ ] Flush log buffers
- [ ] Emit termination telemetry events

---

### 4.7 Metrics & Monitoring

**Description:** Pull metrics from Caddy's Prometheus endpoint for observability.

#### 4.7.1 Caddy Metrics Endpoint

Caddy exposes Prometheus metrics at `/metrics` on the admin API when enabled:

```caddyfile
{
  servers {
    metrics
  }
}
```

#### 4.7.2 Metrics Module

**Requirements:**
- [ ] Fetch raw Prometheus metrics from Caddy admin API
- [ ] Parse Prometheus text format into Elixir data structures
- [ ] Provide typed access to common Caddy metrics
- [ ] Support periodic polling with configurable interval
- [ ] Emit telemetry events with metric values
- [ ] Optional: Push metrics to telemetry for integration with existing dashboards

**Configuration:**
```elixir
config :caddy,
  metrics_enabled: true,               # Enable metrics collection (default: false)
  metrics_interval: 15_000,            # Poll interval ms (default: 15000)
  metrics_endpoint: "/metrics"         # Metrics path (default: "/metrics")
```

**API:**
```elixir
# One-time fetch
Caddy.Metrics.fetch()                  # {:ok, %Metrics{}} | {:error, reason}
Caddy.Metrics.fetch_raw()              # {:ok, prometheus_text} | {:error, reason}

# Parsed metrics access
Caddy.Metrics.get(:http_requests_total)
Caddy.Metrics.get(:http_request_duration_seconds)
Caddy.Metrics.get(:http_response_size_bytes)

# Poller management
Caddy.Metrics.start_poller()           # Start periodic collection
Caddy.Metrics.stop_poller()            # Stop periodic collection
Caddy.Metrics.poller_running?()        # Check if poller is active
```

#### 4.7.3 Metrics Data Structure

```elixir
%Caddy.Metrics{
  timestamp: DateTime.t(),

  # HTTP metrics
  http_requests_total: %{
    {server: "srv0", handler: "reverse_proxy", method: "GET", code: "200"} => 12345
  },
  http_request_duration_seconds: %{
    {server: "srv0", quantile: "0.5"} => 0.023,
    {server: "srv0", quantile: "0.9"} => 0.089,
    {server: "srv0", quantile: "0.99"} => 0.234
  },
  http_request_size_bytes: %{...},
  http_response_size_bytes: %{...},

  # TLS metrics
  tls_handshake_duration_seconds: %{...},
  tls_handshakes_total: %{...},

  # Process metrics
  process_cpu_seconds_total: float(),
  process_resident_memory_bytes: integer(),
  process_open_fds: integer(),

  # Reverse proxy metrics
  reverse_proxy_upstreams_healthy: %{
    {upstream: "localhost:4000"} => 1
  },

  # Raw data for custom parsing
  raw: binary()
}
```

#### 4.7.4 Key Caddy Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `caddy_http_requests_total` | Counter | Total HTTP requests by server, handler, method, code |
| `caddy_http_request_duration_seconds` | Histogram | Request latency distribution |
| `caddy_http_request_size_bytes` | Histogram | Request body sizes |
| `caddy_http_response_size_bytes` | Histogram | Response body sizes |
| `caddy_reverse_proxy_upstreams_healthy` | Gauge | Upstream health status (1=healthy, 0=unhealthy) |
| `caddy_tls_handshake_duration_seconds` | Histogram | TLS handshake latency |
| `caddy_admin_http_requests_total` | Counter | Admin API requests |
| `process_resident_memory_bytes` | Gauge | Caddy process memory usage |
| `process_cpu_seconds_total` | Counter | Caddy CPU time |

#### 4.7.5 Telemetry Integration

When the metrics poller is running, emit telemetry events:

```elixir
# Event: [:caddy, :metrics, :collected]
# Measurements: all numeric metrics
# Metadata: %{timestamp: DateTime.t()}

:telemetry.attach("my-metrics-handler",
  [:caddy, :metrics, :collected],
  fn _event, measurements, _metadata, _config ->
    # measurements contains all parsed metrics
    MyApp.Metrics.record(:caddy_requests, measurements.http_requests_total)
  end,
  nil
)
```

#### 4.7.6 Health Derivation

Derive health status from metrics:

```elixir
Caddy.Metrics.healthy?()               # Based on upstream health metrics
Caddy.Metrics.error_rate()             # Calculate 5xx rate from request metrics
Caddy.Metrics.latency_p99()            # Get p99 latency across all servers
```

---

### 4.8 Application State Machine

**Description:** Track the operational state of the Elixir Caddy library.

The library maintains an internal state that reflects its readiness to manage Caddy.

#### State Diagram

```
                              ┌─────────────────┐
                              │                 │
        ┌────────────────────►│  :initializing  │
        │                     │                 │
        │                     └────────┬────────┘
        │                              │
        │                              ▼
        │                     ┌─────────────────┐
        │    set_caddyfile()  │                 │  No config set
        │  ◄──────────────────│ :unconfigured   │◄─────────────────┐
        │                     │                 │                  │
        │                     └────────┬────────┘                  │
        │                              │                           │
        │                              │ set_caddyfile()           │
        │                              ▼                           │
        │                     ┌─────────────────┐                  │
        │                     │                 │  clear_config()  │
        │                     │  :configured    │──────────────────┘
        │                     │                 │
        │                     └────────┬────────┘
        │                              │
        │                              │ sync_to_caddy() success
        │                              ▼
        │                     ┌─────────────────┐
        │                     │                 │
  error │                     │    :synced      │◄────┐
        │                     │                 │     │
        │                     └────────┬────────┘     │
        │                              │              │
        │         health check fail    │              │ health check ok
        │                              ▼              │
        │                     ┌─────────────────┐     │
        │                     │                 │─────┘
        └─────────────────────│   :degraded     │
                              │                 │
                              └─────────────────┘
```

#### States

| State | Description | Allowed Operations |
|-------|-------------|-------------------|
| `:initializing` | Library starting up | None (transient) |
| `:unconfigured` | No Caddyfile set, waiting for configuration | `set_caddyfile()`, `get_state()` |
| `:configured` | Caddyfile set, not yet synced to Caddy | `sync_to_caddy()`, `set_caddyfile()`, `clear_config()` |
| `:synced` | Configuration pushed to Caddy successfully | All operations |
| `:degraded` | Was synced, but Caddy not responding | `sync_to_caddy()`, health checks continue |

#### API

```elixir
Caddy.get_state()                      # Get current state atom
Caddy.ready?()                         # True if :synced
Caddy.configured?()                    # True if :configured or :synced
Caddy.clear_config()                   # Reset to :unconfigured
```

#### State Transitions

| From | Event | To |
|------|-------|-----|
| `:initializing` | startup complete | `:unconfigured` |
| `:initializing` | startup complete (has saved config) | `:configured` |
| `:unconfigured` | `set_caddyfile(text)` | `:configured` |
| `:configured` | `sync_to_caddy()` success | `:synced` |
| `:configured` | `sync_to_caddy()` failure | `:configured` (with error) |
| `:configured` | `clear_config()` | `:unconfigured` |
| `:synced` | health check failure | `:degraded` |
| `:synced` | `set_caddyfile(text)` | `:configured` |
| `:degraded` | health check success | `:synced` |
| `:degraded` | `sync_to_caddy()` success | `:synced` |

#### Behavior by Mode

| Mode | Empty Config Behavior | Startup Behavior |
|------|----------------------|------------------|
| **External** (default) | Valid - stays in `:unconfigured` state | Starts immediately, waits for config |
| **Embedded** | Invalid - cannot start Caddy without config | Waits in `:unconfigured` until config set |

---

## 4.8 Architectural Limitations

### One-Way Configuration Flow

```
┌─────────────┐    adapt     ┌──────────┐    load     ┌─────────────┐
│  Caddyfile  │ ───────────► │   JSON   │ ──────────► │    Caddy    │
│   (text)    │              │          │             │  (runtime)  │
└─────────────┘              └──────────┘             └─────────────┘
       ▲                                                     │
       │                      ✗ NO REVERSE                   │
       │                      CONVERSION                     │
       └─────────────────────────────────────────────────────┘
                         (cannot recreate Caddyfile from JSON)
```

**Implications:**

| Operation | Supported | Notes |
|-----------|-----------|-------|
| Push Caddyfile → Caddy | ✓ Yes | Via `sync_to_caddy()` |
| Read runtime JSON | ✓ Yes | Via `get_runtime_config()` |
| Detect drift | ✓ Yes | Compares adapted JSON vs runtime |
| Pull Caddy → Caddyfile | ✗ No | JSON cannot be converted back to Caddyfile |
| Rollback | Partial | Restores last JSON, not original Caddyfile |

**Design Decision:** The library prioritizes Caddyfile as the source of truth. Users should:
1. Store Caddyfile in version control or database
2. Push changes via `sync_to_caddy()`
3. Never rely on pulling configuration from runtime Caddy

### Other Limitations

| Limitation | Reason | Workaround |
|------------|--------|------------|
| No multi-instance | Single supervision tree design | Run multiple applications |
| No hot-reload | Explicit sync required | Call `sync_to_caddy()` after changes |
| No config encryption | Caddyfile stored as plaintext | Use external secrets management |
| No clustering | Local process only | Use external config store + sync |

---

## 5. Technical Specifications

### 5.1 System Requirements

| Requirement | Specification |
|-------------|---------------|
| **Elixir** | ~> 1.18 |
| **OTP** | 27+ |
| **Caddy** | 2.x (validated via `caddy version`) |
| **OS** | Linux, macOS (Windows untested) |

### 5.2 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `jason` | ~> 1.4 | JSON encoding/decoding |
| `telemetry` | ~> 1.0 | Event emission |
| `telemetry_poller` | ~> 1.0 | Periodic metrics |

### 5.3 Configuration Schema

```elixir
config :caddy,
  # Core
  start: boolean(),                    # Auto-start server (default: true)
  dump_log: boolean(),                 # Log to stdout (default: false)
  mode: :embedded | :external,         # Operating mode (default: :external)

  # Paths (all have sensible defaults)
  base_path: String.t(),
  etc_path: String.t(),
  run_path: String.t(),
  tmp_path: String.t(),
  socket_file: String.t(),
  pid_file: String.t(),

  # External mode (default)
  admin_url: String.t(),               # "http://host:port" or "unix:///path"
  health_interval: pos_integer(),      # Health check interval ms (default: 30000)
  commands: keyword(String.t()),       # Lifecycle commands (optional)

  # Embedded mode
  caddy_bin: String.t(),               # Binary path (auto-discovered)

  # Logging
  attach_default_handler: boolean(),   # Forward to Logger (default: true)
  log_level: Logger.level(),           # Minimum level (default: :debug)

  # Testing
  request_module: module()             # HTTP client module (for mocking)
```

### 5.4 Data Structures

#### Config Struct
```elixir
%Caddy.Config{
  bin: String.t() | nil,               # Binary path
  caddyfile: String.t(),               # Caddyfile content
  env: [{String.t(), String.t()}]      # Environment variables
}
```

#### Request Struct
```elixir
%Caddy.Admin.Request{
  status: integer(),                   # HTTP status code
  headers: keyword(),                  # Response headers
  body: String.t()                     # Response body
}
```

#### Transport Connection Info
```elixir
%{type: :unix, path: String.t()}
%{type: :tcp, host: charlist(), port: pos_integer()}
```

---

## 6. API Reference Summary

### Main Module (`Caddy`)

| Function | Purpose |
|----------|---------|
| `start_link/1` | Start supervision tree |
| `start/0`, `start/1` | Start with auto-discovery or specific binary |
| `restart_server/0` | Restart server process |
| `stop/1` | Stop supervision tree |
| `set_bin/1`, `set_bin!/1` | Set binary path (with/without restart) |
| `set_caddyfile/1` | Set Caddyfile content |
| `get_caddyfile/0` | Get current Caddyfile |
| `append_caddyfile/1` | Append to Caddyfile |
| `adapt/1` | Validate and convert Caddyfile |
| `save_config/0` | Persist configuration |
| `backup_config/0` | Create backup |
| `restore_config/0` | Restore from backup |
| `sync_to_caddy/0`, `sync_to_caddy/1` | Push config to runtime |
| `check_sync_status/0` | Detect configuration drift |
| `rollback/0` | Restore last known-good config |
| `get_runtime_config/0`, `get_runtime_config/1` | Get running config |
| `apply_runtime_config/1`, `apply_runtime_config/2` | Apply JSON directly |
| `validate_caddyfile/1` | Validate without applying |
| `get_state/0` | Get current application state |
| `ready?/0` | Check if synced and operational |
| `configured?/0` | Check if Caddyfile is set |
| `clear_config/0` | Reset to unconfigured state |

### Metrics Module (`Caddy.Metrics`)

| Function | Purpose |
|----------|---------|
| `fetch/0` | Fetch and parse metrics from Caddy |
| `fetch_raw/0` | Fetch raw Prometheus text |
| `get/1` | Get specific metric value |
| `start_poller/0` | Start periodic metrics collection |
| `stop_poller/0` | Stop metrics poller |
| `poller_running?/0` | Check if poller is active |
| `healthy?/0` | Derive health from metrics |
| `error_rate/0` | Calculate current error rate |
| `latency_p99/0` | Get p99 latency |

---

## 7. Usage Examples

### Default Setup (External Mode)

```elixir
# In application.ex - starts in :unconfigured state
def start(_type, _args) do
  children = [
    # ... other children
    {Caddy, []}  # Starts immediately, waits for configuration
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end

# Later, when ready to configure (can be from any process)
Caddy.set_caddyfile("""
localhost:443 {
  reverse_proxy localhost:4000
}
""")

# Check state before syncing
case Caddy.get_state() do
  :configured ->
    case Caddy.sync_to_caddy() do
      :ok -> Logger.info("Caddy configured and synced")
      {:error, reason} -> Logger.error("Sync failed: #{inspect(reason)}")
    end
  state ->
    Logger.info("Current state: #{state}")
end
```

### External Mode with systemd

```elixir
# In config/runtime.exs
config :caddy,
  admin_url: "http://localhost:2019",
  health_interval: 60_000,
  commands: [
    start: "sudo systemctl start caddy",
    stop: "sudo systemctl stop caddy",
    restart: "sudo systemctl restart caddy",
    status: "systemctl is-active caddy"
  ]

# In application code - check both library state and Caddy status
if Caddy.configured?() do
  case Caddy.Server.check_status() do
    :running -> Caddy.sync_to_caddy()
    :stopped -> Caddy.Server.execute_command(:start)
    :unknown -> Logger.warning("Caddy status unknown")
  end
else
  Logger.info("Waiting for Caddyfile configuration...")
end
```

### Embedded Mode Setup

```elixir
# In config/runtime.exs - explicitly enable embedded mode
config :caddy,
  mode: :embedded,
  caddy_bin: "/usr/bin/caddy"

# In application.ex
def start(_type, _args) do
  children = [
    # ... other children
    {Caddy, []}  # Starts in :unconfigured, waits for config before spawning
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end

# Must set config before Caddy binary will start
Caddy.set_caddyfile("""
{
  admin unix//tmp/caddy.sock
}

localhost:443 {
  reverse_proxy localhost:4000
}
""")

# In embedded mode, sync_to_caddy also starts the binary if needed
Caddy.sync_to_caddy()
```

### Dynamic Route Configuration

```elixir
defmodule MyApp.ProxyManager do
  def add_service(name, port) do
    current = Caddy.get_caddyfile()

    new_block = """

    #{name}.example.com {
      reverse_proxy localhost:#{port}
    }
    """

    Caddy.set_caddyfile(current <> new_block)
    Caddy.sync_to_caddy(backup: true)
  end

  def remove_service(name) do
    current = Caddy.get_caddyfile()
    # Parse and remove block for name
    updated = remove_block(current, "#{name}.example.com")
    Caddy.set_caddyfile(updated)
    Caddy.sync_to_caddy(backup: true)
  end
end
```

### Telemetry Monitoring

```elixir
defmodule MyApp.CaddyMonitor do
  def attach do
    events = [
      [:caddy, :server, :start],
      [:caddy, :server, :exit],
      [:caddy, :api, :error],
      [:caddy, :config_manager, :drift_check],
      [:caddy, :external, :status_changed]
    ]

    :telemetry.attach_many(
      "caddy-monitor",
      events,
      &handle_event/4,
      %{}
    )
  end

  def handle_event([:caddy, :server, :exit], _measurements, metadata, _config) do
    Logger.error("Caddy exited unexpectedly", metadata)
    # Alert, restart, or take corrective action
  end

  def handle_event([:caddy, :config_manager, :drift_check], _m, %{status: {:drift_detected, _}}, _c) do
    Logger.warning("Configuration drift detected")
    # Auto-sync or alert
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
```

---

## 8. Testing Strategy

### Test Configuration

```elixir
# config/test.exs
config :caddy,
  start: false,
  request_module: Caddy.Admin.RequestMock
```

### Mocking HTTP Requests

```elixir
defmodule MyApp.CaddyTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  test "sync_to_caddy pushes configuration" do
    Caddy.Admin.RequestMock
    |> expect(:post, fn "/load", _data, _ct ->
      {:ok, %Caddy.Admin.Request{status: 200}, %{}}
    end)

    Caddy.set_caddyfile("localhost { respond 200 }")
    assert :ok = Caddy.sync_to_caddy()
  end
end
```

---

## 9. Future Roadmap

### Phase 1: Stability (v2.2.0) ✅
- [x] Core embedded mode
- [x] External mode support
- [x] Configuration synchronization (push-only)
- [x] Comprehensive telemetry

### Phase 1.5: State Management (v2.3.0) ✅
- [x] Default to external mode
- [x] Application state machine (unconfigured → configured → synced → degraded)
- [x] Empty config support (waiting state)
- [x] Deprecate `sync_from_caddy()` (removal in v3.0.0)
- [x] State query API (`get_state/0`, `ready?/0`, `configured?/0`)

### Phase 1.6: Metrics & Monitoring (v2.3.0) ✅
- [x] Prometheus metrics endpoint integration (`Caddy.Metrics`)
- [x] Prometheus text format parser
- [x] Periodic metrics polling with configurable interval
- [x] Telemetry events for collected metrics
- [x] Health derivation from upstream metrics
- [x] Error rate and latency calculations

### Phase 2: Enhanced Configuration
- [ ] Configuration templates for common patterns
- [ ] Configuration diff and merge utilities
- [ ] Version history with timestamp tracking
- [ ] Configuration encryption at rest

### Phase 3: Advanced Operations
- [ ] Multi-instance Caddy management
- [ ] Cluster-aware configuration sync
- [ ] Automatic drift remediation
- [ ] Rolling configuration updates

### Phase 4: Developer Experience
- [ ] Mix tasks for common operations
- [ ] Configuration validation DSL
- [ ] Integration test helpers

---

## 10. Example Application: Phoenix LiveView Dashboard

### 10.1 Overview

A standalone Phoenix LiveView application that demonstrates how to use the `caddy` library for interactive Caddy server management. This lives in the `examples/caddy_dashboard/` directory of the repository, **not** inside the published hex package.

**Purpose:**
- Show real-world integration patterns for the `caddy` library
- Provide a copy-and-adapt reference for teams building their own management UI
- Demonstrate all major library features through an interactive interface

**Tech Stack:**
- Phoenix 1.7+ with LiveView
- Tailwind CSS for styling
- Depends on the `caddy` library via path dependency

### 10.2 Features

#### 10.2.1 Dashboard Home

**Description:** At-a-glance view of Caddy status and library state.

**Requirements:**
- [ ] Display current application state (`:unconfigured`, `:configured`, `:synced`, `:degraded`)
- [ ] Show operating mode (embedded vs external)
- [ ] Display Caddy server status (running/stopped/unknown)
- [ ] Show sync status (in-sync, drift detected, never synced)
- [ ] Real-time state updates via LiveView push (subscribe to telemetry events)

#### 10.2.2 Configuration Editor

**Description:** Edit and manage Caddyfile configuration through a web UI.

**Requirements:**
- [ ] Text editor for Caddyfile content with syntax highlighting (CodeMirror or Monaco)
- [ ] Load current Caddyfile from library (`Caddy.get_caddyfile()`)
- [ ] Save Caddyfile to library (`Caddy.set_caddyfile/1`)
- [ ] Validate button that calls `Caddy.validate_caddyfile/1` and displays results
- [ ] Adapt button that shows the JSON output of `Caddy.adapt/1`
- [ ] Sync to Caddy button with confirmation and backup option
- [ ] Diff view comparing in-memory config vs runtime config (`Caddy.check_sync_status/0`)
- [ ] Configuration history / backup management (`Caddy.backup_config/0`, `Caddy.restore_config/0`)

#### 10.2.3 Metrics Dashboard

**Description:** Visualize Caddy metrics collected via the Prometheus endpoint.

**Requirements:**
- [ ] Display health status (`Caddy.Metrics.healthy?/1`)
- [ ] Show error rate (`Caddy.Metrics.error_rate/1`)
- [ ] Show p50 and p99 latency (`Caddy.Metrics.latency_p50/1`, `Caddy.Metrics.latency_p99/1`)
- [ ] Total request count (`Caddy.Metrics.total_requests/1`)
- [ ] Upstream health status table from `reverse_proxy_upstreams_healthy`
- [ ] Process metrics (CPU, memory, open FDs)
- [ ] Auto-refresh via periodic `Caddy.Metrics.fetch/0` or poller subscription
- [ ] Raw Prometheus text view toggle (`Caddy.Metrics.fetch_raw/0`)

#### 10.2.4 Runtime Configuration Browser

**Description:** Browse the live JSON configuration tree from the running Caddy instance.

**Requirements:**
- [ ] Tree view of runtime JSON config (`Caddy.get_runtime_config/0`)
- [ ] Navigate sub-paths (`Caddy.get_runtime_config/1` e.g., `"apps/http/servers"`)
- [ ] Apply JSON patches directly (`Caddy.apply_runtime_config/2`)
- [ ] Rollback button (`Caddy.rollback/0`)

#### 10.2.5 Server Control Panel

**Description:** Lifecycle operations for the Caddy server process.

**Requirements:**
- [ ] Start/stop/restart buttons
- [ ] External mode: execute lifecycle commands (`Caddy.Server.execute_command/1`)
- [ ] Embedded mode: show binary path, PID, process output
- [ ] Health check trigger (`Caddy.Server.External.health_check/0`)

#### 10.2.6 Log Viewer

**Description:** View captured Caddy process logs.

**Requirements:**
- [ ] Tail log output from `Caddy.Logger.tail/1`
- [ ] Auto-scroll with new entries
- [ ] Filter by log level
- [ ] Search within logs

#### 10.2.7 Telemetry Event Stream

**Description:** Live stream of telemetry events for debugging and understanding library behavior.

**Requirements:**
- [ ] Subscribe to all `[:caddy, ...]` telemetry events
- [ ] Display events in a scrollable feed with timestamps
- [ ] Filter by event category (config, server, api, metrics, etc.)
- [ ] Show event measurements and metadata

### 10.3 Project Structure

```
examples/caddy_dashboard/
├── mix.exs                          # Phoenix app, depends on {:caddy, path: "../.."}
├── config/
│   ├── config.exs
│   ├── dev.exs
│   └── runtime.exs                  # Caddy library configuration
├── lib/
│   ├── caddy_dashboard/
│   │   └── application.ex           # Starts Phoenix + Caddy supervision trees
│   └── caddy_dashboard_web/
│       ├── router.ex
│       ├── components/
│       │   ├── layouts.ex
│       │   └── core_components.ex
│       └── live/
│           ├── dashboard_live.ex     # Home dashboard
│           ├── config_live.ex        # Configuration editor
│           ├── metrics_live.ex       # Metrics dashboard
│           ├── runtime_live.ex       # Runtime config browser
│           ├── server_live.ex        # Server control panel
│           ├── logs_live.ex          # Log viewer
│           └── telemetry_live.ex     # Telemetry event stream
├── assets/
│   ├── css/
│   └── js/
│       └── hooks/                    # LiveView hooks for editor, auto-scroll
├── priv/
│   └── static/
└── README.md                        # Setup instructions and screenshots
```

### 10.4 Key Implementation Patterns

#### Telemetry-Driven LiveView Updates

The example app demonstrates subscribing to library telemetry events and pushing updates to the browser in real-time:

```elixir
defmodule CaddyDashboardWeb.DashboardLive do
  use CaddyDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to state change events
      :telemetry.attach(
        "dashboard-#{socket.id}",
        [:caddy, :config_manager, :state_changed],
        &__MODULE__.handle_telemetry/4,
        %{pid: self()}
      )
    end

    state = Caddy.get_state()
    {:ok, assign(socket, state: state, synced: Caddy.ready?())}
  end

  def handle_telemetry(_event, _measurements, metadata, %{pid: pid}) do
    send(pid, {:state_changed, metadata.new_state})
  end

  @impl true
  def handle_info({:state_changed, new_state}, socket) do
    {:noreply, assign(socket, state: new_state, synced: new_state == :synced)}
  end
end
```

#### Configuration Editor with Validation Feedback

```elixir
defmodule CaddyDashboardWeb.ConfigLive do
  use CaddyDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    caddyfile = Caddy.get_caddyfile()
    {:ok, assign(socket, caddyfile: caddyfile, validation: nil, sync_status: nil)}
  end

  @impl true
  def handle_event("validate", %{"caddyfile" => text}, socket) do
    result = Caddy.validate_caddyfile(text)
    {:noreply, assign(socket, validation: result)}
  end

  def handle_event("save", %{"caddyfile" => text}, socket) do
    :ok = Caddy.set_caddyfile(text)
    {:noreply, assign(socket, caddyfile: text, validation: nil)}
  end

  def handle_event("sync", _params, socket) do
    result = Caddy.sync_to_caddy(backup: true)
    {:noreply, assign(socket, sync_status: result)}
  end
end
```

### 10.5 Non-Goals for the Example App

The example app is **not**:

- A production-ready admin panel (no authentication, no RBAC)
- A hex package (not published, path dependency only)
- Part of the `caddy` library test suite
- A required component to use the `caddy` library

It exists purely as a reference implementation and learning tool.

---

## 11. Appendix

### A. Caddyfile Global Options Reference (for library users)

```caddyfile
{
  # Admin API
  admin unix//path/to/socket
  admin off
  admin localhost:2019

  # Logging
  debug
  log {
    output file /var/log/caddy/access.log
    format json
  }

  # TLS
  auto_https off
  auto_https disable_redirects
  email admin@example.com

  # Performance
  grace_period 10s
  shutdown_delay 5s
}
```

### B. Common Configuration Patterns

**Reverse Proxy with Load Balancing:**
```caddyfile
api.example.com {
  reverse_proxy {
    to backend1:8080 backend2:8080
    lb_policy round_robin
    health_uri /health
    health_interval 10s
  }
}
```

**Static Files with SPA Fallback:**
```caddyfile
app.example.com {
  root * /var/www/app
  try_files {path} /index.html
  file_server
}
```

**API Gateway:**
```caddyfile
gateway.example.com {
  route /users/* {
    reverse_proxy users-service:4000
  }
  route /orders/* {
    reverse_proxy orders-service:4001
  }
  route /* {
    respond 404
  }
}
```

### C. Telemetry Event Measurements

| Event | Measurements |
|-------|--------------|
| API operations | `duration` (nanoseconds), `status` (HTTP code) |
| Server operations | `duration` (nanoseconds) |
| File operations | `size` (bytes), `duration` |
| Log operations | `size` (bytes), `count` (lines) |
| Health checks | `duration` (nanoseconds) |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.3.0 | 2026-02-03 | - | Added scope boundary (no UI in core), Phoenix LiveView example app spec, marked Phase 1.5/1.6 complete |
| 2.2.0 | 2026-01-27 | Generated | Added external mode, transport layer |
| 2.1.0 | 2026-01-xx | - | Initial text-first design |
| 2.0.0 | 2025-xx-xx | - | Major refactor from structured config |
