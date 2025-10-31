defmodule Caddy.Admin do
  @moduledoc """
  GenServer that periodically checks Caddy server health.

  This module runs as a background process that checks the Caddy server
  status every 15 seconds and logs any connection issues.
  """
  require Logger

  use GenServer

  @check_interval 15_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.debug("Caddy Admin init")
    Process.send_after(self(), :check_server, @check_interval)
    {:ok, %{}}
  end

  def handle_info(:check_server, state) do
    check_caddy_server()
    Process.send_after(self(), :check_server, @check_interval)
    {:noreply, state}
  end

  defp check_caddy_server do
    %{"listen" => "unix/" <> _} = Caddy.Admin.Api.get_config("admin")
  rescue
    error ->
      Logger.error("Caddy Admin: check_caddy_server failed #{inspect(error)}")
      Caddy.Supervisor.restart_server()
  end
end
