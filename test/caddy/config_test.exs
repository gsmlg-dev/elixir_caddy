defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config

  test "test caddy conifg paths" do
    Config.ensure_path_exists()

    Config.paths()
    |> Enum.each(fn path ->
      assert File.exists?(path)
    end)
  end

  describe "site configuration validation" do
    test "valid site configuration with string" do
      assert :ok = Config.validate_site_config("reverse_proxy localhost:3000")
    end

    test "invalid empty site configuration" do
      assert {:error, "site configuration cannot be empty"} = Config.validate_site_config("")
      assert {:error, "site configuration cannot be empty"} = Config.validate_site_config("   ")
    end

    test "valid site configuration with listen tuple" do
      assert :ok = Config.validate_site_config({":8080", "reverse_proxy localhost:3000"})
    end

    test "invalid empty listen address" do
      assert {:error, "listen address cannot be empty"} =
               Config.validate_site_config({"", "config"})
    end

    test "invalid listen address format" do
      assert {:error, "listen address must contain port (e.g., ':8080')"} =
               Config.validate_site_config({"invalid", "config"})
    end

    test "invalid site configuration format" do
      assert {:error, "invalid site configuration format"} = Config.validate_site_config(123)
      assert {:error, "invalid site configuration format"} = Config.validate_site_config(nil)
    end

    test "set_site with invalid configuration" do
      assert {:error, "site configuration cannot be empty"} = Config.set_site("test", "")
    end

    test "set_site with valid configuration" do
      assert :ok = Config.set_site("test", "reverse_proxy localhost:3000")
    end
  end

  describe "binary path validation" do
    test "valid binary path" do
      # Use a known executable for testing
      bin_path = System.find_executable("echo") || "/bin/echo"

      assert {:error, "Invalid Caddy binary or version incompatibility"} =
               Config.validate_bin(bin_path)
    end

    test "non-existent binary" do
      assert {:error, "Caddy binary not found at path: /nonexistent/path/caddy"} =
               Config.validate_bin("/nonexistent/path/caddy")
    end

    test "non-executable binary" do
      assert {:error, _} = Config.validate_bin("/dev/null")
    end

    test "invalid binary type" do
      assert {:error, "binary path must be a string"} = Config.validate_bin(123)
      assert {:error, "binary path must be a string"} = Config.validate_bin(nil)
    end

    test "set_bin with invalid path" do
      assert {:error, _} = Config.set_bin("/nonexistent/path/caddy")
    end
  end

  describe "configuration validation" do
    test "validate full configuration" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        sites: %{"test" => "reverse_proxy localhost:3000"}
      }

      assert is_binary(Config.to_caddyfile(config))
    end

    test "empty sites configuration" do
      config = %Config{bin: "/usr/bin/caddy", global: "debug", sites: %{}}
      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "debug")
    end
  end
end
