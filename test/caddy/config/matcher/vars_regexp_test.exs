defmodule Caddy.Config.Matcher.VarsRegexpTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.VarsRegexp
  alias Caddy.Caddyfile

  describe "new/3" do
    test "creates vars_regexp matcher without name" do
      matcher = VarsRegexp.new("{custom_var}", "^prefix")
      assert matcher.variable == "{custom_var}"
      assert matcher.pattern == "^prefix"
      assert matcher.name == nil
    end

    test "creates vars_regexp matcher with name" do
      matcher = VarsRegexp.new("{http.request.uri}", "^/api/v([0-9]+)", "version")
      assert matcher.variable == "{http.request.uri}"
      assert matcher.pattern == "^/api/v([0-9]+)"
      assert matcher.name == "version"
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher without name" do
      matcher = VarsRegexp.new("{var}", "^test")
      assert {:ok, ^matcher} = VarsRegexp.validate(matcher)
    end

    test "returns ok for valid matcher with name" do
      matcher = VarsRegexp.new("{var}", "^test", "capture")
      assert {:ok, ^matcher} = VarsRegexp.validate(matcher)
    end

    test "returns error for empty variable" do
      matcher = %VarsRegexp{variable: "", pattern: "test"}
      assert {:error, "variable cannot be empty"} = VarsRegexp.validate(matcher)
    end

    test "returns error for empty pattern" do
      matcher = %VarsRegexp{variable: "{var}", pattern: ""}
      assert {:error, "pattern cannot be empty"} = VarsRegexp.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders without name" do
      matcher = VarsRegexp.new("{debug}", "^(true|1)$")
      assert Caddyfile.to_caddyfile(matcher) == "vars_regexp {debug} ^(true|1)$"
    end

    test "renders with name" do
      matcher = VarsRegexp.new("{path}", "^/v([0-9]+)", "version")
      assert Caddyfile.to_caddyfile(matcher) == "vars_regexp version {path} ^/v([0-9]+)"
    end
  end
end
