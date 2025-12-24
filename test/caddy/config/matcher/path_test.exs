defmodule Caddy.Config.Matcher.PathTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Path
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates path matcher with single path" do
      matcher = Path.new(["/api/*"])
      assert matcher.paths == ["/api/*"]
    end

    test "creates path matcher with multiple paths" do
      matcher = Path.new(["/api/*", "/v1/*", "/static/*"])
      assert matcher.paths == ["/api/*", "/v1/*", "/static/*"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Path.new(["/api/*"])
      assert {:ok, ^matcher} = Path.validate(matcher)
    end

    test "returns error for empty paths" do
      matcher = Path.new([])
      assert {:error, "paths cannot be empty"} = Path.validate(matcher)
    end

    test "returns error for non-string paths" do
      matcher = %Path{paths: [123]}
      assert {:error, "all paths must be strings"} = Path.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single path" do
      matcher = Path.new(["/api/*"])
      assert Caddyfile.to_caddyfile(matcher) == "path /api/*"
    end

    test "renders multiple paths" do
      matcher = Path.new(["/api/*", "/v1/*"])
      assert Caddyfile.to_caddyfile(matcher) == "path /api/* /v1/*"
    end
  end
end
