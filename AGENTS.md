# Repository Guidelines

## Project Structure & Module Organization
Core library code lives in `lib/caddy/**` and is organized by domain (`admin`, `server`, `logger`, `metrics`, `config_manager`). The public entrypoint is `lib/caddy.ex`.

Tests live in `test/**` and mirror the source layout (for example, `lib/caddy/admin/api.ex` -> `test/caddy/admin/api_test.exs`). Shared test setup is in `test/test_helper.exs`.

Supporting material:
- `examples/` contains runnable demos, including a full Phoenix dashboard app in `examples/caddy_dashboard/`.
- `specs/` contains design artifacts and implementation plans.
- `.github/workflows/` defines CI gates.

## Build, Test, and Development Commands
- `mix deps.get`: install dependencies.
- `mix compile --warnings-as-errors`: compile with CI-level strictness.
- `mix test`: run ExUnit tests.
- `mix coveralls` or `mix coveralls.html`: run coverage via ExCoveralls.
- `mix format`: apply formatting.
- `mix format --check-formatted`: verify formatting (CI format job).
- `mix credo --strict`: static linting.
- `mix dialyzer`: type/spec analysis using PLTs in `priv/plts`.
- `mix lint`: project alias for `credo --strict` + `dialyzer`.

## Coding Style & Naming Conventions
Use standard Elixir formatting (`.formatter.exs`) with 2-space indentation and keep lines within Credo expectations (max ~120 chars). Prefer descriptive module names under `Caddy.*` and snake_case function names.

Files should follow Elixir conventions:
- Modules: `lib/caddy/foo_bar.ex` -> `Caddy.FooBar`
- Tests: `test/**/foo_bar_test.exs`

Run `mix format` and `mix credo` before opening a PR.

## Testing Guidelines
Use ExUnit for all tests and Mox for behaviour-based mocks. Name tests `*_test.exs`, mirror source paths, and keep assertions focused on observable behavior.

Before submitting changes, run:
- `mix test`
- `mix coveralls` (or `mix coveralls.html` when reviewing coverage locally)

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style seen in history:
- `feat(config): ...`
- `fix(example): ...`
- `docs: ...`
- `chore: ...`

PRs should include:
- A concise description of user-facing and internal changes
- Linked issue/spec when relevant
- Test updates for behavior changes
- Screenshots/GIFs for `examples/caddy_dashboard` UI changes

Ensure CI passes: compile, format check, Credo, Dialyzer, and test coverage.
