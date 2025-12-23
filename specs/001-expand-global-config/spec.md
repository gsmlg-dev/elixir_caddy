# Feature Specification: Expand Caddy.Config.Global

**Feature Branch**: `001-expand-global-config`
**Created**: 2025-12-22
**Status**: Draft
**Input**: User description: "the struct Caddy.Config.Global should includes more options and dynamic options"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure Common Global Options (Priority: P1)

As a developer integrating Caddy into my Elixir application, I want to configure the most
frequently used global options (ports, TLS settings, logging) through typed struct fields
so that I get compile-time validation and IDE autocompletion.

**Why this priority**: Common options like HTTP/HTTPS ports, admin endpoint, debug mode,
email, and basic TLS settings cover 80% of use cases. Type safety prevents configuration
errors at compile time.

**Independent Test**: Can be tested by creating a Global struct with typed fields and
verifying the rendered Caddyfile output matches expected format.

**Acceptance Scenarios**:

1. **Given** a new Global struct, **When** I set `http_port: 8080` and `https_port: 8443`,
   **Then** the rendered Caddyfile contains `http_port 8080` and `https_port 8443` lines

2. **Given** a Global struct with `auto_https: :disable_redirects`, **When** I render to
   Caddyfile, **Then** the output contains `auto_https disable_redirects`

3. **Given** a Global struct with `log` options configured, **When** I render to Caddyfile,
   **Then** the output contains a properly formatted `log` block with sub-options

---

### User Story 2 - Configure Server Options (Priority: P2)

As a developer running Caddy behind a load balancer, I want to configure server-specific
options like timeouts, trusted proxies, and protocols so that my reverse proxy setup works
correctly with upstream infrastructure.

**Why this priority**: Server options are essential for production deployments behind load
balancers and CDNs. These affect reliability and security.

**Independent Test**: Can be tested by creating a Global struct with server options and
verifying nested Caddyfile block rendering.

**Acceptance Scenarios**:

1. **Given** a Global struct with `servers` configuration, **When** I set
   `trusted_proxies: {:static, ["private_ranges"]}`, **Then** the rendered Caddyfile
   contains a `servers` block with `trusted_proxies static private_ranges`

2. **Given** server timeouts configured, **When** I render to Caddyfile, **Then** the
   output contains a `timeouts` sub-block with `read_body`, `read_header`, `write`,
   and `idle` values

---

### User Story 3 - Configure Dynamic/Custom Options (Priority: P3)

As a developer using Caddy plugins that add custom global options, I want to specify
arbitrary key-value options that aren't part of the core struct so that I can use any
Caddy plugin without waiting for library updates.

**Why this priority**: Extensibility allows users to use any Caddy plugin. The library
shouldn't block users from using new or custom Caddy features.

**Independent Test**: Can be tested by adding custom options and verifying they appear
in rendered output.

**Acceptance Scenarios**:

1. **Given** a Global struct with dynamic options `[{"layer4", "{ ... }"}]`, **When** I
   render to Caddyfile, **Then** the custom options appear in the global block

2. **Given** a Global struct mixing typed fields and dynamic options, **When** I render
   to Caddyfile, **Then** both typed and dynamic options render correctly with typed
   options first

---

### User Story 4 - Configure PKI Options (Priority: P3)

As a developer using internal certificate authorities, I want to configure PKI settings
for local HTTPS and ACME so that I can issue certificates from my organization's CA.

**Why this priority**: PKI configuration is needed for enterprise environments with
internal CAs. Less common than basic TLS but important for specific use cases.

**Independent Test**: Can be tested by creating PKI configuration and verifying nested
block rendering.

**Acceptance Scenarios**:

1. **Given** PKI configuration with custom CA name, **When** I render to Caddyfile,
   **Then** the output contains a `pki` block with `ca local` sub-block

---

### Edge Cases

- What happens when conflicting options are set (e.g., `local_certs` and `acme_ca`)?
  System renders both; Caddy validates at runtime
- What happens when invalid port numbers are provided?
  Type system allows integers; Caddy validates at runtime
- How does system handle nil vs explicit false for boolean options?
  Nil means "use default" (no output); false is explicit if option supports it
- What happens when `extra_options` duplicates a typed field?
  Both render; last value wins in Caddy (user responsibility to avoid duplicates)

## Requirements *(mandatory)*

### Functional Requirements

#### General Options
- **FR-001**: System MUST support `debug` as a boolean field (renders `debug` when true)
- **FR-002**: System MUST support `http_port` as an integer field
- **FR-003**: System MUST support `https_port` as an integer field
- **FR-004**: System MUST support `default_bind` as a list of strings (addresses)
- **FR-005**: System MUST support `order` as a list of directive ordering rules
- **FR-006**: System MUST support `storage` as a string or map for storage configuration
- **FR-007**: System MUST support `storage_clean_interval` as a duration string
- **FR-008**: System MUST support `admin` as string, `:off`, or map with sub-options
- **FR-009**: System MUST support `persist_config` as boolean (renders `persist_config off` when false)
- **FR-010**: System MUST support `grace_period` as a duration string
- **FR-011**: System MUST support `shutdown_delay` as a duration string
- **FR-012**: System MUST support `log` as a map or list of named logger configurations

#### TLS/Certificate Options
- **FR-013**: System MUST support `auto_https` as atom (`:off`, `:disable_redirects`, `:disable_certs`, `:ignore_loaded_certs`)
- **FR-014**: System MUST support `email` as a string field
- **FR-015**: System MUST support `default_sni` as a string field
- **FR-016**: System MUST support `local_certs` as a boolean field
- **FR-017**: System MUST support `skip_install_trust` as a boolean field
- **FR-018**: System MUST support `acme_ca` as a string field
- **FR-019**: System MUST support `acme_ca_root` as a string field
- **FR-020**: System MUST support `acme_eab` as a map with `key_id` and `mac_key`
- **FR-021**: System MUST support `acme_dns` as a tuple of provider and credentials
- **FR-022**: System MUST support `on_demand_tls` as a map with `ask` and/or `permission`
- **FR-023**: System MUST support `key_type` as atom (`:ed25519`, `:p256`, `:p384`, `:rsa2048`, `:rsa4096`)
- **FR-024**: System MUST support `cert_issuer` as a list of issuer configurations
- **FR-025**: System MUST support `renew_interval` as a duration string
- **FR-026**: System MUST support `cert_lifetime` as a duration string
- **FR-027**: System MUST support `ocsp_interval` as a duration string
- **FR-028**: System MUST support `ocsp_stapling` as boolean
- **FR-029**: System MUST support `preferred_chains` as atom or map

#### Server Options
- **FR-030**: System MUST support `servers` as a map with listener address keys
- **FR-031**: Server config MUST support `name`, `protocols`, `timeouts`, `keepalive_interval`
- **FR-032**: Server config MUST support `trusted_proxies` with module and options
- **FR-033**: Server config MUST support `client_ip_headers` as list of header names
- **FR-034**: Server config MUST support `max_header_size` as size string

#### PKI Options
- **FR-035**: System MUST support `pki` as a map with CA configurations
- **FR-036**: PKI CA config MUST support `name`, `root_cn`, `intermediate_cn`, `intermediate_lifetime`

#### Extensibility
- **FR-037**: System MUST support `extra_options` as a list of raw Caddyfile lines for plugin options
- **FR-038**: System MUST render typed fields before `extra_options`
- **FR-039**: System MUST preserve the order of `extra_options` in rendered output

#### Telemetry
- **FR-040**: System MUST emit telemetry events when Global configuration is rendered (per constitution Principle II)

### Key Entities

- **Global**: The main configuration struct representing the entire global options block.
  Contains typed fields for common options and an escape hatch for custom/plugin options.

- **ServerConfig**: Nested configuration for the `servers` option. Contains server-specific
  settings like timeouts, protocols, and trusted proxy configuration.

- **LogConfig**: Nested configuration for named loggers. Contains output, format, level,
  and namespace filtering options.

- **PKIConfig**: Nested configuration for certificate authorities. Contains CA identity
  and certificate settings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can configure 90% of common Caddy global options using typed struct
  fields without resorting to `extra_options`

- **SC-002**: All typed fields render valid Caddyfile syntax that Caddy accepts without errors

- **SC-003**: Existing code using the current Global struct continues to work without
  modification (backward compatible)

- **SC-004**: Developers can discover available options through IDE autocompletion and
  documentation

- **SC-005**: Configuration errors for typed fields are caught at compile time or with
  clear runtime error messages

## Assumptions

- Duration strings follow Caddy's format (e.g., "10s", "5m", "24h", "7d")
- Size strings follow Caddy's format (e.g., "1MB", "5MB")
- Users are responsible for ensuring Caddy binary version supports configured options
- Plugin-specific options should use `extra_options` until explicitly supported
- The library does not validate option values beyond Elixir type checking; Caddy performs
  runtime validation
