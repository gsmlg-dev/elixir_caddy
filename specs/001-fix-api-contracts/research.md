# Research: Fix API Contracts and Harden Error Handling

## Bug Analysis (from codebase review)

### Bug 1: `External.get_caddyfile/0` — Contract Mismatch

**Location**: `lib/caddy/server/external.ex:108-115`

**Current code**:
```elixir
case Api.get_config() do
  {:ok, _resp, config} when is_map(config) ->
    JSON.encode!(config)
  _ ->
    ""
end
```

**Actual return of `Api.get_config/0`**: `map() | nil` (lines 170-188 of `api.ex`).

**Effect**: The `{:ok, _resp, config}` pattern never matches. The catch-all `_` always fires. `get_caddyfile/0` always returns `""` regardless of runtime state.

**Fix decision**: Update the pattern match in `External.get_caddyfile/0` to match the actual return type (`map | nil`).

---

### Bug 2: `External.push_initial_config/0` — Double Contract Mismatch

**Location**: `lib/caddy/server/external.ex:381-400`

**Mismatch A — `Api.adapt/1`**:
- Current match: `{:ok, _resp, json_config}` and `{:ok, _resp, _non_map}` and `{:error, reason}`
- Actual return (`api.ex:432-455`): `json_conf` map directly on success, `%{}` on error — never a tuple.
- Effect: All tuple-pattern clauses never match. Config push always falls through to the catch-all/silent failure.

**Mismatch B — `Api.load/1`**:
- Current match: `{:ok, _resp, _body}` and `{:error, reason}`
- Actual return (`api.ex:98-120`): `%{status:, body:}` struct on success; `%{status: 0, body: nil}` on error — never a tuple.
- Effect: Success clause never matches; failure clause never matches. The `push_initial_config/0` → `handle_continue` path can hit `CaseClauseError` if no default clause is present, or return wrong results.

**Fix decision**: Rewrite `push_initial_config/0` to consume the actual return contracts:
- `Api.adapt/1` → check `is_map(result) and map_size(result) > 0`
- `Api.load/1` → inspect `%{status: status}` for 2xx vs error

---

### Bug 3: `Api.load/1` Map Variant — `BadMapError` on nil Runtime Config

**Location**: `lib/caddy/admin/api.ex:91-96`

**Current code**:
```elixir
def load(conf) when is_map(conf) do
  get_config()
  |> Map.merge(conf)  # raises BadMapError when get_config() returns nil
  |> JSON.encode!()()
  |> load()
end
```

**Condition**: `get_config/0` returns `nil` on connection failure (lines 180-187 of `api.ex`).

**Fix decision**: Guard the merge with a case on the result of `get_config/0`:
- If `nil`: return `%{status: 0, body: nil}` (consistent with existing error return pattern)
- If map: proceed with merge

---

### Bug 4: `Request.do_recv/3` — `JSON.decode!` on Possible `{:error, reason}`

**Location**: `lib/caddy/admin/request.ex:133-135`

**Current code**:
```elixir
defp do_recv(socket, {:ok, :http_eoh}, resp) do
  case :proplists.get_value(:"Content-Type", resp.headers) do
    "application/json" -> {:ok, resp, JSON.decode!(read_body(socket, resp))}
    _ -> {:ok, resp, read_body(socket, resp)}
  end
end
```

**Problem A**: `read_body/2` can return `{:error, reason}` (lines 162-164). Passing that to `JSON.decode!` raises `JSON.DecodeError`.

**Problem B**: In the non-JSON branch, `{:ok, resp, {:error, reason}}` is returned — a structured response containing an error tuple as the body, which callers won't detect.

**Additional issue found** (not in original review): `read_chunked_body/3` at line 182 has `{:ok, data} = :gen_tcp.recv(...)` — an unsafe pattern match that raises on socket error in the chunked body path.

**Fix decision**:
- Check `read_body/2` result before calling `JSON.decode`
- Replace `JSON.decode!` with `JSON.decode` and handle `{:error, reason}`
- Return `{:error, reason}` if body read fails

---

### Bug 5: Command String Parsing — Empty String Guard

**Location**: `lib/caddy/server/external.ex:341-343`

**Current code**:
```elixir
[executable | args] = String.split(cmd_string)
```

**Problem A**: An empty string `""` splits to `[""]`, so `executable = ""` and `args = []`. `System.cmd("", [])` raises an `ErlangError` (`:enoent`), which IS caught by the rescue clause — so no crash, but error message is opaque.

**Problem B** (medium severity): Arguments containing spaces (paths, quoted strings) are split incorrectly. `String.split/1` treats all whitespace as delimiters without respecting quoting semantics.

**Fix decision**:
- Add an empty-string guard clause that returns `{:error, :empty_command}` explicitly
- Document that quoted/spaced args are unsupported (out of scope for this fix; a comment is sufficient)

---

### Constitution Compliance Issue Found (not in original review)

**Location**: `lib/caddy/admin/request.ex:171`

```elixir
Logger.debug("read_chunked_body: #{inspect(socket)} #{inspect(resp)} #{inspect(acc)}")
```

Direct `Logger.debug` call violates Constitution Principle II. Must use `Caddy.Telemetry.log_debug/2`.

**Fix decision**: Replace with `Caddy.Telemetry.log_debug/2` call in the same location.

Also: `lib/caddy/admin/api.ex:30` has `require Logger` with no corresponding Logger calls in the file. This is an unused import.

**Fix decision**: Remove unused `require Logger` from `api.ex`.

---

## Return Type Contracts (Confirmed)

| Function | Declared `@spec` | Actual Return |
|----------|-----------------|---------------|
| `Api.get_config/0` | (none) | `map() \| nil` |
| `Api.adapt/1` | `map()` | `map()` (success) or `%{}` (error) |
| `Api.load/1` binary | `Caddy.Admin.Request.t()` | `%Request{status:, body:}` struct |
| `Api.load/1` map | `Caddy.Admin.Request.t()` | Same (or `%{status: 0, body: nil}` on error) |
| `Request.get/1` | (impl) | `{:ok, resp, body} \| {:error, reason}` |

**Note**: No `@spec` changes are required since the public-facing contracts are correct — only the internal callers in `External` need to be updated to match what `Api` actually returns.

---

## Decisions Summary

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Fix `External` to consume actual `Api` return types | Minimal change; no `Api` public signature changes |
| D2 | Guard `Api.load/1` map merge against nil | Returns `%{status: 0, body: nil}` consistent with existing error pattern |
| D3 | Use `JSON.decode/1` (safe) instead of `JSON.decode!/1` | Allows error normalization instead of raising |
| D4 | Add empty-string guard in `execute_shell_command/1` | Makes error explicit and testable |
| D5 | Replace `Logger.debug` with `Caddy.Telemetry.log_debug` in `request.ex` | Constitution Principle II compliance |
| D6 | Remove unused `require Logger` from `api.ex` | Credo strict compliance |
