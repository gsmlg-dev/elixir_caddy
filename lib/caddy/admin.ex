defmodule Caddy.Admin do
  @moduledoc false
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

  defp check_caddy_server() do
    %{"listen" => "unix/" <> _} = Caddy.Admin.Api.get_config("admin")
  rescue
    error ->
      Logger.error("Caddy Admin: check_caddy_server failed #{inspect(error)}")
      Caddy.restart_server()
  end
end
