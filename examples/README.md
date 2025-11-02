# Protocol-Based Config Examples

This directory contains examples demonstrating the new protocol-based configuration system.

## Running the Examples

```bash
# Protocol demonstration
elixir -r lib/caddy/caddyfile.ex -r lib/caddy/config/snippet.ex -r lib/caddy/config/import.ex -r lib/caddy/config/global.ex -r lib/caddy/config/site.ex examples/protocol_demo.exs

# Builder pattern demonstration
elixir -r lib/caddy/caddyfile.ex -r lib/caddy/config/snippet.ex -r lib/caddy/config/import.ex -r lib/caddy/config/site.ex examples/builder_demo.exs

# Testing benefits demonstration
elixir -r lib/caddy/caddyfile.ex -r lib/caddy/config/snippet.ex -r lib/caddy/config/import.ex -r lib/caddy/config/global.ex -r lib/caddy/config/site.ex examples/testing_demo.exs
```

## What's Demonstrated

### protocol_demo.exs
- **Snippet creation** with argument placeholders (`{args[0]}`)
- **Import directives** (with and without args)
- **Global configuration** blocks
- **Site configuration** with all features
- **Complete Caddyfile** generation
- Your specific **log-zone** snippet requirement

### builder_demo.exs
- **Fluent API** (method chaining)
- **Step-by-step building**
- **Conditional configuration**
- **Building from data** (Enum.map)
- **Composing with Enum.reduce**
- **Custom helper functions**

### testing_demo.exs
- **Pure function testing** (no I/O needed)
- **Performance** (100 iterations in ~1ms)
- **Clear assertions**
- **Struct inspection**
- **Property-based testing** examples
- **Test factories**

## Key Benefits

### ✅ Ease of Use
- Type-safe structs with clear fields
- Builder pattern for fluent API
- Self-documenting code
- Great IDE support

### ✅ Testing
- Pure functions - no I/O needed
- Blazing fast tests
- Easy to test each component
- Simple test factories
- No mocking required

### ✅ Protocol-Based
- Elegant and extensible
- Users can implement custom types
- Clean separation of data and rendering
- NixOS-inspired declarative structure

## Next Steps

Once we complete the implementation, you'll be able to use this like:

```elixir
# In your code
alias Caddy.Config.{Site, Snippet}

# Define reusable snippets
ConfigProvider.add_snippet("log-zone", """
log {
  format json
  output file /srv/logs/{args[0]}/{args[1]}/access.log {
    roll_size 50mb
    roll_keep 5
    roll_keep_for 720h
  }
}
""")

# Create sites
site = Site.new("example.com")
  |> Site.import_snippet("log-zone", ["app", "production"])
  |> Site.reverse_proxy("localhost:3000")

ConfigProvider.set_site("example", site)

# Generate Caddyfile
config = ConfigProvider.get_config()
caddyfile = Caddy.Caddyfile.to_caddyfile(config)
```

## Implementation Status

✅ Phase 1: Protocol Foundation (Complete)
✅ Phase 2: Core Structs (Complete)
✅ Phase 3: Site Configuration (Complete)
⏳ Phase 4-9: Integration with existing code (In Progress)
