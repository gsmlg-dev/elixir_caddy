# Caddy

By set `mix.exs` to install
```elixir
{:caddy, "~> 1.0"}
```

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
      # Start a Caddy by calling: Caddy.start_link([])
      {Caddy, [
        caddy_bin: "<path to caddy binary>",
        caddy_file: "<path to caddyfile config>", # caddyfile to load, if not set use config instead
        config: %{}, # map() parsed json config,
        merge_saved: false, # Merge saved config, defaults to false
      ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
```
