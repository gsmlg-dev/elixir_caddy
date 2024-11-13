import Config

config :caddy, Caddy,
  admin_socket: Application.app_dir(:caddy, "priv/run/caddy.sock")

config :logger,
  level: :debug,
  truncate: 4096
