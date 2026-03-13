# Quickstart: Implementing API Contract Fixes

## Overview

This feature fixes five concrete bugs in three files. All changes are internal; no public
API signatures change. Implementation order follows risk/impact:

1. `Api.load/1` nil-guard (isolated, lowest risk)
2. `Request.do_recv/3` safe decode (isolated, lowest risk)
3. `External.get_caddyfile/0` pattern fix (isolated)
4. `External.push_initial_config/0` double contract fix (depends on understanding 3)
5. `execute_shell_command/1` empty guard (isolated)
6. Constitution compliance: replace `Logger.debug` → `Caddy.Telemetry.log_debug` in `request.ex`
7. Constitution compliance: remove unused `require Logger` from `api.ex`

## Running Tests

```bash
# Run all tests
mix test

# Run scoped tests for this feature
mix test test/caddy/admin/api_test.exs
mix test test/caddy/admin/request_test.exs
mix test test/caddy/server/external_test.exs

# Quality gates (must pass before merge)
mix credo --strict
mix dialyzer
mix format --check-formatted
```

## Key Patterns

### Pattern 1: Consuming `Api.get_config/0` correctly

```elixir
# WRONG (current External.get_caddyfile)
case Api.get_config() do
  {:ok, _resp, config} when is_map(config) -> ...  # never matches

# CORRECT
case Api.get_config() do
  config when is_map(config) -> ...
  nil -> ...
end
```

### Pattern 2: Consuming `Api.adapt/1` correctly

```elixir
# WRONG (current push_initial_config)
case Api.adapt(caddyfile) do
  {:ok, _resp, json_config} -> ...  # never matches

# CORRECT
json_config = Api.adapt(caddyfile)
if is_map(json_config) and map_size(json_config) > 0 do
  ...
else
  {:error, :invalid_adapt_response}
end
```

### Pattern 3: Consuming `Api.load/1` correctly

```elixir
# WRONG (current push_initial_config)
case Api.load(json_config) do
  {:ok, _resp, _body} -> :ok  # never matches
  {:error, reason} -> {:error, reason}  # never matches

# CORRECT
case Api.load(json_config) do
  %{status: status} when status in 200..299 -> :ok
  %{status: 0} -> {:error, :load_connection_failed}
  %{status: status} -> {:error, {:load_failed, status}}
end
```

### Pattern 4: Safe body decode in `Request`

```elixir
# WRONG (raises on socket error)
"application/json" -> {:ok, resp, JSON.decode!(read_body(socket, resp))}

# CORRECT (propagates errors)
"application/json" ->
  case read_body(socket, resp) do
    {:error, reason} -> {:error, reason}
    body ->
      case JSON.decode(body) do
        {:ok, decoded} -> {:ok, resp, decoded}
        {:error, reason} -> {:error, {:decode_error, reason}}
      end
  end
```

## New Test Cases Required

### `test/caddy/admin/api_test.exs`

- `load/1` with map when `get_config` returns `nil` → `%{status: 0, body: nil}` (no exception)

### `test/caddy/admin/request_test.exs`

These cannot use the Mox mock (Request IS the mock target). They test private behavior
indirectly through integration or by testing the public `get/1`, `post/3` behaviour
with a controlled socket error scenario.

### `test/caddy/server/external_test.exs`

All require `Caddy.Admin.RequestMock` setup (already used in the file).

- `get_caddyfile/0` when `get_config` returns a map → JSON string returned
- `get_caddyfile/0` when `get_config` returns `nil` → `""` returned
- `push_config/0` (via `handle_call`) when adapt succeeds and load returns 200 → `:ok`
- `push_config/0` when adapt returns empty map → `{:error, :invalid_adapt_response}`
- `push_config/0` when load returns non-2xx → `{:error, {:load_failed, status}}`
- `execute_command/1` with empty command string → `{:error, :empty_command}`
