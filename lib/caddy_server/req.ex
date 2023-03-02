defmodule CaddyServer.Req do
  @moduledoc """
  Caddy Admin API

  ```
  POST /load Sets or replaces the active configuration

  POST /stop Stops the active configuration and exits the process

  GET /config/[path] Exports the config at the named path

  POST /config/[path] Sets or replaces object; appends to array

  PUT /config/[path] Creates new object; inserts into array

  PATCH /config/[path] Replaces an existing object or array element

  DELETE /config/[path] Deletes the value at the named path

  Using @id in JSON Easily traverse into the config structure

  Concurrent config changes Avoid collisions when making unsynchronized changes to config

  POST /adapt Adapts a configuration to JSON without running it

  GET /pki/ca/<id> Returns information about a particular PKI app CA

  GET /pki/ca/<id>/certificates Returns the certificate chain of a particular PKI app CA

  GET /reverse_proxy/upstreams Returns the current status of the configured proxy upstreams
  ```

  """

  alias CaddyServer.Req
  alias CaddyServer.AdminSocket
  require Logger

  defstruct status: 0, headers: [], body: ""

  # Send requests to the docker daemon.
  # request("GET", "/containers/json")
  # request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
  #
  # To post data you need to add a Content-Type and a Content-Length header to the
  # request and then send the data to the socket
  def get(path) do
    unix_path = AdminSocket.socket_path() |> String.replace(~r/^unix\//, "")

    {:ok, socket} =
      :gen_tcp.connect({:local, unix_path}, 0, [
        :binary,
        {:active, false},
        {:packet, :http_bin}
      ])

    req_raw = "GET #{path} HTTP/1.1\r\nHost: caddy-admin.local\r\n\r\n"
    :gen_tcp.send(socket, req_raw)
    do_recv(socket)
  end

  # Reads from tty. In case of non tty you need to read
  # {:packet, :raw} and decode as described under Stream Format here: https://docs.docker.com/engine/api/v1.40/#operation/ContainerAttach
  # For now just read lines from TTY or timeout after 5 seconds if nothing to be read
  # This requires an attached socket:
  # {:stream, _, socket} = request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
  # read_stream(socket)
  def read_stream(socket) do
    :inet.setopts(socket, [{:packet, :line}])
    :gen_tcp.recv(socket, 0, 5000)
  end

  # Writes to attached container
  # This requires an attached socket:
  # {:stream, _, socket} = request("POST", "/containers/abc/attach?stream=1&stdin=1&stdout=1")
  # write_stream(socket, "echo \"Hello World\"\r\n")
  # read_stream(socket)
  def write_stream(socket, data) do
    :gen_tcp.send(socket, data)
  end

  def do_recv(socket), do: do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %Req{})

  def do_recv(socket, {:ok, {:http_response, {1, 1}, code, _}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %Req{resp | status: code})
  end

  def do_recv(socket, {:ok, {:http_header, _, h, _, v}}, resp) do
    do_recv(socket, :gen_tcp.recv(socket, 0, 5000), %Req{resp | headers: [{h, v} | resp.headers]})
  end

  def do_recv(socket, {:ok, :http_eoh}, resp) do
    # Now we only have body left.
    # # Depending on headers here you may want to do different things.
    # # The response might be chunked, or upgraded in case you have attached to the container
    # # Now I can receive the response. Because of `:active, false} I need to explicitly ask for data, otherwise it gets send to the process as messages.
    case :proplists.get_value(:"Content-Type", resp.headers) do
      "application/json" -> {:ok, resp, Jason.decode!(read_body(socket, resp))}
      _ -> {:ok, resp, read_body(socket, resp)}
    end
  end

  def read_body(socket, resp) do
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

  def read_chunked_body(socket, resp), do: read_chunked_body(socket, resp, [])

  def read_chunked_body(socket, resp, acc) do
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
