# Data Model: Fix API Contracts

This feature does not introduce new data entities. It corrects internal function contracts and
error handling behavior within existing modules. The relevant type contracts are documented here.

## Existing Types (unchanged)

### `Caddy.Admin.Request` struct

```elixir
%Caddy.Admin.Request{
  status:  integer(),   # HTTP status code; 0 indicates connection failure
  headers: Keyword.t(), # HTTP response headers
  body:    binary()     # Raw response body
}
```

Used as the return value from `Api.load/1` and other admin operations that return the full
HTTP response. **No changes to this type.**

### Runtime Config

```
map() | nil
```

The runtime configuration from Caddy's admin API. `nil` means Caddy was unreachable.
Returned by `Api.get_config/0`. **No changes to this type.**

## Corrected Behavior Contracts

### `Api.adapt/1` — no change to type, fix caller expectations

```
Input:  binary()  (Caddyfile content)
Output: map()     (JSON config on success, %{} on connection error)
```

The returned map is non-empty on success. Callers must check `map_size > 0` to detect
connection-level failures.

### `Api.load/1` — no change to type, fix nil-guard behavior

```
Input:  map() | binary()
Output: %Caddy.Admin.Request{} | %{status: 0, body: nil}
```

When called with `map()` and the runtime config is unavailable (`nil`), now returns
`%{status: 0, body: nil}` instead of raising `BadMapError`.

### `Request.do_recv/3` — no change to type, fix error propagation

```
Output (success): {:ok, %Caddy.Admin.Request{}, map() | binary()}
Output (error):   {:error, reason}
```

Body read errors and JSON decode errors now surface as `{:error, reason}` tuples
instead of raising exceptions.
