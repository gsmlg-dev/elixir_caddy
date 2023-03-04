defmodule CaddyServer.AdminSocket do
  require Logger

  @doc """
  Return admin socket path of caddy server.

  soeket path is set in config
  ```
  config :caddy_server, CaddyServer, control_socket: nil
  ```

  If confit is not set, use default socket
  root:
  `unix//var/run/caddy_admin.sock`
  user:
  `unix/${HOME}/.local/run/caddy_admin.sock`

  """
  def socket_path() do
    case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:control_socket) do
      {:ok, socket} when is_binary(socket) ->
        Logger.debug("using socket setted in application env: #{socket}")
        socket

      _ ->
        create_socket_path()
    end
  end

  defp create_socket_path() do
    rp = "unix//var/run/caddy_admin.sock"

    if check_write_perm(cut_prefix(rp)) do
      Logger.debug("using socket: #{rp}")
      p = Path.dirname(rp)

      unless File.exists?(p) do
        :ok = File.mkdir_p(p)
      end

      rp
    else
      up = "unix/#{System.get_env("HOME")}/.local/run/caddy_admin.sock"
      Logger.debug("using socket: #{up}")
      p = Path.dirname(up)

      unless File.exists?(p) do
        :ok = File.mkdir_p(p)
      end

      up
    end
  end

  defp check_write_perm(f) do
    if File.exists?(f) do
      perm = has_write_perm?(f)
      # Logger.debug("checking write perm: #{f} | #{perm}")
      perm
    else
      p = Path.dirname(f)
      check_write_perm(p)
    end
  end

  defp has_write_perm?(f) do
    case File.stat(f) do
      {:ok, %File.Stat{access: :read_write}} -> true
      {:ok, %File.Stat{access: :write}} -> true
      _ -> false
    end
  end

  defp cut_prefix(p) do
    if String.slice(p, 0, 5) == "unix/" do
      String.slice(p, 5, String.length(p))
    else
      p
    end
  end
end
