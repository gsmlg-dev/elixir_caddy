defmodule Caddy.Config.Matcher.ExpressionTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Expression
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates expression matcher with simple expression" do
      matcher = Expression.new("{method} == \"GET\"")
      assert matcher.expression == "{method} == \"GET\""
    end

    test "creates expression matcher with complex expression" do
      matcher = Expression.new("{path}.startsWith(\"/api\") && {method} == \"GET\"")
      assert matcher.expression == "{path}.startsWith(\"/api\") && {method} == \"GET\""
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Expression.new("{method} == \"GET\"")
      assert {:ok, ^matcher} = Expression.validate(matcher)
    end

    test "returns error for empty expression" do
      matcher = %Expression{expression: ""}
      assert {:error, "expression cannot be empty"} = Expression.validate(matcher)
    end

    test "returns error for nil expression" do
      matcher = %Expression{expression: nil}
      assert {:error, "expression cannot be empty"} = Expression.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders simple expression" do
      matcher = Expression.new("{method} == \"GET\"")
      assert Caddyfile.to_caddyfile(matcher) == "expression {method} == \"GET\""
    end

    test "renders complex expression" do
      matcher = Expression.new("{path}.startsWith(\"/api\")")
      assert Caddyfile.to_caddyfile(matcher) == "expression {path}.startsWith(\"/api\")"
    end
  end
end
