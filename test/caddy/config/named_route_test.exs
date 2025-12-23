defmodule Caddy.Config.NamedRouteTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.NamedRoute
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates named route with simple directives" do
      route = NamedRoute.new("error_handler", "respond 500")
      assert route.name == "error_handler"
      assert route.directives == "respond 500"
    end

    test "creates named route with multi-line directives" do
      directives = """
      header Cache-Control "public, max-age=3600"
      header X-Frame-Options DENY
      """

      route = NamedRoute.new("common_headers", directives)
      assert route.name == "common_headers"
      assert route.directives == directives
    end
  end

  describe "validate/1" do
    test "returns ok for valid route" do
      route = NamedRoute.new("my_route", "respond 200")
      assert {:ok, ^route} = NamedRoute.validate(route)
    end

    test "returns ok for name with hyphens" do
      route = NamedRoute.new("my-route", "respond 200")
      assert {:ok, ^route} = NamedRoute.validate(route)
    end

    test "returns ok for name with numbers" do
      route = NamedRoute.new("route123", "respond 200")
      assert {:ok, ^route} = NamedRoute.validate(route)
    end

    test "returns error for empty name" do
      route = %NamedRoute{name: "", directives: "respond 200"}
      assert {:error, "name cannot be empty"} = NamedRoute.validate(route)
    end

    test "returns error for nil name" do
      route = %NamedRoute{name: nil, directives: "respond 200"}
      assert {:error, "name cannot be empty"} = NamedRoute.validate(route)
    end

    test "returns error for name with spaces" do
      route = %NamedRoute{name: "my route", directives: "respond 200"}

      assert {:error, "name must contain only alphanumeric characters, underscores, and hyphens"} =
               NamedRoute.validate(route)
    end

    test "returns error for name with special characters" do
      route = %NamedRoute{name: "route@123", directives: "respond 200"}

      assert {:error, "name must contain only alphanumeric characters, underscores, and hyphens"} =
               NamedRoute.validate(route)
    end

    test "returns error for empty directives" do
      route = %NamedRoute{name: "my_route", directives: ""}
      assert {:error, "directives cannot be empty"} = NamedRoute.validate(route)
    end

    test "returns error for nil directives" do
      route = %NamedRoute{name: "my_route", directives: nil}
      assert {:error, "directives cannot be empty"} = NamedRoute.validate(route)
    end
  end

  describe "valid_name?/1" do
    test "accepts alphanumeric names" do
      assert NamedRoute.valid_name?("route")
      assert NamedRoute.valid_name?("ROUTE")
      assert NamedRoute.valid_name?("route123")
    end

    test "accepts underscores" do
      assert NamedRoute.valid_name?("my_route")
      assert NamedRoute.valid_name?("_private")
    end

    test "accepts hyphens" do
      assert NamedRoute.valid_name?("my-route")
      assert NamedRoute.valid_name?("route-v2")
    end

    test "rejects spaces" do
      refute NamedRoute.valid_name?("my route")
    end

    test "rejects special characters" do
      refute NamedRoute.valid_name?("route!")
      refute NamedRoute.valid_name?("route@")
      refute NamedRoute.valid_name?("route.v2")
    end
  end

  describe "invoke/1" do
    test "generates invoke directive" do
      route = NamedRoute.new("common_headers", "header X-Test true")
      assert NamedRoute.invoke(route) == "invoke &(common_headers)"
    end
  end

  describe "invoke_by_name/1" do
    test "generates invoke directive from name" do
      assert NamedRoute.invoke_by_name("common_headers") == "invoke &(common_headers)"
    end

    test "generates invoke directive with hyphenated name" do
      assert NamedRoute.invoke_by_name("my-route") == "invoke &(my-route)"
    end
  end

  describe "Caddyfile protocol" do
    test "renders simple route" do
      route = NamedRoute.new("error_handler", "respond 500")
      result = Caddyfile.to_caddyfile(route)
      assert result =~ "&(error_handler) {"
      assert result =~ "respond 500"
      assert result =~ "}"
    end

    test "renders multi-line directives" do
      directives = """
      header Cache-Control "public, max-age=3600"
      header X-Frame-Options DENY
      """

      route = NamedRoute.new("common_headers", directives)
      result = Caddyfile.to_caddyfile(route)
      assert result =~ "&(common_headers) {"
      assert result =~ "header Cache-Control"
      assert result =~ "header X-Frame-Options DENY"
      assert result =~ "}"
    end

    test "indents directives properly" do
      route = NamedRoute.new("test_route", "respond 200")
      result = Caddyfile.to_caddyfile(route)
      # Each directive line should be indented
      assert result =~ "  respond 200"
    end
  end
end
