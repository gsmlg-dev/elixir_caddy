# Implementation Plan: Expand Caddy.Config.Global

**Branch**: `001-expand-global-config` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-expand-global-config/spec.md`

## Summary

Expand the `Caddy.Config.Global` struct to support comprehensive Caddyfile global options
(35+ typed fields) while maintaining backward compatibility. The implementation adds typed
fields for common options (ports, TLS, logging, servers, PKI) and preserves the existing
`extra_options` escape hatch for plugin extensibility.

## Technical Context

**Language/Version**: Elixir ~> 1.18, OTP 27+
**Primary Dependencies**: Jason (JSON), Telemetry (observability), Mox (testing)
**Storage**: N/A (in-memory configuration structs)
**Testing**: ExUnit with Mox for mocking
**Target Platform**: Any platform supporting Elixir/OTP (Linux, macOS, Windows)
**Project Type**: Single Elixir library
**Performance Goals**: N/A (configuration rendering is not performance-critical)
**Constraints**: Backward compatible with existing `Caddy.Config.Global` API
**Scale/Scope**: ~35 new struct fields, 4 new nested config structs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. OTP-First Architecture | ✅ PASS | `Caddy.Config.Global` is a plain struct (no process state); fits existing Agent-based `Caddy.Config` |
| II. Observability by Default | ✅ PASS | FR-040 requires telemetry events; will use `Caddy.Telemetry.log_*` functions |
| III. Test-Driven Quality | ✅ PASS | Tests required per spec; existing `global_test.exs` will be extended |
| IV. Configuration Transparency | ✅ PASS | All new fields documented with types; backward compatible per SC-003 |
| V. Minimal Dependencies | ✅ PASS | No new dependencies required |
| VI. Caddyfile Structure | ✅ PASS | Global config is Part 1 of 3-part architecture; supports existing separation |

**Quality Standards Compliance**:
- Static Analysis: Code will pass `mix credo --strict` and `mix dialyzer`
- Formatting: Code will pass `mix format --check-formatted`
- Documentation: All public modules/functions will have `@moduledoc`/`@doc`
- Type Specs: All public functions will have `@spec` annotations
- Logging: All logging will use `Caddy.Telemetry.log_*` functions

## Project Structure

### Documentation (this feature)

```text
specs/001-expand-global-config/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no API contracts for struct)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/
├── caddy/
│   ├── config/
│   │   ├── global.ex           # MODIFY: Expand struct with 35+ fields
│   │   ├── global/
│   │   │   ├── server.ex       # NEW: ServerConfig nested struct
│   │   │   ├── log.ex          # NEW: LogConfig nested struct
│   │   │   ├── pki.ex          # NEW: PKIConfig nested struct
│   │   │   └── timeouts.ex     # NEW: TimeoutsConfig nested struct
│   │   ├── site.ex             # UNCHANGED
│   │   ├── import.ex           # UNCHANGED
│   │   └── snippet.ex          # UNCHANGED
│   ├── caddyfile.ex            # MODIFY: Update protocol impl for new fields
│   └── telemetry.ex            # UNCHANGED (already has needed events)

test/
├── caddy/
│   ├── config/
│   │   ├── global_test.exs     # MODIFY: Add tests for new fields
│   │   └── global/
│   │       ├── server_test.exs # NEW: ServerConfig tests
│   │       ├── log_test.exs    # NEW: LogConfig tests
│   │       ├── pki_test.exs    # NEW: PKIConfig tests
│   │       └── timeouts_test.exs # NEW: TimeoutsConfig tests
```

**Structure Decision**: Elixir library structure with nested config modules under
`lib/caddy/config/global/` for complex nested configurations. This keeps related
code together while avoiding a monolithic global.ex file.

## Complexity Tracking

> No constitution violations. All changes follow existing patterns.

| Decision | Rationale |
|----------|-----------|
| Nested structs in `global/` subdirectory | Complex options (servers, log, pki) have many sub-options; separate modules improve maintainability |
| Keep backward compatibility | SC-003 requires existing code to work; all new fields default to `nil` |
