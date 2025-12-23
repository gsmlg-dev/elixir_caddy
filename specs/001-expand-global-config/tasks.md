# Tasks: Expand Caddy.Config.Global

**Input**: Design documents from `/specs/001-expand-global-config/`
**Prerequisites**: plan.md (required), spec.md (required), data-model.md, research.md, quickstart.md

**Tests**: Tests are included per constitution Principle III (Test-Driven Quality) and spec requirements.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Elixir library**: `lib/caddy/` for source, `test/caddy/` for tests

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure for nested config modules

- [X] T001 Create directory lib/caddy/config/global/ for nested config structs
- [X] T002 Create directory test/caddy/config/global/ for nested config tests

**Checkpoint**: Directory structure ready for implementation ✅

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create nested config structs that all user stories depend on

**⚠️ CRITICAL**: User stories 1-4 depend on these nested structs being available

### Timeouts Struct (used by Server)

- [X] T003 [P] Create Caddy.Config.Global.Timeouts struct in lib/caddy/config/global/timeouts.ex
- [X] T004 [P] Implement Caddy.Caddyfile protocol for Timeouts in lib/caddy/config/global/timeouts.ex
- [X] T005 [P] Add tests for Timeouts struct in test/caddy/config/global/timeouts_test.exs

### Log Struct (used by US1)

- [X] T006 [P] Create Caddy.Config.Global.Log struct in lib/caddy/config/global/log.ex
- [X] T007 [P] Implement Caddy.Caddyfile protocol for Log in lib/caddy/config/global/log.ex
- [X] T008 [P] Add tests for Log struct in test/caddy/config/global/log_test.exs

### Server Struct (used by US2)

- [X] T009 Create Caddy.Config.Global.Server struct in lib/caddy/config/global/server.ex (depends on T003)
- [X] T010 Implement Caddy.Caddyfile protocol for Server in lib/caddy/config/global/server.ex
- [X] T011 Add tests for Server struct in test/caddy/config/global/server_test.exs

### PKI Struct (used by US4)

- [X] T012 [P] Create Caddy.Config.Global.PKI struct in lib/caddy/config/global/pki.ex
- [X] T013 [P] Implement Caddy.Caddyfile protocol for PKI in lib/caddy/config/global/pki.ex
- [X] T014 [P] Add tests for PKI struct in test/caddy/config/global/pki_test.exs

**Checkpoint**: All nested config structs ready - user story implementation can begin ✅

---

## Phase 3: User Story 1 - Configure Common Global Options (Priority: P1) 🎯 MVP

**Goal**: Support typed fields for common global options (ports, TLS settings, logging)

**Independent Test**: Create Global struct with http_port, https_port, auto_https, log fields and verify Caddyfile output

### Tests for User Story 1

- [X] T015 [P] [US1] Add tests for http_port field rendering in test/caddy/config/global_test.exs
- [X] T016 [P] [US1] Add tests for https_port field rendering in test/caddy/config/global_test.exs
- [X] T017 [P] [US1] Add tests for auto_https field rendering in test/caddy/config/global_test.exs
- [X] T018 [P] [US1] Add tests for log field rendering in test/caddy/config/global_test.exs
- [X] T019 [P] [US1] Add tests for TLS options (local_certs, skip_install_trust, key_type) in test/caddy/config/global_test.exs
- [X] T020 [P] [US1] Add backward compatibility tests in test/caddy/config/global_test.exs

### Implementation for User Story 1

- [X] T021 [US1] Add new general option fields to Global struct defstruct in lib/caddy/config/global.ex
- [X] T022 [US1] Add new TLS option fields to Global struct defstruct in lib/caddy/config/global.ex
- [X] T023 [US1] Add log field to Global struct defstruct in lib/caddy/config/global.ex
- [X] T024 [US1] Update @type t() spec with all new fields in lib/caddy/config/global.ex
- [X] T025 [US1] Add rendering for http_port/https_port in build_options/1 in lib/caddy/config/global.ex
- [X] T026 [US1] Add rendering for auto_https in build_options/1 in lib/caddy/config/global.ex
- [X] T027 [US1] Add rendering for TLS boolean flags in build_options/1 in lib/caddy/config/global.ex
- [X] T028 [US1] Add rendering for TLS string options in build_options/1 in lib/caddy/config/global.ex
- [X] T029 [US1] Add rendering for log blocks in build_options/1 in lib/caddy/config/global.ex
- [X] T030 [US1] Add rendering for general options (grace_period, shutdown_delay, etc.) in lib/caddy/config/global.ex
- [X] T031 [US1] Verify backward compatibility with existing fields in lib/caddy/config/global.ex

**Checkpoint**: User Story 1 complete - common global options work independently ✅

---

## Phase 4: User Story 2 - Configure Server Options (Priority: P2)

**Goal**: Support servers configuration with timeouts, trusted proxies, and protocols

**Independent Test**: Create Global struct with servers map containing Server structs and verify nested Caddyfile block output

### Tests for User Story 2

- [X] T032 [P] [US2] Add tests for servers field rendering in test/caddy/config/global_test.exs
- [X] T033 [P] [US2] Add tests for server with timeouts block in test/caddy/config/global_test.exs
- [X] T034 [P] [US2] Add tests for trusted_proxies rendering in test/caddy/config/global_test.exs

### Implementation for User Story 2

- [X] T035 [US2] Add servers field to Global struct defstruct in lib/caddy/config/global.ex
- [X] T036 [US2] Update @type t() spec with servers field in lib/caddy/config/global.ex
- [X] T037 [US2] Add rendering for servers blocks in build_options/1 in lib/caddy/config/global.ex

**Checkpoint**: User Story 2 complete - server options work independently ✅

---

## Phase 5: User Story 3 - Configure Dynamic/Custom Options (Priority: P3)

**Goal**: Ensure extra_options works correctly with typed fields

**Independent Test**: Create Global struct mixing typed fields and extra_options, verify render order

### Tests for User Story 3

- [X] T038 [P] [US3] Add tests for extra_options render order in test/caddy/config/global_test.exs
- [X] T039 [P] [US3] Add tests for mixed typed and dynamic options in test/caddy/config/global_test.exs

### Implementation for User Story 3

- [X] T040 [US3] Verify extra_options renders after all typed fields in lib/caddy/config/global.ex
- [X] T041 [US3] Add documentation for extra_options usage in lib/caddy/config/global.ex

**Checkpoint**: User Story 3 complete - dynamic options work with typed fields ✅

---

## Phase 6: User Story 4 - Configure PKI Options (Priority: P3)

**Goal**: Support PKI configuration for internal certificate authorities

**Independent Test**: Create Global struct with pki configuration and verify nested pki block output

### Tests for User Story 4

- [X] T042 [P] [US4] Add tests for pki field rendering in test/caddy/config/global_test.exs
- [X] T043 [P] [US4] Add tests for local_certs + pki combination in test/caddy/config/global_test.exs

### Implementation for User Story 4

- [X] T044 [US4] Add pki field to Global struct defstruct in lib/caddy/config/global.ex
- [X] T045 [US4] Update @type t() spec with pki field in lib/caddy/config/global.ex
- [X] T046 [US4] Add rendering for pki block in build_options/1 in lib/caddy/config/global.ex

**Checkpoint**: User Story 4 complete - PKI options work independently ✅

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final quality improvements and validation

- [X] T047 Update @moduledoc documentation in lib/caddy/config/global.ex
- [X] T048 [P] Update @moduledoc in all nested struct modules (log.ex, server.ex, pki.ex, timeouts.ex)
- [X] T049 Run mix format on all modified files
- [X] T050 Run mix credo --strict and fix any issues
- [X] T051 Run mix dialyzer and fix any type warnings
- [X] T052 [P] Add telemetry event for Global config rendering in lib/caddy/config/global.ex
- [X] T053 Validate quickstart.md examples work correctly
- [X] T054 Run full test suite with mix test

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Log struct)
- **User Story 2 (Phase 4)**: Depends on Foundational (Server, Timeouts structs)
- **User Story 3 (Phase 5)**: Depends on User Story 1 (needs typed fields to test ordering)
- **User Story 4 (Phase 6)**: Depends on Foundational (PKI struct)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Independent of US1
- **User Story 3 (P3)**: Requires US1 complete (tests render order of typed vs dynamic)
- **User Story 4 (P3)**: Can start after Foundational - Independent of US1/US2

### Within Each User Story

- Tests SHOULD be written first (TDD per constitution)
- Struct field additions before rendering logic
- Rendering logic before complex features

### Parallel Opportunities

- T003-T008, T012-T014 can all run in parallel (different nested structs)
- T009-T011 depends on T003 (Server uses Timeouts)
- All [P] marked tests within a story can run in parallel
- US2 and US4 can run in parallel after Foundational
- All Phase 7 [P] tasks can run in parallel

---

## Parallel Example: Foundational Phase

```bash
# Launch all independent nested struct implementations together:
Task T003: "Create Caddy.Config.Global.Timeouts struct"
Task T006: "Create Caddy.Config.Global.Log struct"
Task T012: "Create Caddy.Config.Global.PKI struct"

# After Timeouts complete (T003-T005), launch Server:
Task T009: "Create Caddy.Config.Global.Server struct"
```

## Parallel Example: User Story 1 Tests

```bash
# Launch all US1 tests together (they test different fields):
Task T015: "tests for http_port field"
Task T016: "tests for https_port field"
Task T017: "tests for auto_https field"
Task T018: "tests for log field"
Task T019: "tests for TLS options"
Task T020: "backward compatibility tests"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T014) - focus on Log struct needed for US1
3. Complete Phase 3: User Story 1 (T015-T031)
4. **STOP and VALIDATE**: Run tests, verify common options work
5. Release as minor version increment

### Incremental Delivery

1. Setup + Foundational → All nested structs ready
2. User Story 1 → Common options (80% use case) ✅ MVP
3. User Story 2 → Server options (production deployments)
4. User Story 3 → Extra options ordering verified
5. User Story 4 → PKI options (enterprise use case)
6. Polish → Documentation, quality gates

### Parallel Team Strategy

With multiple developers:

1. All complete Setup together
2. Foundational: Each developer takes 1 nested struct
3. Once Foundational done:
   - Developer A: User Story 1 + 3
   - Developer B: User Story 2 + 4
4. All complete Polish together

---

## Notes

- All new fields default to `nil` for backward compatibility (SC-003)
- Use `Caddy.Telemetry.log_*` for any logging per constitution
- Tests use existing patterns from test/caddy/config/global_test.exs
- Nested structs implement Caddy.Caddyfile protocol for composability
