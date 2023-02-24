defmodule CaddyServer do
  @moduledoc """
  Documentation for `CaddyServer`.
  """

  @version "2.6.4"

  @doc """
  Start Caddy server at

  Accept accesss from `127.0.0.1/8`

  Start server with

  ```
  CaddyServer.start()
  ```

  To start server, libevent must be installed.
  """
  def start() do
    File.mkdir_p(Application.app_dir(:caddy_server, "priv") <> "/etc")
    f = Application.app_dir(:caddy_server, "priv") <> "/etc/Caddyfile"
    File.write!(f, caddyfile())

    port =
      Port.open(
        {:spawn_executable, cmd()},
        args: ["run", "--adapter", "caddyfile", "--config", f]
      )
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
    p = Application.app_dir(:caddy_server, "priv")
    caddy_cmd = p <> "/bin/caddy"

    unless File.exists?(caddy_cmd) do
      IO.puts("cmd not exists, downloading...")

      case download() do
        0 -> caddy_cmd
        _ -> :error
      end
    else
      caddy_cmd
    end
  end

  @doc """
  Download caddy from Github

  https://github.com/caddyserver/caddy/releases

  ## Examples

      iex> CaddyServer.download()
      0

  """
  def download() do
    (Application.app_dir(:caddy_server, "priv") <> "/bin") |> File.mkdir_p()

    body =
      case System.fetch_env("HTTP_PROXY") do
        {:ok, proxy} ->
          %HTTPoison.Response{status_code: 200, body: body} =
            download_url()
            |> HTTPoison.get!([], proxy: {"10.100.0.1", 3128}, follow_redirect: true)

          body

        :error ->
          %HTTPoison.Response{status_code: 200, body: body} =
            download_url() |> HTTPoison.get!([], follow_redirect: true)

          body
      end

    p = Application.app_dir(:caddy_server, "priv")
    f = p <> "/" <> filename()

    File.write!(f, body)

    {_, code} = System.cmd("tar", ["zxf", f, "-C", p, "caddy"])
    File.mkdir_p(Application.app_dir(:caddy_server, "priv") <> "/bin")
    System.cmd("mv", ["#{p}/caddy", "#{p}/bin/caddy"])

    code
  end

  def download_url() do
    "https://github.com/caddyserver/caddy/releases/download/v#{@version}/" <> filename()
  end

  def filename() do
    {os, arch} = os_arch()
    "caddy_#{@version}_#{os}_#{arch}.tar.gz"
  end

  def os_arch() do
    {arch, os_str} =
      case :erlang.system_info(:system_architecture) |> to_string() do
        "aarch64-" <> os_info ->
          {"arm64", os_info}

        "x86_64-" <> os_info ->
          {"amd64", os_info}

        _ ->
          IO.puts("unsupported")
          :error
      end

    {ostype} =
      cond do
        String.contains?(os_str, "darwin") -> {"mac"}
        String.contains?(os_str, "linux") -> {"linux"}
        true -> :error
      end

    {ostype, arch}
  end
end
