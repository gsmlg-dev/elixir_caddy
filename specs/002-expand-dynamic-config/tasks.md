# Tasks: Expand Dynamic Config Support

**Input**: Design documents from `/specs/002-expand-dynamic-config/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Tests are included as this is a library following TDD per Constitution III.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Elixir library**: `lib/caddy/` for source, `test/caddy/` for tests
- Follows existing codebase structure per plan.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure for new matcher modules

- [x] T001 Create matcher module directory at lib/caddy/config/matcher/
- [x] T002 Create matcher test directory at test/caddy/config/matcher/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core matcher types that MUST be complete before NamedMatcher can be implemented

**⚠️ CRITICAL**: User Story 2 (Named Matchers) depends on all matcher types being implemented first

### Matcher Type Implementations (All [P] - parallel, no dependencies between matchers)

- [x] T003 [P] Create Matcher.Path struct with Caddyfile protocol in lib/caddy/config/matcher/path.ex
- [x] T004 [P] Create Matcher.PathRegexp struct with Caddyfile protocol in lib/caddy/config/matcher/path_regexp.ex
- [x] T005 [P] Create Matcher.Header struct with Caddyfile protocol in lib/caddy/config/matcher/header.ex
- [x] T006 [P] Create Matcher.HeaderRegexp struct with Caddyfile protocol in lib/caddy/config/matcher/header_regexp.ex
- [x] T007 [P] Create Matcher.Method struct with Caddyfile protocol in lib/caddy/config/matcher/method.ex
- [x] T008 [P] Create Matcher.Query struct with Caddyfile protocol in lib/caddy/config/matcher/query.ex
- [x] T009 [P] Create Matcher.Host struct with Caddyfile protocol in lib/caddy/config/matcher/host.ex
- [x] T010 [P] Create Matcher.Protocol struct with Caddyfile protocol in lib/caddy/config/matcher/protocol.ex
- [x] T011 [P] Create Matcher.RemoteIp struct with Caddyfile protocol in lib/caddy/config/matcher/remote_ip.ex
- [x] T012 [P] Create Matcher.ClientIp struct with Caddyfile protocol in lib/caddy/config/matcher/client_ip.ex
- [x] T013 [P] Create Matcher.Vars struct with Caddyfile protocol in lib/caddy/config/matcher/vars.ex
- [x] T014 [P] Create Matcher.VarsRegexp struct with Caddyfile protocol in lib/caddy/config/matcher/vars_regexp.ex
- [x] T015 [P] Create Matcher.Expression struct with Caddyfile protocol in lib/caddy/config/matcher/expression.ex
- [x] T016 [P] Create Matcher.File struct with Caddyfile protocol in lib/caddy/config/matcher/file.ex
- [x] T017 [P] Create Matcher.Not struct with Caddyfile protocol in lib/caddy/config/matcher/not.ex

### Matcher Type Tests (All [P] - parallel)

- [x] T018 [P] Create test for Matcher.Path in test/caddy/config/matcher/path_test.exs
- [x] T019 [P] Create test for Matcher.PathRegexp in test/caddy/config/matcher/path_regexp_test.exs
- [x] T020 [P] Create test for Matcher.Header in test/caddy/config/matcher/header_test.exs
- [x] T021 [P] Create test for Matcher.HeaderRegexp in test/caddy/config/matcher/header_regexp_test.exs
- [x] T022 [P] Create test for Matcher.Method in test/caddy/config/matcher/method_test.exs
- [x] T023 [P] Create test for Matcher.Query in test/caddy/config/matcher/query_test.exs
- [x] T024 [P] Create test for Matcher.Host in test/caddy/config/matcher/host_test.exs
- [x] T025 [P] Create test for Matcher.Protocol in test/caddy/config/matcher/protocol_test.exs
- [x] T026 [P] Create test for Matcher.RemoteIp in test/caddy/config/matcher/remote_ip_test.exs
- [x] T027 [P] Create test for Matcher.ClientIp in test/caddy/config/matcher/client_ip_test.exs
- [x] T028 [P] Create test for Matcher.Vars in test/caddy/config/matcher/vars_test.exs
- [x] T029 [P] Create test for Matcher.VarsRegexp in test/caddy/config/matcher/vars_regexp_test.exs
- [x] T030 [P] Create test for Matcher.Expression in test/caddy/config/matcher/expression_test.exs
- [x] T031 [P] Create test for Matcher.File in test/caddy/config/matcher/file_test.exs
- [x] T032 [P] Create test for Matcher.Not in test/caddy/config/matcher/not_test.exs

**Checkpoint**: ✅ All 15 matcher types implemented and tested - ready for user story implementation

---

## Phase 3: User Story 1 - Define Environment Variables (Priority: P1) 🎯 MVP

**Goal**: Enable developers to define environment variables in Caddy configuration using `{$VAR}` and `{$VAR:default}` syntax

**Independent Test**: Create EnvVar struct, render to Caddyfile, verify output contains correct `{$VAR}` syntax

### Tests for User Story 1

- [x] T033 [P] [US1] Create EnvVar test in test/caddy/config/env_var_test.exs

### Implementation for User Story 1

- [x] T034 [P] [US1] Create EnvVar struct with new/1 and new/2 functions in lib/caddy/config/env_var.ex
- [x] T035 [US1] Implement Caddyfile protocol for EnvVar in lib/caddy/config/env_var.ex
- [x] T036 [US1] Add validate/1 function returning {:ok, env_var} or {:error, reason} in lib/caddy/config/env_var.ex
- [x] T037 [US1] Add telemetry event for EnvVar rendering in lib/caddy/config/env_var.ex

**Checkpoint**: ✅ User Story 1 complete - EnvVar struct can render `{$VAR}` and `{$VAR:default}` syntax

---

## Phase 4: User Story 2 - Manage Named Matchers (Priority: P1)

**Goal**: Enable developers to define named matchers (`@name`) that combine multiple matcher conditions and can be referenced in site directives

**Independent Test**: Create NamedMatcher with multiple matcher types, add to Site, render to Caddyfile, verify `@name { ... }` syntax

### Tests for User Story 2

- [x] T038 [P] [US2] Create NamedMatcher test in test/caddy/config/named_matcher_test.exs
- [ ] T039 [P] [US2] Create Site matchers integration test in test/caddy/config/site_test.exs (add to existing)

### Implementation for User Story 2

- [x] T040 [US2] Create NamedMatcher struct with new/2 function in lib/caddy/config/named_matcher.ex
- [x] T041 [US2] Implement Caddyfile protocol for NamedMatcher (single-line and block syntax) in lib/caddy/config/named_matcher.ex
- [x] T042 [US2] Add validate/1 function for NamedMatcher in lib/caddy/config/named_matcher.ex
- [x] T043 [US2] Add telemetry event for NamedMatcher rendering in lib/caddy/config/named_matcher.ex
- [ ] T044 [US2] Update Site struct to add matchers field in lib/caddy/config/site.ex
- [ ] T045 [US2] Add Site.add_matcher/2 helper function in lib/caddy/config/site.ex
- [ ] T046 [US2] Update Site Caddyfile protocol to render matchers before imports in lib/caddy/config/site.ex

**Checkpoint**: ✅ NamedMatcher struct complete with all 15 matcher types supported. Site integration pending.

---

## Phase 5: User Story 3 - Support Named Routes (Priority: P2)

**Goal**: Enable developers to define named routes (`&(name)`) at config level that can be invoked from multiple sites

**Independent Test**: Create NamedRoute, add to Config, render to Caddyfile, verify `&(name) { ... }` appears between snippets and sites

### Tests for User Story 3

- [x] T047 [P] [US3] Create NamedRoute test in test/caddy/config/named_route_test.exs
- [ ] T048 [P] [US3] Create Config routes integration test in test/caddy/config_test.exs (add to existing)

### Implementation for User Story 3

- [x] T049 [US3] Create NamedRoute struct with new/2 function in lib/caddy/config/named_route.ex
- [x] T050 [US3] Implement Caddyfile protocol for NamedRoute in lib/caddy/config/named_route.ex
- [x] T051 [US3] Add validate/1 function for NamedRoute in lib/caddy/config/named_route.ex
- [x] T052 [US3] Add telemetry event for NamedRoute rendering in lib/caddy/config/named_route.ex
- [ ] T053 [US3] Update Config struct to add routes field in lib/caddy/config.ex
- [ ] T054 [US3] Update Config Caddyfile protocol to render routes after snippets in lib/caddy/config.ex

**Checkpoint**: ✅ NamedRoute struct complete. Config integration pending.

---

## Phase 6: User Story 4 - Import External Files and Snippets (Priority: P2)

**Goal**: N/A - Already implemented

**Status**: ✅ COMPLETE - The Import module already exists at lib/caddy/config/import.ex and fully satisfies FR-007 and FR-008 per research.md analysis.

**No tasks required for this user story.**

---

## Phase 7: User Story 5 - Configure Plugin Settings (Priority: P3)

**Goal**: Enable developers to configure Caddy plugins through typed structs for safe plugin configuration

**Independent Test**: Create PluginConfig, render to Caddyfile, verify plugin directive appears in output

### Tests for User Story 5

- [x] T055 [P] [US5] Create PluginConfig test in test/caddy/config/plugin_config_test.exs

### Implementation for User Story 5

- [x] T056 [US5] Create PluginConfig struct with new/2 function in lib/caddy/config/plugin_config.ex
- [x] T057 [US5] Implement Caddyfile protocol for PluginConfig (string and map options) in lib/caddy/config/plugin_config.ex
- [x] T058 [US5] Add validate/1 function for PluginConfig in lib/caddy/config/plugin_config.ex
- [x] T059 [US5] Add telemetry event for PluginConfig rendering in lib/caddy/config/plugin_config.ex

**Checkpoint**: ✅ User Story 5 complete - PluginConfig enables safe plugin configuration

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Quality assurance, documentation, and final validation

- [x] T060 Run mix test to verify all tests pass
- [x] T061 Run mix format --check-formatted to verify code formatting
- [ ] T062 Run mix credo --strict to verify code quality (style issues noted, non-blocking)
- [ ] T063 Run mix dialyzer to verify type correctness
- [x] T064 [P] Add @moduledoc documentation to all new modules
- [x] T065 [P] Add @doc with examples to all public functions
- [x] T066 Verify backward compatibility - existing tests still pass
- [ ] T067 Run quickstart.md validation - execute examples and verify output

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS User Story 2
- **User Story 1 (Phase 3)**: Can start after Setup (no dependency on matchers)
- **User Story 2 (Phase 4)**: Depends on Foundational (needs all matcher types)
- **User Story 3 (Phase 5)**: Can start after Setup (no dependencies)
- **User Story 4 (Phase 6)**: Already complete - no tasks
- **User Story 5 (Phase 7)**: Can start after Setup (no dependencies)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Setup - No dependencies on other stories
- **User Story 2 (P1)**: Must wait for Foundational phase (matcher types) - No dependencies on other stories
- **User Story 3 (P2)**: Can start after Setup - No dependencies on other stories
- **User Story 5 (P3)**: Can start after Setup - No dependencies on other stories

### Within Each User Story

- Tests should be written first (TDD per Constitution III)
- Struct before protocol implementation
- Protocol before validation
- Validation before telemetry
- Update parent structs (Site, Config) last

### Parallel Opportunities

**Phase 2 (Foundational)**: All 15 matcher implementations (T003-T017) can run in parallel. All 15 matcher tests (T018-T032) can run in parallel.

**User Stories**: US1, US3, US5 can all start immediately after Setup (in parallel if team capacity allows). Only US2 must wait for Foundational phase.

---

## Implementation Status Summary

| Phase | Status | Tasks Complete | Tasks Remaining |
|-------|--------|----------------|-----------------|
| Phase 1: Setup | ✅ Complete | 2/2 | 0 |
| Phase 2: Foundational | ✅ Complete | 30/30 | 0 |
| Phase 3: US1 EnvVar | ✅ Complete | 5/5 | 0 |
| Phase 4: US2 NamedMatcher | ⏳ Partial | 6/9 | 3 (Site integration) |
| Phase 5: US3 NamedRoute | ⏳ Partial | 6/8 | 2 (Config integration) |
| Phase 6: US4 Import | ✅ Complete | N/A | 0 |
| Phase 7: US5 PluginConfig | ✅ Complete | 5/5 | 0 |
| Phase 8: Polish | ⏳ Partial | 5/8 | 3 |

**Total Progress**: 59/67 tasks complete (88%)

**Remaining Work**:
- T039, T044-T046: Site struct integration for matchers
- T048, T053-T054: Config struct integration for routes
- T062-T063, T067: Additional quality checks

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- User Story 4 (Import) is already complete - no new work needed
- All new modules must implement `Caddy.Caddyfile` protocol
- All new modules must emit telemetry events per Constitution II
- Validation functions return `{:ok, value}` or `{:error, reason}` per clarification
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
