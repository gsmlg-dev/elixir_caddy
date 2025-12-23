# Research: Expand Caddy.Config.Global

**Feature**: 001-expand-global-config
**Date**: 2025-12-22

## Overview

Research conducted to inform implementation of expanded `Caddy.Config.Global` struct.

## Caddy Global Options Research

### Decision: Field Organization by Category

**Rationale**: Group 35+ fields into logical categories matching Caddy documentation structure
for better discoverability and maintenance.

**Categories**:
1. General Options (12 fields): debug, http_port, https_port, default_bind, order, storage,
   storage_clean_interval, admin, persist_config, grace_period, shutdown_delay, log
2. TLS/Certificate Options (17 fields): auto_https, email, default_sni, local_certs,
   skip_install_trust, acme_ca, acme_ca_root, acme_eab, acme_dns, on_demand_tls, key_type,
   cert_issuer, renew_interval, cert_lifetime, ocsp_interval, ocsp_stapling, preferred_chains
3. Server Options (5 fields in nested struct): name, protocols, timeouts, trusted_proxies,
   client_ip_headers, max_header_size, keepalive_interval
4. PKI Options (in nested struct): ca configurations with name, root_cn, intermediate_cn,
   intermediate_lifetime

**Alternatives considered**:
- Flat struct with all fields: Rejected due to poor organization with 35+ fields
- Multiple separate modules: Rejected as it breaks the single Global config concept

### Decision: Nested Structs for Complex Options

**Rationale**: Options like `servers`, `log`, and `pki` have complex nested structures in
Caddyfile. Using nested Elixir structs provides:
- Type safety for nested configurations
- IDE autocompletion for sub-options
- Clear ownership of related fields

**Nested structs**:
- `Caddy.Config.Global.Server` - for `servers { }` block options
- `Caddy.Config.Global.Log` - for `log { }` block options
- `Caddy.Config.Global.PKI` - for `pki { }` block options
- `Caddy.Config.Global.Timeouts` - for server timeout sub-block

**Alternatives considered**:
- Maps for nested options: Rejected due to lack of type safety
- Keyword lists: Rejected due to poor discoverability

### Decision: Backward Compatible Field Defaults

**Rationale**: SC-003 requires existing code to work without modification. All new fields
default to `nil`, which means "use Caddy default" (no output in Caddyfile).

**Implementation**:
- Existing fields preserved: `admin`, `debug`, `email`, `acme_ca`, `storage`, `extra_options`
- New fields added with `nil` default
- `nil` fields produce no output in rendered Caddyfile
- Explicit values render to Caddyfile syntax

**Alternatives considered**:
- Default to Caddy's actual defaults: Rejected as it would change behavior for existing users
- Required fields: Rejected as most options are truly optional in Caddy

### Decision: Type Representations

**Rationale**: Use Elixir-idiomatic types that map cleanly to Caddyfile syntax.

| Caddy Type | Elixir Type | Example |
|------------|-------------|---------|
| Boolean flag | `boolean()` | `debug: true` → `debug` |
| Integer | `integer()` | `http_port: 8080` → `http_port 8080` |
| String | `String.t()` | `email: "a@b.com"` → `email a@b.com` |
| Duration | `String.t()` | `grace_period: "30s"` → `grace_period 30s` |
| Size | `String.t()` | `max_header_size: "5MB"` → `max_header_size 5MB` |
| Enum | `atom()` | `auto_https: :off` → `auto_https off` |
| List | `[String.t()]` | `default_bind: ["0.0.0.0"]` → `default_bind 0.0.0.0` |
| Map/Struct | `map()` or struct | Rendered as nested block |

**Alternatives considered**:
- Custom duration/size types with validation: Rejected per assumption that Caddy validates
- String for all fields: Rejected due to poor type safety

### Decision: Caddyfile Protocol Implementation

**Rationale**: Extend existing `Caddy.Caddyfile` protocol implementation to handle new fields.

**Approach**:
1. Maintain existing `build_options/1` pattern
2. Add rendering functions for each field category
3. Nested structs implement `Caddy.Caddyfile` protocol for composability
4. Render order: typed fields first, then `extra_options`

**Alternatives considered**:
- New rendering module: Rejected as protocol implementation already exists
- Macro-based rendering: Rejected as too complex for the benefit

## Elixir Best Practices Applied

### Struct Design

- Use `@enforce_keys` sparingly (only for truly required fields, currently none)
- Provide `new/1` constructor for keyword-based initialization
- Use `@type t()` for struct type specification
- Document all fields with `@typedoc`

### Protocol Implementation

- Implement `Caddy.Caddyfile` protocol for all nested config structs
- Use pattern matching for conditional rendering
- Keep rendering functions pure (no side effects)

### Testing Strategy

- Unit tests for each struct's `new/1` function
- Unit tests for Caddyfile protocol implementation
- Property-based testing considered but deferred (no complex invariants)

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| How to handle Caddy version differences? | Assumption: Users ensure binary version supports options |
| Should we validate duration/size formats? | No, per assumption that Caddy validates |
| How to handle deprecated options? | Document in `@moduledoc`; render if user sets them |

## References

- [Caddy Global Options Documentation](https://caddyserver.com/docs/caddyfile/options)
- [Caddy JSON Config Reference](https://caddyserver.com/docs/json/)
- Existing `lib/caddy/config/global.ex` implementation
- Existing `test/caddy/config/global_test.exs` tests
