import Config

config :caddy_server, CaddyServer,
  version: "2.8.4",
  auto_download: true,
  control_socket: nil,
  bin_path: nil,
  global_conf: """
  http_port 80
  https_port 443
  """,
  site_conf: """
  :3955 {
    log {
      output stdout
      format json
    }

    header {
      X-Frame-Options SAMEORIGIN
      X-Content-Type-Options nosniff
      X-XSS-Protection "1; mode=block"
      X-Server "elixir_caddy"
    }

    route {
      reverse_proxy /api/* {
        to https://api.github.com:443
        header_up Host api.github.com
      }

      reverse_proxy unix//tmp/app.sock
    }
  }
  """

config :logger,
  level: :debug,
  truncate: 4096
