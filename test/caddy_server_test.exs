defmodule CaddyServerTest do
  use ExUnit.Case
  doctest CaddyServer

  test "test caddy server version" do
    assert CaddyServer.version() =~ "2.6.4"
  end

  test "test caddy server cmd" do
    assert CaddyServer.cmd() =~ "priv/bin/caddy"
  end

  test "test caddyfile" do
    assert CaddyServer.caddyfile() =~ "admin unix//"
  end
end
