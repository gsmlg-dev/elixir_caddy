# Feature Specification: Fix API Contracts and Harden Error Handling

**Feature Branch**: `001-fix-api-contracts`
**Created**: 2026-03-07
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reliable Config Push on Caddy Startup (Priority: P1)

As a developer using this library, when my application starts and Caddy transitions to running, the initial configuration is reliably pushed without crashing the process — even on the first boot or after a restart.

**Why this priority**: The current API contract mismatch between the server and admin modules causes a `CaseClauseError` on the exact path that runs when Caddy starts, making the startup flow unreliable in normal conditions.

**Independent Test**: Can be fully tested by simulating the external Caddy startup sequence in isolation — verifying that config adaptation and loading complete successfully and return structured results, delivering a functional startup flow.

**Acceptance Scenarios**:

1. **Given** Caddy is transitioning to the running state, **When** the initial config push is triggered, **Then** configuration is adapted and loaded without raising an exception.
2. **Given** the config adaptation step returns a failure, **When** the startup sequence handles it, **Then** the failure is captured as a structured error and the process does not crash.
3. **Given** the config load step receives a non-success status, **When** the startup sequence handles it, **Then** the failure is captured as a structured error and the process does not crash.

---

### User Story 2 - Accurate Runtime Config Retrieval (Priority: P1)

As a developer, when I call the function to retrieve the current running Caddy configuration, the result accurately reflects what Caddy is serving — or a clear empty/nil result when Caddy is not yet running.

**Why this priority**: The current implementation silently returns an empty string even when a live config exists, masking real runtime state and making diagnosis of configuration issues impossible.

**Independent Test**: Can be tested by mocking the admin API to return a valid config map and verifying the retrieval function returns that config rather than an empty fallback.

**Acceptance Scenarios**:

1. **Given** Caddy is running with an active config, **When** the get-config function is called, **Then** the current config is returned as structured data.
2. **Given** Caddy is not yet running or the admin API is unreachable, **When** the get-config function is called, **Then** a clear empty or nil result is returned without masking any available data.

---

### User Story 3 - Safe Config Merge Against Unavailable Runtime (Priority: P2)

As a developer, when I load a configuration update and the running Caddy instance is temporarily unreachable, the operation returns a clear error instead of crashing the calling process.

**Why this priority**: A nil runtime config during a map-merge causes an uncontrolled crash (BadMapError) that propagates to the caller instead of a structured failure they can handle.

**Independent Test**: Can be tested by mocking the runtime config fetch to return nil and asserting the merge operation returns a structured error tuple.

**Acceptance Scenarios**:

1. **Given** the running Caddy admin API is unavailable, **When** a config load with a map argument is issued, **Then** the function returns a structured failure result, not an exception.
2. **Given** the running Caddy admin API returns a valid config, **When** a config load with a map argument is issued, **Then** the configs are merged and loaded successfully.

---

### User Story 4 - Non-Crashing HTTP Body Read Errors (Priority: P2)

As a developer, when a network socket error or partial body read occurs during an admin API call, the library returns a structured error instead of raising an exception in the request worker.

**Why this priority**: An exception in the HTTP transport layer can cascade into process instability under network issues, making the library unreliable in any environment with transient connectivity problems.

**Independent Test**: Can be tested by simulating a body-read error in the request pipeline and asserting a structured error tuple is returned, with no exception raised.

**Acceptance Scenarios**:

1. **Given** a socket read returns an error during body retrieval, **When** the response is being parsed, **Then** the error is returned as a structured failure, not raised as an exception.
2. **Given** a response body contains malformed content, **When** the response is being decoded, **Then** a structured error is returned instead of an exception.

---

### User Story 5 - Expanded Behavioral Test Coverage (Priority: P3)

As a developer maintaining this library, the test suite catches regressions in critical runtime paths — not just verifying that functions exist and structs have correct fields.

**Why this priority**: Current tests are predominantly shape and arity checks. Runtime logic paths (startup, adapt, load, request parsing) are untested, allowing regressions to pass CI silently.

**Independent Test**: Can be verified by running the test suite and confirming new tests exercise the adapt-success, adapt-failure, load-success, load-non-2xx, and request transport-error scenarios.

**Acceptance Scenarios**:

1. **Given** the test suite runs, **When** the adapt step succeeds, **Then** a test asserts the structured success result.
2. **Given** the test suite runs, **When** the adapt step fails, **Then** a test asserts the structured error result.
3. **Given** the test suite runs, **When** the load step returns a non-2xx status, **Then** a test asserts the failure is captured correctly.
4. **Given** the test suite runs, **When** a request encounters a transport error, **Then** a test asserts a structured error is returned without exceptions.

---

### Edge Cases

- What happens when the admin API returns an unexpected response shape not covered by current match clauses?
- How does the system behave if Caddy's admin socket does not yet exist when config push is triggered?
- What happens if the command string for launching an external Caddy process is empty or contains paths with spaces?
- How does the system handle a body that is valid bytes but not valid JSON?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The config retrieval function MUST return the actual runtime configuration as structured data when Caddy is running, and a clear nil or empty result when it is not.
- **FR-002**: The config adaptation call MUST return a consistent structured result (success or failure) regardless of what the underlying admin endpoint returns.
- **FR-003**: The config load call MUST return a consistent structured result (success or failure) for all response statuses, including non-2xx responses.
- **FR-004**: The config merge-and-load operation MUST return a structured failure when the runtime config is unavailable, without raising an exception.
- **FR-005**: The HTTP body read path MUST return a structured failure for any socket or read error, without raising an exception.
- **FR-006**: The HTTP response decode path MUST return a structured failure for malformed content, without raising an exception.
- **FR-007**: The test suite MUST include behavior-focused tests covering: successful config push startup, adapt success and failure, load success and non-2xx failure, and request transport error normalization.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero unhandled exceptions (CaseClauseError, BadMapError, or decode exceptions) occur on the config push startup path under normal and failure-mode conditions.
- **SC-002**: All API-facing functions return a consistent structured result type for both success and failure cases, with 100% of identified contract mismatches resolved.
- **SC-003**: Test coverage for the identified critical paths increases from shape/arity checks to behavioral assertions, with at least one test per identified failure scenario in the review findings.
- **SC-004**: The library remains stable (no process crashes) when the Caddy admin interface is transiently unavailable during config operations.

## Assumptions

- The library's existing public API signatures are not changed — only internal return value handling and error normalization.
- The mock/behaviour infrastructure (`Caddy.Admin.RequestMock`) already in place is sufficient to support the new behavioral tests without additional test infrastructure.
- Command string parsing improvement (quoted paths with spaces) is in scope only as a defensive validation guard, not a full shell tokenizer implementation.
