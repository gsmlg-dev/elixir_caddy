# Builder Pattern Demo
# This shows how easy it is to build complex configurations

alias Caddy.Caddyfile
alias Caddy.Config.{Snippet, Site}

IO.puts("\n" <> IO.ANSI.cyan() <> "=== Fluent Builder API Demo ===" <> IO.ANSI.reset() <> "\n")

# ============================================================================
# Example 1: Building a Site Step-by-Step
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "Example 1: Step-by-Step Site Building" <> IO.ANSI.reset())

site = Site.new("myapp.com")

IO.puts("\nStep 1: Just hostname")
IO.puts(IO.ANSI.green() <> Caddyfile.to_caddyfile(site) <> IO.ANSI.reset())

site = site |> Site.listen(":443")
IO.puts("\nStep 2: Add listen address")
IO.puts(IO.ANSI.green() <> Caddyfile.to_caddyfile(site) <> IO.ANSI.reset())

site = site |> Site.add_alias("www.myapp.com")
IO.puts("\nStep 3: Add alias")
IO.puts(IO.ANSI.green() <> Caddyfile.to_caddyfile(site) <> IO.ANSI.reset())

site = site |> Site.reverse_proxy("localhost:3000")
IO.puts("\nStep 4: Add reverse proxy")
IO.puts(IO.ANSI.green() <> Caddyfile.to_caddyfile(site) <> IO.ANSI.reset())

# ============================================================================
# Example 2: Chaining Everything
# ============================================================================
IO.puts("\n" <> IO.ANSI.yellow() <> "Example 2: Chained Builder (One Expression)" <> IO.ANSI.reset())

chained_site =
  Site.new("api.example.com")
  |> Site.listen(":8080")
  |> Site.add_alias(["api.example.org", "api.backup.com"])
  |> Site.tls(:internal)
  |> Site.import_snippet("log-zone", ["api", "staging"])
  |> Site.import_snippet("cors", ["*"])
  |> Site.add_directive("encode gzip")
  |> Site.add_directive({"header", "X-API-Version 2.0"})
  |> Site.reverse_proxy("localhost:4000")

IO.puts("\nOne chained expression produces:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(chained_site))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 3: Conditional Building
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 3: Conditional Configuration" <> IO.ANSI.reset())

env = :production  # Could be :development or :production

base_site = Site.new("conditional.com")
  |> Site.reverse_proxy("localhost:3000")

site_with_env = if env == :production do
  base_site
  |> Site.listen(":443")
  |> Site.tls(:auto)
  |> Site.import_snippet("log-zone", ["app", "prod"])
  |> Site.add_directive("encode gzip")
else
  base_site
  |> Site.listen(":8080")
  |> Site.tls(:off)
end

IO.puts("\nProduction config:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(site_with_env))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 4: Building from Data
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 4: Building Sites from Data" <> IO.ANSI.reset())

# Imagine this comes from a database or config file
services = [
  %{name: "web", port: 3000, aliases: ["www.example.com"]},
  %{name: "api", port: 4000, aliases: []},
  %{name: "admin", port: 5000, aliases: ["admin.example.com"]}
]

sites = Enum.map(services, fn service ->
  Site.new("#{service.name}.example.com")
  |> Site.add_alias(service.aliases)
  |> Site.import_snippet("log-zone", [service.name, "production"])
  |> Site.reverse_proxy("localhost:#{service.port}")
end)

IO.puts("\nGenerated #{length(sites)} sites from data:")
Enum.each(sites, fn site ->
  IO.puts("\n" <> IO.ANSI.green() <> Caddyfile.to_caddyfile(site) <> IO.ANSI.reset())
end)

# ============================================================================
# Example 5: Composing Multiple Directives
# ============================================================================
IO.puts("\n" <> IO.ANSI.yellow() <> "Example 5: Adding Multiple Directives" <> IO.ANSI.reset())

security_directives = [
  {"header", "X-Content-Type-Options nosniff"},
  {"header", "X-Frame-Options DENY"},
  {"header", "X-XSS-Protection \"1; mode=block\""},
  "encode gzip",
  "encode zstd"
]

secure_site = Enum.reduce(security_directives, Site.new("secure.example.com"), fn directive, site ->
  Site.add_directive(site, directive)
end)
|> Site.reverse_proxy("localhost:3000")

IO.puts("\nSite with multiple security directives:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(secure_site))
IO.puts(IO.ANSI.reset())

# ============================================================================
# Example 6: Helper Function Pattern
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nExample 6: Custom Helper Functions" <> IO.ANSI.reset())

# Define your own helpers
defmodule SiteHelpers do
  alias Caddy.Config.Site

  def with_standard_security(site) do
    site
    |> Site.add_directive({"header", "X-Content-Type-Options nosniff"})
    |> Site.add_directive({"header", "X-Frame-Options DENY"})
    |> Site.add_directive("encode gzip")
  end

  def with_logging(site, app_name, env) do
    site
    |> Site.import_snippet("log-zone", [app_name, env])
  end

  def with_cors(site, origin) do
    site
    |> Site.import_snippet("cors", [origin])
  end
end

helper_site = Site.new("helper-example.com")
  |> SiteHelpers.with_standard_security()
  |> SiteHelpers.with_logging("myapp", "production")
  |> SiteHelpers.with_cors("https://example.com")
  |> Site.reverse_proxy("localhost:3000")

IO.puts("\nSite built with custom helpers:")
IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(helper_site))
IO.puts(IO.ANSI.reset())

IO.puts("\n" <> IO.ANSI.cyan() <> "=== Demo Complete ===" <> IO.ANSI.reset())
IO.puts("\nKey Patterns Demonstrated:")
IO.puts("✓ Step-by-step building")
IO.puts("✓ Method chaining (fluent API)")
IO.puts("✓ Conditional configuration")
IO.puts("✓ Building from data (Enum.map)")
IO.puts("✓ Composing with Enum.reduce")
IO.puts("✓ Custom helper functions")
IO.puts("\nAll using pure, testable functions! 🎉")
