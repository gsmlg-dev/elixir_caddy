defmodule Caddy.Admin.TransportTest do
  use ExUnit.Case, async: true

  alias Caddy.Admin.Transport

  describe "parse_url/1" do
    test "parses unix:///path/to/sock" do
      assert {:ok, %{type: :unix, path: "/var/run/caddy.sock"}} =
               Transport.parse_url("unix:///var/run/caddy.sock")
    end

    test "parses unix socket with custom path" do
      assert {:ok, %{type: :unix, path: "/tmp/caddy.sock"}} =
               Transport.parse_url("unix:///tmp/caddy.sock")
    end

    test "parses http://localhost:2019" do
      assert {:ok, %{type: :tcp, host: ~c"localhost", port: 2019}} =
               Transport.parse_url("http://localhost:2019")
    end

    test "parses http://localhost with default port" do
      assert {:ok, %{type: :tcp, host: ~c"localhost", port: 2019}} =
               Transport.parse_url("http://localhost")
    end

    test "parses http://192.168.1.1:2019" do
      assert {:ok, %{type: :tcp, host: ~c"192.168.1.1", port: 2019}} =
               Transport.parse_url("http://192.168.1.1:2019")
    end

    test "parses http with custom port" do
      assert {:ok, %{type: :tcp, host: ~c"example.com", port: 8080}} =
               Transport.parse_url("http://example.com:8080")
    end

    test "ignores path in http URL" do
      assert {:ok, %{type: :tcp, host: ~c"localhost", port: 2019}} =
               Transport.parse_url("http://localhost:2019/config/")
    end

    test "returns error for invalid URL" do
      assert {:error, :invalid_url} = Transport.parse_url("invalid")
      assert {:error, :invalid_url} = Transport.parse_url("")
      assert {:error, :invalid_url} = Transport.parse_url("ftp://localhost")
    end

    test "returns error for empty unix path" do
      assert {:error, :invalid_url} = Transport.parse_url("unix://")
    end

    test "returns error for empty http host" do
      assert {:error, :invalid_url} = Transport.parse_url("http://")
    end

    test "returns error for https (not supported)" do
      assert {:error, :https_not_supported} = Transport.parse_url("https://localhost:2019")
    end

    test "returns error for invalid port" do
      assert {:error, :invalid_port} = Transport.parse_url("http://localhost:invalid")
      assert {:error, :invalid_port} = Transport.parse_url("http://localhost:0")
      assert {:error, :invalid_port} = Transport.parse_url("http://localhost:99999")
    end
  end

  describe "host_header/1" do
    test "returns configured host for unix socket" do
      conn_info = %{type: :unix, path: "/var/run/caddy.sock"}
      assert is_binary(Transport.host_header(conn_info))
    end

    test "returns host:port for tcp connection" do
      conn_info = %{type: :tcp, host: ~c"localhost", port: 2019}
      assert Transport.host_header(conn_info) == "localhost:2019"
    end
  end

  describe "get_connection/0" do
    test "returns unix socket connection by default" do
      # Default admin_url falls back to unix socket
      {:ok, conn_info} = Transport.get_connection()
      assert conn_info.type == :unix
    end
  end

  describe "connect/2" do
    test "returns error for non-existent unix socket" do
      conn_info = %{type: :unix, path: "/nonexistent/socket.sock"}
      assert {:error, _reason} = Transport.connect(conn_info, timeout: 100)
    end

    test "returns error for unreachable tcp host" do
      conn_info = %{type: :tcp, host: ~c"127.0.0.1", port: 59_999}
      assert {:error, _reason} = Transport.connect(conn_info, timeout: 100)
    end
  end
end
