defmodule Caddy.Config.Matcher.QueryTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Query
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates query matcher with single param" do
      matcher = Query.new(%{"debug" => "true"})
      assert matcher.params == %{"debug" => "true"}
    end

    test "creates query matcher with multiple params" do
      matcher = Query.new(%{"page" => "*", "sort" => "asc"})
      assert matcher.params == %{"page" => "*", "sort" => "asc"}
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Query.new(%{"debug" => "true"})
      assert {:ok, ^matcher} = Query.validate(matcher)
    end

    test "returns error for empty params" do
      matcher = Query.new(%{})
      assert {:error, "params cannot be empty"} = Query.validate(matcher)
    end

    test "returns error for non-string keys" do
      matcher = %Query{params: %{123 => "value"}}
      assert {:error, "all keys and values must be strings"} = Query.validate(matcher)
    end

    test "returns error for non-string values" do
      matcher = %Query{params: %{"key" => 123}}
      assert {:error, "all keys and values must be strings"} = Query.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single param" do
      matcher = Query.new(%{"debug" => "true"})
      assert Caddyfile.to_caddyfile(matcher) == "query debug=true"
    end

    test "renders multiple params" do
      matcher = Query.new(%{"page" => "1", "sort" => "asc"})
      result = Caddyfile.to_caddyfile(matcher)
      # Order may vary due to map, so check both params are present
      assert result =~ "query"
      assert result =~ "page=1"
      assert result =~ "sort=asc"
    end
  end
end
