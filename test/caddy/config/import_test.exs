defmodule Caddy.Config.ImportTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Import
  alias Caddy.Caddyfile

  describe "snippet/2" do
    test "creates import without arguments" do
      import_directive = Import.snippet("cors")

      assert import_directive.snippet == "cors"
      assert import_directive.args == []
      assert import_directive.path == nil
    end

    test "creates import with single argument" do
      import_directive = Import.snippet("log-zone", ["app"])

      assert import_directive.snippet == "log-zone"
      assert import_directive.args == ["app"]
    end

    test "creates import with multiple arguments" do
      import_directive = Import.snippet("log-zone", ["app", "production"])

      assert import_directive.snippet == "log-zone"
      assert import_directive.args == ["app", "production"]
    end
  end

  describe "file/1" do
    test "creates file import" do
      import_directive = Import.file("/etc/caddy/common.conf")

      assert import_directive.path == "/etc/caddy/common.conf"
      assert import_directive.snippet == nil
    end
  end

  describe "Caddyfile protocol" do
    test "renders snippet import without arguments" do
      import_directive = Import.snippet("cors")
      result = Caddyfile.to_caddyfile(import_directive)

      assert result == "import cors"
    end

    test "renders snippet import with single argument" do
      import_directive = Import.snippet("log-zone", ["app"])
      result = Caddyfile.to_caddyfile(import_directive)

      assert result == ~s(import log-zone "app")
    end

    test "renders snippet import with multiple arguments" do
      import_directive = Import.snippet("log-zone", ["app", "production"])
      result = Caddyfile.to_caddyfile(import_directive)

      assert result == ~s(import log-zone "app" "production")
    end

    test "renders file import" do
      import_directive = Import.file("/etc/caddy/common.conf")
      result = Caddyfile.to_caddyfile(import_directive)

      assert result == "import /etc/caddy/common.conf"
    end

    test "quotes arguments with spaces" do
      import_directive = Import.snippet("test", ["arg with spaces"])
      result = Caddyfile.to_caddyfile(import_directive)

      assert result == ~s(import test "arg with spaces")
    end

    test "returns empty string for invalid import" do
      import_directive = %Import{}
      result = Caddyfile.to_caddyfile(import_directive)

      assert result == ""
    end
  end
end
