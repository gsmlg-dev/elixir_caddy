defmodule CaddyServer do
  @moduledoc """
  Documentation for `CaddyServer`.
  """

  require Logger

  @default_version "2.6.4"

  @doc """
  Start Caddy server at

  Accept accesss from `127.0.0.1/8`

  Start server with

  ```
  CaddyServer.start()
  ```

  """
  def start() do
    File.mkdir_p(priv_dir("/etc"))
    f = priv_dir("/etc/Caddyfile")

    Logger.info("Write Caddyfile")
    Logger.debug("Caddyfile:\n#{caddyfile()}")
    File.write!(f, caddyfile())

    Logger.info("Staring Caddy Server...")

    port =
      Port.open(
        {:spawn_executable, cmd()},
        args: ["run", "--adapter", "caddyfile", "--config", f]
      )

    port
  end

  @doc """
  Return Caddy Version from ` Application.get_env(:caddy_server, CaddyServer) |> Keyword.get(:version)`

  if not defined, use `@default_version` instead

  """
  def version() do
    case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:version) do
      {:ok, version} -> version
      :error -> @default_version
    end
  end

  def caddyfile() do
    """

    {
      admin #{control_socket()} {
        origins caddy-admin.local
      }
    }

    """
  end

  def cmd() do
    path =
      if CaddyServer.Downloader.downloaded_bin() |> File.exists?() do
        CaddyServer.Downloader.downloaded_bin()
      else
        case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:bin_path) do
          {:ok, bin_path} when is_binary(bin_path) ->
            Logger.debug("using bin_path setted in application env: #{bin_path}")
            bin_path

          _ ->
            if CaddyServer.Downloader.auto?() do
              0 = CaddyServer.Downloader.download()
              CaddyServer.Downloader.downloaded_bin()
            else
              ""
            end
        end
      end

    if File.exists?(path) do
      path
    else
      raise "No Caddy command found"
    end
  end

  def control_socket() do
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
    Logger.debug("#{f}: #{inspect(File.stat(f))}")

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

  defp priv_dir(p) do
    Application.app_dir(:caddy_server, "priv#{p}")
  end
end
