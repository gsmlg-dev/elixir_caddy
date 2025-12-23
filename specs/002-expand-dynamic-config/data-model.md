# Data Model: Expand Dynamic Config Support

**Date**: 2025-12-23
**Feature**: 002-expand-dynamic-config

## Entity Overview

```
Caddy.Config (root)
├── global: Global.t()
├── snippets: %{String.t() => Snippet.t()}      # EXISTS
├── routes: %{String.t() => NamedRoute.t()}     # NEW
├── sites: %{String.t() => Site.t()}
└── env: [{String.t(), String.t()}]

Caddy.Config.Site (updated)
├── host_name: String.t()
├── matchers: [NamedMatcher.t()]                # NEW
├── imports: [Import.t()]                       # EXISTS
├── directives: [directive()]
└── ...existing fields...

NamedMatcher
├── name: String.t()                            # e.g., "api", "static"
└── matchers: [Matcher.t()]                     # AND'ed together

Matcher (union type - one of 15 types)
├── Matcher.Path
├── Matcher.PathRegexp
├── Matcher.Header
├── Matcher.HeaderRegexp
├── Matcher.Method
├── Matcher.Query
├── Matcher.Host
├── Matcher.Protocol
├── Matcher.RemoteIp
├── Matcher.ClientIp
├── Matcher.Vars
├── Matcher.VarsRegexp
├── Matcher.Expression
├── Matcher.File
└── Matcher.Not
```

## New Entities

### 1. EnvVar

**Purpose**: Environment variable reference with optional default value.

```elixir
defmodule Caddy.Config.EnvVar do
  @type t :: %__MODULE__{
    name: String.t(),           # Variable name (without $)
    default: String.t() | nil   # Optional default value
  }

  defstruct [:name, default: nil]
end
```

**Rendering**:
- Without default: `{$NAME}`
- With default: `{$NAME:default_value}`

**Validation**:
- `name` must be non-empty string
- `name` must match pattern `^[A-Za-z_][A-Za-z0-9_]*$`

---

### 2. NamedMatcher

**Purpose**: Reusable matcher definition scoped to a site.

```elixir
defmodule Caddy.Config.NamedMatcher do
  @type t :: %__MODULE__{
    name: String.t(),           # Matcher name (without @)
    matchers: [Matcher.t()]     # List of conditions (AND'ed)
  }

  defstruct [:name, matchers: []]
end
```

**Rendering**:
- Single matcher: `@name matcher value`
- Multiple matchers:
  ```
  @name {
    matcher1 value
    matcher2 value
  }
  ```

**Validation**:
- `name` must be non-empty, alphanumeric with hyphens/underscores
- `matchers` must be non-empty list

---

### 3. NamedRoute

**Purpose**: Reusable route definition at config level (experimental Caddy feature).

```elixir
defmodule Caddy.Config.NamedRoute do
  @type t :: %__MODULE__{
    name: String.t(),           # Route name (without &())
    content: String.t()         # Route directives
  }

  defstruct [:name, :content]
end
```

**Rendering**:
```
&(route-name) {
  content here
}
```

**Validation**:
- `name` must be non-empty, alphanumeric with hyphens/underscores
- `content` must be non-empty

---

### 4. PluginConfig

**Purpose**: Arbitrary plugin configuration container.

```elixir
defmodule Caddy.Config.PluginConfig do
  @type t :: %__MODULE__{
    name: String.t(),                   # Plugin directive name
    options: String.t() | map()         # Raw string or structured options
  }

  defstruct [:name, options: ""]
end
```

**Rendering**: Depends on options type:
- String: `name options_string`
- Map: `name { key value ... }`

**Validation**:
- `name` must be non-empty

---

## Matcher Types

### Common Pattern

All matcher types follow this pattern:
```elixir
defmodule Caddy.Config.Matcher.{Type} do
  @type t :: %__MODULE__{...fields...}
  defstruct [...]
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.{Type} do
  def to_caddyfile(matcher), do: "type ...values..."
end
```

### 5. Matcher.Path

```elixir
@type t :: %__MODULE__{
  paths: [String.t()]    # One or more path patterns
}
```

**Rendering**: `path /api/* /v1/*`

---

### 6. Matcher.PathRegexp

```elixir
@type t :: %__MODULE__{
  name: String.t() | nil,    # Optional capture name
  pattern: String.t()        # RE2 regex pattern
}
```

**Rendering**:
- Without name: `path_regexp ^/api/v[0-9]+`
- With name: `path_regexp version ^/api/v([0-9]+)`

---

### 7. Matcher.Header

```elixir
@type t :: %__MODULE__{
  field: String.t(),            # Header field name
  values: [String.t()]          # Optional values (wildcard supported)
}
```

**Rendering**: `header Content-Type application/json`

---

### 8. Matcher.HeaderRegexp

```elixir
@type t :: %__MODULE__{
  name: String.t() | nil,    # Optional capture name
  field: String.t(),         # Header field
  pattern: String.t()        # RE2 regex
}
```

**Rendering**: `header_regexp auth Authorization ^Bearer\s+(.+)$`

---

### 9. Matcher.Method

```elixir
@type t :: %__MODULE__{
  verbs: [String.t()]        # HTTP methods (uppercase)
}
```

**Rendering**: `method GET POST PUT`

---

### 10. Matcher.Query

```elixir
@type t :: %__MODULE__{
  params: %{String.t() => String.t()}    # key => value pairs
}
```

**Rendering**: `query key1=value1 key2=*`

---

### 11. Matcher.Host

```elixir
@type t :: %__MODULE__{
  hosts: [String.t()]        # Hostnames
}
```

**Rendering**: `host example.com www.example.com`

---

### 12. Matcher.Protocol

```elixir
@type t :: %__MODULE__{
  protocol: String.t()       # http, https, grpc, http/2+, etc.
}
```

**Rendering**: `protocol https`

---

### 13. Matcher.RemoteIp

```elixir
@type t :: %__MODULE__{
  ranges: [String.t()]       # IP addresses or CIDR ranges
}
```

**Rendering**: `remote_ip 192.168.0.0/16 10.0.0.0/8`

---

### 14. Matcher.ClientIp

```elixir
@type t :: %__MODULE__{
  ranges: [String.t()]       # IP addresses or CIDR ranges
}
```

**Rendering**: `client_ip 192.168.0.0/16`

---

### 15. Matcher.Vars

```elixir
@type t :: %__MODULE__{
  variable: String.t(),      # Variable or placeholder
  values: [String.t()]       # Possible values
}
```

**Rendering**: `vars {magic_number} 3 5 7`

---

### 16. Matcher.VarsRegexp

```elixir
@type t :: %__MODULE__{
  name: String.t() | nil,    # Optional capture name
  variable: String.t(),      # Variable or placeholder
  pattern: String.t()        # RE2 regex
}
```

**Rendering**: `vars_regexp match {var} ^prefix`

---

### 17. Matcher.Expression

```elixir
@type t :: %__MODULE__{
  expression: String.t()     # CEL expression
}
```

**Rendering**: `expression {method}.startsWith("P")`

---

### 18. Matcher.File

```elixir
@type t :: %__MODULE__{
  root: String.t() | nil,
  try_files: [String.t()],
  try_policy: :first_exist | :smallest_size | :largest_size | :most_recently_modified | nil,
  split_path: [String.t()]
}
```

**Rendering**:
```
file {
  root /srv
  try_files {path}.html {path}
  try_policy first_exist
}
```

---

### 19. Matcher.Not

```elixir
@type t :: %__MODULE__{
  matchers: [Matcher.t()]    # Negated matchers
}
```

**Rendering**:
- Single: `not path /admin/*`
- Multiple:
  ```
  not {
    path /admin/*
    method DELETE
  }
  ```

---

## Updated Entities

### Site (Update)

Add `matchers` field:

```elixir
defstruct [
  :host_name,
  listen: nil,
  server_aliases: [],
  tls: :auto,
  matchers: [],              # NEW: [NamedMatcher.t()]
  imports: [],
  directives: [],
  extra_config: ""
]
```

**Rendering Order** in site block:
1. Named matchers (`@name ...`)
2. Import directives (`import ...`)
3. TLS configuration
4. Other directives

---

### Config (Update)

Add `routes` field:

```elixir
defstruct [
  version: "2.0",
  bin: nil,
  global: "",
  snippets: %{},
  routes: %{},               # NEW: %{String.t() => NamedRoute.t()}
  sites: %{},
  env: []
]
```

**Rendering Order** in Caddyfile:
1. Global block
2. Snippets (`(name) { ... }`)
3. Named routes (`&(name) { ... }`)
4. Sites

---

## Type Definitions Summary

```elixir
# Union type for all matchers
@type matcher ::
  Matcher.Path.t() |
  Matcher.PathRegexp.t() |
  Matcher.Header.t() |
  Matcher.HeaderRegexp.t() |
  Matcher.Method.t() |
  Matcher.Query.t() |
  Matcher.Host.t() |
  Matcher.Protocol.t() |
  Matcher.RemoteIp.t() |
  Matcher.ClientIp.t() |
  Matcher.Vars.t() |
  Matcher.VarsRegexp.t() |
  Matcher.Expression.t() |
  Matcher.File.t() |
  Matcher.Not.t()
```

## Validation Rules

| Entity | Field | Rule |
|--------|-------|------|
| EnvVar | name | Non-empty, matches `^[A-Za-z_][A-Za-z0-9_]*$` |
| NamedMatcher | name | Non-empty, alphanumeric/hyphen/underscore |
| NamedMatcher | matchers | Non-empty list |
| NamedRoute | name | Non-empty, alphanumeric/hyphen/underscore |
| NamedRoute | content | Non-empty string |
| Matcher.Method | verbs | All uppercase |
| Matcher.Protocol | protocol | One of: http, https, grpc, http/N, http/N+ |
