defmodule CaddyServer.Downloader do
  @moduledoc """
  CaddyServer Downloader Program
  """

  require Logger

  @doc """
  Return if auto download is enabled.


  ## Examples

      iex> CaddyServer.Downloader.auto?()
      false

  """
  def auto?() do
    case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:auto_download) do
      {:ok, true} -> true
      _ -> false
    end
  end

  @doc """
  Download caddy from Github

  https://github.com/caddyserver/caddy/releases

  ## Examples

      iex> CaddyServer.Downloader.download()
      0

  """
  def download() do
    priv_dir("/bin") |> File.mkdir_p()
    Logger.info("Download Caddy binary from Github...")

    body =
      case Application.get_env(:caddy_server, CaddyServer) |> Keyword.fetch(:download_proxy) do
        {:ok, proxy} ->
          Logger.info("Download Caddy binary using proxy #{inspect(proxy)}")

          %HTTPoison.Response{status_code: 200, body: body} =
            download_url()
            |> HTTPoison.get!([], proxy: proxy, follow_redirect: true)

          Logger.info("Download Caddy binary from Github done")
          body

        :error ->
          %HTTPoison.Response{status_code: 200, body: body} =
            download_url() |> HTTPoison.get!([], follow_redirect: true)

          Logger.info("Download Caddy binary from Github done")
          body
      end

    f = priv_dir("/" <> filename())

    File.write!(f, body)

    {_, code} = System.cmd("tar", ["zxf", f, "-C", priv_dir(), "caddy"])
    priv_dir("/bin") |> File.mkdir_p()
    System.cmd("mv", [priv_dir("/caddy"), downloaded_bin()])

    code
  end

  def download_url() do
    "https://github.com/caddyserver/caddy/releases/download/v#{version()}/#{filename()}"
  end

  def downloaded_bin() do
    priv_dir("/bin/caddy")
  end

  defp version() do
    CaddyServer.version()
  end

  defp filename() do
    {os, arch} = os_arch()
    "caddy_#{version()}_#{os}_#{arch}.tar.gz"
  end

  defp os_arch() do
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

  defp priv_dir(p) do
    Application.app_dir(:caddy_server, "priv#{p}")
  end

  defp priv_dir() do
    Application.app_dir(:caddy_server, "priv")
  end
end
