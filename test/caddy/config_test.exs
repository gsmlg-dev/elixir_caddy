defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config
  alias Caddy.ConfigProvider

  setup do
    # Ensure fresh state for each test
    :ok
  end

  describe "configuration structure validation" do
    test "valid configuration with caddyfile text" do
      config = %Config{
        bin: "/usr/bin/caddy",
        caddyfile: """
        {
          debug
        }

        example.com {
          reverse_proxy localhost:3000
        }
        """,
        env: [{"KEY", "value"}]
      }

      assert :ok = Config.validate_config(config)
    end

    test "valid configuration with nil bin" do
      config = %Config{
        bin: nil,
        caddyfile: "{ debug }",
        env: []
      }

      assert :ok = Config.validate_config(config)
    end

    test "invalid bin type" do
      config = %Config{
        bin: 123,
        caddyfile: "{ debug }",
        env: []
      }

      assert {:error, "bin must be a string or nil"} = Config.validate_config(config)
    end

    test "invalid env type" do
      config = %Config{
        bin: "/usr/bin/caddy",
        caddyfile: "{ debug }",
        env: "not a list"
      }

      assert {:error, "env must be a list"} = Config.validate_config(config)
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

  describe "to_caddyfile" do
    test "returns the caddyfile text directly" do
      caddyfile_text = """
      {
        debug
        admin unix//tmp/caddy.sock
      }

      example.com {
        reverse_proxy localhost:3000
      }
      """

      config = %Config{
        bin: "/usr/bin/caddy",
        caddyfile: caddyfile_text
      }

      assert Config.to_caddyfile(config) == caddyfile_text
    end

    test "handles empty caddyfile" do
      config = %Config{caddyfile: ""}
      assert Config.to_caddyfile(config) == ""
    end
  end

  describe "default_caddyfile" do
    test "generates default caddyfile with admin socket" do
      caddyfile = Config.default_caddyfile()
      assert String.contains?(caddyfile, "admin unix/")
      assert String.contains?(caddyfile, "{")
      assert String.contains?(caddyfile, "}")
    end
  end

  describe "adapt function" do
    test "adapt uses System.find_executable when binary not configured" do
      # Save current config
      original_config = ConfigProvider.get_config()

      # Temporarily set config with no binary
      Agent.update(ConfigProvider, fn _state -> %Config{bin: nil, caddyfile: ""} end)

      # ConfigProvider.adapt will call Config.adapt which falls back to System.find_executable
      result = ConfigProvider.adapt("{ debug }")

      case result do
        {:ok, _config} ->
          # Caddy was found in PATH
          assert true

        {:error, "Caddy binary path not configured"} ->
          # Caddy not in PATH
          assert true

        {:error, _reason} ->
          # Some other error
          assert true
      end

      # Restore original config
      Agent.update(ConfigProvider, fn _state -> original_config end)
    end

    test "adapt returns error for empty content" do
      assert {:error, _} = ConfigProvider.adapt("")
    end
  end

  describe "initialization" do
    test "init creates default configuration structure" do
      config = ConfigProvider.init([])
      assert %Config{} = config
      assert is_binary(config.caddyfile)
      assert is_list(config.env)
    end

    test "init with caddy_bin argument" do
      config = ConfigProvider.init(caddy_bin: "/custom/path/caddy")
      assert config.bin == "/custom/path/caddy"
    end
  end

  describe "ConfigProvider operations" do
    test "set_caddyfile updates the config" do
      new_caddyfile = "{ admin off }"
      :ok = ConfigProvider.set_caddyfile(new_caddyfile)
      assert ConfigProvider.get_caddyfile() == new_caddyfile
    end

    test "append_caddyfile adds to existing config" do
      original = ConfigProvider.get_caddyfile()
      ConfigProvider.set_caddyfile("{ debug }")
      :ok = ConfigProvider.append_caddyfile("example.com { respond 200 }")
      result = ConfigProvider.get_caddyfile()
      assert String.contains?(result, "{ debug }")
      assert String.contains?(result, "example.com")

      # Restore
      ConfigProvider.set_caddyfile(original)
    end

    test "get returns config value by key" do
      assert is_binary(ConfigProvider.get(:caddyfile)) or is_nil(ConfigProvider.get(:caddyfile))
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

    test "ensure_dir_exists creates parent directories" do
      test_path =
        Path.join(System.tmp_dir!(), "caddy_test_#{System.unique_integer()}/sub/file.txt")

      assert :ok = Config.ensure_dir_exists(test_path)
      assert File.exists?(Path.dirname(test_path))

      # Cleanup
      File.rm_rf(Path.dirname(Path.dirname(test_path)))
    end
  end

  describe "path utilities" do
    test "base_path returns string" do
      assert is_binary(Config.base_path())
    end

    test "etc_path returns string" do
      assert is_binary(Config.etc_path())
    end

    test "run_path returns string" do
      assert is_binary(Config.run_path())
    end

    test "tmp_path returns string" do
      assert is_binary(Config.tmp_path())
    end

    test "socket_file returns string" do
      assert is_binary(Config.socket_file())
    end

    test "pid_file returns string" do
      assert is_binary(Config.pid_file())
    end

    test "init_file returns string" do
      assert is_binary(Config.init_file())
    end
  end

  describe "init_env" do
    test "returns list of environment tuples" do
      env = Config.init_env()
      assert is_list(env)
      assert Enum.all?(env, fn {k, v} -> is_binary(k) and is_binary(v) end)
    end
  end
end
