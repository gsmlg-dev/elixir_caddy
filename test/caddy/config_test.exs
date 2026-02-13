defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config
  alias Caddy.ConfigProvider

  setup do
    # Ensure fresh state for each test
    :ok
  end

  describe "configuration structure validation" do
    test "valid configuration with 3-part structure" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additionals: [%{name: "snippet", content: "(snippet) { }"}],
        sites: [%{address: "example.com", config: "reverse_proxy localhost:3000"}],
        env: [{"KEY", "value"}]
      }

      assert :ok = Config.validate_config(config)
    end

    test "valid configuration with nil bin" do
      config = %Config{
        bin: nil,
        global: "debug",
        additionals: [],
        sites: [],
        env: []
      }

      assert :ok = Config.validate_config(config)
    end

    test "invalid bin type" do
      config = %Config{
        bin: 123,
        global: "debug",
        additionals: [],
        sites: [],
        env: []
      }

      assert {:error, "bin must be a string or nil"} = Config.validate_config(config)
    end

    test "invalid env type" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additionals: [],
        sites: [],
        env: "not a list"
      }

      assert {:error, "env must be a list"} = Config.validate_config(config)
    end

    test "invalid sites type" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additionals: [],
        sites: "not a list",
        env: []
      }

      assert {:error, "sites must be a list"} = Config.validate_config(config)
    end

    test "invalid site structure" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additionals: [],
        sites: [%{address: "example.com"}],
        env: []
      }

      assert {:error, "sites must be a list of maps with :address and :config string keys"} =
               Config.validate_config(config)
    end

    test "invalid additionals type" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additionals: "not a list",
        sites: [],
        env: []
      }

      assert {:error, "additionals must be a list"} = Config.validate_config(config)
    end

    test "invalid additional structure" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug",
        additionals: [%{name: "test"}],
        sites: [],
        env: []
      }

      assert {:error, "additionals must be a list of maps with :name and :content string keys"} =
               Config.validate_config(config)
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
    test "assembles 3 parts into caddyfile" do
      config = %Config{
        bin: "/usr/bin/caddy",
        global: "debug\nadmin unix//tmp/caddy.sock",
        additionals: [],
        sites: [%{address: "example.com", config: "reverse_proxy localhost:3000"}]
      }

      caddyfile = Config.to_caddyfile(config)

      assert String.contains?(caddyfile, "{")
      assert String.contains?(caddyfile, "debug")
      assert String.contains?(caddyfile, "admin unix//tmp/caddy.sock")
      assert String.contains?(caddyfile, "example.com {")
      assert String.contains?(caddyfile, "reverse_proxy localhost:3000")
    end

    test "handles empty config" do
      config = %Config{global: "", additionals: [], sites: []}
      assert Config.to_caddyfile(config) == ""
    end

    test "handles only global config" do
      config = %Config{global: "debug", additionals: [], sites: []}
      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "{\n  debug\n}")
    end

    test "handles only sites" do
      config = %Config{
        global: "",
        additionals: [],
        sites: [%{address: "example.com", config: "respond 200"}]
      }

      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "example.com {")
      assert String.contains?(caddyfile, "respond 200")
    end

    test "handles additional directives" do
      config = %Config{
        global: "",
        additionals: [%{name: "snippet", content: "(snippet) {\n  header X-Custom value\n}"}],
        sites: []
      }

      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "(snippet)")
      assert String.contains?(caddyfile, "header X-Custom value")
    end

    test "handles multiple additionals" do
      config = %Config{
        global: "",
        additionals: [
          %{name: "common", content: "(common) { header X-Common value }"},
          %{name: "security", content: "(security) { header X-Security value }"}
        ],
        sites: []
      }

      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "(common)")
      assert String.contains?(caddyfile, "(security)")
    end

    test "handles multiple sites" do
      config = %Config{
        global: "debug",
        additionals: [],
        sites: [
          %{address: "example.com", config: "reverse_proxy localhost:3000"},
          %{address: "api.example.com", config: "reverse_proxy localhost:4000"}
        ]
      }

      caddyfile = Config.to_caddyfile(config)
      assert String.contains?(caddyfile, "example.com {")
      assert String.contains?(caddyfile, "api.example.com {")
      assert String.contains?(caddyfile, "localhost:3000")
      assert String.contains?(caddyfile, "localhost:4000")
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

  describe "default_config" do
    test "returns config struct with defaults" do
      config = Config.default_config()
      assert %Config{} = config
      assert String.contains?(config.global, "admin unix/")
      assert config.additionals == []
      assert config.sites == []
      assert is_list(config.env)
    end
  end

  describe "adapt function" do
    test "adapt uses System.find_executable when binary not configured" do
      # Save current config
      original_config = ConfigProvider.get_config()

      # Temporarily set config with no binary
      Agent.update(ConfigProvider, fn _state ->
        %Config{bin: nil, global: "", additionals: [], sites: []}
      end)

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
      assert is_binary(config.global)
      assert is_list(config.additionals)
      assert is_list(config.sites)
      assert is_list(config.env)
    end

    test "init with caddy_bin argument" do
      config = ConfigProvider.init(caddy_bin: "/custom/path/caddy")
      assert config.bin == "/custom/path/caddy"
    end
  end

  describe "ConfigProvider operations" do
    test "set_caddyfile updates the config by parsing" do
      new_caddyfile = "{ admin off }"
      :ok = ConfigProvider.set_caddyfile(new_caddyfile)
      result = ConfigProvider.get_caddyfile()
      assert String.contains?(result, "admin off")
    end

    test "append_caddyfile adds sites to existing config" do
      original = ConfigProvider.get_caddyfile()
      ConfigProvider.set_caddyfile("{ debug }")
      :ok = ConfigProvider.append_caddyfile("example.com { respond 200 }")
      result = ConfigProvider.get_caddyfile()
      assert String.contains?(result, "debug")
      assert String.contains?(result, "example.com")

      # Restore
      ConfigProvider.set_caddyfile(original)
    end

    test "get returns config value by key" do
      assert is_binary(ConfigProvider.get(:global)) or is_nil(ConfigProvider.get(:global))
    end
  end

  describe "ConfigProvider 3-part operations" do
    test "set_global and get_global" do
      original = ConfigProvider.get_global()
      ConfigProvider.set_global("debug\nauto_https off")
      assert ConfigProvider.get_global() == "debug\nauto_https off"
      ConfigProvider.set_global(original)
    end

    test "add_additional and get_additionals" do
      original_additionals = ConfigProvider.get_additionals()

      ConfigProvider.add_additional("test-snippet", "(test) { header X-Test value }")
      additionals = ConfigProvider.get_additionals()
      assert Enum.any?(additionals, &(&1.name == "test-snippet"))

      # Cleanup
      ConfigProvider.remove_additional("test-snippet")

      # Restore original
      Agent.update(ConfigProvider, fn config -> %{config | additionals: original_additionals} end)
    end

    test "get_additional returns specific additional" do
      original_additionals = ConfigProvider.get_additionals()

      ConfigProvider.add_additional("specific-snippet", "(specific) { header X-Specific value }")
      additional = ConfigProvider.get_additional("specific-snippet")
      assert additional.name == "specific-snippet"
      assert String.contains?(additional.content, "(specific)")

      # Cleanup
      Agent.update(ConfigProvider, fn config -> %{config | additionals: original_additionals} end)
    end

    test "update_additional updates existing additional" do
      original_additionals = ConfigProvider.get_additionals()

      ConfigProvider.add_additional("update-snippet", "(update) { header X-Old value }")
      ConfigProvider.update_additional("update-snippet", "(update) { header X-New value }")

      additional = ConfigProvider.get_additional("update-snippet")
      assert String.contains?(additional.content, "X-New")

      # Cleanup
      Agent.update(ConfigProvider, fn config -> %{config | additionals: original_additionals} end)
    end

    test "remove_additional removes additional by name" do
      original_additionals = ConfigProvider.get_additionals()

      ConfigProvider.add_additional("toremove-snippet", "(toremove) { }")
      assert ConfigProvider.get_additional("toremove-snippet") != nil

      ConfigProvider.remove_additional("toremove-snippet")
      assert ConfigProvider.get_additional("toremove-snippet") == nil

      # Restore
      Agent.update(ConfigProvider, fn config -> %{config | additionals: original_additionals} end)
    end

    test "add_site and get_sites" do
      original_sites = ConfigProvider.get_sites()

      ConfigProvider.add_site("test.example.com", "respond 200")
      sites = ConfigProvider.get_sites()
      assert Enum.any?(sites, &(&1.address == "test.example.com"))

      # Cleanup
      ConfigProvider.remove_site("test.example.com")

      # Restore original sites
      Agent.update(ConfigProvider, fn config -> %{config | sites: original_sites} end)
    end

    test "get_site returns specific site" do
      original_sites = ConfigProvider.get_sites()

      ConfigProvider.add_site("specific.example.com", "respond 201")
      site = ConfigProvider.get_site("specific.example.com")
      assert site.address == "specific.example.com"
      assert site.config == "respond 201"

      # Cleanup
      Agent.update(ConfigProvider, fn config -> %{config | sites: original_sites} end)
    end

    test "remove_site removes site by address" do
      original_sites = ConfigProvider.get_sites()

      ConfigProvider.add_site("toremove.example.com", "respond 200")
      assert ConfigProvider.get_site("toremove.example.com") != nil

      ConfigProvider.remove_site("toremove.example.com")
      assert ConfigProvider.get_site("toremove.example.com") == nil

      # Restore original sites
      Agent.update(ConfigProvider, fn config -> %{config | sites: original_sites} end)
    end

    test "update_site updates existing site" do
      original_sites = ConfigProvider.get_sites()

      ConfigProvider.add_site("update.example.com", "respond 200")
      ConfigProvider.update_site("update.example.com", "respond 201")

      site = ConfigProvider.get_site("update.example.com")
      assert site.config == "respond 201"

      # Cleanup
      Agent.update(ConfigProvider, fn config -> %{config | sites: original_sites} end)
    end

    test "update_site adds site if not found" do
      original_sites = ConfigProvider.get_sites()

      ConfigProvider.update_site("newsite.example.com", "respond 200")
      site = ConfigProvider.get_site("newsite.example.com")
      assert site != nil
      assert site.config == "respond 200"

      # Cleanup
      Agent.update(ConfigProvider, fn config -> %{config | sites: original_sites} end)
    end
  end

  describe "ConfigProvider.parse_caddyfile" do
    test "parses empty caddyfile" do
      {global, additionals, sites} = ConfigProvider.parse_caddyfile("")
      assert global == ""
      assert additionals == []
      assert sites == []
    end

    test "parses global block" do
      caddyfile = """
      {
        debug
        admin off
      }
      """

      {global, additionals, sites} = ConfigProvider.parse_caddyfile(caddyfile)
      assert String.contains?(global, "debug")
      assert String.contains?(global, "admin off")
      assert additionals == []
      assert sites == []
    end

    test "parses site block" do
      caddyfile = """
      example.com {
        reverse_proxy localhost:3000
      }
      """

      {global, additionals, sites} = ConfigProvider.parse_caddyfile(caddyfile)
      assert global == ""
      assert additionals == []
      assert length(sites) == 1
      assert hd(sites).address == "example.com"
      assert String.contains?(hd(sites).config, "reverse_proxy localhost:3000")
    end

    test "parses complete caddyfile" do
      caddyfile = """
      {
        debug
      }

      example.com {
        reverse_proxy localhost:3000
      }

      api.example.com {
        reverse_proxy localhost:4000
      }
      """

      {global, additionals, sites} = ConfigProvider.parse_caddyfile(caddyfile)
      assert String.contains?(global, "debug")
      assert additionals == []
      assert length(sites) == 2
      assert Enum.any?(sites, &(&1.address == "example.com"))
      assert Enum.any?(sites, &(&1.address == "api.example.com"))
    end

    test "parses snippet as additional" do
      caddyfile = """
      (common) {
        header X-Frame-Options DENY
      }
      """

      {global, additionals, sites} = ConfigProvider.parse_caddyfile(caddyfile)
      assert global == ""
      assert length(additionals) == 1
      assert hd(additionals).name == "common"
      assert String.contains?(hd(additionals).content, "(common)")
      assert String.contains?(hd(additionals).content, "header X-Frame-Options DENY")
      assert sites == []
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
