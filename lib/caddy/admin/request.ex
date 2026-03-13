defmodule Caddy.Admin.Request do
  @moduledoc """
  Low-level HTTP client for Caddy Admin API.

  This module provides HTTP communication with the Caddy admin API
  using the `http_fetch` library. It implements the RequestBehaviour
  and handles GET, POST, PUT, PATCH, and DELETE operations.

  ## Implementation Details

  - Uses `HTTP.fetch/2` for all HTTP operations
  - Supports both Unix sockets (embedded mode) and TCP (external mode)
  - Automatically decodes JSON responses
  - Returns structured response with status, headers, and body
  """
  @behaviour Caddy.Admin.RequestBehaviour

  alias Caddy.Admin.Request

  @type t :: %__MODULE__{
          status: integer(),
          headers: Keyword.t(),
          body: binary()
        }

  defstruct status: 0, headers: [], body: ""

  @doc """
  Send HTTP GET method to admin API
  """
  @impl true
  def get(path) do
    do_fetch("GET", path, nil, nil)
  end

  @doc """
  Send HTTP POST method to admin API
  """
  @impl true
  def post(path, data, content_type \\ "application/json") do
    do_fetch("POST", path, data, content_type)
  end

  @doc """
  Send HTTP PATCH method to admin API
  """
  @impl true
  def patch(path, data, content_type \\ "application/json") do
    do_fetch("PATCH", path, data, content_type)
  end

  @doc """
  Send HTTP PUT method to admin API
  """
  @impl true
  @spec put(binary(), binary(), binary()) ::
          {:ok, atom | %{:headers => list, optional(any) => any}, String.t() | map()}
  def put(path, data, content_type \\ "application/json") do
    do_fetch("PUT", path, data, content_type)
  end

  @doc """
  Send HTTP DELETE method to admin API
  """
  @impl true
  @spec delete(binary(), binary(), binary()) ::
          {:ok, atom | %{:headers => list, optional(any) => any}, String.t() | map()}
  def delete(path, data \\ "", content_type \\ "application/json") do
    do_fetch("DELETE", path, data, content_type)
  end

  defp do_fetch(method, path, body, content_type) do
    {url, fetch_opts} = build_fetch_args(Caddy.Config.admin_url(), path)

    fetch_opts = Keyword.put(fetch_opts, :method, method)

    fetch_opts =
      if body && body != "",
        do: Keyword.put(fetch_opts, :body, body),
        else: fetch_opts

    fetch_opts =
      if content_type,
        do: Keyword.put(fetch_opts, :content_type, content_type),
        else: fetch_opts

    try do
      HTTP.fetch(url, fetch_opts)
      |> HTTP.Promise.await()
      |> parse_response()
    rescue
      e -> {:error, {:request_exception, e}}
    catch
      :exit, reason -> {:error, {:request_exit, reason}}
    end
  end

  defp build_fetch_args("unix://" <> socket_path, path) do
    {"http://localhost#{path}", [unix_socket: socket_path]}
  end

  defp build_fetch_args(admin_url, path) do
    {admin_url <> path, []}
  end

  defp parse_response(%HTTP.Response{} = resp) do
    request = %Request{
      status: resp.status,
      headers: HTTP.Headers.to_list(resp.headers),
      body: resp.body
    }

    {media_type, _params} = HTTP.Response.content_type(resp)
    body = resp.body || HTTP.Response.read_all(resp)

    if String.contains?(media_type, "application/json") do
      case JSON.decode(body) do
        {:ok, decoded} -> {:ok, request, decoded}
        {:error, reason} -> {:error, {:decode_error, reason}}
      end
    else
      {:ok, request, body}
    end
  end

  defp parse_response({:ok, %HTTP.Response{} = resp}) do
    parse_response(resp)
  end

  defp parse_response({:error, reason}) do
    {:error, reason}
  end
end
