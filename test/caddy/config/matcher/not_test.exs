defmodule Caddy.Config.Matcher.NotTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Not
  alias Caddy.Config.Matcher.Path
  alias Caddy.Config.Matcher.Method
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates not matcher with single matcher" do
      inner = Path.new(["/admin/*"])
      matcher = Not.new([inner])
      assert matcher.matchers == [inner]
    end

    test "creates not matcher with multiple matchers" do
      path = Path.new(["/admin/*"])
      method = Method.new(["DELETE"])
      matcher = Not.new([path, method])
      assert matcher.matchers == [path, method]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      inner = Path.new(["/admin/*"])
      matcher = Not.new([inner])
      assert {:ok, ^matcher} = Not.validate(matcher)
    end

    test "returns error for empty matchers" do
      matcher = Not.new([])
      assert {:error, "matchers cannot be empty"} = Not.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single matcher inline" do
      inner = Path.new(["/admin/*"])
      matcher = Not.new([inner])
      assert Caddyfile.to_caddyfile(matcher) == "not path /admin/*"
    end

    test "renders multiple matchers as block" do
      path = Path.new(["/admin/*"])
      method = Method.new(["DELETE"])
      matcher = Not.new([path, method])
      result = Caddyfile.to_caddyfile(matcher)
      assert result =~ "not {"
      assert result =~ "path /admin/*"
      assert result =~ "method DELETE"
      assert result =~ "}"
    end
  end
end
