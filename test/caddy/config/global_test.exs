defmodule Caddy.Config.GlobalTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Global
  alias Caddy.Config.Global.{Log, PKI, Server, Timeouts}
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

    test "creates global config with new fields" do
      global = Global.new(http_port: 8080, https_port: 8443, auto_https: :disable_redirects)

      assert global.http_port == 8080
      assert global.https_port == 8443
      assert global.auto_https == :disable_redirects
    end

    test "new fields default to nil" do
      global = Global.new()

      assert global.http_port == nil
      assert global.https_port == nil
      assert global.auto_https == nil
      assert global.local_certs == nil
      assert global.servers == nil
      assert global.log == nil
      assert global.pki == nil
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

  # User Story 1: Configure Common Global Options
  describe "US1: Common Global Options" do
    test "renders http_port" do
      global = Global.new(http_port: 8080)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "http_port 8080"
    end

    test "renders https_port" do
      global = Global.new(https_port: 8443)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "https_port 8443"
    end

    test "renders auto_https" do
      global = Global.new(auto_https: :disable_redirects)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "auto_https disable_redirects"
    end

    test "renders auto_https off" do
      global = Global.new(auto_https: :off)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "auto_https off"
    end

    test "renders local_certs flag" do
      global = Global.new(local_certs: true)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "local_certs"
    end

    test "does not render local_certs when false" do
      global = Global.new(local_certs: false)
      result = Caddyfile.to_caddyfile(global)

      assert result == ""
    end

    test "renders skip_install_trust flag" do
      global = Global.new(skip_install_trust: true)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "skip_install_trust"
    end

    test "renders key_type" do
      global = Global.new(key_type: :ed25519)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "key_type ed25519"
    end

    test "renders key_type p256" do
      global = Global.new(key_type: :p256)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "key_type p256"
    end

    test "renders grace_period" do
      global = Global.new(grace_period: "30s")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "grace_period 30s"
    end

    test "renders shutdown_delay" do
      global = Global.new(shutdown_delay: "5s")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "shutdown_delay 5s"
    end

    test "renders default_bind" do
      global = Global.new(default_bind: ["0.0.0.0", "::"])
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "default_bind 0.0.0.0 ::"
    end

    test "renders renew_interval" do
      global = Global.new(renew_interval: "30m")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "renew_interval 30m"
    end

    test "renders cert_lifetime" do
      global = Global.new(cert_lifetime: "90d")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "cert_lifetime 90d"
    end

    test "renders acme_ca_root" do
      global = Global.new(acme_ca_root: "/path/to/root.pem")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "acme_ca_root /path/to/root.pem"
    end

    test "renders default_sni" do
      global = Global.new(default_sni: "example.com")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "default_sni example.com"
    end

    test "renders persist_config off" do
      global = Global.new(persist_config: false)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "persist_config off"
    end

    test "does not render persist_config when true" do
      global = Global.new(persist_config: true)
      result = Caddyfile.to_caddyfile(global)

      assert result == ""
    end

    test "renders ocsp_stapling off" do
      global = Global.new(ocsp_stapling: false)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "ocsp_stapling off"
    end

    test "renders storage_clean_interval" do
      global = Global.new(storage_clean_interval: "24h")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "storage_clean_interval 24h"
    end

    test "renders ocsp_interval" do
      global = Global.new(ocsp_interval: "1h")
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "ocsp_interval 1h"
    end

    test "renders acme_dns" do
      global = Global.new(acme_dns: {:cloudflare, "{env.CLOUDFLARE_API_TOKEN}"})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}"
    end

    test "renders acme_eab block" do
      global = Global.new(acme_eab: %{key_id: "my_key_id", mac_key: "my_mac_key"})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "acme_eab {"
      assert result =~ "key_id my_key_id"
      assert result =~ "mac_key my_mac_key"
    end

    test "renders on_demand_tls with ask" do
      global = Global.new(on_demand_tls: %{ask: "http://localhost:9123/ask"})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "on_demand_tls {"
      assert result =~ "ask http://localhost:9123/ask"
    end

    test "renders preferred_chains smallest" do
      global = Global.new(preferred_chains: :smallest)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "preferred_chains smallest"
    end

    test "renders order directives" do
      global = Global.new(order: [{:php_server, :before, :file_server}])
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "order php_server before file_server"
    end

    test "renders log block" do
      log = %Log{output: "stdout", format: :json}
      global = Global.new(log: [log])
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "log {"
      assert result =~ "output stdout"
      assert result =~ "format json"
    end

    test "backward compatibility - existing code works unchanged" do
      global = %Global{
        admin: "unix//var/run/caddy.sock",
        debug: true,
        email: "admin@example.com"
      }

      result = Caddyfile.to_caddyfile(global)

      assert result =~ "debug"
      assert result =~ "admin unix//var/run/caddy.sock"
      assert result =~ "email admin@example.com"
    end
  end

  # User Story 2: Configure Server Options
  describe "US2: Server Options" do
    test "renders servers block with listener" do
      server = %Server{name: "https"}
      global = Global.new(servers: %{":443" => server})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "servers :443 {"
      assert result =~ "name https"
    end

    test "renders server with protocols" do
      server = %Server{protocols: [:h1, :h2, :h3]}
      global = Global.new(servers: %{":443" => server})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "protocols h1 h2 h3"
    end

    test "renders server with timeouts block" do
      timeouts = %Timeouts{read_body: "10s", read_header: "5s", write: "30s", idle: "2m"}
      server = %Server{timeouts: timeouts}
      global = Global.new(servers: %{":443" => server})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "timeouts {"
      assert result =~ "read_body 10s"
      assert result =~ "read_header 5s"
      assert result =~ "write 30s"
      assert result =~ "idle 2m"
    end

    test "renders server with trusted_proxies" do
      server = %Server{trusted_proxies: {:static, ["private_ranges"]}}
      global = Global.new(servers: %{":443" => server})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "trusted_proxies static private_ranges"
    end

    test "renders server with client_ip_headers" do
      server = %Server{client_ip_headers: ["X-Forwarded-For", "X-Real-IP"]}
      global = Global.new(servers: %{":443" => server})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "client_ip_headers X-Forwarded-For X-Real-IP"
    end

    test "renders complex server configuration" do
      server = %Server{
        name: "https",
        protocols: [:h1, :h2],
        timeouts: %Timeouts{read_body: "10s", idle: "2m"},
        trusted_proxies: {:static, ["private_ranges"]}
      }

      global = Global.new(servers: %{":443" => server})
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "servers :443 {"
      assert result =~ "name https"
      assert result =~ "protocols h1 h2"
      assert result =~ "timeouts {"
      assert result =~ "trusted_proxies static private_ranges"
    end
  end

  # User Story 3: Configure Dynamic/Custom Options
  describe "US3: Dynamic Options" do
    test "extra_options renders after typed fields" do
      global =
        Global.new(
          debug: true,
          http_port: 8080,
          extra_options: ["layer4 {", "  # layer4 config", "}"]
        )

      result = Caddyfile.to_caddyfile(global)

      # Verify order: typed fields first, then extra_options
      debug_pos = :binary.match(result, "debug") |> elem(0)
      http_port_pos = :binary.match(result, "http_port") |> elem(0)
      layer4_pos = :binary.match(result, "layer4") |> elem(0)

      assert debug_pos < layer4_pos
      assert http_port_pos < layer4_pos
    end

    test "mixed typed and extra_options work correctly" do
      global =
        Global.new(
          debug: true,
          email: "admin@example.com",
          http_port: 8080,
          extra_options: ["custom_directive value"]
        )

      result = Caddyfile.to_caddyfile(global)

      assert result =~ "debug"
      assert result =~ "email admin@example.com"
      assert result =~ "http_port 8080"
      assert result =~ "custom_directive value"
    end
  end

  # User Story 4: Configure PKI Options
  describe "US4: PKI Options" do
    test "renders pki block" do
      pki = %PKI{
        ca_id: "local",
        name: "My Company CA",
        root_cn: "Root CA",
        intermediate_cn: "Intermediate CA"
      }

      global = Global.new(pki: pki)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "pki {"
      assert result =~ "ca local {"
      assert result =~ ~s(name "My Company CA")
      assert result =~ ~s(root_cn "Root CA")
      assert result =~ ~s(intermediate_cn "Intermediate CA")
    end

    test "renders local_certs with pki" do
      pki = %PKI{name: "Internal CA", intermediate_lifetime: "30d"}

      global = Global.new(local_certs: true, pki: pki)
      result = Caddyfile.to_caddyfile(global)

      assert result =~ "local_certs"
      assert result =~ "pki {"
      assert result =~ ~s(name "Internal CA")
      assert result =~ "intermediate_lifetime 30d"
    end
  end

  # Integration tests
  describe "Integration" do
    test "renders complete production configuration" do
      global =
        Global.new(
          debug: false,
          http_port: 80,
          https_port: 443,
          admin: "unix//var/run/caddy.sock",
          grace_period: "30s",
          shutdown_delay: "5s",
          email: "admin@example.com",
          acme_ca: "https://acme-v02.api.letsencrypt.org/directory",
          key_type: :ed25519,
          renew_interval: "30m",
          log: [
            %Log{
              output: "file /var/log/caddy/access.log",
              format: :json,
              level: :INFO
            }
          ],
          servers: %{
            ":443" => %Server{
              protocols: [:h1, :h2, :h3],
              timeouts: %Timeouts{
                read_body: "10s",
                read_header: "5s",
                write: "30s",
                idle: "2m"
              },
              trusted_proxies: {:static, ["private_ranges"]}
            }
          }
        )

      result = Caddyfile.to_caddyfile(global)

      # Verify all components are present
      assert result =~ "http_port 80"
      assert result =~ "https_port 443"
      assert result =~ "admin unix//var/run/caddy.sock"
      assert result =~ "grace_period 30s"
      assert result =~ "shutdown_delay 5s"
      assert result =~ "email admin@example.com"
      assert result =~ "acme_ca https://acme-v02.api.letsencrypt.org/directory"
      assert result =~ "key_type ed25519"
      assert result =~ "renew_interval 30m"
      assert result =~ "log {"
      assert result =~ "output file /var/log/caddy/access.log"
      assert result =~ "format json"
      assert result =~ "level INFO"
      assert result =~ "servers :443 {"
      assert result =~ "protocols h1 h2 h3"
      assert result =~ "timeouts {"
      assert result =~ "trusted_proxies static private_ranges"
    end

    test "renders development configuration" do
      global =
        Global.new(
          debug: true,
          http_port: 8080,
          https_port: 8443,
          local_certs: true,
          auto_https: :disable_redirects
        )

      result = Caddyfile.to_caddyfile(global)

      assert result =~ "debug"
      assert result =~ "local_certs"
      assert result =~ "http_port 8080"
      assert result =~ "https_port 8443"
      assert result =~ "auto_https disable_redirects"
    end
  end
end
