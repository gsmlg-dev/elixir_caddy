defmodule CaddyTest do
  use ExUnit.Case
  doctest Caddy

  test "test caddy server version" do
    assert Caddy.Bootstrap.get(:version) =~ "2.8.4"
  end

  test "test caddy server cmd" do
    assert Caddy.Bootstrap.get(:bin_path) =~ "bin/caddy"
  end

  test "test caddyfile" do
    assert Caddy.Config.get(:caddy_bin) =~ "bin/caddy"
  end
end
