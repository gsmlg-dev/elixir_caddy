defmodule Caddy.Config.SiteTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Site
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates site with hostname" do
      site = Site.new("example.com")

      assert site.host_name == "example.com"
      assert site.tls == :auto
      assert site.server_aliases == []
      assert site.imports == []
      assert site.directives == []
    end
  end

  describe "builder functions" do
    test "listen/2 sets listen address" do
      site = Site.new("example.com") |> Site.listen(":443")

      assert site.listen == ":443"
    end

    test "add_alias/2 with single alias" do
      site = Site.new("example.com") |> Site.add_alias("www.example.com")

      assert site.server_aliases == ["www.example.com"]
    end

    test "add_alias/2 with multiple aliases" do
      site =
        Site.new("example.com")
        |> Site.add_alias(["www.example.com", "example.org"])

      assert site.server_aliases == ["www.example.com", "example.org"]
    end

    test "tls/2 with atom" do
      site = Site.new("example.com") |> Site.tls(:internal)

      assert site.tls == :internal
    end

    test "tls/2 with cert and key" do
      site = Site.new("example.com") |> Site.tls({"/cert.pem", "/key.pem"})

      assert site.tls == {"/cert.pem", "/key.pem"}
    end

    test "import_snippet/3" do
      site = Site.new("example.com") |> Site.import_snippet("log-zone", ["app", "prod"])

      assert length(site.imports) == 1
      assert hd(site.imports).snippet == "log-zone"
      assert hd(site.imports).args == ["app", "prod"]
    end

    test "import_file/2" do
      site = Site.new("example.com") |> Site.import_file("/etc/caddy/common.conf")

      assert length(site.imports) == 1
      assert hd(site.imports).path == "/etc/caddy/common.conf"
    end

    test "reverse_proxy/2" do
      site = Site.new("example.com") |> Site.reverse_proxy("localhost:3000")

      assert site.directives == ["reverse_proxy localhost:3000"]
    end

    test "add_directive/2 with string" do
      site = Site.new("example.com") |> Site.add_directive("encode gzip")

      assert site.directives == ["encode gzip"]
    end

    test "add_directive/2 with tuple" do
      site = Site.new("example.com") |> Site.add_directive({"header", "X-Custom value"})

      assert site.directives == [{"header", "X-Custom value"}]
    end

    test "chaining multiple operations" do
      site =
        Site.new("example.com")
        |> Site.listen(":443")
        |> Site.add_alias("www.example.com")
        |> Site.tls(:auto)
        |> Site.reverse_proxy("localhost:3000")
        |> Site.add_directive("encode gzip")

      assert site.listen == ":443"
      assert site.server_aliases == ["www.example.com"]
      assert site.tls == :auto
      assert length(site.directives) == 2
    end
  end

  describe "Caddyfile protocol" do
    test "renders simple site" do
      site = Site.new("example.com") |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "example.com {"
      assert result =~ "  respond 200"
      assert result =~ "}"
    end

    test "renders site with listen address" do
      site =
        Site.new("example.com")
        |> Site.listen(":443")
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ ":443 example.com {"
    end

    test "renders site with server aliases" do
      site =
        Site.new("example.com")
        |> Site.add_alias(["www.example.com", "example.org"])
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "example.com www.example.com example.org {"
    end

    test "renders site with TLS off" do
      site =
        Site.new("example.com")
        |> Site.tls(:off)
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "  tls off"
    end

    test "renders site with TLS internal" do
      site =
        Site.new("example.com")
        |> Site.tls(:internal)
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "  tls internal"
    end

    test "renders site with TLS cert and key" do
      site =
        Site.new("example.com")
        |> Site.tls({"/cert.pem", "/key.pem"})
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "  tls /cert.pem /key.pem"
    end

    test "does not render TLS directive for auto" do
      site =
        Site.new("example.com")
        |> Site.tls(:auto)
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      refute result =~ "tls"
    end

    test "renders site with imports" do
      site =
        Site.new("example.com")
        |> Site.import_snippet("log-zone", ["app", "prod"])
        |> Site.import_snippet("cors")
        |> Site.add_directive("respond 200")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ ~s(  import log-zone "app" "prod")
      assert result =~ "  import cors"
    end

    test "renders complete complex site" do
      site =
        Site.new("app.example.com")
        |> Site.listen(":443")
        |> Site.add_alias(["www.app.example.com"])
        |> Site.tls(:auto)
        |> Site.import_snippet("log-zone", ["app", "production"])
        |> Site.import_snippet("security-headers")
        |> Site.add_directive("encode gzip")
        |> Site.reverse_proxy("localhost:3000")

      result = Caddyfile.to_caddyfile(site)

      assert result =~ ":443 app.example.com www.app.example.com {"
      assert result =~ ~s(  import log-zone "app" "production")
      assert result =~ "  import security-headers"
      assert result =~ "  encode gzip"
      assert result =~ "  reverse_proxy localhost:3000"
    end

    test "renders directives as tuples" do
      site =
        Site.new("example.com")
        |> Site.add_directive({"header", "X-Custom-Header value"})

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "  header X-Custom-Header value"
    end

    test "renders extra_config" do
      site = %Site{
        host_name: "example.com",
        extra_config: "custom directive\nanother directive"
      }

      result = Caddyfile.to_caddyfile(site)

      assert result =~ "  custom directive"
      assert result =~ "  another directive"
    end

    test "maintains proper directive order" do
      site =
        Site.new("example.com")
        |> Site.tls(:internal)
        |> Site.import_snippet("log")
        |> Site.add_directive("encode gzip")
        |> Site.reverse_proxy("localhost:3000")

      result = Caddyfile.to_caddyfile(site)

      lines =
        result
        |> String.split("\n")
        |> Enum.filter(&(String.trim(&1) != "" and &1 != "}"))
        |> tl()

      # TLS should come first, then imports, then directives
      assert Enum.at(lines, 0) =~ "tls internal"
      assert Enum.at(lines, 1) =~ "import log"
      assert Enum.at(lines, 2) =~ "encode gzip"
      assert Enum.at(lines, 3) =~ "reverse_proxy localhost:3000"
    end
  end
end
