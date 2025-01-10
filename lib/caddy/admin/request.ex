defmodule Caddy.Admin.Request do
  @moduledoc """

  Req, send request through socket

  """

  alias Caddy.Admin.Request
  alias Caddy.Config
  require Logger

  @type t :: %__MODULE__{
    status: integer(),
    headers: Keyword.t(),
    body: binary(),
  }

  defstruct status: 0, headers: [], body: ""

  @doc """
  Send HTTP GET method to admin socket
  """
  def get(path) do
    unix_path = get_admin_sock()

    {:ok, socket} =
      :gen_tcp.connect({:local, unix_path}, 0, [
        :binary,
        {:active, false},
        {:packet, :http_bin}
      ])

    req_raw_header = gen_raw_header("get", path)
    :gen_tcp.send(socket, req_raw_header)
    do_recv(socket)
  end

  @doc """
  Send HTTP POST method to admin socket
  """
  def post(path, data, content_type \\ "application/json") do
    unix_path = get_admin_sock()

    {:ok, socket} =
      :gen_tcp.connect({:local, unix_path}, 0, [
        :binary,
        {:active, false},
        {:packet, :http_bin}
      ])

    req_raw_header = gen_raw_header("post", path, content_type)

    :gen_tcp.send(socket, req_raw_header)
    :gen_tcp.send(socket, data)
    do_recv(socket)
  end

  @doc """
  Send HTTP PATCH method to admin socket
  """
  def patch(path, data, content_type \\ "application/json") do
    unix_path = get_admin_sock()

    {:ok, socket} =
      :gen_tcp.connect({:local, unix_path}, 0, [
        :binary,
        {:active, false},
        {:packet, :http_bin}
      ])

    req_raw_header = gen_raw_header("patch", path, content_type)

    :gen_tcp.send(socket, req_raw_header)
    :gen_tcp.send(socket, data)
    do_recv(socket)
  end

  @doc """
  Send HTTP PUT method to admin socket
  """
  @spec put(binary(), binary(), binary()) ::
          {:ok, atom | %{:headers => list, optional(any) => any}, String.t() | map()}
  def put(path, data, content_type \\ "application/json") do
    unix_path = get_admin_sock()

    {:ok, socket} =
      :gen_tcp.connect({:local, unix_path}, 0, [
        :binary,
        {:active, false},
        {:packet, :http_bin}
      ])

    req_raw_header = gen_raw_header("put", path, content_type)

    :gen_tcp.send(socket, req_raw_header)
    :gen_tcp.send(socket, data)
    do_recv(socket)
  end

  @doc """
  Send HTTP DELETE method to admin socket
  """
  @spec delete(binary(), binary(), binary()) ::
          {:ok, atom | %{:headers => list, optional(any) => any}, String.t() | map()}
  def delete(path, data \\ "", content_type \\ "application/json") do
    unix_path = get_admin_sock()

    {:ok, socket} =
      :gen_tcp.connect({:local, unix_path}, 0, [
        :binary,
        {:active, false},
        {:packet, :http_bin}
      ])

    req_raw_header = gen_raw_header("delete", path, content_type)

    :gen_tcp.send(socket, req_raw_header)
    :gen_tcp.send(socket, data)
    do_recv(socket)
  end

  defp get_admin_sock() do
    Config.get(:config)
    |> get_in(["admin", "listen"])
    |> String.replace(~r/^unix\//, "")
  end

  defp gen_raw_header(method, path, content_type \\ nil) do
    host = Config.get(:config) |> get_in(["admin", "origins"]) |> Enum.at(0, "caddy-admin.local")

    """
    #{String.upcase(method)} #{path} HTTP/1.1
    Host: #{host}
    #{if(content_type == nil, do: "\r\n", else: "Content-Type: #{content_type}\r\n")}
    """
  end

  defp do_recv(socket), do: do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %Request{})

  defp do_recv(socket, {:ok, {:http_response, {1, 1}, code, _}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %Request{resp | status: code})
  end

  defp do_recv(socket, {:ok, {:http_header, _, h, _, v}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %Request{
      resp
      | headers: [{h, v} | resp.headers]
    })
  end

  defp do_recv(socket, {:ok, :http_eoh}, resp) do
    # Now we only have body left.
    # # Depending on headers here you may want to do different things.
    # # The response might be chunked, or upgraded in case you have attached to the container
    # # Now I can receive the response. Because of `:active, false} I need to explicitly ask for data, otherwise it gets send to the process as messages.
    case :proplists.get_value(:"Content-Type", resp.headers) do
      "application/json" -> {:ok, resp, Jason.decode!(read_body(socket, resp))}
      _ -> {:ok, resp, read_body(socket, resp)}
    end
  end

  defp read_body(socket, resp) do
    case :proplists.get_value(:"Content-Length", resp.headers) do
      :undefined ->
        # No content length. Checked if chunked
        case :proplists.get_value(:"Transfer-Encoding", resp.headers) do
          "chunked" ->
            {:ok, resp_body} = read_chunked_body(socket, resp)
            resp_body

          # No body
          _ ->
            ""
        end

      content_length ->
        bytes_to_read = String.to_integer(content_length)
        # No longer line based http, just read data
        :inet.setopts(socket, [{:packet, :raw}])

        case :gen_tcp.recv(socket, bytes_to_read, 5000) do
          {:ok, data} ->
            data

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp read_chunked_body(socket, resp), do: read_chunked_body(socket, resp, [])

  defp read_chunked_body(socket, resp, acc) do
    Logger.debug("read_chunked_body: #{inspect(socket)} #{inspect(resp)} #{inspect(acc)}")
    :inet.setopts(socket, [{:packet, :line}])

    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, length} ->
        length = String.trim_trailing(length, "\r\n") |> String.to_integer(16)

        if length == 0 do
          {:ok, :erlang.iolist_to_binary(Enum.reverse(acc))}
        else
          :inet.setopts(socket, [{:packet, :raw}])
          {:ok, data} = :gen_tcp.recv(socket, length, 5000)
          :gen_tcp.recv(socket, 2, 5000)
          read_chunked_body(socket, resp, [data | acc])
        end

      other ->
        {:error, other}
    end
  end
end
