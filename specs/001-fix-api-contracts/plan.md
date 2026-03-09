# Implementation Plan: Fix API Contracts and Harden Error Handling

**Branch**: `001-fix-api-contracts` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-fix-api-contracts/spec.md`

## Summary

Fix contract mismatches between `Caddy.Admin.Api` callers in `Caddy.Server.External` that
cause `CaseClauseError` and `BadMapError` exceptions on the normal startup path. The approach
is to **fix the callers** to consume what `Api` actually returns (not change `Api`'s return
types), plus guard `Api.load/1`'s map-merge against nil, and make `Caddy.Admin.Request`'s
body-reading path return structured errors instead of raising exceptions. A constitution
compliance fix (direct `Logger.debug` → `Caddy.Telemetry.log_debug`) is included.

## Technical Context

**Language/Version**: Elixir ~> 1.18, OTP 27+
**Primary Dependencies**: Jason (JSON), Telemetry (observability), Mox (test mocking)
**Storage**: N/A (in-memory config state managed by `Caddy.Config` Agent)
**Testing**: ExUnit + Mox
**Target Platform**: Linux server (embeddable library)
**Project Type**: Single Elixir library
**Performance Goals**: No regressions — defensive fixes only
**Constraints**: Public API signatures MUST NOT change — only caller pattern-matching and
internal error normalization
**Scale/Scope**: 5 targeted fixes across 2 files; ~7 new behavioral test cases in 2 test files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. OTP-First Architecture | ✅ PASS | No new processes; fixes within existing GenServer/Agent structure |
| II. Observability by Default | ⚠️ VIOLATION FOUND | `request.ex:171` uses `Logger.debug` directly — **PROHIBITED**; fixed in this feature via `Caddy.Telemetry.log_debug/2` |
| III. Test-Driven Quality | ✅ PASS | New behavioral tests required per FR-007 and SC-003 |
| IV. Configuration Transparency | ✅ PASS | No configuration changes |
| V. Minimal Dependencies | ✅ PASS | No new dependencies |
| VI. Caddyfile Structure | ✅ PASS | Not in scope |

**Re-check post-design**: Constitution violation in `request.ex:171` is resolved by fix D5
(replace `Logger.debug` with `Caddy.Telemetry.log_debug`). All other principles maintained.

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-api-contracts/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── internal-function-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/caddy/
├── admin/
│   ├── api.ex           # Fix: nil guard in load/1 map clause; remove unused require Logger
│   └── request.ex       # Fix: read_body error propagation; safe Jason.decode; Logger→Telemetry
└── server/
    └── external.ex      # Fix: get_caddyfile/0 pattern; push_initial_config/0 double mismatch;
                         #      execute_shell_command/1 empty guard

test/caddy/
├── admin/
│   └── api_test.exs     # Add: load/1 with nil runtime config
└── server/
    └── external_test.exs # Add: get_caddyfile, push_config success/failure, empty command tests
```

**Structure Decision**: Single library project. All implementation changes are edits to
existing files. No new files are required.

## Complexity Tracking

> One constitution violation detected (`Logger.debug` in `request.ex`) — being FIXED,
> not introduced. No unjustified violations remain.

## Key Decisions (from research.md)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Fix `External` callers to consume actual `Api` return types | Minimal change; no public `Api` signature changes |
| D2 | Guard `Api.load/1` map merge against nil → return `%{status: 0, body: nil}` | Consistent with existing error return pattern |
| D3 | Use `Jason.decode/1` (safe) instead of `Jason.decode!/1` | Allows error normalization without raising |
| D4 | Add empty-string guard in `execute_shell_command/1` → `{:error, :empty_command}` | Makes error explicit and testable |
| D5 | Replace `Logger.debug` with `Caddy.Telemetry.log_debug` in `request.ex` | Constitution Principle II compliance |
| D6 | Remove unused `require Logger` from `api.ex` | Credo strict compliance |
