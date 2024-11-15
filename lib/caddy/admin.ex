defmodule Caddy.Admin do
  @moduledoc """

  Caddy Admin

  Start Caddy Admin

  """
  require Logger

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.info("Caddy Admin init")
    Process.send_after(self(), :check_server, 30_000)
    {:ok, %{}}
  end

  def handle_info(:check_server, state) do
    check_caddy_server()
    Process.send_after(self(), :check_server, 30_000)
    {:noreply, state}
  end

  defp check_caddy_server() do
    Caddy.Admin.Api.get_config("admin")
  rescue
    _ ->
      Caddy.Bootstrap.restart()
  end

end
