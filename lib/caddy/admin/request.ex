defmodule Caddy.Admin.Request do
  @moduledoc """
  Low-level HTTP client for Caddy Admin API.

  This module provides direct HTTP communication with the Caddy admin API
  using either Unix domain sockets or TCP connections. It implements the
  RequestBehaviour and handles GET, POST, PUT, PATCH, and DELETE operations.

  ## Implementation Details

  - Uses `Caddy.Admin.Transport` for connection management
  - Supports both Unix sockets (embedded mode) and TCP (external mode)
  - Parses HTTP responses with `:http_bin` packet mode
  - Automatically decodes JSON responses
  - Returns structured response with status, headers, and body
  """
  @behaviour Caddy.Admin.RequestBehaviour

  alias Caddy.Admin.Request
  alias Caddy.Admin.Transport
  require Logger

  @type t :: %__MODULE__{
          status: integer(),
          headers: Keyword.t(),
          body: binary() | map() | list()
        }

  defstruct status: 0, headers: [], body: ""

  @doc """
  Send HTTP GET method to admin API
  """
  @impl true
  def get(path, headers \\ []) do
    with {:ok, conn_info} <- Transport.get_connection(),
         {:ok, socket} <- Transport.connect(conn_info) do
      socket_module = Transport.socket_module(conn_info)
      req_raw_header = gen_raw_header("get", path, nil, conn_info, headers)
      Transport.send(socket_module, socket, req_raw_header)
      do_recv(socket_module, socket)
    end
  end

  @doc """
  Send HTTP POST method to admin API
  """
  @impl true
  def post(path, data, content_type \\ "application/json", headers \\ []) do
    with {:ok, conn_info} <- Transport.get_connection(),
         {:ok, socket} <- Transport.connect(conn_info) do
      socket_module = Transport.socket_module(conn_info)
      req_raw_header = gen_raw_header("post", path, content_type, conn_info, headers)
      Transport.send(socket_module, socket, req_raw_header)
      Transport.send(socket_module, socket, data)
      do_recv(socket_module, socket)
    end
  end

  @doc """
  Send HTTP PATCH method to admin API
  """
  @impl true
  def patch(path, data, content_type \\ "application/json", headers \\ []) do
    with {:ok, conn_info} <- Transport.get_connection(),
         {:ok, socket} <- Transport.connect(conn_info) do
      socket_module = Transport.socket_module(conn_info)
      req_raw_header = gen_raw_header("patch", path, content_type, conn_info, headers)
      Transport.send(socket_module, socket, req_raw_header)
      Transport.send(socket_module, socket, data)
      do_recv(socket_module, socket)
    end
  end

  @doc """
  Send HTTP PUT method to admin API
  """
  @impl true
  def put(path, data, content_type \\ "application/json", headers \\ []) do
    with {:ok, conn_info} <- Transport.get_connection(),
         {:ok, socket} <- Transport.connect(conn_info) do
      socket_module = Transport.socket_module(conn_info)
      req_raw_header = gen_raw_header("put", path, content_type, conn_info, headers)
      Transport.send(socket_module, socket, req_raw_header)
      Transport.send(socket_module, socket, data)
      do_recv(socket_module, socket)
    end
  end

  @doc """
  Send HTTP DELETE method to admin API
  """
  @impl true
  def delete(path, data \\ "", content_type \\ "application/json", headers \\ []) do
    with {:ok, conn_info} <- Transport.get_connection(),
         {:ok, socket} <- Transport.connect(conn_info) do
      socket_module = Transport.socket_module(conn_info)
      req_raw_header = gen_raw_header("delete", path, content_type, conn_info, headers)
      Transport.send(socket_module, socket, req_raw_header)
      Transport.send(socket_module, socket, data)
      do_recv(socket_module, socket)
    end
  end

  defp gen_raw_header(method, path, content_type, conn_info, headers) do
    host = Transport.host_header(conn_info)
    content_type_line = if content_type, do: "Content-Type: #{content_type}\r\n", else: ""
    header_lines = Enum.map_join(headers, "", fn {key, value} -> "#{key}: #{value}\r\n" end)

    "#{String.upcase(method)} #{path} HTTP/1.1\r\nHost: #{host}\r\n#{content_type_line}#{header_lines}\r\n"
  end

  defp do_recv(socket_module, socket) do
    do_recv(socket_module, socket, Transport.recv(socket_module, socket, 0, 5000), %Request{})
  end

  defp do_recv(_socket_module, _socket, {:error, reason}, _resp) do
    {:error, reason}
  end

  defp do_recv(
         socket_module,
         socket,
         {:ok, {:http_response, {_major, _minor}, code, _}},
         %Request{} = resp
       ) do
    do_recv(socket_module, socket, Transport.recv(socket_module, socket, 0, 5000), %Request{
      resp
      | status: code
    })
  end

  defp do_recv(socket_module, socket, {:ok, {:http_header, _, h, _, v}}, %Request{} = resp) do
    do_recv(socket_module, socket, Transport.recv(socket_module, socket, 0, 5000), %Request{
      resp
      | headers: [{h, v} | resp.headers]
    })
  end

  defp do_recv(socket_module, socket, {:ok, :http_eoh}, %Request{} = resp) do
    case read_body(socket_module, socket, resp) do
      {:error, reason} ->
        {:error, reason}

      body ->
        decode_body(resp, body)
    end
  end

  defp do_recv(_socket_module, _socket, {:ok, {:http_error, reason}}, _resp) do
    {:error, {:http_error, reason}}
  end

  defp do_recv(_socket_module, _socket, unexpected, _resp) do
    {:error, {:unexpected_response, unexpected}}
  end

  defp read_body(socket_module, socket, resp) do
    case :proplists.get_value(:"Content-Length", resp.headers) do
      :undefined ->
        # No content length. Checked if chunked
        case :proplists.get_value(:"Transfer-Encoding", resp.headers) do
          "chunked" ->
            read_chunked_body(socket_module, socket, resp)

          # No body
          _ ->
            ""
        end

      content_length ->
        bytes_to_read = String.to_integer(content_length)
        # No longer line based http, just read data
        Transport.setopts(socket_module, socket, [{:packet, :raw}])

        case Transport.recv(socket_module, socket, bytes_to_read, 5000) do
          {:ok, data} ->
            data

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp read_chunked_body(socket_module, socket, resp) do
    with {:ok, body} <- read_chunked_body(socket_module, socket, resp, []) do
      body
    end
  end

  defp read_chunked_body(socket_module, socket, resp, acc) do
    Logger.debug("read_chunked_body: #{inspect(socket)} #{inspect(resp)} #{inspect(acc)}")
    Transport.setopts(socket_module, socket, [{:packet, :line}])

    case Transport.recv(socket_module, socket, 0, 5000) do
      {:ok, length} ->
        length = String.trim_trailing(length, "\r\n") |> String.to_integer(16)

        if length == 0 do
          {:ok, :erlang.iolist_to_binary(Enum.reverse(acc))}
        else
          Transport.setopts(socket_module, socket, [{:packet, :raw}])

          with {:ok, data} <- Transport.recv(socket_module, socket, length, 5000),
               {:ok, _crlf} <- Transport.recv(socket_module, socket, 2, 5000) do
            read_chunked_body(socket_module, socket, resp, [data | acc])
          end
        end

      other ->
        {:error, other}
    end
  rescue
    ArgumentError -> {:error, :invalid_chunk_size}
  end

  defp decode_body(resp, body) do
    case :proplists.get_value(:"Content-Type", resp.headers) do
      "application/json" ->
        case JSON.decode(body) do
          {:ok, decoded} -> {:ok, resp, decoded}
          {:error, reason} -> {:error, {:decode_error, reason}}
        end

      _ ->
        {:ok, resp, body}
    end
  end
end
