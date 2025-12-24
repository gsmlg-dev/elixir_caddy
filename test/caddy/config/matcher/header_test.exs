defmodule Caddy.Config.Matcher.HeaderTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Header
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates header matcher with single value" do
      matcher = Header.new("Content-Type", ["application/json"])
      assert matcher.field == "Content-Type"
      assert matcher.values == ["application/json"]
    end

    test "creates header matcher with multiple values" do
      matcher = Header.new("Accept", ["text/html", "application/json"])
      assert matcher.field == "Accept"
      assert matcher.values == ["text/html", "application/json"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher with values" do
      matcher = Header.new("Content-Type", ["application/json"])
      assert {:ok, ^matcher} = Header.validate(matcher)
    end

    test "returns ok for header presence check (empty values)" do
      # Empty values means "check header presence only"
      matcher = Header.new("Authorization")
      assert {:ok, ^matcher} = Header.validate(matcher)
    end

    test "returns error for empty field" do
      matcher = %Header{field: "", values: ["value"]}
      assert {:error, "field cannot be empty"} = Header.validate(matcher)
    end

    test "returns error for non-string values" do
      matcher = %Header{field: "Content-Type", values: [123]}
      assert {:error, "all values must be strings"} = Header.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders header presence check" do
      matcher = Header.new("Authorization")
      assert Caddyfile.to_caddyfile(matcher) == "header Authorization"
    end

    test "renders single value" do
      matcher = Header.new("Content-Type", ["application/json"])
      assert Caddyfile.to_caddyfile(matcher) == "header Content-Type application/json"
    end

    test "renders multiple values" do
      matcher = Header.new("Accept", ["text/html", "application/json"])
      assert Caddyfile.to_caddyfile(matcher) == "header Accept text/html application/json"
    end
  end
end
