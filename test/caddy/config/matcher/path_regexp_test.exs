defmodule Caddy.Config.Matcher.PathRegexpTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.PathRegexp
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates path_regexp matcher with pattern only" do
      matcher = PathRegexp.new("^/api/v[0-9]+")
      assert matcher.pattern == "^/api/v[0-9]+"
      assert matcher.name == nil
    end

    test "creates path_regexp matcher with pattern and name" do
      matcher = PathRegexp.new("^/api/v([0-9]+)", "version")
      assert matcher.pattern == "^/api/v([0-9]+)"
      assert matcher.name == "version"
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher without name" do
      matcher = PathRegexp.new("^/api")
      assert {:ok, ^matcher} = PathRegexp.validate(matcher)
    end

    test "returns ok for valid matcher with name" do
      matcher = PathRegexp.new("^/api/v([0-9]+)", "version")
      assert {:ok, ^matcher} = PathRegexp.validate(matcher)
    end

    test "returns error for empty pattern" do
      matcher = %PathRegexp{pattern: ""}
      assert {:error, "pattern cannot be empty"} = PathRegexp.validate(matcher)
    end

    test "returns error for nil pattern" do
      matcher = %PathRegexp{pattern: nil}
      assert {:error, "pattern cannot be empty"} = PathRegexp.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders pattern without name" do
      matcher = PathRegexp.new("^/api/v[0-9]+")
      assert Caddyfile.to_caddyfile(matcher) == "path_regexp ^/api/v[0-9]+"
    end

    test "renders pattern with name" do
      matcher = PathRegexp.new("^/api/v([0-9]+)", "version")
      assert Caddyfile.to_caddyfile(matcher) == "path_regexp version ^/api/v([0-9]+)"
    end
  end
end
