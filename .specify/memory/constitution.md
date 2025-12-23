<!--
Sync Impact Report
==================
Version change: 1.0.1 → 1.1.0
Modified principles: None
Added sections:
  - VI. Caddyfile Structure: Defines mandatory 3-part configuration architecture
    (global config, additionals list, site configs list)
Removed sections: None
Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ Compatible (no changes needed)
  - .specify/templates/spec-template.md: ✅ Compatible (no changes needed)
  - .specify/templates/tasks-template.md: ✅ Compatible (no changes needed)
Follow-up TODOs: None
-->

# Elixir Caddy Constitution

## Core Principles

### I. OTP-First Architecture

All features MUST follow OTP design principles. Components MUST be implemented as proper
OTP behaviors (GenServer, Agent, Supervisor) when managing state or processes. Supervision
trees MUST be used for fault tolerance. The library MUST be embeddable in any Elixir
application's supervision tree without side effects.

**Rationale**: OTP patterns provide battle-tested fault tolerance, process isolation, and
standardized interfaces that Elixir developers expect from production-grade libraries.

### II. Observability by Default

Every significant operation MUST emit telemetry events. The `Caddy.Telemetry` module serves
as the single source of truth for all observable events.

**Logging Requirements**:
- All logging MUST use `Caddy.Telemetry.log_*` functions (`log_debug/2`, `log_info/2`,
  `log_warning/2`, `log_error/2`)
- Direct usage of `Logger` module (Logger.debug, Logger.info, etc.) is PROHIBITED
- The default telemetry handler forwards log events to Elixir's Logger automatically
- Users MAY disable the default handler and attach custom handlers for their needs

**Rationale**: Telemetry-based logging decouples the library from specific logging
implementations. Users can integrate Caddy log events into their existing monitoring
infrastructure, filter events, or route them to external services without modifying
library code.

### III. Test-Driven Quality

Tests MUST be written before or alongside implementation. Mox MUST be used for mocking
external dependencies (HTTP clients, file system where appropriate). Tests MUST be
independent and not require external services (Caddy binary) to pass. Code MUST pass
Credo strict mode and Dialyzer before merge.

**Rationale**: High test coverage with mocked dependencies ensures reliability and enables
confident refactoring. Static analysis catches type errors and code smells early.

### IV. Configuration Transparency

All configuration options MUST be documented with clear defaults. Configuration paths
MUST be customizable via application environment. Runtime configuration changes MUST
be explicit (via API calls) rather than implicit. Breaking configuration changes MUST
follow semantic versioning.

**Rationale**: Users need predictable, well-documented configuration to integrate the
library into diverse deployment environments.

### V. Minimal Dependencies

External dependencies MUST be justified by significant functionality gain. Dependencies
MUST be actively maintained and widely adopted in the Elixir ecosystem. Dev/test
dependencies MUST be isolated from production builds.

**Rationale**: Fewer dependencies reduce security surface, simplify upgrades, and minimize
conflicts with user applications.

### VI. Caddyfile Structure

The `Caddy.Config` module MUST organize Caddyfile configuration into three distinct parts:

1. **Global Config**: Server-wide settings enclosed in `{ }` block at the top of Caddyfile
   (e.g., `debug`, `auto_https off`, admin socket configuration)
2. **Additionals Config**: A list of additional configuration blocks that are NOT site
   definitions (e.g., named matchers, snippets, import statements). Each additional MUST
   be stored and retrievable independently.
3. **Site Configs**: A list of site definitions, where each site has a unique identifier,
   address/matcher, and directive block. Sites MUST be independently addable, removable,
   and modifiable via API.

**Implementation Requirements**:
- `Caddy.Config` MUST provide separate getter/setter functions for each configuration part
- The generated Caddyfile MUST concatenate parts in order: global → additionals → sites
- Each site MUST be identifiable by a user-provided key for targeted updates
- Configuration changes MUST emit telemetry events per Principle II

**Rationale**: Separating configuration into logical parts enables granular management of
Caddy settings. Users can modify individual sites or global settings without regenerating
the entire configuration, supporting dynamic proxy management in production environments.

## Quality Standards

- **Static Analysis**: All code MUST pass `mix credo --strict` and `mix dialyzer`
- **Formatting**: All code MUST pass `mix format --check-formatted`
- **Documentation**: Public modules MUST have `@moduledoc`, public functions MUST have `@doc`
- **Type Specs**: Public functions SHOULD have `@spec` annotations
- **Test Coverage**: New features MUST include corresponding tests
- **Logging**: All log statements MUST use `Caddy.Telemetry.log_*` functions

## Development Workflow

1. **Feature Development**: Create feature branch from `main`
2. **Implementation**: Follow TDD - write tests, see them fail, implement, refactor
3. **Quality Gates**: Run `mix lint` (credo + dialyzer) before committing
4. **Code Review**: All changes require PR review before merge
5. **Versioning**: Follow semantic versioning for releases

## Governance

This constitution supersedes informal practices. All pull requests MUST verify compliance
with these principles. Reviewers SHOULD reference specific principles when requesting changes.

**Amendment Process**:
1. Propose amendment via pull request to this file
2. Document rationale and impact on existing code
3. Update dependent templates if principles change
4. Increment constitution version according to semantic versioning

**Compliance Review**: Quarterly review of codebase against constitution principles is
RECOMMENDED. Non-compliant code discovered should be addressed via dedicated refactoring
tasks.

**Version**: 1.1.0 | **Ratified**: 2025-12-15 | **Last Amended**: 2025-12-22
