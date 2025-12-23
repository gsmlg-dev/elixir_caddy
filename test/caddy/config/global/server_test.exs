defmodule Caddy.Config.Global.ServerTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Global.Server
  alias Caddy.Config.Global.Timeouts
  alias Caddy.Caddyfile

  doctest Caddy.Config.Global.Server

  describe "new/1" do
    test "creates empty server with defaults" do
      server = Server.new()

      assert server.name == nil
      assert server.protocols == nil
      assert server.timeouts == nil
      assert server.trusted_proxies == nil
      assert server.trusted_proxies_strict == nil
      assert server.client_ip_headers == nil
      assert server.max_header_size == nil
      assert server.keepalive_interval == nil
      assert server.log_credentials == nil
      assert server.strict_sni_host == nil
    end

    test "creates server with specified values" do
      server = Server.new(name: "https", protocols: [:h1, :h2])

      assert server.name == "https"
      assert server.protocols == [:h1, :h2]
    end

    test "creates server with timeouts" do
      timeouts = %Timeouts{read_body: "10s"}
      server = Server.new(timeouts: timeouts)

      assert server.timeouts == timeouts
    end
  end

  describe "Caddyfile protocol" do
    test "renders empty string for empty server" do
      server = %Server{}
      result = Caddyfile.to_caddyfile(server)

      assert result == ""
    end

    test "renders name option" do
      server = %Server{name: "https"}
      result = Caddyfile.to_caddyfile(server)

      assert result == "name https"
    end

    test "renders protocols option" do
      server = %Server{protocols: [:h1, :h2, :h3]}
      result = Caddyfile.to_caddyfile(server)

      assert result == "protocols h1 h2 h3"
    end

    test "renders timeouts block" do
      timeouts = %Timeouts{read_body: "10s", idle: "2m"}
      server = %Server{timeouts: timeouts}
      result = Caddyfile.to_caddyfile(server)

      assert result =~ "timeouts {"
      assert result =~ "read_body 10s"
      assert result =~ "idle 2m"
    end

    test "renders trusted_proxies option" do
      server = %Server{trusted_proxies: {:static, ["private_ranges"]}}
      result = Caddyfile.to_caddyfile(server)

      assert result == "trusted_proxies static private_ranges"
    end

    test "renders trusted_proxies with multiple values" do
      server = %Server{trusted_proxies: {:static, ["192.168.0.0/16", "10.0.0.0/8"]}}
      result = Caddyfile.to_caddyfile(server)

      assert result == "trusted_proxies static 192.168.0.0/16 10.0.0.0/8"
    end

    test "renders trusted_proxies_strict flag when true" do
      server = %Server{trusted_proxies_strict: true}
      result = Caddyfile.to_caddyfile(server)

      assert result == "trusted_proxies_strict"
    end

    test "does not render trusted_proxies_strict when false" do
      server = %Server{trusted_proxies_strict: false}
      result = Caddyfile.to_caddyfile(server)

      assert result == ""
    end

    test "renders client_ip_headers option" do
      server = %Server{client_ip_headers: ["X-Forwarded-For", "X-Real-IP"]}
      result = Caddyfile.to_caddyfile(server)

      assert result == "client_ip_headers X-Forwarded-For X-Real-IP"
    end

    test "renders max_header_size option" do
      server = %Server{max_header_size: "5MB"}
      result = Caddyfile.to_caddyfile(server)

      assert result == "max_header_size 5MB"
    end

    test "renders keepalive_interval option" do
      server = %Server{keepalive_interval: "30s"}
      result = Caddyfile.to_caddyfile(server)

      assert result == "keepalive_interval 30s"
    end

    test "renders log_credentials flag when true" do
      server = %Server{log_credentials: true}
      result = Caddyfile.to_caddyfile(server)

      assert result == "log_credentials"
    end

    test "does not render log_credentials when false" do
      server = %Server{log_credentials: false}
      result = Caddyfile.to_caddyfile(server)

      assert result == ""
    end

    test "renders strict_sni_host option" do
      server = %Server{strict_sni_host: :on}
      result = Caddyfile.to_caddyfile(server)

      assert result == "strict_sni_host on"
    end

    test "renders strict_sni_host insecure_off" do
      server = %Server{strict_sni_host: :insecure_off}
      result = Caddyfile.to_caddyfile(server)

      assert result == "strict_sni_host insecure_off"
    end

    test "renders multiple options in correct order" do
      server = %Server{
        name: "https",
        protocols: [:h1, :h2],
        max_header_size: "5MB",
        keepalive_interval: "30s"
      }

      result = Caddyfile.to_caddyfile(server)

      # Verify order: name, protocols, max_header_size, keepalive_interval
      assert result =~ ~r/name.*protocols.*max_header_size.*keepalive_interval/s
    end

    test "renders complex server configuration" do
      server = %Server{
        name: "https",
        protocols: [:h1, :h2, :h3],
        timeouts: %Timeouts{read_body: "10s", idle: "2m"},
        trusted_proxies: {:static, ["private_ranges"]},
        client_ip_headers: ["X-Forwarded-For"]
      }

      result = Caddyfile.to_caddyfile(server)

      assert result =~ "name https"
      assert result =~ "protocols h1 h2 h3"
      assert result =~ "timeouts {"
      assert result =~ "read_body 10s"
      assert result =~ "trusted_proxies static private_ranges"
      assert result =~ "client_ip_headers X-Forwarded-For"
    end

    test "does not render empty protocols list" do
      server = %Server{name: "https", protocols: []}
      result = Caddyfile.to_caddyfile(server)

      assert result == "name https"
      refute result =~ "protocols"
    end

    test "does not render empty client_ip_headers list" do
      server = %Server{name: "https", client_ip_headers: []}
      result = Caddyfile.to_caddyfile(server)

      assert result == "name https"
      refute result =~ "client_ip_headers"
    end
  end
end
