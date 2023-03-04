# CaddyServer

## Start Caddy Server by `Port`

Start in Application supervisor

```elixir
def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PhoenixWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PhoenixWeb.PubSub},
      # Start the Endpoint (http/https)
      PhoenixWeb.Endpoint,
      # Start a CaddyServer by calling: CaddyServer.start_link([])
      {CaddyServer, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

## Config Caddy Server

Set caddy config:

```elixir
config :caddy_server, CaddyServer,
  version: "2.6.4", # auto download version
  auto_download: true, # enable auto download
  control_socket: nil, # caddy server admin's unix socket
  bin_path: nil, # caddy server binary file path
  # Caddyfile of caddy server
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

```

