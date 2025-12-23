defmodule Caddy.Config.NamedMatcherTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.NamedMatcher
  alias Caddy.Config.Matcher.{Path, Method, Header, Host}
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates named matcher with single matcher" do
      path = Path.new(["/api/*"])
      matcher = NamedMatcher.new("api", [path])
      assert matcher.name == "api"
      assert matcher.matchers == [path]
    end

    test "creates named matcher with multiple matchers" do
      path = Path.new(["/api/*"])
      method = Method.new(["POST", "PUT"])
      matcher = NamedMatcher.new("api_write", [path, method])
      assert matcher.name == "api_write"
      assert matcher.matchers == [path, method]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher with single matcher" do
      path = Path.new(["/api/*"])
      matcher = NamedMatcher.new("api", [path])
      assert {:ok, ^matcher} = NamedMatcher.validate(matcher)
    end

    test "returns ok for valid matcher with multiple matchers" do
      path = Path.new(["/api/*"])
      method = Method.new(["GET"])
      matcher = NamedMatcher.new("api_read", [path, method])
      assert {:ok, ^matcher} = NamedMatcher.validate(matcher)
    end

    test "returns ok for name with hyphens" do
      path = Path.new(["/api/*"])
      matcher = NamedMatcher.new("api-v2", [path])
      assert {:ok, ^matcher} = NamedMatcher.validate(matcher)
    end

    test "returns ok for name with numbers" do
      path = Path.new(["/api/*"])
      matcher = NamedMatcher.new("api2", [path])
      assert {:ok, ^matcher} = NamedMatcher.validate(matcher)
    end

    test "returns error for empty name" do
      path = Path.new(["/api/*"])
      matcher = %NamedMatcher{name: "", matchers: [path]}
      assert {:error, "name cannot be empty"} = NamedMatcher.validate(matcher)
    end

    test "returns error for nil name" do
      path = Path.new(["/api/*"])
      matcher = %NamedMatcher{name: nil, matchers: [path]}
      assert {:error, "name cannot be empty"} = NamedMatcher.validate(matcher)
    end

    test "returns error for name with @ prefix" do
      path = Path.new(["/api/*"])
      matcher = %NamedMatcher{name: "@api", matchers: [path]}

      assert {:error, "name must contain only alphanumeric characters, underscores, and hyphens"} =
               NamedMatcher.validate(matcher)
    end

    test "returns error for name with spaces" do
      path = Path.new(["/api/*"])
      matcher = %NamedMatcher{name: "my api", matchers: [path]}

      assert {:error, "name must contain only alphanumeric characters, underscores, and hyphens"} =
               NamedMatcher.validate(matcher)
    end

    test "returns error for empty matchers" do
      matcher = %NamedMatcher{name: "api", matchers: []}
      assert {:error, "matchers cannot be empty"} = NamedMatcher.validate(matcher)
    end
  end

  describe "valid_name?/1" do
    test "accepts alphanumeric names" do
      assert NamedMatcher.valid_name?("api")
      assert NamedMatcher.valid_name?("API")
      assert NamedMatcher.valid_name?("api123")
    end

    test "accepts underscores" do
      assert NamedMatcher.valid_name?("api_v2")
      assert NamedMatcher.valid_name?("_private")
    end

    test "accepts hyphens" do
      assert NamedMatcher.valid_name?("api-v2")
      assert NamedMatcher.valid_name?("my-matcher")
    end

    test "rejects @ prefix" do
      refute NamedMatcher.valid_name?("@api")
    end

    test "rejects spaces" do
      refute NamedMatcher.valid_name?("my api")
    end

    test "rejects special characters" do
      refute NamedMatcher.valid_name?("api!")
      refute NamedMatcher.valid_name?("api$")
      refute NamedMatcher.valid_name?("api.v2")
    end
  end

  describe "Caddyfile protocol" do
    test "renders single matcher inline" do
      path = Path.new(["/api/*"])
      matcher = NamedMatcher.new("api", [path])
      assert Caddyfile.to_caddyfile(matcher) == "@api path /api/*"
    end

    test "renders multiple matchers as block" do
      path = Path.new(["/api/*"])
      method = Method.new(["POST", "PUT"])
      matcher = NamedMatcher.new("api_write", [path, method])
      result = Caddyfile.to_caddyfile(matcher)
      assert result =~ "@api_write {"
      assert result =~ "path /api/*"
      assert result =~ "method POST PUT"
      assert result =~ "}"
    end

    test "renders complex multi-matcher combination" do
      path = Path.new(["/admin/*"])
      method = Method.new(["GET", "POST"])
      header = Header.new("X-Admin-Token", ["secret"])
      host = Host.new(["admin.example.com"])
      matcher = NamedMatcher.new("admin_access", [path, method, header, host])

      result = Caddyfile.to_caddyfile(matcher)
      assert result =~ "@admin_access {"
      assert result =~ "path /admin/*"
      assert result =~ "method GET POST"
      assert result =~ "header X-Admin-Token secret"
      assert result =~ "host admin.example.com"
      assert result =~ "}"
    end
  end
end
