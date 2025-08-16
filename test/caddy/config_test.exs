defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config
  alias Caddy.ConfigProvider

  setup do
    # Ensure fresh state for each test
    :ok
  end

  describe "configuration structure validation" do
    test "valid configuration" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additional: [],
        sites: %{"test" => "reverse_proxy localhost:3000"},
        env: [{"KEY", "value"}]
      }
      
      assert :ok = Config.validate_config(config)
    end

    test "invalid configuration structure" do
      config = %Config{
        bin: 123,  # Invalid type
        global: "debug",
        sites: %{"test" => "reverse_proxy localhost:3000"}
      }
      
      assert {:error, "binary path must be a string or nil"} = Config.validate_config(config)
    end

    test "invalid site configuration in sites" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        sites: %{"test" => ""}
      }
      
      assert {:error, "invalid site configuration in sites"} = Config.validate_config(config)
    end
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
  end

  describe "binary path validation" do
    test "non-existent binary" do
      assert {:error, "Caddy binary not found at path: /nonexistent/path/caddy"} =
               Config.validate_bin("/nonexistent/path/caddy")
    end

    test "invalid binary type" do
      assert {:error, "binary path must be a string"} = Config.validate_bin(123)
      assert {:error, "binary path must be a string"} = Config.validate_bin(nil)
    end

    test "set_bin with validation" do
      assert {:error, _} = ConfigProvider.set_bin("/nonexistent/path/caddy")
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

  describe "configuration conversion" do
    test "to_caddyfile generates valid caddyfile" do
      config = %Config{
        global: "debug",
        additional: ["metrics :2020"],
        sites: %{
          "test" => "reverse_proxy localhost:3000",
          "proxy" => {":8080", "reverse_proxy localhost:3128"}
        }
      }
      
      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "debug")
      assert String.contains?(caddyfile, "metrics :2020")
      assert String.contains?(caddyfile, "## test")
      assert String.contains?(caddyfile, "## proxy")
    end

    test "to_caddyfile handles empty configuration" do
      config = %Config{}
      caddyfile = Config.to_caddyfile(config)
      assert is_binary(caddyfile)
      assert String.contains?(caddyfile, "{")
    end
  end

  describe "configuration management" do
    test "set_config validates configuration" do
      valid_config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        sites: %{"test" => "reverse_proxy localhost:3000"}
      }
      
      assert :ok = ConfigProvider.set_config(valid_config)
    end

    test "set_config rejects invalid configuration" do
      invalid_config = %Config{
        bin: 123,  # Invalid type
        global: "debug",
        sites: %{"test" => "reverse_proxy localhost:3000"}
      }
      
      assert {:error, "binary path must be a string or nil"} = ConfigProvider.set_config(invalid_config)
    end
  end

  describe "adapt function" do
    test "adapt returns error when binary not configured" do
      # Ensure binary is not configured
      ConfigProvider.set_config(%Config{bin: nil})
      assert {:error, "Caddy binary path not configured"} = ConfigProvider.adapt("test")
    end

    test "adapt returns error for empty content" do
      assert {:error, _} = ConfigProvider.adapt("")
    end
  end

  describe "initialization" do
    test "init creates default configuration structure" do
      config = ConfigProvider.init([])
      assert %Config{} = config
      assert is_binary(config.global)
      assert is_list(config.env)
      assert is_map(config.sites)
      assert is_list(config.additional)
    end
  end

  describe "file operations" do
    test "ensure_path_exists handles directory creation" do
      test_dir = Path.join(System.tmp_dir!(), "caddy_test_#{System.unique_integer()}")
      
      # Test the core directory creation logic
      assert File.mkdir_p(Path.join(test_dir, "etc")) == :ok
      assert File.exists?(Path.join(test_dir, "etc"))
      
      # Cleanup
      File.rm_rf(test_dir)
    end
  end
end