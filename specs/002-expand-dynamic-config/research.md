# Research: Expand Dynamic Config Support

**Date**: 2025-12-23
**Feature**: 002-expand-dynamic-config

## Research Items Resolved

### 1. Caddy Matcher Types (Complete Reference)

**Decision**: Implement all 15 Caddy matcher types as typed Elixir structs.

**Rationale**: Per clarification session, user requested comprehensive matcher coverage. All types are stable in Caddy v2.x and documented in official Caddyfile matchers documentation.

**Matcher Types with Parameters**:

| Matcher | Parameters | Caddyfile Syntax |
|---------|------------|------------------|
| `path` | paths (list of strings) | `path /api/*` |
| `path_regexp` | name (optional), pattern | `path_regexp name pattern` |
| `header` | field, values (optional) | `header Field [Value]` |
| `header_regexp` | name (optional), field, pattern | `header_regexp name Field pattern` |
| `method` | verbs (list) | `method GET POST` |
| `query` | key-value pairs | `query key=value` |
| `host` | hostnames (list) | `host example.com` |
| `protocol` | protocol string | `protocol https` |
| `remote_ip` | ranges (list) | `remote_ip 192.168.0.0/16` |
| `client_ip` | ranges (list) | `client_ip 10.0.0.0/8` |
| `vars` | variable, values (list) | `vars {var} val1 val2` |
| `vars_regexp` | name (optional), variable, pattern | `vars_regexp name {var} pattern` |
| `expression` | CEL expression | `expression {method}.startsWith("P")` |
| `file` | root, try_files, try_policy, split_path | `file { root /srv }` |
| `not` | nested matcher(s) | `not { path /api/* }` |

**Alternatives Considered**:
- Support only common matchers (path, header, method) → Rejected per user clarification
- Use raw strings for all matchers → Rejected for lack of type safety

### 2. Environment Variable Syntax

**Decision**: Support both `{$VAR}` and `{$VAR:default}` syntax.

**Rationale**: These are the two official Caddy parse-time substitution formats. Runtime placeholders (`{env.*}`) are a different feature and already supported via raw directive strings.

**Implementation Notes**:
- EnvVar struct stores `name` and optional `default`
- Rendering produces `{$NAME}` or `{$NAME:default}`
- No validation of actual environment variable existence (Caddy handles at parse time)

**Alternatives Considered**:
- Resolve environment variables at Elixir render time → Rejected per spec assumption
- Support `{env.*}` runtime placeholders → Deferred (works via existing directive strings)

### 3. Named Matcher Rendering Position

**Decision**: Named matchers render at the beginning of site blocks, before other directives.

**Rationale**: Caddy requires matchers to be defined before they can be referenced. Placing them at the top of site blocks ensures correct ordering.

**Caddyfile Output Order within Site**:
1. Named matcher definitions (`@name { ... }`)
2. Import directives (`import ...`)
3. TLS configuration (`tls ...`)
4. Other directives (`reverse_proxy`, `encode`, etc.)

**Alternatives Considered**:
- User-defined ordering → Complex, error-prone
- Random ordering → Would break matcher references

### 4. Named Route Placement

**Decision**: Named routes render between snippets and sites in the Caddyfile.

**Rationale**: Per Constitution VI, configuration follows order: global → additionals → sites. Named routes are "additionals" alongside snippets but distinct (they use `&(name)` syntax).

**Implementation Notes**:
- Add `routes` field to `Caddy.Config` struct: `%{String.t() => NamedRoute.t()}`
- Render order: global block → snippets → named routes → sites
- `invoke` directive in sites references routes by name

**Alternatives Considered**:
- Store routes inside sites → Wrong; routes are top-level per Caddy spec
- Merge routes into snippets map → Wrong syntax (`&()` vs `()`)

### 5. Import Module Status

**Decision**: Existing `Caddy.Config.Import` module is complete and meets FR-007/FR-008.

**Rationale**: Code review shows Import already supports:
- Snippet imports with arguments
- File path imports
- Proper Caddyfile protocol implementation

**No Changes Needed**: FR-007 and FR-008 are already satisfied by existing implementation.

### 6. Plugin Configuration Approach

**Decision**: Use `extra_options` pattern for plugin configuration (same as Global struct).

**Rationale**:
- Caddy has hundreds of plugins with diverse configuration formats
- Creating typed structs for all plugins is impractical
- `extra_options` field in Global already provides escape hatch for arbitrary config
- Users can pass raw plugin directives as strings

**Implementation Notes**:
- PluginConfig struct: `%{name: String.t(), options: String.t() | map()}`
- For global plugins: add to Global.extra_options
- For site plugins: add to Site.extra_config or directives

**Alternatives Considered**:
- Typed structs for popular plugins (cloudflare DNS, etc.) → Future enhancement
- Plugin registry system → Overengineered for current needs

### 7. Validation Pattern

**Decision**: All validation functions return `{:ok, value}` or `{:error, reason}`.

**Rationale**: Per clarification session, this matches existing codebase patterns (e.g., `validate_bin/1`, `validate_site_config/1`) and is idiomatic Elixir.

**Validation Scope**:
- Matcher struct: validate required fields present, valid types
- Named matcher: validate name format (alphanumeric, hyphen, underscore)
- Named route: validate name format, non-empty content
- EnvVar: validate name is valid identifier

**Alternatives Considered**:
- Raise exceptions → Not idiomatic for validation
- Collect multiple errors → Overengineered for simple structs

### 8. Telemetry Events

**Decision**: Emit telemetry on config struct rendering, following existing patterns.

**Rationale**: Constitution II requires telemetry for all significant operations. Rendering is the key operation for config structs.

**New Events**:
- `[:caddy, :config, :render]` - when any new config struct is rendered
  - Measurements: `%{duration: native_time}`
  - Metadata: `%{module: module_name, result_size: bytes}`

**Note**: Global struct already emits this event; new structs will follow same pattern.

## Dependencies Verified

| Dependency | Status | Notes |
|------------|--------|-------|
| Jason | Already installed | Used for JSON encoding |
| Telemetry | Already installed | Used for observability |
| Mox | Already installed (test) | For mocking in tests |
| Caddy.Caddyfile protocol | Exists | All new structs implement this |

## No Unknowns Remaining

All technical decisions have been made. Ready for Phase 1 data model design.
