defmodule CaddyServerTest do
  use ExUnit.Case
  doctest CaddyServer

  test "test caddy download url" do
    assert CaddyServer.download_url() =~
             "https://github.com/caddyserver/caddy/releases/download/v2.6.4/caddy_2.6.4_mac_arm64.tar.gz"
  end
end
