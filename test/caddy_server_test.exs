defmodule CaddyTest do
  use ExUnit.Case
  doctest Caddy

  test "test caddy server version" do
    assert Caddy.version() =~ "2.8.4"
  end

  test "test caddy server cmd" do
    assert Caddy.cmd() =~ "priv/bin/caddy"
  end

  test "test caddyfile" do
    assert Caddy.caddyfile() =~ "admin unix//"
  end
end
