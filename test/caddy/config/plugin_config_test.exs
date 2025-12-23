defmodule Caddy.Config.PluginConfigTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.PluginConfig
  alias Caddy.Caddyfile

  describe "new/2" do
    test "creates plugin config with empty config" do
      plugin = PluginConfig.new("crowdsec")
      assert plugin.name == "crowdsec"
      assert plugin.config == %{}
    end

    test "creates plugin config with options" do
      plugin = PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      assert plugin.name == "crowdsec"
      assert plugin.config == %{api_url: "http://localhost:8080"}
    end
  end

  describe "validate/1" do
    test "returns ok for valid plugin" do
      plugin = PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      assert {:ok, ^plugin} = PluginConfig.validate(plugin)
    end

    test "returns ok for plugin with empty config" do
      plugin = PluginConfig.new("cache")
      assert {:ok, ^plugin} = PluginConfig.validate(plugin)
    end

    test "returns ok for name with hyphens" do
      plugin = PluginConfig.new("rate-limit", %{})
      assert {:ok, ^plugin} = PluginConfig.validate(plugin)
    end

    test "returns ok for name with underscores" do
      plugin = PluginConfig.new("my_plugin", %{})
      assert {:ok, ^plugin} = PluginConfig.validate(plugin)
    end

    test "returns error for empty name" do
      plugin = %PluginConfig{name: "", config: %{}}
      assert {:error, "name cannot be empty"} = PluginConfig.validate(plugin)
    end

    test "returns error for nil name" do
      plugin = %PluginConfig{name: nil, config: %{}}
      assert {:error, "name cannot be empty"} = PluginConfig.validate(plugin)
    end

    test "returns error for name with spaces" do
      plugin = %PluginConfig{name: "my plugin", config: %{}}

      assert {:error, "name must contain only alphanumeric characters, underscores, and hyphens"} =
               PluginConfig.validate(plugin)
    end
  end

  describe "valid_name?/1" do
    test "accepts alphanumeric names" do
      assert PluginConfig.valid_name?("crowdsec")
      assert PluginConfig.valid_name?("plugin123")
    end

    test "accepts hyphens" do
      assert PluginConfig.valid_name?("rate-limit")
    end

    test "accepts underscores" do
      assert PluginConfig.valid_name?("my_plugin")
    end

    test "rejects spaces" do
      refute PluginConfig.valid_name?("my plugin")
    end

    test "rejects special characters" do
      refute PluginConfig.valid_name?("plugin@")
      refute PluginConfig.valid_name?("plugin!")
    end
  end

  describe "merge/2" do
    test "merges additional config" do
      plugin = PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      merged = PluginConfig.merge(plugin, %{api_key: "secret"})
      assert merged.config == %{api_url: "http://localhost:8080", api_key: "secret"}
    end

    test "overwrites existing keys" do
      plugin = PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      merged = PluginConfig.merge(plugin, %{api_url: "http://localhost:9090"})
      assert merged.config == %{api_url: "http://localhost:9090"}
    end
  end

  describe "Caddyfile protocol" do
    test "renders plugin with no config" do
      plugin = PluginConfig.new("cache")
      assert Caddyfile.to_caddyfile(plugin) == "cache"
    end

    test "renders plugin with string config" do
      plugin = PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      result = Caddyfile.to_caddyfile(plugin)
      assert result =~ "crowdsec {"
      assert result =~ "api_url http://localhost:8080"
      assert result =~ "}"
    end

    test "renders plugin with integer config" do
      plugin = PluginConfig.new("rate_limit", %{burst: 20})
      result = Caddyfile.to_caddyfile(plugin)
      assert result =~ "rate_limit {"
      assert result =~ "burst 20"
    end

    test "renders plugin with boolean config" do
      plugin = PluginConfig.new("cache", %{enabled: true, debug: false})
      result = Caddyfile.to_caddyfile(plugin)
      assert result =~ "cache {"
      assert result =~ "enabled"
      assert result =~ "debug off"
    end

    test "renders plugin with list config" do
      plugin =
        PluginConfig.new("cors", %{allowed_origins: ["http://localhost", "http://example.com"]})

      result = Caddyfile.to_caddyfile(plugin)
      assert result =~ "cors {"
      assert result =~ "allowed_origins http://localhost http://example.com"
    end

    test "renders plugin with string containing spaces" do
      plugin = PluginConfig.new("header", %{value: "Hello World"})
      result = Caddyfile.to_caddyfile(plugin)
      assert result =~ "header {"
      assert result =~ ~s(value "Hello World")
    end

    test "renders plugin with atom config" do
      plugin = PluginConfig.new("log", %{level: :debug})
      result = Caddyfile.to_caddyfile(plugin)
      assert result =~ "log {"
      assert result =~ "level debug"
    end

    test "renders multiple options sorted alphabetically" do
      plugin = PluginConfig.new("test", %{zebra: "last", alpha: "first", beta: "second"})
      result = Caddyfile.to_caddyfile(plugin)
      lines = String.split(result, "\n")
      # Should be sorted: alpha, beta, zebra
      assert Enum.at(lines, 1) =~ "alpha"
      assert Enum.at(lines, 2) =~ "beta"
      assert Enum.at(lines, 3) =~ "zebra"
    end
  end
end
