# Tasks: Fix API Contracts and Harden Error Handling

**Input**: Design documents from `/specs/001-fix-api-contracts/`
**Branch**: `001-fix-api-contracts`
**Tests**: Included — explicitly required by FR-007 and User Story 5 (US5)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths included in each task description

---

## Phase 1: Setup (Baseline Verification)

**Purpose**: Confirm the starting state before any changes. No new files or infrastructure needed — this is a bug-fix feature.

- [x] T001 Read `lib/caddy/server/external.ex`, `lib/caddy/admin/api.ex`, `lib/caddy/admin/request.ex` and confirm the five bug locations match the plan
- [x] T002 Run `mix test test/caddy/admin/api_test.exs test/caddy/admin/request_test.exs test/caddy/server/external_test.exs` and confirm all existing tests pass as a baseline
- [x] T003 [P] Run `mix credo --strict` and record any pre-existing violations (do not fix them yet)
- [x] T004 [P] Run `mix dialyzer` and record any pre-existing warnings (do not fix them yet)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: These two fixes are in the same files as later story fixes but are the safest changes — they establish consistent error returns and must land before test tasks that depend on mock behavior.

**⚠️ CRITICAL**: Complete both tasks before starting any User Story phase.

- [x] T005 Remove unused `require Logger` at line 30 of `lib/caddy/admin/api.ex` (Credo strict: unused import)
- [x] T006 Replace `Logger.debug/1` call at line 171 of `lib/caddy/admin/request.ex` with `Caddy.Telemetry.log_debug/2` using `module: __MODULE__, socket: inspect(socket), acc_length: length(acc)` metadata; remove `require Logger` and `alias ... Logger` lines if no other Logger calls remain in the file

**Checkpoint**: Run `mix credo --strict` — both violations from T003 baseline should now be resolved.

---

## Phase 3: User Story 1 — Reliable Config Push on Caddy Startup (Priority: P1) 🎯 MVP

**Goal**: `push_initial_config/0` in `Caddy.Server.External` correctly matches `Api.adapt/1` return (`map()`, not a tuple) and `Api.load/1` return (`%{status:, body:}` struct, not a tuple), so the startup config push path never raises `CaseClauseError`.

**Independent Test**: Mock `Caddy.Admin.RequestMock` to return a successful adapt (non-empty map) and a 200 load; call `External.push_config/0` via a running supervised GenServer; assert `:ok` is returned.

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementing T010**

- [ ] T007 [US1] Add `describe "push_config/0"` block to `test/caddy/server/external_test.exs`; add a `setup` helper that mocks the initial health-check call (mock `get` on `"/config/"` → `{:error, :econnrefused}`) and starts `External` with `start_supervised!(Caddy.Server.External)`
- [ ] T008 [P] [US1] Add test in `test/caddy/server/external_test.exs`: mock `post` on `"/adapt"` → `{:ok, %Request{status: 200}, %{"apps" => %{}}}` and `post` on `"/load"` → `{:ok, %Request{status: 200}, ""}`, call `External.push_config()`, assert `:ok` returned
- [ ] T009 [P] [US1] Add test in `test/caddy/server/external_test.exs`: mock `post` on `"/adapt"` → `{:ok, %Request{status: 200}, %{}}` (empty map = adapt failure), call `External.push_config()`, assert `{:error, :invalid_adapt_response}` returned
- [ ] T010 [P] [US1] Add test in `test/caddy/server/external_test.exs`: mock `post` on `"/adapt"` → `{:ok, %Request{status: 200}, %{"apps" => %{}}}` and `post` on `"/load"` → `{:ok, %Request{status: 400}, "bad config"}`, call `External.push_config()`, assert `{:error, {:load_failed, 400}}` returned
- [ ] T011 [P] [US1] Add test in `test/caddy/server/external_test.exs`: mock adapt → non-empty map, mock load → `{:ok, %Request{status: 0}, nil}` (connection failure map), call `External.push_config()`, assert `{:error, :load_connection_failed}` returned

### Implementation for User Story 1

- [ ] T012 [US1] In `lib/caddy/server/external.ex`, replace the `case Api.adapt(caddyfile) do` block in `push_initial_config/0` (lines ~381–400): match `json_config when is_map(json_config) and map_size(json_config) > 0` for adapt success; match `_ ->` for adapt failure returning `{:error, :invalid_adapt_response}`; inside the success branch, match `Api.load/1` result as `%{status: status} when status in 200..299 ->` `:ok`, `%{status: 0} ->` `{:error, :load_connection_failed}`, `%{status: status} ->` `{:error, {:load_failed, status}}`
- [ ] T013 [US1] Run `mix test test/caddy/server/external_test.exs` and confirm T007–T011 tests now pass

**Checkpoint**: User Story 1 fully functional. Config push startup path no longer raises on any response shape.

---

## Phase 4: User Story 2 — Accurate Runtime Config Retrieval (Priority: P1)

**Goal**: `get_caddyfile/0` in `Caddy.Server.External` matches the actual return of `Api.get_config/0` (`map() | nil`, not `{:ok, resp, body}` tuple), so the current runtime config is returned accurately instead of always returning `""`.

**Independent Test**: Mock `Caddy.Admin.RequestMock` to return a map from `/config/`; call `External.get_caddyfile/0` directly (public function, no GenServer needed); assert a non-empty JSON string is returned.

### Tests for User Story 2

> **Write these tests FIRST, ensure they FAIL before implementing T016**

- [ ] T014 [P] [US2] Add test in `test/caddy/server/external_test.exs` under `describe "get_caddyfile/0"`: mock `get` on `"/config/"` → `{:ok, %Request{status: 200}, %{"apps" => %{"http" => %{}}}}`, call `External.get_caddyfile()`, assert result is a non-empty binary containing `"apps"`
- [ ] T015 [P] [US2] Add test in `test/caddy/server/external_test.exs`: mock `get` on `"/config/"` → `{:error, :econnrefused}`, call `External.get_caddyfile()`, assert result is `""`

### Implementation for User Story 2

- [ ] T016 [US2] In `lib/caddy/server/external.ex`, replace the `case Api.get_config() do` block in `get_caddyfile/0` (lines ~108–116): change `{:ok, _resp, config} when is_map(config)` to `config when is_map(config)`; keep the catch-all `_ -> ""` unchanged
- [ ] T017 [US2] Run `mix test test/caddy/server/external_test.exs` and confirm T014–T015 tests now pass

**Checkpoint**: User Stories 1 AND 2 fully functional. `external.ex` has no remaining contract mismatches.

---

## Phase 5: User Story 3 — Safe Config Merge Against Unavailable Runtime (Priority: P2)

**Goal**: `Api.load/1` map variant guards the `Map.merge` against a `nil` return from `get_config/0`, returning `%{status: 0, body: nil}` instead of raising `BadMapError`.

**Independent Test**: Mock `get` on `"/config/"` → `{:error, :econnrefused}` (causing `get_config/0` to return `nil`); call `Api.load(%{"foo" => "bar"})`; assert `%{status: 0, body: nil}` returned without exception.

### Tests for User Story 3

> **Write this test FIRST, ensure it FAILS before implementing T020**

- [x] T018 [P] [US3] Add test in `test/caddy/admin/api_test.exs` under `describe "load/1"`: mock `get` on `"/config/"` → `{:error, :econnrefused}`, call `Api.load(%{"foo" => "bar"})`, assert `%{status: 0, body: nil}` returned (no exception raised)

### Implementation for User Story 3

- [x] T019 [US3] In `lib/caddy/admin/api.ex`, replace the `load(conf) when is_map(conf)` body (lines ~91–96): wrap with `case get_config() do; current when is_map(current) -> current |> Map.merge(conf) |> JSON.encode!()() |> load(); nil -> %{status: 0, body: nil}; end`
- [x] T020 [US3] Run `mix test test/caddy/admin/api_test.exs` and confirm T018 passes along with all pre-existing `load/1` tests

**Checkpoint**: User Story 3 fully functional. `api.ex` load map path no longer crashes on nil runtime config.

---

## Phase 6: User Story 4 — Non-Crashing HTTP Body Read Errors (Priority: P2)

**Goal**: `Request.do_recv/3` safely handles body-read errors and JSON decode errors by returning `{:error, reason}` tuples instead of raising exceptions.

**Independent Test**: Via `ApiTest` mock infrastructure — mock the request module to return `{:error, :timeout}` from a `get` call; verify the Api-level caller receives the error rather than crashing.

*Note*: `Request` itself is the real HTTP implementation; it cannot be mocked at its own level. The correctness of `do_recv` is validated through the full stack. The new clause in `do_recv` is validated via direct calling patterns inside `read_body` error scenarios.

### Tests for User Story 4

- [x] T021 [P] [US4] Add test in `test/caddy/admin/request_test.exs` under `describe "Error handling"`: verify that `{:error, reason}` returned from a transport-level call is propagated — mock `Caddy.Admin.RequestMock.get/1` (in ApiTest, not RequestTest) to return `{:error, :timeout}` and verify `Api.get/1` returns `%{status: 0, body: nil}` and does not raise (this validates the full pipeline contract, not the internal `do_recv` directly)
- [x] T022 [P] [US4] Add test in `test/caddy/admin/api_test.exs`: mock `post` on `"/adapt"` → `{:error, :closed}`, call `Api.adapt("something")`, assert `%{}` returned (no exception)

### Implementation for User Story 4

- [x] T023 [US4] In `lib/caddy/admin/request.ex`, rewrite `do_recv(socket, {:ok, :http_eoh}, resp)` (lines ~127–136): first `case read_body(socket, resp) do {:error, reason} -> {:error, reason}; body -> ...end`; inside the body branch, use `JSON.decode(body)` (not `decode!`) and handle both `{:ok, decoded}` and `{:error, reason}` returning `{:error, {:decode_error, reason}}` on failure
- [x] T024 [US4] Run `mix test test/caddy/admin/request_test.exs test/caddy/admin/api_test.exs` and confirm T021–T022 pass with no regressions

**Checkpoint**: User Story 4 fully functional. HTTP transport errors no longer propagate as raised exceptions.

---

## Phase 7: User Story 5 — Expanded Behavioral Test Coverage (Priority: P3)

**Goal**: Verify that all five bug scenarios are covered by named, assertion-based tests that would catch regressions in CI. This phase validates the test gaps identified in the review.

**Independent Test**: Run `mix test` suite — all test files must pass; test count in `external_test.exs`, `api_test.exs`, and `request_test.exs` must each be higher than the Phase 1 baseline.

### Implementation for User Story 5

- [x] T025 [P] [US5] Add `describe "execute_shell_command/0 with empty command"` in `test/caddy/server/external_test.exs`: configure `Application.put_env(:caddy, :commands, start: "")` before calling `External.execute_command(:start)`, assert `{:error, :empty_command}` returned (this requires Fix 5 below to be implemented first)
- [x] T026 [P] [US5] Review `test/caddy/admin/api_test.exs` — add a test under `describe "adapt/1"` for the case where the mock returns `{:ok, %Request{status: 400}, %{"error" => "bad caddyfile"}}` and assert the map is returned (validates non-2xx adapt does not crash) — pre-existing test "handles syntax errors in caddyfile" already covers this
- [x] T027 [P] [US5] Add `describe "load/1 with map — nil runtime"` integration note comment in `test/caddy/admin/api_test.exs` linking to T018 (already added in Phase 5); confirm the test description matches the review finding #2
- [x] T028 [US5] Implement Fix 5: in `lib/caddy/server/external.ex`, add a guard clause `defp execute_shell_command(""), do: {:error, :empty_command}` immediately before the existing `defp execute_shell_command(cmd_string)` definition (lines ~340)
- [x] T029 [US5] Run `mix test` (full suite) and confirm count of passing tests is higher than Phase 1 baseline; all new tests pass

**Checkpoint**: All five user stories complete. Full behavioral test coverage for all identified regression paths.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates, formatting, and final verification across all changes.

- [x] T030 [P] Run `mix format` and fix any formatting issues introduced in the changed files (`api.ex`, `request.ex`, `external.ex`, all test files)
- [x] T031 [P] Run `mix credo --strict` — confirm zero violations; ensure T005 and T006 fully resolved the Logger violations and no new issues introduced
- [x] T032 [P] Run `mix dialyzer` — confirm no new warnings introduced; update `@spec` annotations if Dialyzer flags the updated `load/1` map variant return type
- [x] T033 Run `mix test` (full suite) one final time — confirm all tests pass and no regressions from formatting/spec updates
- [x] T034 Review `specs/001-fix-api-contracts/quickstart.md` implementation guide and verify each code pattern example in the quickstart matches the final implementation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — removes Logger violations before test baselines
- **US1 (Phase 3)**: Depends on Phase 2; requires `Caddy.Admin.RequestMock` (pre-existing)
- **US2 (Phase 4)**: Depends on Phase 2; can run in parallel with US1 (different functions in `external.ex`)
- **US3 (Phase 5)**: Depends on Phase 2; fully independent — touches only `api.ex`
- **US4 (Phase 6)**: Depends on Phase 2; fully independent — touches only `request.ex`
- **US5 (Phase 7)**: Depends on US1–US4 being complete (tests reference those fixes)
- **Polish (Phase 8)**: Depends on all story phases complete

### User Story Dependencies

- **US1 (P1)**: After Foundational — no story dependencies
- **US2 (P1)**: After Foundational — no story dependencies; parallel with US1 if different file sections edited
- **US3 (P2)**: After Foundational — fully independent (different file from US1/US2)
- **US4 (P2)**: After Foundational — fully independent (different file from US1/US2/US3)
- **US5 (P3)**: After US1–US4 — validates all fixes are covered by tests

### Within Each User Story

- Test tasks (T00x for tests) MUST be written and confirmed FAILING before implementation
- Implementation task follows immediately after tests fail
- Run the scoped test suite to confirm green before moving to next story

### Parallel Opportunities

- T003 and T004 (credo + dialyzer baseline) can run in parallel
- T008, T009, T010, T011 (US1 test cases) can all be written in parallel (same file, different test blocks)
- T014 and T015 (US2 tests) can be written in parallel
- US3 (Phase 5) and US4 (Phase 6) can be worked in parallel by two developers (different files)
- T030, T031, T032 (Polish) can run in parallel

---

## Parallel Example: US3 and US4 (simultaneous)

```text
Developer A — Phase 5: US3 (api.ex)
  T018: Add nil runtime config test to api_test.exs
  T019: Implement nil-guard in api.ex load/1
  T020: Run api_test.exs

Developer B — Phase 6: US4 (request.ex)
  T021: Add transport error test to request_test.exs
  T022: Add adapt error test to api_test.exs
  T023: Rewrite do_recv/3 in request.ex
  T024: Run request_test.exs + api_test.exs
```

---

## Implementation Strategy

### MVP (User Stories 1 + 2 Only)

1. Complete Phase 1: Baseline verification
2. Complete Phase 2: Foundational (Logger fixes)
3. Complete Phase 3: User Story 1 (push_initial_config fix) — eliminates CaseClauseError on startup
4. Complete Phase 4: User Story 2 (get_caddyfile fix) — eliminates silent empty return
5. **STOP and VALIDATE**: Run `mix test test/caddy/server/external_test.exs`
6. The startup path is now stable — deliverable as a patch

### Full Fix Delivery (All 5 Stories)

1. Phase 1 → Phase 2 (baseline + Logger)
2. Phase 3 + Phase 4 in sequence (US1 → US2 in external.ex)
3. Phase 5 + Phase 6 in parallel (US3 in api.ex, US4 in request.ex)
4. Phase 7 (US5 — test coverage validation + Fix 5 empty command)
5. Phase 8 (Polish — format, credo, dialyzer, final test run)

---

## Notes

- [P] tasks = different files or independent test blocks, no write conflicts
- [Story] label maps each task to its user story for traceability
- No new dependencies are added — Mox infrastructure is pre-existing
- Caddy binary NOT required to run any test (all mocked via `Caddy.Admin.RequestMock`)
- Quality gate: `mix credo --strict` + `mix dialyzer` + `mix format --check-formatted` must all pass before merge
- Fixes 1–5 (code) and Fixes 6–7 (constitution) are all bundled; do not skip Fixes 6–7

## Total Task Count

| Phase | Tasks | Notes |
|-------|-------|-------|
| Phase 1: Setup | T001–T004 | 4 tasks |
| Phase 2: Foundational | T005–T006 | 2 tasks |
| Phase 3: US1 Config Push | T007–T013 | 7 tasks (5 test + 2 impl) |
| Phase 4: US2 Config Retrieval | T014–T017 | 4 tasks (2 test + 2 impl) |
| Phase 5: US3 Nil Guard | T018–T020 | 3 tasks (1 test + 2 impl) |
| Phase 6: US4 Safe Decode | T021–T024 | 4 tasks (2 test + 2 impl) |
| Phase 7: US5 Test Coverage | T025–T029 | 5 tasks (3 test + 2 impl) |
| Phase 8: Polish | T030–T034 | 5 tasks |
| **Total** | **T001–T034** | **34 tasks** |
