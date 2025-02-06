# Caddy

[![release](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml/badge.svg)](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml)

Add this in `deps` in `mix.exs` to install

```elixir
{:caddy, "~> 2.0"}
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
      ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

Start in extra_applications

```elixir
def application do
  [
    extra_applications: [Caddy.Application]
  ]
end
```
