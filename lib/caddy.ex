defmodule Caddy do
  @moduledoc """

  # Caddy

  Start Caddy HTTP Server in supervisor tree

  - Start in your application

  ```elixir
  def start(_type, _args) do
    children = [
      # Start a Caddy by calling: Caddy.start_link([])
      {Caddy, [
        caddy_bin: "/usr/bin/caddy",
      ]}
      # Start the Telemetry supervisor
      PhoenixWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PhoenixWeb.PubSub},
      # Start the Endpoint (http/https)
      PhoenixWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: PhoenixWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

  - Start in extra_applications

  ```elixir
  def application do
    [
      extra_applications: [Caddy.Application]
    ]
  end
  ```

  """
  require Logger

  use Supervisor

  @spec start() :: :ignore | {:error, any()} | {:ok, pid()}
  def start() do
    caddy_bin = System.find_executable("caddy")
    start_link(caddy_bin: caddy_bin)
  end

  @spec stop(term()) :: :ok
  def stop(reason \\ :normal) do
    Supervisor.stop(__MODULE__, reason)
  end

  @spec start_link(Keyword.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    children = [
      Caddy.Logger,
      {Caddy.Config, args},
      Caddy.Server
      # Caddy.Admin
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
