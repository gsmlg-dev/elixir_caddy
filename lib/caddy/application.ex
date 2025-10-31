defmodule Caddy.Application do
  @moduledoc """
  OTP Application for Caddy reverse proxy management.

  Starts the main Caddy supervisor tree when the application starts.
  Note: Only starts in non-test environments (see mix.exs).
  """

  use Application

  @impl true
  def start(_type, args) do
    children = [
      {Caddy, args}
    ]

    opts = [strategy: :one_for_one, name: Caddy.Application]
    Supervisor.start_link(children, opts)
  end
end
