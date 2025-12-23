# Quickstart: Dynamic Config Support

**Feature**: 002-expand-dynamic-config

## Overview

This feature adds support for dynamic Caddy configuration elements:
- Environment variables (`{$VAR}`)
- Named matchers (`@name`)
- Named routes (`&(name)`)
- Import directives (already implemented)
- Plugin configurations

## Usage Examples

### Environment Variables

```elixir
alias Caddy.Config.EnvVar

# Simple variable reference
env_var = EnvVar.new("DATABASE_URL")
# Renders as: {$DATABASE_URL}

# Variable with default value
env_var = EnvVar.new("PORT", "8080")
# Renders as: {$PORT:8080}

# Use in site configuration
site = Site.new("example.com")
  |> Site.add_directive("reverse_proxy localhost:{$APP_PORT}")
```

### Named Matchers

```elixir
alias Caddy.Config.NamedMatcher
alias Caddy.Config.Matcher.{Path, Method, Header}

# Simple path matcher
matcher = NamedMatcher.new("api", [
  Path.new(["/api/*"])
])
# Renders as: @api path /api/*

# Complex matcher with multiple conditions
matcher = NamedMatcher.new("api-write", [
  Path.new(["/api/*"]),
  Method.new(["POST", "PUT", "DELETE"])
])
# Renders as:
# @api-write {
#   path /api/*
#   method POST PUT DELETE
# }

# Add to site
site = Site.new("example.com")
  |> Site.add_matcher(matcher)
  |> Site.add_directive("reverse_proxy @api localhost:3000")
```

### All Matcher Types

```elixir
alias Caddy.Config.Matcher

# Path matching
Path.new(["/api/*", "/v1/*"])

# Path with regex
PathRegexp.new("^/users/([0-9]+)")
PathRegexp.new("user_id", "^/users/([0-9]+)")  # with capture name

# Header matching
Header.new("Content-Type", ["application/json"])
Header.new("Authorization")  # check presence only

# Header with regex
HeaderRegexp.new("Cookie", "session=([a-f0-9]+)")

# HTTP method
Method.new(["GET", "POST"])

# Query parameters
Query.new(%{"page" => "*", "sort" => "asc"})

# Host matching
Host.new(["api.example.com", "api.example.org"])

# Protocol
Protocol.new("https")
Protocol.new("http/2+")

# IP-based matching
RemoteIp.new(["192.168.0.0/16", "10.0.0.0/8"])
ClientIp.new(["172.16.0.0/12"])

# Variable matching
Vars.new("{http.request.uri.query.debug}", ["true", "1"])
VarsRegexp.new("{custom_var}", "^prefix")

# CEL expressions
Expression.new("{method}.startsWith(\"P\")")

# File existence
File.new(
  root: "/srv/www",
  try_files: ["{path}.html", "{path}", "=404"]
)

# Negation
Not.new([Path.new(["/admin/*"])])
```

### Named Routes

```elixir
alias Caddy.Config.NamedRoute

# Define a reusable route
route = NamedRoute.new("common-api", """
reverse_proxy localhost:3000
encode gzip
header Cache-Control "max-age=3600"
""")

# Add to config
config = %Caddy.Config{}
  |> Caddy.Config.add_route(route)

# Invoke from a site
site = Site.new("api.example.com")
  |> Site.add_directive("invoke common-api")

# Renders as:
# &(common-api) {
#   reverse_proxy localhost:3000
#   encode gzip
#   header Cache-Control "max-age=3600"
# }
#
# api.example.com {
#   invoke common-api
# }
```

### Import Directives (Existing)

```elixir
alias Caddy.Config.Import

# Import a snippet
import = Import.snippet("cors-headers")
# Renders as: import cors-headers

# Import with arguments
import = Import.snippet("log-zone", ["app", "production"])
# Renders as: import log-zone "app" "production"

# Import from file
import = Import.file("/etc/caddy/common.conf")
# Renders as: import /etc/caddy/common.conf
```

### Plugin Configuration

```elixir
alias Caddy.Config.PluginConfig

# Simple plugin directive
plugin = PluginConfig.new("crowdsec", "api_url http://localhost:8080")

# Plugin with block options
plugin = PluginConfig.new("rate_limit", %{
  zone: "static",
  rate: "10r/s"
})

# Add to global config
global = %Caddy.Config.Global{
  extra_options: [Caddy.Caddyfile.to_caddyfile(plugin)]
}
```

## Complete Configuration Example

```elixir
alias Caddy.Config
alias Caddy.Config.{Global, Site, Snippet, NamedMatcher, NamedRoute}
alias Caddy.Config.Matcher.{Path, Method, Header}

# Build configuration
config = %Config{
  global: %Global{
    admin: "unix//tmp/caddy.sock",
    email: "admin@example.com"
  },
  snippets: %{
    "cors" => Snippet.new("cors", """
    header Access-Control-Allow-Origin *
    header Access-Control-Allow-Methods "GET, POST, OPTIONS"
    """)
  },
  routes: %{
    "api-backend" => NamedRoute.new("api-backend", """
    reverse_proxy localhost:3000
    encode gzip
    """)
  },
  sites: %{
    "main" => Site.new("example.com")
      |> Site.add_matcher(NamedMatcher.new("api", [Path.new(["/api/*"])]))
      |> Site.add_matcher(NamedMatcher.new("static", [
        Path.new(["/css/*", "/js/*", "/images/*"]),
        Method.new(["GET"])
      ]))
      |> Site.import_snippet("cors")
      |> Site.add_directive("reverse_proxy @api localhost:3000")
      |> Site.add_directive("file_server @static")
  }
}

# Render to Caddyfile
caddyfile = Caddy.Config.to_caddyfile(config)
```

Output:
```caddyfile
{
  admin unix//tmp/caddy.sock
  email admin@example.com
}

(cors) {
  header Access-Control-Allow-Origin *
  header Access-Control-Allow-Methods "GET, POST, OPTIONS"
}

&(api-backend) {
  reverse_proxy localhost:3000
  encode gzip
}

example.com {
  @api path /api/*
  @static {
    path /css/* /js/* /images/*
    method GET
  }
  import cors
  reverse_proxy @api localhost:3000
  file_server @static
}
```

## API Summary

| Module | Function | Description |
|--------|----------|-------------|
| `EnvVar` | `new(name)`, `new(name, default)` | Create env var reference |
| `NamedMatcher` | `new(name, matchers)` | Create named matcher |
| `NamedRoute` | `new(name, content)` | Create named route |
| `Site` | `add_matcher(site, matcher)` | Add matcher to site |
| `Config` | `add_route(config, route)` | Add route to config |
| All structs | `Caddy.Caddyfile.to_caddyfile/1` | Render to Caddyfile syntax |
