# Feature Specification: Expand Dynamic Config Support

**Feature Branch**: `002-expand-dynamic-config`
**Created**: 2025-12-23
**Status**: Draft
**Input**: User description: "we still need update Caddy.Config, it still missing additional part of config, this is list of dynamic config, maybe variable, snippets or caddy plugins config"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define Environment Variables (Priority: P1)

As a developer, I want to define environment variables in my Caddy configuration so that I can externalize sensitive values and deployment-specific settings without hardcoding them.

**Why this priority**: Environment variables are the most common way to externalize configuration across deployment environments. This is critical for production deployments where sensitive data (API keys, database URLs) must not be in code.

**Independent Test**: Can be fully tested by defining variables with `{$VAR}` syntax and verifying they are correctly rendered in the Caddyfile output.

**Acceptance Scenarios**:

1. **Given** a Config struct with no environment variables defined, **When** I call `Caddy.Config.set_env_var("API_KEY", "secret123")`, **Then** the variable should be stored and available for use in site configurations.
2. **Given** a Config with environment variable `DATABASE_URL` defined, **When** I render the Caddyfile, **Then** the configuration should include `{$DATABASE_URL}` syntax where referenced.
3. **Given** a Config with an environment variable with a default value, **When** I render the Caddyfile, **Then** it should output `{$VAR:default_value}` syntax.

---

### User Story 2 - Manage Named Matchers (Priority: P1)

As a developer, I want to define named matchers that can be reused across multiple directives in a site so that I can avoid duplicating complex matching logic and keep my configuration DRY.

**Why this priority**: Named matchers are essential for non-trivial Caddy configurations. They allow defining complex request matching criteria once and referencing them multiple times.

**Independent Test**: Can be fully tested by creating a named matcher struct, adding it to a site, and verifying it renders correctly with `@name { ... }` syntax.

**Acceptance Scenarios**:

1. **Given** a Site configuration, **When** I add a named matcher `@api` with path matcher `/api/*`, **Then** the Caddyfile should render `@api path /api/*` within the site block.
2. **Given** a Site with a named matcher using multiple conditions, **When** I render the Caddyfile, **Then** it should output the matcher block with all conditions AND'ed together.
3. **Given** a Site with a named matcher, **When** I reference it in a directive like `reverse_proxy @api localhost:3000`, **Then** the directive should correctly reference the named matcher.

---

### User Story 3 - Support Named Routes (Priority: P2)

As a developer, I want to define named routes that can be invoked from multiple sites so that I can reduce memory usage and maintain consistent routing logic across virtual hosts.

**Why this priority**: Named routes are useful for large deployments with many sites sharing identical routing logic, but are less commonly needed than matchers and variables.

**Independent Test**: Can be fully tested by defining a named route with `&(name)` syntax and invoking it from a site.

**Acceptance Scenarios**:

1. **Given** a Config struct, **When** I add a named route `&(common-api)` with reverse proxy configuration, **Then** the route should be stored at the top level (not inside a site).
2. **Given** a Config with a named route, **When** a site uses `invoke common-api`, **Then** the Caddyfile should correctly render both the route definition and the invocation.
3. **Given** multiple sites invoking the same named route, **When** I render the Caddyfile, **Then** the route should be defined only once and referenced in all invoking sites.

---

### User Story 4 - Import External Files and Snippets (Priority: P2)

As a developer, I want to import external Caddyfile snippets or files so that I can organize large configurations into modular, reusable parts.

**Why this priority**: Import directives enable configuration modularity which is important for larger projects, but many simple deployments don't require this level of organization.

**Independent Test**: Can be fully tested by adding an import directive to a site and verifying it renders correctly.

**Acceptance Scenarios**:

1. **Given** a Site configuration, **When** I add an import for snippet `common-headers`, **Then** the Caddyfile should render `import common-headers` within the site block.
2. **Given** a Site with an import that includes arguments, **When** I render the Caddyfile, **Then** it should output `import snippet-name arg1 arg2`.
3. **Given** a Site with an import from a file path, **When** I render the Caddyfile, **Then** it should output `import /path/to/config.caddyfile`.

---

### User Story 5 - Configure Plugin Settings (Priority: P3)

As a developer, I want to configure Caddy plugins through typed structs so that I can safely configure third-party modules without raw string manipulation.

**Why this priority**: Plugin configuration is advanced functionality needed only by users with custom Caddy builds. Most deployments use standard Caddy without plugins.

**Independent Test**: Can be fully tested by defining a plugin configuration struct and verifying it integrates with the global or site config.

**Acceptance Scenarios**:

1. **Given** a Config struct, **When** I add plugin configuration for a known plugin type, **Then** the configuration should be stored and rendered in the appropriate location (global or site level).
2. **Given** a Global config with plugin-specific directives, **When** I render the Caddyfile, **Then** the plugin directives should appear in the global block.
3. **Given** unknown plugin configuration (arbitrary key-value), **When** I use the `extra_options` field, **Then** it should render the raw configuration as-is.

---

### Edge Cases

- What happens when a named matcher is defined but never referenced? (Should still render in case of external references)
- How does the system handle circular snippet imports? (Caddy handles this at runtime; library should not validate)
- What happens when an environment variable reference uses an undefined variable? (Should render as-is; Caddy will error or use empty string)
- How should conflicting matcher names across sites be handled? (Each site has its own namespace; no conflict)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support storing and rendering environment variable definitions with syntax `{$VAR}` for parse-time substitution.
- **FR-002**: System MUST support environment variable default values with syntax `{$VAR:default}`.
- **FR-003**: System MUST support defining named matchers with the `@name` syntax within site configurations.
- **FR-004**: Named matchers MUST support both single-line syntax (`@name matcher value`) and block syntax (`@name { ... }`).
- **FR-005**: System MUST support defining named routes with the `&(name)` syntax at the config level.
- **FR-006**: System MUST support the `invoke` directive to reference named routes from sites.
- **FR-007**: System MUST support import directives for snippets, files, and glob patterns.
- **FR-008**: Import directives MUST support passing arguments to snippets.
- **FR-009**: System MUST maintain backward compatibility with existing `snippets` field and `Snippet` struct.
- **FR-010**: System MUST provide struct-based configuration for commonly-used plugin directives.
- **FR-011**: System MUST support arbitrary plugin configuration via `extra_options` for unknown plugins.
- **FR-012**: All new configuration elements MUST implement the `Caddy.Caddyfile` protocol.
- **FR-013**: System MUST emit telemetry events when rendering new configuration elements.
- **FR-014**: System MUST provide validation functions for new configuration types, returning `{:ok, value}` on success or `{:error, reason}` on failure (consistent with existing validation patterns).
- **FR-015**: System MUST provide typed structs for ALL Caddy matcher types (path, path_regexp, header, header_regexp, method, query, host, protocol, remote_ip, client_ip, vars, vars_regexp, expression, file, not).

### Key Entities

- **EnvVar**: Represents an environment variable reference with optional default value. Contains `name` (string) and `default` (string | nil).
- **NamedMatcher**: Represents a reusable matcher definition. Contains `name` (string), `matchers` (list of typed Matcher structs covering all Caddy matcher types: path, path_regexp, header, header_regexp, method, query, host, protocol, remote_ip, client_ip, vars, vars_regexp, expression, file, not), and `site_scope` (belongs to a specific site).
- **NamedRoute**: Represents a reusable route definition at config level. Contains `name` (string) and `content` (route directives).
- **Import**: Represents an import directive. Contains `target` (snippet name, file path, or glob pattern) and `args` (list of arguments).
- **PluginConfig**: Represents arbitrary plugin configuration. Contains `name` (string) and `options` (map or raw string).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can define and use environment variables in configuration without writing raw Caddyfile strings.
- **SC-002**: Developers can create named matchers using typed structs with full IDE autocompletion support.
- **SC-003**: Configuration rendering correctly produces valid Caddyfile syntax for all new elements.
- **SC-004**: All new structs integrate seamlessly with existing `Caddy.Config` workflow (set, get, render).
- **SC-005**: Existing tests continue to pass without modification (backward compatibility).
- **SC-006**: New configuration elements are documented with examples in module documentation.
- **SC-007**: Telemetry events are emitted for all new configuration operations, following existing patterns.

## Clarifications

### Session 2025-12-23

- Q: What matcher types should NamedMatcher support? → A: Support ALL Caddy matcher types with typed structs (comprehensive)
- Q: How should validation errors be handled? → A: Return `{:ok, value}` / `{:error, reason}` tuples (idiomatic Elixir)

## Assumptions

- Named routes are an experimental Caddy feature but stable enough for implementation.
- Plugin configurations will primarily use the `extra_options` escape hatch; typed plugin structs are optional enhancements.
- The `Snippet` struct already exists and works correctly; this feature extends but does not replace it.
- Environment variable expansion happens at Caddy parse time, not at Elixir render time (we emit the syntax, not the resolved value).
- Named matchers are scoped to individual sites; cross-site matcher sharing uses snippets instead.
