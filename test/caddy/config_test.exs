defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config

  setup_all do
    Caddy.Config.start_link([caddy_bin: System.find_executable("caddy")])

    on_exit(fn ->
      nil
      # Caddy.stop()
    end)
  end

  test "test caddy conifg paths" do
    Config.ensure_path_exists()
    Config.paths() |> Enum.each(fn(path) ->
      assert File.exists?(path)
    end)
  end

  test "test caddy config get config" do
    assert %Config{} = Config.get_config()
  end

  test "test config config check bin and version" do
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
end
