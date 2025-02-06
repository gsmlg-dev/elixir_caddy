# Elixir Caddy

[![release](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml/badge.svg)](https://github.com/gsmlg-dev/elixir_caddy/actions/workflows/release.yml)

Start `Caddy` reverse proxy server in `Elixir` project.

Manage caddy configuration in `Elixir`.

Add this in `deps` in `mix.exs` to install

```elixir
{:caddy, "~> 2.0"}
```

Start in Application supervisor

```elixir
def start(_type, _args) do
  children = [
    # Start a Caddy by calling: Caddy.start_link([])
    {Caddy, caddy_bin: "/path/to/caddy"}
  ]

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

* Notice

If caddy_bin is not specifiy, Caddy.Server will not start.

## Set `Caddy` binary when needed.

Set `caddy_bin` to the path of Caddy binary file and start `Caddy.Server`.

```elixir
Caddy.Cofnig.set_bin("/usr/bin/caddy")
Caddy.restart_server()
```

This will restart server automatically

```elixir
Caddy.Cofnig.set_bin!("/usr/bin/caddy")
```
