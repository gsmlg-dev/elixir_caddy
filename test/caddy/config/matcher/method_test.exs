defmodule Caddy.Config.Matcher.MethodTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Method
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates method matcher with single verb" do
      matcher = Method.new(["GET"])
      assert matcher.verbs == ["GET"]
    end

    test "creates method matcher with multiple verbs" do
      matcher = Method.new(["GET", "POST", "PUT"])
      assert matcher.verbs == ["GET", "POST", "PUT"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Method.new(["GET", "POST"])
      assert {:ok, ^matcher} = Method.validate(matcher)
    end

    test "returns error for empty verbs" do
      matcher = Method.new([])
      assert {:error, "verbs cannot be empty"} = Method.validate(matcher)
    end

    test "returns error for non-string verbs" do
      matcher = %Method{verbs: [:get]}
      assert {:error, "all verbs must be strings"} = Method.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single verb" do
      matcher = Method.new(["GET"])
      assert Caddyfile.to_caddyfile(matcher) == "method GET"
    end

    test "renders multiple verbs" do
      matcher = Method.new(["GET", "POST", "DELETE"])
      assert Caddyfile.to_caddyfile(matcher) == "method GET POST DELETE"
    end
  end
end
