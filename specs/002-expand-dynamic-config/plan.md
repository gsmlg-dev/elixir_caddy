# Implementation Plan: Expand Dynamic Config Support

**Branch**: `002-expand-dynamic-config` | **Date**: 2025-12-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-expand-dynamic-config/spec.md`

## Summary

Extend `Caddy.Config` to support dynamic configuration elements including environment variables (`{$VAR}`), named matchers (`@name`), named routes (`&(name)`), and plugin configurations. All new configuration types will be implemented as typed Elixir structs implementing the `Caddy.Caddyfile` protocol, with comprehensive matcher type support (15 matcher types), telemetry integration, and idiomatic error handling via `{:ok, value}/{:error, reason}` tuples.

## Technical Context

**Language/Version**: Elixir ~> 1.18, OTP 27+
**Primary Dependencies**: Jason (JSON), Telemetry (observability), Mox (testing)
**Storage**: N/A (in-memory configuration structs)
**Testing**: ExUnit with Mox for mocking, mix test
**Target Platform**: Elixir library (embeddable in any OTP application)
**Project Type**: Single Elixir library
**Performance Goals**: N/A (configuration rendering, not request handling)
**Constraints**: Must maintain backward compatibility with existing Snippet/Site/Global structs
**Scale/Scope**: Library feature - adds ~15 new modules for matcher types + 4 core config modules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Compliance Notes |
|-----------|--------|------------------|
| I. OTP-First Architecture | PASS | New structs are pure data, no GenServers needed; integrates with existing Agent-based ConfigProvider |
| II. Observability by Default | PASS | FR-013 requires telemetry events for all new config rendering; will use `Caddy.Telemetry.log_*` functions |
| III. Test-Driven Quality | PASS | Tests will be written for all new modules; Mox not needed (pure struct/protocol implementations) |
| IV. Configuration Transparency | PASS | All new options documented with `@moduledoc` and `@doc`; follows existing patterns |
| V. Minimal Dependencies | PASS | No new dependencies required; uses existing Jason/Telemetry |
| VI. Caddyfile Structure | PASS | Named routes go in "additionals" section; matchers go in sites; env vars render inline |

**Gate Status**: PASS - All principles satisfied without violations.

## Project Structure

### Documentation (this feature)

```text
specs/002-expand-dynamic-config/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - library, no API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/
├── caddy/
│   ├── config/
│   │   ├── env_var.ex           # NEW: Environment variable struct
│   │   ├── named_matcher.ex     # NEW: Named matcher struct
│   │   ├── named_route.ex       # NEW: Named route struct
│   │   ├── plugin_config.ex     # NEW: Plugin configuration struct
│   │   ├── matcher/             # NEW: Matcher types directory
│   │   │   ├── path.ex
│   │   │   ├── path_regexp.ex
│   │   │   ├── header.ex
│   │   │   ├── header_regexp.ex
│   │   │   ├── method.ex
│   │   │   ├── query.ex
│   │   │   ├── host.ex
│   │   │   ├── protocol.ex
│   │   │   ├── remote_ip.ex
│   │   │   ├── client_ip.ex
│   │   │   ├── vars.ex
│   │   │   ├── vars_regexp.ex
│   │   │   ├── expression.ex
│   │   │   ├── file.ex
│   │   │   └── not.ex
│   │   ├── import.ex            # EXISTS: Already implemented
│   │   ├── snippet.ex           # EXISTS: Already implemented
│   │   ├── site.ex              # UPDATE: Add matchers field
│   │   └── global.ex            # EXISTS: No changes needed
│   ├── config.ex                # UPDATE: Add routes field, update to_caddyfile
│   └── telemetry.ex             # UPDATE: Add new event types

test/
├── caddy/
│   ├── config/
│   │   ├── env_var_test.exs          # NEW
│   │   ├── named_matcher_test.exs    # NEW
│   │   ├── named_route_test.exs      # NEW
│   │   ├── plugin_config_test.exs    # NEW
│   │   └── matcher/                  # NEW
│   │       ├── path_test.exs
│   │       ├── header_test.exs
│   │       └── ... (one per matcher type)
│   └── config_test.exs               # UPDATE: Add integration tests
```

**Structure Decision**: Single Elixir library following existing conventions. New modules placed under `lib/caddy/config/` with matcher types in a subdirectory to maintain organization. Tests mirror source structure.

## Complexity Tracking

No constitution violations requiring justification.
