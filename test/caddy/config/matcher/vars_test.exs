defmodule Caddy.Config.Matcher.VarsTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Vars
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates vars matcher with single value" do
      matcher = Vars.new("{http.request.scheme}", ["https"])
      assert matcher.variable == "{http.request.scheme}"
      assert matcher.values == ["https"]
    end

    test "creates vars matcher with multiple values" do
      matcher = Vars.new("{custom_var}", ["val1", "val2"])
      assert matcher.variable == "{custom_var}"
      assert matcher.values == ["val1", "val2"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Vars.new("{debug}", ["true"])
      assert {:ok, ^matcher} = Vars.validate(matcher)
    end

    test "returns error for empty variable" do
      matcher = %Vars{variable: "", values: ["value"]}
      assert {:error, "variable cannot be empty"} = Vars.validate(matcher)
    end

    test "returns error for empty values" do
      matcher = %Vars{variable: "{var}", values: []}
      assert {:error, "values cannot be empty"} = Vars.validate(matcher)
    end

    test "returns error for non-string variable" do
      matcher = %Vars{variable: 123, values: ["value"]}
      assert {:error, "variable must be a string"} = Vars.validate(matcher)
    end

    test "returns error for non-string values" do
      matcher = %Vars{variable: "{var}", values: [123]}
      assert {:error, "all values must be strings"} = Vars.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single value" do
      matcher = Vars.new("{debug}", ["true"])
      assert Caddyfile.to_caddyfile(matcher) == "vars {debug} true"
    end

    test "renders multiple values" do
      matcher = Vars.new("{env}", ["dev", "test"])
      assert Caddyfile.to_caddyfile(matcher) == "vars {env} dev test"
    end
  end
end
