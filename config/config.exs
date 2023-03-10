# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :caddy_server, CaddyServer,
  version: "2.6.4",
  auto_download: true,
  control_socket: nil,
  bin_path: nil,
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
