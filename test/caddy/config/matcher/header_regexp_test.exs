defmodule Caddy.Config.Matcher.HeaderRegexpTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.HeaderRegexp
  alias Caddy.Caddyfile

  describe "new/3" do
    test "creates header_regexp matcher without name" do
      matcher = HeaderRegexp.new("User-Agent", "^Mozilla")
      assert matcher.field == "User-Agent"
      assert matcher.pattern == "^Mozilla"
      assert matcher.name == nil
    end

    test "creates header_regexp matcher with name" do
      matcher = HeaderRegexp.new("Authorization", "Bearer\\s+(.+)", "token")
      assert matcher.field == "Authorization"
      assert matcher.pattern == "Bearer\\s+(.+)"
      assert matcher.name == "token"
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher without name" do
      matcher = HeaderRegexp.new("User-Agent", "^Mozilla")
      assert {:ok, ^matcher} = HeaderRegexp.validate(matcher)
    end

    test "returns ok for valid matcher with name" do
      matcher = HeaderRegexp.new("Authorization", "Bearer\\s+(.+)", "token")
      assert {:ok, ^matcher} = HeaderRegexp.validate(matcher)
    end

    test "returns error for empty field" do
      matcher = %HeaderRegexp{field: "", pattern: "test"}
      assert {:error, "field cannot be empty"} = HeaderRegexp.validate(matcher)
    end

    test "returns error for empty pattern" do
      matcher = %HeaderRegexp{field: "User-Agent", pattern: ""}
      assert {:error, "pattern cannot be empty"} = HeaderRegexp.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders without name" do
      matcher = HeaderRegexp.new("User-Agent", "^Mozilla")
      assert Caddyfile.to_caddyfile(matcher) == "header_regexp User-Agent ^Mozilla"
    end

    test "renders with name" do
      matcher = HeaderRegexp.new("Authorization", "Bearer\\s+(.+)", "token")
      assert Caddyfile.to_caddyfile(matcher) == "header_regexp token Authorization Bearer\\s+(.+)"
    end
  end
end
