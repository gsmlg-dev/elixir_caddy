defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config

  setup_all do
    on_exit(fn ->
      nil
    end)
  end

  test "test caddy conifg paths" do
    Config.ensure_path_exists()

    Config.paths()
    |> Enum.each(fn path ->
      assert File.exists?(path)
    end)
  end

  test "test caddy config get config" do
    assert %Config{} = Config.get_config()
  end

  test "test config config check caddy bin" do
    assert :ok = Config.check_bin(Config.get_config().bin)
  end

  test "test caddy config adapt" do
    cfg = """
    {
      admin unix//run/caddy.socket
      auto_https off
    }
    git.example.com {
      root * /var/www/git.example.com
      file_server
    }
    """

    assert {:ok, config} = Config.adapt(cfg)
    assert "unix//run/caddy.socket" = get_in(config, ["admin", "listen"])
  end

  test "test caddy config global" do
    global = Config.get_config() |> Map.get(:global)
    assert global =~ "admin unix/#{Config.socket_file()}"
  end

  test "test caddy config set_global" do
    global_config = """
    debug
    admin unix/#{Config.socket_file()}
    """

    assert {:ok, config} = Config.set_global(global_config)
    assert config =~ "debug"
    assert config =~ "admin unix/#{Config.socket_file()}"
  end

  test "test caddy config set_site" do
    site_config = """
    reverse_proxy {
      to https://z.cn
      header_up host z.cn
    }
    """

    assert {:ok, "z.cn", {":8088", ^site_config}} =
             Config.set_site("z.cn", {":8088", site_config})

    Caddy.restart_server()

    caddyfile = Caddy.Server.get_caddyfile()
    assert caddyfile =~ "to https://z.cn"
    assert caddyfile =~ "header_up host z.cn"
  end
end
