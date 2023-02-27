defmodule CaddyServer do
  @moduledoc """
  Documentation for `CaddyServer`.
  """

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
    File.write!(f, caddyfile())

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
      admin unix//var/run/caddy_admin.sock {
        origins localhost
      }
    }

    """
  end

  def cmd() do
    path =
      case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:bin_path) do
        :error ->
          if CaddyServer.Downloader.auto?() do
            0 = CaddyServer.Downloader.download()
            CaddyServer.Downloader.downloaded_bin()
          else
            ""
          end

        {:ok, nil} ->
          if CaddyServer.Downloader.auto?() do
            0 = CaddyServer.Downloader.download()
            CaddyServer.Downloader.downloaded_bin()
          else
            ""
          end

        {:ok, bin_path} ->
          bin_path
      end

    if File.exists?(path) do
      path
    else
      raise "No Caddy command found"
    end
  end

  defp priv_dir(p) do
    Application.app_dir(:caddy_server, "priv#{p}")
  end

end
