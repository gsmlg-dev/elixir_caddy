defmodule Caddy.Admin.Transport do
  @moduledoc """
  Transport abstraction for connecting to Caddy Admin API.

  Supports both Unix domain sockets and TCP connections, allowing
  communication with Caddy instances running in embedded or external mode.

  ## URL Formats

  - `unix:///path/to/socket` - Unix domain socket
  - `http://host:port` - TCP connection (default port: 2019)

  ## Examples

      # Parse and connect to Unix socket
      {:ok, conn_info} = Transport.parse_url("unix:///var/run/caddy.sock")
      {:ok, socket} = Transport.connect(conn_info)

      # Parse and connect to TCP
      {:ok, conn_info} = Transport.parse_url("http://localhost:2019")
      {:ok, socket} = Transport.connect(conn_info)
  """

  @type unix_conn :: %{type: :unix, path: binary()}
  @type tcp_conn :: %{type: :tcp, host: charlist(), port: non_neg_integer()}
  @type conn_info :: unix_conn() | tcp_conn()

  @default_caddy_port 2019
  @connect_timeout 5_000

  @doc """
  Parse an admin URL into connection information.

  ## Examples

      iex> Transport.parse_url("unix:///tmp/caddy.sock")
      {:ok, %{type: :unix, path: "/tmp/caddy.sock"}}

      iex> Transport.parse_url("http://localhost:2019")
      {:ok, %{type: :tcp, host: ~c"localhost", port: 2019}}

      iex> Transport.parse_url("http://192.168.1.1")
      {:ok, %{type: :tcp, host: ~c"192.168.1.1", port: 2019}}

      iex> Transport.parse_url("invalid")
      {:error, :invalid_url}
  """
  @spec parse_url(binary()) :: {:ok, conn_info()} | {:error, term()}
  def parse_url("unix://" <> path) when byte_size(path) > 0 do
    {:ok, %{type: :unix, path: path}}
  end

  def parse_url("http://" <> rest) when byte_size(rest) > 0 do
    parse_tcp(rest)
  end

  def parse_url("https://" <> _rest) do
    {:error, :https_not_supported}
  end

  def parse_url(_) do
    {:error, :invalid_url}
  end

  @doc """
  Get connection info based on current configuration.

  In embedded mode, uses the configured socket file.
  In external mode, uses the configured admin_url.
  """
  @spec get_connection() :: {:ok, conn_info()} | {:error, term()}
  def get_connection do
    parse_url(Caddy.Config.admin_url())
  end

  @doc """
  Connect to Caddy admin API using the provided connection info.

  Returns a socket that can be used with `:gen_tcp` functions.

  ## Options

  - `:timeout` - Connection timeout in milliseconds (default: 5000)
  - `:packet` - Packet mode (default: `:http_bin` for HTTP parsing)
  """
  @spec connect(conn_info(), keyword()) :: {:ok, :gen_tcp.socket()} | {:error, term()}
  def connect(conn_info, opts \\ [])

  def connect(%{type: :unix, path: path}, opts) do
    timeout = Keyword.get(opts, :timeout, @connect_timeout)
    packet = Keyword.get(opts, :packet, :http_bin)

    :gen_tcp.connect(
      {:local, path},
      0,
      [
        :binary,
        {:active, false},
        {:packet, packet}
      ],
      timeout
    )
  end

  def connect(%{type: :tcp, host: host, port: port}, opts) do
    timeout = Keyword.get(opts, :timeout, @connect_timeout)
    packet = Keyword.get(opts, :packet, :http_bin)

    :gen_tcp.connect(
      host,
      port,
      [
        :binary,
        {:active, false},
        {:packet, packet}
      ],
      timeout
    )
  end

  @doc """
  Connect using the current configuration.

  Convenience function that combines `get_connection/0` and `connect/2`.
  """
  @spec connect_from_config(keyword()) :: {:ok, :gen_tcp.socket()} | {:error, term()}
  def connect_from_config(opts \\ []) do
    with {:ok, conn_info} <- get_connection() do
      connect(conn_info, opts)
    end
  end

  @doc """
  Get the host header value for HTTP requests.

  For Unix sockets, returns a configured or default host.
  For TCP connections, returns the actual host:port.
  """
  @spec host_header(conn_info()) :: binary()
  def host_header(%{type: :unix}) do
    Application.get_env(:caddy, :admin_host, "caddy-admin.local")
  end

  def host_header(%{type: :tcp, host: host, port: port}) do
    "#{host}:#{port}"
  end

  # Parse TCP host:port from URL remainder
  defp parse_tcp(host_port) do
    # Remove any trailing path
    host_port = host_port |> String.split("/") |> List.first()

    case String.split(host_port, ":") do
      [host] when byte_size(host) > 0 ->
        {:ok, %{type: :tcp, host: String.to_charlist(host), port: @default_caddy_port}}

      [host, port_str] when byte_size(host) > 0 ->
        case Integer.parse(port_str) do
          {port, ""} when port > 0 and port < 65_536 ->
            {:ok, %{type: :tcp, host: String.to_charlist(host), port: port}}

          _ ->
            {:error, :invalid_port}
        end

      _ ->
        {:error, :invalid_host}
    end
  end
end
