defmodule Caddy.ConfigTest do
  use ExUnit.Case
  # doctest Caddy.Config

  test "test caddy conifg command_stdin" do
    caddy = System.find_executable("caddy")
    command = "#{caddy} adapt"
    config = """
    {
      admin off
      auto_https off
    }
    """
    r = Caddy.Config.command_stdin(command, config)
    assert {output, code} = r
    assert 0 = code
    assert "Error: parsing caddyfile: invalid character 'a' looking for beginning of object key string" = output
  end
end
