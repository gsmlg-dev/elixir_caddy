# Data Model: Expand Caddy.Config.Global

**Feature**: 001-expand-global-config
**Date**: 2025-12-22

## Entity Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Caddy.Config.Global                              │
│  (Main struct - represents Caddyfile global options block)          │
├─────────────────────────────────────────────────────────────────────┤
│ General Options (12 fields)                                          │
│ TLS/Certificate Options (17 fields)                                  │
│ Nested: servers → [Caddy.Config.Global.Server]                       │
│ Nested: log → [Caddy.Config.Global.Log]                              │
│ Nested: pki → Caddy.Config.Global.PKI                                │
│ Extensibility: extra_options → [String.t()]                          │
└─────────────────────────────────────────────────────────────────────┘
         │
         ├──────────────────────────────────────────┐
         │                                          │
         ▼                                          ▼
┌─────────────────────────┐              ┌─────────────────────────┐
│ Caddy.Config.Global.    │              │ Caddy.Config.Global.    │
│ Server                  │              │ Log                     │
├─────────────────────────┤              ├─────────────────────────┤
│ listener_address: key   │              │ name: key               │
│ name: String.t()        │              │ output: String.t()      │
│ protocols: [atom()]     │              │ format: atom()          │
│ timeouts: Timeouts.t()  │              │ level: atom()           │
│ trusted_proxies: tuple()│              │ include: [String.t()]   │
│ client_ip_headers: list │              │ exclude: [String.t()]   │
│ max_header_size: String │              └─────────────────────────┘
│ keepalive_interval: Str │
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐              ┌─────────────────────────┐
│ Caddy.Config.Global.    │              │ Caddy.Config.Global.    │
│ Timeouts                │              │ PKI                     │
├─────────────────────────┤              ├─────────────────────────┤
│ read_body: String.t()   │              │ ca_id: String.t()       │
│ read_header: String.t() │              │ name: String.t()        │
│ write: String.t()       │              │ root_cn: String.t()     │
│ idle: String.t()        │              │ intermediate_cn: String │
└─────────────────────────┘              │ intermediate_lifetime:  │
                                         └─────────────────────────┘
```

## Caddy.Config.Global (Main Struct)

### Fields

#### Existing Fields (Backward Compatible)

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `admin` | `String.t() \| :off \| nil` | `nil` | `admin <value>` or `admin off` |
| `debug` | `boolean()` | `false` | `debug` (when true) |
| `email` | `String.t() \| nil` | `nil` | `email <value>` |
| `acme_ca` | `String.t() \| nil` | `nil` | `acme_ca <url>` |
| `storage` | `String.t() \| nil` | `nil` | `storage <config>` |
| `extra_options` | `[String.t()]` | `[]` | Raw lines appended |

#### New General Options

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `http_port` | `integer() \| nil` | `nil` | `http_port <port>` |
| `https_port` | `integer() \| nil` | `nil` | `https_port <port>` |
| `default_bind` | `[String.t()] \| nil` | `nil` | `default_bind <hosts...>` |
| `order` | `[{atom(), atom(), atom()}] \| nil` | `nil` | `order <dir> before\|after <dir2>` |
| `storage_clean_interval` | `String.t() \| nil` | `nil` | `storage_clean_interval <duration>` |
| `persist_config` | `boolean() \| nil` | `nil` | `persist_config off` (when false) |
| `grace_period` | `String.t() \| nil` | `nil` | `grace_period <duration>` |
| `shutdown_delay` | `String.t() \| nil` | `nil` | `shutdown_delay <duration>` |

#### New TLS/Certificate Options

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `auto_https` | `atom() \| nil` | `nil` | `auto_https off\|disable_redirects\|...` |
| `default_sni` | `String.t() \| nil` | `nil` | `default_sni <name>` |
| `local_certs` | `boolean() \| nil` | `nil` | `local_certs` (when true) |
| `skip_install_trust` | `boolean() \| nil` | `nil` | `skip_install_trust` (when true) |
| `acme_ca_root` | `String.t() \| nil` | `nil` | `acme_ca_root <path>` |
| `acme_eab` | `map() \| nil` | `nil` | `acme_eab { key_id ... mac_key ... }` |
| `acme_dns` | `{atom(), String.t()} \| nil` | `nil` | `acme_dns <provider> <credentials>` |
| `on_demand_tls` | `map() \| nil` | `nil` | `on_demand_tls { ask <url> }` |
| `key_type` | `atom() \| nil` | `nil` | `key_type ed25519\|p256\|...` |
| `cert_issuer` | `[map()] \| nil` | `nil` | `cert_issuer <name> { ... }` |
| `renew_interval` | `String.t() \| nil` | `nil` | `renew_interval <duration>` |
| `cert_lifetime` | `String.t() \| nil` | `nil` | `cert_lifetime <duration>` |
| `ocsp_interval` | `String.t() \| nil` | `nil` | `ocsp_interval <duration>` |
| `ocsp_stapling` | `boolean() \| nil` | `nil` | `ocsp_stapling off` (when false) |
| `preferred_chains` | `atom() \| map() \| nil` | `nil` | `preferred_chains smallest\|{...}` |

#### New Nested Options

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `servers` | `%{String.t() => Server.t()} \| nil` | `nil` | `servers [<addr>] { ... }` |
| `log` | `[Log.t()] \| nil` | `nil` | `log [<name>] { ... }` |
| `pki` | `PKI.t() \| nil` | `nil` | `pki { ca ... }` |

### Type Definition

```elixir
@type t :: %__MODULE__{
  # Existing fields
  admin: String.t() | :off | nil,
  debug: boolean(),
  email: String.t() | nil,
  acme_ca: String.t() | nil,
  storage: String.t() | nil,
  extra_options: [String.t()],

  # New general options
  http_port: integer() | nil,
  https_port: integer() | nil,
  default_bind: [String.t()] | nil,
  order: [{atom(), atom(), atom()}] | nil,
  storage_clean_interval: String.t() | nil,
  persist_config: boolean() | nil,
  grace_period: String.t() | nil,
  shutdown_delay: String.t() | nil,

  # New TLS/certificate options
  auto_https: atom() | nil,
  default_sni: String.t() | nil,
  local_certs: boolean() | nil,
  skip_install_trust: boolean() | nil,
  acme_ca_root: String.t() | nil,
  acme_eab: map() | nil,
  acme_dns: {atom(), String.t()} | nil,
  on_demand_tls: map() | nil,
  key_type: atom() | nil,
  cert_issuer: [map()] | nil,
  renew_interval: String.t() | nil,
  cert_lifetime: String.t() | nil,
  ocsp_interval: String.t() | nil,
  ocsp_stapling: boolean() | nil,
  preferred_chains: atom() | map() | nil,

  # New nested options
  servers: %{String.t() => Server.t()} | nil,
  log: [Log.t()] | nil,
  pki: PKI.t() | nil
}
```

---

## Caddy.Config.Global.Server (Nested Struct)

Represents a server configuration block within `servers { }`.

### Fields

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `name` | `String.t() \| nil` | `nil` | `name <name>` |
| `protocols` | `[atom()] \| nil` | `nil` | `protocols h1 h2 h3` |
| `timeouts` | `Timeouts.t() \| nil` | `nil` | `timeouts { ... }` |
| `trusted_proxies` | `{atom(), [String.t()]} \| nil` | `nil` | `trusted_proxies static ...` |
| `trusted_proxies_strict` | `boolean() \| nil` | `nil` | `trusted_proxies_strict` |
| `client_ip_headers` | `[String.t()] \| nil` | `nil` | `client_ip_headers X-Forwarded-For ...` |
| `max_header_size` | `String.t() \| nil` | `nil` | `max_header_size 5MB` |
| `keepalive_interval` | `String.t() \| nil` | `nil` | `keepalive_interval 30s` |
| `log_credentials` | `boolean() \| nil` | `nil` | `log_credentials` (when true) |
| `strict_sni_host` | `atom() \| nil` | `nil` | `strict_sni_host on\|insecure_off` |

### Type Definition

```elixir
@type t :: %__MODULE__{
  name: String.t() | nil,
  protocols: [atom()] | nil,
  timeouts: Timeouts.t() | nil,
  trusted_proxies: {atom(), [String.t()]} | nil,
  trusted_proxies_strict: boolean() | nil,
  client_ip_headers: [String.t()] | nil,
  max_header_size: String.t() | nil,
  keepalive_interval: String.t() | nil,
  log_credentials: boolean() | nil,
  strict_sni_host: atom() | nil
}
```

---

## Caddy.Config.Global.Timeouts (Nested Struct)

Represents timeout configuration within a server block.

### Fields

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `read_body` | `String.t() \| nil` | `nil` | `read_body 10s` |
| `read_header` | `String.t() \| nil` | `nil` | `read_header 5s` |
| `write` | `String.t() \| nil` | `nil` | `write 30s` |
| `idle` | `String.t() \| nil` | `nil` | `idle 2m` |

### Type Definition

```elixir
@type t :: %__MODULE__{
  read_body: String.t() | nil,
  read_header: String.t() | nil,
  write: String.t() | nil,
  idle: String.t() | nil
}
```

---

## Caddy.Config.Global.Log (Nested Struct)

Represents a named logger configuration.

### Fields

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `name` | `String.t() \| nil` | `nil` | `log <name> { ... }` (nil = default) |
| `output` | `String.t() \| map() \| nil` | `nil` | `output stdout\|file {...}` |
| `format` | `atom() \| map() \| nil` | `nil` | `format console\|json {...}` |
| `level` | `atom() \| nil` | `nil` | `level DEBUG\|INFO\|WARN\|ERROR` |
| `include` | `[String.t()] \| nil` | `nil` | `include http.* admin.*` |
| `exclude` | `[String.t()] \| nil` | `nil` | `exclude http.log.access` |

### Type Definition

```elixir
@type t :: %__MODULE__{
  name: String.t() | nil,
  output: String.t() | map() | nil,
  format: atom() | map() | nil,
  level: atom() | nil,
  include: [String.t()] | nil,
  exclude: [String.t()] | nil
}
```

---

## Caddy.Config.Global.PKI (Nested Struct)

Represents PKI (certificate authority) configuration.

### Fields

| Field | Type | Default | Caddyfile Syntax |
|-------|------|---------|------------------|
| `ca_id` | `String.t()` | `"local"` | `ca <id> { ... }` |
| `name` | `String.t() \| nil` | `nil` | `name "My CA"` |
| `root_cn` | `String.t() \| nil` | `nil` | `root_cn "Root CA"` |
| `intermediate_cn` | `String.t() \| nil` | `nil` | `intermediate_cn "Intermediate"` |
| `intermediate_lifetime` | `String.t() \| nil` | `nil` | `intermediate_lifetime 7d` |

### Type Definition

```elixir
@type t :: %__MODULE__{
  ca_id: String.t(),
  name: String.t() | nil,
  root_cn: String.t() | nil,
  intermediate_cn: String.t() | nil,
  intermediate_lifetime: String.t() | nil
}
```

---

## Rendering Order

When converting `Caddy.Config.Global` to Caddyfile format:

1. Boolean flags (debug, local_certs, skip_install_trust)
2. Admin configuration
3. Port configuration (http_port, https_port)
4. Bind configuration (default_bind)
5. Storage configuration
6. TLS/ACME configuration
7. Logging configuration (log blocks)
8. Server configuration (servers blocks)
9. PKI configuration (pki block)
10. `extra_options` (raw lines, last for plugin options)

---

## Validation Rules

| Rule | Scope | Enforcement |
|------|-------|-------------|
| Port must be 1-65535 | `http_port`, `https_port` | Caddy runtime |
| Duration format valid | All duration fields | Caddy runtime |
| Size format valid | `max_header_size` | Caddy runtime |
| Key type must be valid enum | `key_type` | Elixir pattern match |
| Auto HTTPS must be valid enum | `auto_https` | Elixir pattern match |
| Protocol must be valid enum | `protocols` | Elixir pattern match |

Note: Per spec assumptions, validation beyond Elixir type checking is delegated to Caddy runtime.
