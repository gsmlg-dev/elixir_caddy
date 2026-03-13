# Internal Function Contracts

This feature has no external REST API changes. The contracts below describe the corrected
internal function signatures and their expected input/output behaviors.

---

## `Caddy.Server.External.get_caddyfile/0`

**File**: `lib/caddy/server/external.ex`

```elixir
@spec get_caddyfile() :: binary()
```

| Scenario | Input (via `Api.get_config/0`) | Expected Output |
|----------|-------------------------------|-----------------|
| Caddy running, config loaded | `%{"apps" => ...}` (non-nil map) | JSON-encoded config string |
| Caddy not running | `nil` | `""` |
| Caddy returns empty config | `%{}` | `"{}"` or `""` (both acceptable) |

**Before**: Matched `{:ok, _resp, config}` which never fires — always returned `""`.
**After**: Matches `map | nil` directly.

---

## `Caddy.Server.External.push_initial_config/0` (private)

**File**: `lib/caddy/server/external.ex`

```elixir
@spec push_initial_config() :: :ok | {:error, term()}
```

| Scenario | `Api.adapt/1` return | `Api.load/1` return | Expected Output |
|----------|---------------------|---------------------|-----------------|
| Success | non-empty map | `%{status: 200, ...}` | `:ok` |
| Adapt connection failure | `%{}` (empty) | (not called) | `{:error, :invalid_adapt_response}` |
| Load non-2xx | non-empty map | `%{status: 400, ...}` | `{:error, {:load_failed, 400}}` |
| Load connection failure | non-empty map | `%{status: 0, body: nil}` | `{:error, {:load_failed, 0}}` |
| Empty Caddyfile | (not called) | (not called) | `:ok` |

**Before**: `case Api.adapt(caddyfile) do {:ok, ...}` — never matched, silent failure.
**After**: Checks `is_map(result) and map_size(result) > 0` for adapt, checks `%{status: s}` for load.

---

## `Caddy.Admin.Api.load/1` (map variant)

**File**: `lib/caddy/admin/api.ex`

```elixir
@spec load(map()) :: Caddy.Admin.Request.t() | %{status: 0, body: nil}
```

| Scenario | `get_config/0` return | Expected Output |
|----------|-----------------------|-----------------|
| Runtime available | `%{"apps" => ...}` | Merged config loaded, `%Request{status: 200}` |
| Runtime unavailable | `nil` | `%{status: 0, body: nil}` (no exception) |

**Before**: `get_config() |> Map.merge(conf)` — raises `BadMapError` when `get_config()` returns nil.
**After**: `case get_config() do nil -> %{status: 0, body: nil}; current -> ... end`

---

## `Caddy.Admin.Request.do_recv/3` (private)

**File**: `lib/caddy/admin/request.ex`

```elixir
# Internal — not exported
```

| Scenario | `read_body/2` result | Content-Type | Expected Output |
|----------|---------------------|--------------|-----------------|
| Success, JSON | `"{ ... }"` binary | `application/json` | `{:ok, resp, decoded_map}` |
| Success, plain | `"text"` binary | other | `{:ok, resp, "text"}` |
| Body read error | `{:error, :timeout}` | any | `{:error, :timeout}` |
| Malformed JSON | `"not json"` binary | `application/json` | `{:error, {:decode_error, reason}}` |

**Before**: `JSON.decode!(read_body(...))` — raises on `{:error, reason}` input.
**After**: Check read_body result first; use `JSON.decode/1`; propagate errors as tuples.

---

## `Caddy.Server.External.execute_shell_command/1` (private)

**File**: `lib/caddy/server/external.ex`

```elixir
# Internal — not exported
```

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Valid command | `"systemctl start caddy"` | `{:ok, output}` or `{:error, ...}` |
| Empty command | `""` | `{:error, :empty_command}` |
| Command exits non-zero | any | `{:error, {:command_failed, exit_code, output}}` |
| Executable not found | any | `{:error, {:command_error, :enoent}}` |

**Before**: Empty string silently passed to `System.cmd("", [])`, rescued as generic ErlangError.
**After**: Explicit guard clause for `""` returns `{:error, :empty_command}`.
