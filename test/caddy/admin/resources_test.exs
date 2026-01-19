defmodule Caddy.Admin.ResourcesTest do
  use ExUnit.Case, async: true
  import Mox

  alias Caddy.Admin.Resources
  alias Caddy.Admin.Request

  setup :verify_on_exit!

  setup do
    Application.put_env(:caddy, :request_module, Caddy.Admin.RequestMock)
    :ok
  end

  # ============================================================================
  # Apps
  # ============================================================================

  describe "get_apps/0" do
    test "returns apps when available" do
      apps = %{"http" => %{}, "tls" => %{}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps" ->
        {:ok, %Request{status: 200}, apps}
      end)

      assert {:ok, ^apps} = Resources.get_apps()
    end

    test "returns error when not found" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Resources.get_apps()
    end
  end

  describe "get_app/1" do
    test "returns specific app" do
      http_app = %{"servers" => %{}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http" ->
        {:ok, %Request{status: 200}, http_app}
      end)

      assert {:ok, ^http_app} = Resources.get_app("http")
    end

    test "returns error for non-existent app" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/nonexistent" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Resources.get_app("nonexistent")
    end
  end

  describe "set_app/2" do
    test "updates app configuration" do
      config = %{"servers" => %{"srv0" => %{}}}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http", _, _ ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Resources.set_app("http", config)
    end
  end

  describe "delete_app/1" do
    test "deletes app" do
      expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/apps/http",
                                                     "",
                                                     "application/json" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert :ok = Resources.delete_app("http")
    end
  end

  # ============================================================================
  # HTTP Servers
  # ============================================================================

  describe "get_http_servers/0" do
    test "returns all HTTP servers" do
      servers = %{"srv0" => %{"listen" => [":443"]}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http/servers" ->
        {:ok, %Request{status: 200}, servers}
      end)

      assert {:ok, ^servers} = Resources.get_http_servers()
    end
  end

  describe "get_http_server/1" do
    test "returns specific server" do
      server = %{"listen" => [":443"], "routes" => []}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http/servers/srv0" ->
        {:ok, %Request{status: 200}, server}
      end)

      assert {:ok, ^server} = Resources.get_http_server("srv0")
    end
  end

  describe "set_http_server/2" do
    test "updates server configuration" do
      config = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http/servers/srv0", _, _ ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Resources.set_http_server("srv0", config)
    end
  end

  describe "create_http_server/2" do
    test "creates new server" do
      config = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/apps/http/servers/newsrv", _, _ ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Resources.create_http_server("newsrv", config)
    end
  end

  describe "delete_http_server/1" do
    test "deletes server" do
      expect(
        Caddy.Admin.RequestMock,
        :delete,
        1,
        fn "/config/apps/http/servers/srv0", "", "application/json" ->
          {:ok, %Request{status: 200}, %{}}
        end
      )

      assert :ok = Resources.delete_http_server("srv0")
    end
  end

  # ============================================================================
  # Routes
  # ============================================================================

  describe "get_routes/1" do
    test "returns routes for server" do
      routes = [%{"match" => [%{"path" => ["/*"]}]}]

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http/servers/srv0/routes" ->
        {:ok, %Request{status: 200}, routes}
      end)

      assert {:ok, ^routes} = Resources.get_routes("srv0")
    end
  end

  describe "get_route/2" do
    test "returns specific route" do
      route = %{"match" => [%{"path" => ["/api/*"]}]}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http/servers/srv0/routes/0" ->
        {:ok, %Request{status: 200}, route}
      end)

      assert {:ok, ^route} = Resources.get_route("srv0", 0)
    end
  end

  describe "add_route/2" do
    test "appends route to server" do
      route = %{"match" => [%{"path" => ["/new/*"]}]}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/apps/http/servers/srv0/routes",
                                                   _,
                                                   _ ->
        {:ok, %Request{status: 200}, route}
      end)

      assert {:ok, ^route} = Resources.add_route("srv0", route)
    end
  end

  describe "update_route/3" do
    test "updates route at index" do
      route = %{"match" => [%{"path" => ["/updated/*"]}]}

      expect(
        Caddy.Admin.RequestMock,
        :patch,
        1,
        fn "/config/apps/http/servers/srv0/routes/0", _, _ ->
          {:ok, %Request{status: 200}, route}
        end
      )

      assert {:ok, ^route} = Resources.update_route("srv0", 0, route)
    end
  end

  describe "insert_route/3" do
    test "inserts route at index" do
      route = %{"match" => [%{"path" => ["/inserted/*"]}]}

      expect(
        Caddy.Admin.RequestMock,
        :put,
        1,
        fn "/config/apps/http/servers/srv0/routes/1", _, _ ->
          {:ok, %Request{status: 200}, route}
        end
      )

      assert {:ok, ^route} = Resources.insert_route("srv0", 1, route)
    end
  end

  describe "delete_route/2" do
    test "deletes route at index" do
      expect(
        Caddy.Admin.RequestMock,
        :delete,
        1,
        fn "/config/apps/http/servers/srv0/routes/0", "", "application/json" ->
          {:ok, %Request{status: 200}, %{}}
        end
      )

      assert :ok = Resources.delete_route("srv0", 0)
    end
  end

  # ============================================================================
  # TLS
  # ============================================================================

  describe "get_tls/0" do
    test "returns TLS configuration" do
      tls = %{"automation" => %{"policies" => []}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/tls" ->
        {:ok, %Request{status: 200}, tls}
      end)

      assert {:ok, ^tls} = Resources.get_tls()
    end
  end

  describe "set_tls/1" do
    test "updates TLS configuration" do
      config = %{"automation" => %{"policies" => []}}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/tls", _, _ ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Resources.set_tls(config)
    end
  end

  describe "get_tls_automation/0" do
    test "returns TLS automation config" do
      automation = %{"policies" => []}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/tls/automation" ->
        {:ok, %Request{status: 200}, automation}
      end)

      assert {:ok, ^automation} = Resources.get_tls_automation()
    end
  end

  # ============================================================================
  # Admin
  # ============================================================================

  describe "get_admin/0" do
    test "returns admin configuration" do
      admin = %{"listen" => "unix//tmp/caddy.sock"}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/admin" ->
        {:ok, %Request{status: 200}, admin}
      end)

      assert {:ok, ^admin} = Resources.get_admin()
    end
  end

  describe "set_admin/1" do
    test "updates admin configuration" do
      config = %{"listen" => ":2019"}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/admin", _, _ ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Resources.set_admin(config)
    end
  end

  # ============================================================================
  # Reverse Proxy Upstreams
  # ============================================================================

  describe "get_upstreams/0" do
    test "returns upstream status" do
      upstreams = [%{"address" => "localhost:3000", "healthy" => true}]

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/reverse_proxy/upstreams" ->
        {:ok, %Request{status: 200}, upstreams}
      end)

      assert {:ok, ^upstreams} = Resources.get_upstreams()
    end

    test "returns error on connection failure" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/reverse_proxy/upstreams" ->
        {:error, :econnrefused}
      end)

      assert {:error, :connection_failed} = Resources.get_upstreams()
    end
  end

  # ============================================================================
  # PKI
  # ============================================================================

  describe "get_pki_ca/1" do
    test "returns CA info" do
      ca_info = %{"name" => "local", "root_certificate" => "..."}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/pki/ca/local" ->
        {:ok, %Request{status: 200}, ca_info}
      end)

      assert {:ok, ^ca_info} = Resources.get_pki_ca("local")
    end
  end

  describe "get_pki_certificates/1" do
    test "returns certificate chain" do
      certs = ["cert1", "cert2"]

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/pki/ca/local/certificates" ->
        {:ok, %Request{status: 200}, certs}
      end)

      assert {:ok, ^certs} = Resources.get_pki_certificates("local")
    end
  end
end
