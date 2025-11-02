# Testing Demo
# This shows how easy it is to test with the protocol-based approach

alias Caddy.Caddyfile
alias Caddy.Config.{Snippet, Site, Global}

IO.puts("\n" <> IO.ANSI.cyan() <> "=== Testing Benefits Demo ===" <> IO.ANSI.reset() <> "\n")

# ============================================================================
# Benefit 1: No File I/O Needed
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "Benefit 1: Pure Functions = Easy Testing" <> IO.ANSI.reset())

IO.puts("\nOld way (hard to test):")
IO.puts(IO.ANSI.red() <> """
# Needs filesystem, temp files, cleanup, etc.
test "config generates caddyfile" do
  config_file = "/tmp/test_#{:rand.uniform(10000)}.json"
  File.write!(config_file, jason_config)
  result = System.cmd("caddy", ["adapt", "--config", config_file])
  File.rm!(config_file)
  # ...assert something
end
""" <> IO.ANSI.reset())

IO.puts("New way (pure functions):")
IO.puts(IO.ANSI.green() <> """
test "site renders correctly" do
  site = Site.new("example.com") |> Site.reverse_proxy("localhost:3000")
  result = Caddyfile.to_caddyfile(site)
  assert result =~ "example.com {"
  assert result =~ "reverse_proxy localhost:3000"
end
""" <> IO.ANSI.reset())

# ============================================================================
# Benefit 2: Fast Tests
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "\nBenefit 2: Blazing Fast Tests (No I/O)" <> IO.ANSI.reset())

# Simulate running 100 test iterations
start_time = System.monotonic_time(:millisecond)

for _i <- 1..100 do
  site = Site.new("test-#{:rand.uniform(1000)}.com")
    |> Site.reverse_proxy("localhost:#{:rand.uniform(9000)}")
    |> Site.add_directive("encode gzip")

  _result = Caddyfile.to_caddyfile(site)
end

end_time = System.monotonic_time(:millisecond)
duration = end_time - start_time

IO.puts("\n✓ Ran 100 site generations in #{duration}ms")
IO.puts("✓ No file I/O, no external processes")
IO.puts("✓ Perfect for property-based testing!")

# ============================================================================
# Benefit 3: Easy Assertions
# ============================================================================
IO.puts("\n" <> IO.ANSI.yellow() <> "Benefit 3: Crystal Clear Test Assertions" <> IO.ANSI.reset())

test_site = Site.new("test.com")
  |> Site.listen(":443")
  |> Site.import_snippet("log-zone", ["test", "dev"])
  |> Site.reverse_proxy("localhost:3000")

result = Caddyfile.to_caddyfile(test_site)

IO.puts("\nGenerated config:")
IO.puts(IO.ANSI.green() <> result <> IO.ANSI.reset())

IO.puts("\nPossible test assertions:")
IO.puts(IO.ANSI.cyan() <> """
✓ assert result =~ ":443 test.com {"
✓ assert result =~ "import log-zone"
✓ assert result =~ "reverse_proxy localhost:3000"
✓ refute result =~ "tls"
✓ assert String.contains?(result, "import")
""" <> IO.ANSI.reset())

# ============================================================================
# Benefit 4: Struct Inspection
# ============================================================================
IO.puts("\n" <> IO.ANSI.yellow() <> "Benefit 4: Test Internal State (Not Just Output)" <> IO.ANSI.reset())

IO.puts("\nYou can test the struct itself:")
IO.puts(IO.ANSI.green() <> """
test "site builder sets fields correctly" do
  site = Site.new("example.com")
    |> Site.listen(":443")
    |> Site.add_alias("www.example.com")

  # Test the struct directly!
  assert site.host_name == "example.com"
  assert site.listen == ":443"
  assert site.server_aliases == ["www.example.com"]
  assert length(site.directives) == 0
end
""" <> IO.ANSI.reset())

# ============================================================================
# Benefit 5: Property-Based Testing
# ============================================================================
IO.puts(IO.ANSI.yellow() <> "Benefit 5: Perfect for Property-Based Testing" <> IO.ANSI.reset())

IO.puts("\nExample with StreamData:")
IO.puts(IO.ANSI.green() <> """
property "all sites must have hostname in output" do
  check all hostname <- string(:alphanumeric, min_length: 1),
            port <- integer(1..65535) do

    site = Site.new(hostname) |> Site.reverse_proxy("localhost:\#{port}")
    result = Caddyfile.to_caddyfile(site)

    assert result =~ hostname
    assert result =~ "localhost:\#{port}"
  end
end
""" <> IO.ANSI.reset())

# ============================================================================
# Benefit 6: Test Factories
# ============================================================================
IO.puts("\n" <> IO.ANSI.yellow() <> "Benefit 6: Simple Test Factories" <> IO.ANSI.reset())

defmodule TestFactory do
  alias Caddy.Config.{Site, Snippet, Global}

  def build_site(attrs \\ []) do
    defaults = %{
      host_name: "test.example.com",
      listen: nil,
      directives: ["respond 200"]
    }

    attrs = Enum.into(attrs, defaults)

    Site.new(attrs.host_name)
    |> maybe_listen(attrs.listen)
    |> add_directives(attrs.directives)
  end

  defp maybe_listen(site, nil), do: site
  defp maybe_listen(site, address), do: Site.listen(site, address)

  defp add_directives(site, directives) do
    Enum.reduce(directives, site, fn dir, s -> Site.add_directive(s, dir) end)
  end

  def build_snippet(name, content) do
    Snippet.new(name, content)
  end

  def build_global(opts \\ []) do
    Global.new(opts)
  end
end

IO.puts("\nFactory usage:")
factory_site = TestFactory.build_site(
  host_name: "factory.com",
  listen: ":8080",
  directives: ["encode gzip", "reverse_proxy localhost:3000"]
)

IO.puts(IO.ANSI.green())
IO.puts(Caddyfile.to_caddyfile(factory_site))
IO.puts(IO.ANSI.reset())

IO.puts("One-liner test setup:")
IO.puts(IO.ANSI.green() <> """
site = TestFactory.build_site(host_name: "my-test.com")
""" <> IO.ANSI.reset())

# ============================================================================
# Summary
# ============================================================================
IO.puts("\n" <> IO.ANSI.cyan() <> "=== Testing Benefits Summary ===" <> IO.ANSI.reset())

benefits = [
  "✓ No file I/O needed - pure functions",
  "✓ Blazing fast (100 iterations in #{duration}ms)",
  "✓ Easy assertions on output string",
  "✓ Can test struct internals directly",
  "✓ Perfect for property-based testing",
  "✓ Simple test factories",
  "✓ No mocking needed",
  "✓ No cleanup required",
  "✓ Can run tests in parallel",
  "✓ Deterministic (no race conditions)"
]

IO.puts("")
Enum.each(benefits, fn benefit ->
  IO.puts(IO.ANSI.green() <> benefit <> IO.ANSI.reset())
end)

IO.puts("\n" <> IO.ANSI.yellow() <> "Compare to old approach:" <> IO.ANSI.reset())
old_issues = [
  "✗ Needs filesystem access",
  "✗ Needs temp file management",
  "✗ Needs cleanup after tests",
  "✗ Slower (I/O overhead)",
  "✗ Can have race conditions",
  "✗ Harder to run in parallel",
  "✗ More complex setup/teardown"
]

Enum.each(old_issues, fn issue ->
  IO.puts(IO.ANSI.red() <> issue <> IO.ANSI.reset())
end)

IO.puts("\n" <> IO.ANSI.cyan() <> "Protocol-based design = Easy, fast, reliable tests! 🎉" <> IO.ANSI.reset())
