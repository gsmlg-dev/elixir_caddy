defmodule Caddy.Config.EnvVarTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.EnvVar
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates env var without default" do
      env = EnvVar.new("DATABASE_URL")
      assert env.name == "DATABASE_URL"
      assert env.default == nil
    end

    test "creates env var with default" do
      env = EnvVar.new("PORT", "8080")
      assert env.name == "PORT"
      assert env.default == "8080"
    end
  end

  describe "validate/1" do
    test "returns ok for valid env var without default" do
      env = EnvVar.new("APP_ENV")
      assert {:ok, ^env} = EnvVar.validate(env)
    end

    test "returns ok for valid env var with default" do
      env = EnvVar.new("PORT", "3000")
      assert {:ok, ^env} = EnvVar.validate(env)
    end

    test "returns ok for underscore-prefixed name" do
      env = EnvVar.new("_INTERNAL_VAR")
      assert {:ok, ^env} = EnvVar.validate(env)
    end

    test "returns error for empty name" do
      env = %EnvVar{name: ""}
      assert {:error, "name cannot be empty"} = EnvVar.validate(env)
    end

    test "returns error for nil name" do
      env = %EnvVar{name: nil}
      assert {:error, "name cannot be empty"} = EnvVar.validate(env)
    end

    test "returns error for name starting with digit" do
      env = %EnvVar{name: "123VAR"}

      assert {:error, "name must contain only alphanumeric characters and underscores"} =
               EnvVar.validate(env)
    end

    test "returns error for name with hyphens" do
      env = %EnvVar{name: "MY-VAR"}

      assert {:error, "name must contain only alphanumeric characters and underscores"} =
               EnvVar.validate(env)
    end

    test "returns error for name with special characters" do
      env = %EnvVar{name: "VAR!@#"}

      assert {:error, "name must contain only alphanumeric characters and underscores"} =
               EnvVar.validate(env)
    end
  end

  describe "valid_name?/1" do
    test "accepts uppercase letters" do
      assert EnvVar.valid_name?("MYVAR")
    end

    test "accepts lowercase letters" do
      assert EnvVar.valid_name?("myvar")
    end

    test "accepts mixed case letters" do
      assert EnvVar.valid_name?("MyVar")
    end

    test "accepts underscores" do
      assert EnvVar.valid_name?("MY_VAR")
    end

    test "accepts leading underscore" do
      assert EnvVar.valid_name?("_PRIVATE")
    end

    test "accepts numbers in middle/end" do
      assert EnvVar.valid_name?("VAR123")
      assert EnvVar.valid_name?("V1A2R3")
    end

    test "rejects leading digit" do
      refute EnvVar.valid_name?("1VAR")
    end

    test "rejects hyphens" do
      refute EnvVar.valid_name?("MY-VAR")
    end

    test "rejects spaces" do
      refute EnvVar.valid_name?("MY VAR")
    end

    test "rejects special characters" do
      refute EnvVar.valid_name?("VAR$")
      refute EnvVar.valid_name?("VAR@")
    end
  end

  describe "Caddyfile protocol" do
    test "renders env var without default" do
      env = EnvVar.new("DATABASE_URL")
      assert Caddyfile.to_caddyfile(env) == "{$DATABASE_URL}"
    end

    test "renders env var with default" do
      env = EnvVar.new("PORT", "8080")
      assert Caddyfile.to_caddyfile(env) == "{$PORT:8080}"
    end

    test "renders env var with empty string default" do
      env = EnvVar.new("OPTIONAL_VAR", "")
      assert Caddyfile.to_caddyfile(env) == "{$OPTIONAL_VAR:}"
    end

    test "renders complex default value" do
      env = EnvVar.new("API_URL", "https://api.example.com")
      assert Caddyfile.to_caddyfile(env) == "{$API_URL:https://api.example.com}"
    end
  end
end
