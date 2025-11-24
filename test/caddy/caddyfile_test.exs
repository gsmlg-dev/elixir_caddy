defmodule Caddy.CaddyfileTest do
  use ExUnit.Case, async: true

  alias Caddy.Caddyfile

  describe "protocol with strings" do
    test "converts string to itself" do
      assert Caddyfile.to_caddyfile("hello") == "hello"
    end

    test "preserves multiline strings" do
      content = """
      line 1
      line 2
      """

      assert Caddyfile.to_caddyfile(content) == content
    end

    test "preserves empty strings" do
      assert Caddyfile.to_caddyfile("") == ""
    end
  end

  describe "fallback implementation" do
    test "returns empty string for unimplemented types" do
      assert Caddyfile.to_caddyfile(123) == ""
      assert Caddyfile.to_caddyfile(:atom) == ""
      assert Caddyfile.to_caddyfile([1, 2, 3]) == ""
    end
  end
end
