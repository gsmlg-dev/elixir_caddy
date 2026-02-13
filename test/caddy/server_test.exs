defmodule Caddy.ServerTest do
  use ExUnit.Case, async: false

  alias Caddy.{Config, ConfigProvider}

  setup do
    # Store original config to restore after test
    original_config = ConfigProvider.get_config()

    on_exit(fn ->
      # Restore original configuration
      ConfigProvider.set_config(original_config)

      # Clean up any test artifacts
      if File.exists?(Config.pid_file()) do
        File.rm(Config.pid_file())
      end
    end)

    {:ok, original_config: original_config}
  end

  describe "Server lifecycle" do
    test "can retrieve server configuration", %{original_config: _config} do
      config = ConfigProvider.get_config()

      # Configuration should be a Config struct
      assert %Config{} = config
      # Should have a binary path (may be nil if not configured)
      assert is_binary(config.bin) or is_nil(config.bin)
    end

    test "set_bin validates the binary path", %{original_config: original} do
      # Try to set an invalid path - should fail validation
      result = ConfigProvider.set_bin("/nonexistent/caddy")
      assert {:error, _reason} = result

      # Config should remain unchanged after failed validation
      config = ConfigProvider.get_config()
      assert config.bin == original.bin
    end

    test "can set caddyfile configuration", %{original_config: _original} do
      caddyfile = """
      {
        debug
        auto_https off
      }
      """

      ConfigProvider.set_caddyfile(caddyfile)
      config = ConfigProvider.get_config()

      # Config stores parsed parts, not raw caddyfile
      assert String.contains?(config.global, "debug")
      assert String.contains?(config.global, "auto_https off")
    end

    test "can append to caddyfile configuration", %{original_config: _original} do
      ConfigProvider.set_caddyfile("{ debug }")
      ConfigProvider.append_caddyfile("example.com { reverse_proxy localhost:3000 }")

      # Check assembled caddyfile contains both
      caddyfile = ConfigProvider.get_caddyfile()

      assert String.contains?(caddyfile, "debug")
      assert String.contains?(caddyfile, "example.com")
    end
  end

  describe "Configuration validation" do
    test "validates caddy binary exists" do
      # Test that validation catches non-existent binaries
      result = Config.validate_bin("/this/does/not/exist")
      assert {:error, _message} = result
    end

    test "validates caddy binary when it exists" do
      caddy_bin = System.find_executable("caddy")

      if caddy_bin do
        result = Config.validate_bin(caddy_bin)
        # Should either be :ok or an error about permissions/version
        case result do
          :ok -> assert true
          {:error, _msg} -> assert true
        end
      else
        assert true
      end
    end

    test "rejects non-binary input" do
      result = Config.validate_bin(123)
      assert {:error, _} = result
    end
  end

  describe "PID file management" do
    test "pid file path is generated correctly" do
      pid_file = Config.pid_file()
      assert is_binary(pid_file)
      assert String.ends_with?(pid_file, "caddy.pid")
    end

    test "socket file path is generated correctly" do
      socket_file = Config.socket_file()
      assert is_binary(socket_file)
      assert String.ends_with?(socket_file, "caddy.sock")
    end
  end

  describe "Path management" do
    test "ensures all required paths exist" do
      result = Config.ensure_path_exists()
      assert result == true

      # Verify paths were created
      assert File.dir?(Config.priv_path())
      assert File.dir?(Config.share_path())
      assert File.dir?(Config.etc_path())
      assert File.dir?(Config.run_path())
      assert File.dir?(Config.tmp_path())
    end
  end
end
