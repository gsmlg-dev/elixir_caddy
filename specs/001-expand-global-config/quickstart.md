# Quickstart: Expand Caddy.Config.Global

**Feature**: 001-expand-global-config
**Date**: 2025-12-22

## Basic Usage

### Creating a Global Config

```elixir
alias Caddy.Config.Global

# Minimal configuration (all defaults)
global = Global.new()

# Common configuration
global = Global.new(
  debug: true,
  http_port: 8080,
  https_port: 8443,
  email: "admin@example.com"
)

# Render to Caddyfile
Caddy.Caddyfile.to_caddyfile(global)
# Output:
# {
#   debug
#   http_port 8080
#   https_port 8443
#   email admin@example.com
# }
```

### Configuring TLS/ACME

```elixir
global = Global.new(
  email: "admin@example.com",
  acme_ca: "https://acme-staging-v02.api.letsencrypt.org/directory",
  key_type: :ed25519,
  auto_https: :disable_redirects
)

# With ACME DNS challenge
global = Global.new(
  email: "admin@example.com",
  acme_dns: {:cloudflare, "{env.CLOUDFLARE_API_TOKEN}"}
)

# With on-demand TLS
global = Global.new(
  on_demand_tls: %{ask: "http://localhost:9123/ask"}
)
```

### Configuring Server Options

```elixir
alias Caddy.Config.Global.{Server, Timeouts}

# Server with timeouts
server = %Server{
  name: "https",
  protocols: [:h1, :h2, :h3],
  timeouts: %Timeouts{
    read_body: "10s",
    read_header: "5s",
    write: "30s",
    idle: "2m"
  },
  trusted_proxies: {:static, ["private_ranges"]},
  client_ip_headers: ["X-Forwarded-For", "X-Real-IP"]
}

global = Global.new(
  servers: %{":443" => server}
)

# Render to Caddyfile
Caddy.Caddyfile.to_caddyfile(global)
# Output:
# {
#   servers :443 {
#     name https
#     protocols h1 h2 h3
#     timeouts {
#       read_body 10s
#       read_header 5s
#       write 30s
#       idle 2m
#     }
#     trusted_proxies static private_ranges
#     client_ip_headers X-Forwarded-For X-Real-IP
#   }
# }
```

### Configuring Logging

```elixir
alias Caddy.Config.Global.Log

# Default logger to file
log = %Log{
  output: "file /var/log/caddy/access.log",
  format: :json,
  level: :INFO
}

# Named logger with filtering
admin_log = %Log{
  name: "admin",
  output: "stdout",
  format: :console,
  include: ["admin.*"]
}

global = Global.new(
  log: [log, admin_log]
)
```

### Configuring PKI

```elixir
alias Caddy.Config.Global.PKI

pki = %PKI{
  ca_id: "local",
  name: "My Company Internal CA",
  root_cn: "My Company Root CA",
  intermediate_cn: "My Company Intermediate CA",
  intermediate_lifetime: "30d"
}

global = Global.new(
  local_certs: true,
  pki: pki
)
```

### Using Extra Options for Plugins

```elixir
# For plugin options not yet supported as typed fields
global = Global.new(
  debug: true,
  extra_options: [
    "layer4 {",
    "  # layer4 plugin configuration",
    "}"
  ]
)
```

## Backward Compatibility

Existing code continues to work unchanged:

```elixir
# This still works exactly as before
global = %Global{
  admin: "unix//var/run/caddy.sock",
  debug: true,
  email: "admin@example.com"
}
```

## Complete Example

```elixir
alias Caddy.Config.Global
alias Caddy.Config.Global.{Server, Timeouts, Log, PKI}

global = Global.new(
  # General
  debug: false,
  http_port: 80,
  https_port: 443,
  admin: "unix//var/run/caddy.sock",
  grace_period: "30s",
  shutdown_delay: "5s",

  # TLS
  email: "admin@example.com",
  acme_ca: "https://acme-v02.api.letsencrypt.org/directory",
  key_type: :ed25519,
  renew_interval: "30m",

  # Logging
  log: [
    %Log{
      output: "file /var/log/caddy/access.log",
      format: :json,
      level: :INFO
    }
  ],

  # Server
  servers: %{
    ":443" => %Server{
      protocols: [:h1, :h2, :h3],
      timeouts: %Timeouts{
        read_body: "10s",
        read_header: "5s",
        write: "30s",
        idle: "2m"
      },
      trusted_proxies: {:static, ["private_ranges"]}
    }
  }
)

# Render and use
caddyfile = Caddy.Caddyfile.to_caddyfile(global)
```

## Testing

```elixir
# In your tests
defmodule MyApp.CaddyConfigTest do
  use ExUnit.Case

  alias Caddy.Config.Global
  alias Caddy.Caddyfile

  test "renders http_port correctly" do
    global = Global.new(http_port: 8080)
    result = Caddyfile.to_caddyfile(global)
    assert result =~ "http_port 8080"
  end

  test "preserves backward compatibility" do
    global = %Global{debug: true, email: "test@example.com"}
    result = Caddyfile.to_caddyfile(global)
    assert result =~ "debug"
    assert result =~ "email test@example.com"
  end
end
```

## Common Patterns

### Development Configuration

```elixir
def dev_config do
  Global.new(
    debug: true,
    http_port: 8080,
    https_port: 8443,
    local_certs: true,
    auto_https: :disable_redirects
  )
end
```

### Production Configuration

```elixir
def prod_config do
  Global.new(
    email: System.get_env("ACME_EMAIL"),
    admin: "unix//var/run/caddy.sock",
    grace_period: "30s",
    shutdown_delay: "5s",
    servers: %{
      ":443" => %Server{
        protocols: [:h1, :h2, :h3],
        trusted_proxies: {:static, ["private_ranges"]}
      }
    }
  )
end
```
