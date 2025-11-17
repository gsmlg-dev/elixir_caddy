# Protocol-Based Config Demo
# Run with: elixir -r lib/caddy/caddyfile.ex -r lib/caddy/config/snippet.ex -r lib/caddy/config/import.ex -r lib/caddy/config/global.ex -r lib/caddy/config/site.ex examples/protocol_demo.exs

alias Caddy.Caddyfile
alias Caddy.Config.{Snippet, Import, Global, Site}

IO.puts("\n" <> IO.ANSI.cyan() <> "=== Protocol-Based Caddy Configuration Demo ===" <> IO.ANSI.reset() <> "\n")

# ============================================================================
# Example 1: Simple Snippet
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "Example 1: Creating and Rendering a Snippet" <> IO.ANSI.reset())

snippet = Snippet.new("cors", """
@origin header Origin {args[0]}
header @origin Access-Control-Allow-Origin "{args[0]}"
header @origin Access-Control-Allow-Methods "GET, POST, PUT, DELETE"
""")

IO.puts("\nSnippet struct:")
IO.inspect(snippet, pretty: true)

IO.puts("\nRendered Caddyfile:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(snippet))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 2: Your Log-Zone Snippet
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 2: Log-Zone Snippet (from your requirement)" <> IO.ANSI.reset())

log_zone = Snippet.new("log-zone", """
log {
  format json
  output file /srv/logs/{args[0]}/{args[1]}/access.log {
    roll_size 50mb
    roll_keep 5
    roll_keep_for 720h
  }
}
""")

IO.puts("\nRendered Caddyfile:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(log_zone))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 3: Import Directive
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 3: Import Directives" <> IO.ANSI.reset())

import1 = Import.snippet("cors")
import2 = Import.snippet("log-zone", ["app", "production"])
import3 = Import.file("/etc/caddy/common.conf")

IO.puts("\nImport without args: #{Caddyfile.to_caddyfile(import1)}")
IO.puts("Import with args: #{Caddyfile.to_caddyfile(import2)}")
IO.puts("Import from file: #{Caddyfile.to_caddyfile(import3)}")

# ============================================================================
# Example 4: Global Configuration
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 4: Global Configuration" <> IO.ANSI.reset())

global = Global.new(
  debug: true,
  admin: "unix//var/run/caddy.sock",
  email: "admin@example.com",
  acme_ca: "https://acme-staging-v02.api.letsencrypt.org/directory"
)

IO.puts("\nGlobal struct:")
IO.inspect(global, pretty: true)

IO.puts("\nRendered Caddyfile:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(global))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 5: Simple Site
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 5: Simple Site Configuration" <> IO.ANSI.reset())

site = Site.new("example.com")
  |> Site.reverse_proxy("localhost:3000")
  |> Site.add_directive("encode gzip")

IO.puts("\nSite struct:")
IO.inspect(site, pretty: true, limit: :infinity)

IO.puts("\nRendered Caddyfile:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(site))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 6: Complex Site with Everything
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 6: Complex Site (NixOS-style)" <> IO.ANSI.reset())

complex_site = Site.new("app.example.com")
  |> Site.listen(":443")
  |> Site.add_alias(["www.app.example.com", "app.example.org"])
  |> Site.tls(:auto)
  |> Site.import_snippet("log-zone", ["app", "production"])
  |> Site.import_snippet("cors", ["https://example.com"])
  |> Site.add_directive("encode gzip")
  |> Site.add_directive({"header", "X-Frame-Options DENY"})
  |> Site.reverse_proxy("localhost:3000")

IO.puts("\nRendered Caddyfile:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(complex_site))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 7: Multiple Sites Setup
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 7: Production Multi-Site Setup" <> IO.ANSI.reset())

# Define snippets
security_snippet = Snippet.new("security-headers", """
header {
  X-Content-Type-Options nosniff
  X-Frame-Options DENY
  X-XSS-Protection "1; mode=block"
  Strict-Transport-Security "max-age=31536000"
}
""")

rate_limit_snippet = Snippet.new("rate-limit", """
rate_limit {
  zone {args[0]} {
    key {remote_host}
    events {args[1]}
    window {args[2]}
  }
}
""")

# Define sites
web_site = Site.new("example.com")
  |> Site.listen(":443")
  |> Site.add_alias(["www.example.com"])
  |> Site.import_snippet("log-zone", ["web", "production"])
  |> Site.import_snippet("security-headers")
  |> Site.import_snippet("rate-limit", ["web", "100", "1m"])
  |> Site.reverse_proxy("localhost:3000")

api_site = Site.new("api.example.com")
  |> Site.import_snippet("log-zone", ["api", "production"])
  |> Site.import_snippet("rate-limit", ["api", "1000", "1m"])
  |> Site.add_directive("encode gzip")
  |> Site.reverse_proxy("localhost:4000")

IO.puts("\n--- Snippets ---")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(log_zone))
IO.puts("\n" <> Caddyfile.to_caddyfile(security_snippet))
IO.puts("\n" <> Caddyfile.to_caddyfile(rate_limit_snippet))
IO.puts(IO.ANSI.reset())

IO.puts("\n--- Web Site ---")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(web_site))
IO.puts(IO.ANSI.reset())

IO.puts("\n--- API Site ---")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(api_site))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 8: Complete Caddyfile Preview
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 8: Complete Caddyfile (What it would look like)" <> IO.ANSI.reset())

IO.puts(IO.ANSI.cyan() <> "\n# This is how a complete Caddyfile would be structured:" <> IO.ANSI.reset())
IO.puts(IO.ANSI.green())

complete = """
#{Caddyfile.to_caddyfile(global)}

#{Caddyfile.to_caddyfile(log_zone)}

#{Caddyfile.to_caddyfile(security_snippet)}

#{Caddyfile.to_caddyfile(rate_limit_snippet)}

#{Caddyfile.to_caddyfile(web_site)}

#{Caddyfile.to_caddyfile(api_site)}
"""

IO.puts(complete)
IO.puts(IO.ANSI.reset())

IO.puts(IO.ANSI.cyan() <> "\n=== Demo Complete ===" <> IO.ANSI.reset())
IO.puts("\nKey Features Demonstrated:")
IO.puts("✓ Protocol-based rendering (elegant and extensible)")
IO.puts("✓ Snippets with argument placeholders ({args[0]})")
IO.puts("✓ Import directives (with and without args)")
IO.puts("✓ Global configuration block")
IO.puts("✓ Site builder pattern (fluent API)")
IO.puts("✓ NixOS-inspired declarative structure")
IO.puts("✓ Type-safe configuration")
IO.puts("✓ Easy to test (no I/O needed)")
