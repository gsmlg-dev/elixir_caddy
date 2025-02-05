defmodule Caddy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, args) do
    children = [
      {Caddy.Config, args},
      Caddy.Logger,
      Caddy.Server
      # Caddy.Admin
    ]

    opts = [strategy: :one_for_one, name: Caddy.Application]
    Supervisor.start_link(children, opts)
  end
end
