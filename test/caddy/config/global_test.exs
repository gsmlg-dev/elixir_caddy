defmodule Caddy.Config.GlobalTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Global
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates empty global config" do
      global = Global.new()

      assert global.debug == false
      assert global.admin == nil
      assert global.email == nil
      assert global.extra_options == []
    end

    test "creates global config with options" do
      global = Global.new(debug: true, admin: "unix//tmp/caddy.sock")

      assert global.debug == true
      assert global.admin == "unix//tmp/caddy.sock"
    end
  end

  describe "Caddyfile protocol" do
    test "renders empty global as empty string" do
      global = Global.new()
      result = Caddyfile.to_caddyfile(global)

      assert result == ""
    end

    test "renders debug flag" do
      global = Global.new(debug: true)
      result = Caddyfile.to_caddyfile(global)

      assert result == "{\n  debug\n}"
    end

    test "renders admin endpoint" do
      global = Global.new(admin: "unix//var/run/caddy.sock")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "{"
      assert result =~ "admin unix//var/run/caddy.sock"
      assert result =~ "}"
    end

    test "renders admin off" do
      global = Global.new(admin: :off)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "admin off"
    end

    test "renders email" do
      global = Global.new(email: "admin@example.com")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "email admin@example.com"
    end

    test "renders acme_ca" do
      global = Global.new(acme_ca: "https://acme-staging-v02.api.letsencrypt.org/directory")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "acme_ca https://acme-staging-v02.api.letsencrypt.org/directory"
    end

    test "renders storage" do
      global = Global.new(storage: "file_system /var/lib/caddy")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "storage file_system /var/lib/caddy"
    end

    test "renders multiple options" do
      global =
        Global.new(
          debug: true,
          admin: "unix//tmp/caddy.sock",
          email: "admin@example.com",
          acme_ca: "https://acme-staging-v02.api.letsencrypt.org/directory"
        )

      result = Caddyfile.to_caddyfile(global)

      assert result =~ "{"
      assert result =~ "debug"
      assert result =~ "admin unix//tmp/caddy.sock"
      assert result =~ "email admin@example.com"
      assert result =~ "acme_ca https://acme-staging-v02.api.letsencrypt.org/directory"
      assert result =~ "}"
    end

    test "renders extra_options" do
      global = Global.new(extra_options: ["log", "auto_https off"])
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "log"
      assert result =~ "auto_https off"
    end

    test "maintains proper indentation" do
      global = Global.new(debug: true, admin: "unix//tmp/caddy.sock")
      result = Caddyfile.to_caddyfile(global)

      lines = String.split(result, "\n")
      assert Enum.at(lines, 0) == "{"
      assert Enum.at(lines, 1) =~ ~r/^  /
      assert Enum.at(lines, 2) =~ ~r/^  /
    end
  end
end
