defmodule Caddy.Admin.ApiTest do
  use ExUnit.Case, async: true

  import Mox

  alias Caddy.Admin.Api
  alias Caddy.Admin.Request

  setup :verify_on_exit!

  setup do
    Application.put_env(:caddy, :request_module, Caddy.Admin.RequestMock)
    :ok
  end

  describe "request contract" do
    test "get/1 returns tagged response on success" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/some/path" ->
        {:ok, %Request{status: 200}, "body"}
      end)

      assert {:ok, %Request{body: "body", status: 200}} = Api.get("/some/path")
    end

    test "get/1 returns tagged transport errors" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/failing/path" ->
        {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = Api.get("/failing/path")
    end

    test "get/1 returns tagged HTTP errors" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/missing" ->
        {:ok, %Request{status: 404}, %{"error" => "not found"}}
      end)

      assert {:error, {:http_error, 404, %{"error" => "not found"}}} = Api.get("/missing")
    end
  end

  describe "load/1" do
    test "loads binary config" do
      config = "{}"

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", ^config, "application/json" ->
        {:ok, %Request{status: 200}, "body"}
      end)

      assert {:ok, %Request{body: "body", status: 200}} = Api.load(config)
    end

    test "loads map config directly without fetching or merging runtime config" do
      config = %{"foo" => "bar"}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", body, "application/json" ->
        assert JSON.decode!(body) == config
        {:ok, %Request{status: 200}, "body"}
      end)

      assert {:ok, %Request{status: 200, body: "body"}} = Api.load(config)
    end

    test "returns HTTP error tuple for invalid config" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _, "application/json" ->
        {:ok, %Request{status: 400}, "invalid config"}
      end)

      assert {:error, {:http_error, 400, "invalid config"}} = Api.load("{invalid}")
    end
  end

  describe "config endpoints" do
    test "get_config/0 returns full config" do
      config = %{"admin" => %{}, "apps" => %{}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Api.get_config()
    end

    test "get_config/1 returns config at path" do
      config = %{"servers" => %{}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http" ->
        {:ok, %Request{status: 200}, config}
      end)

      assert {:ok, ^config} = Api.get_config("apps/http")
    end

    test "get_config_with_etag/1 returns body and ETag" do
      config = %{"servers" => %{}}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http" ->
        {:ok, %Request{status: 200, headers: [{:ETag, "abc"}]}, config}
      end)

      assert {:ok, %{config: ^config, etag: "abc"}} = Api.get_config_with_etag("apps/http")
    end

    test "post, put, patch and delete config return body on success" do
      data = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/apps/http/servers",
                                                   body,
                                                   "application/json" ->
        assert JSON.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/apps/http/servers/srv0",
                                                  body,
                                                  "application/json" ->
        assert JSON.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http/servers/srv0",
                                                    body,
                                                    "application/json" ->
        assert JSON.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/apps/http/servers/srv0",
                                                     "",
                                                     "application/json" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert {:ok, ^data} = Api.post_config("apps/http/servers", data)
      assert {:ok, ^data} = Api.put_config("apps/http/servers/srv0", data)
      assert {:ok, ^data} = Api.patch_config("apps/http/servers/srv0", data)
      assert {:ok, %{}} = Api.delete_config("apps/http/servers/srv0")
    end

    test "If-Match option is sent on mutation requests" do
      data = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http/servers/srv0",
                                                    body,
                                                    "application/json",
                                                    [{"If-Match", "abc"}] ->
        assert JSON.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      assert {:ok, ^data} = Api.patch_config("apps/http/servers/srv0", data, if_match: "abc")
    end
  end

  describe "adapt/1" do
    test "adapts caddyfile to JSON config" do
      caddyfile = "localhost:8080 { respond \"Hello\" }"
      json = %{"apps" => %{"http" => %{}}}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", ^caddyfile, "application/json" ->
        {:ok, %Request{status: 200}, json}
      end)

      assert {:ok, ^json} = Api.adapt(caddyfile)
    end

    test "returns tagged transport error" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _, "application/json" ->
        {:error, :closed}
      end)

      assert {:error, :closed} = Api.adapt("some caddyfile content")
    end
  end

  describe "operational endpoints" do
    test "health_check/0 uses root endpoint" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:ok, %Request{status: 200}, ""}
      end)

      assert {:ok, %{status: :healthy}} = Api.health_check()
    end

    test "health_check/0 classifies connection errors" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:error, :timeout}
      end)

      assert {:error, {:connection_failed, :timeout}} = Api.health_check()
    end

    test "server_info/0 returns root body" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:ok, %Request{status: 200}, %{"version" => "2.7.6"}}
      end)

      assert {:ok, %{"version" => "2.7.6"}} = Api.server_info()
    end

    test "documented endpoints return response bodies" do
      upstreams = [%{"address" => "localhost:3000", "healthy" => true}]
      ca_info = %{"id" => "local"}
      certs = [%{"not_after" => "2099-01-01T00:00:00Z"}]

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/reverse_proxy/upstreams" ->
        {:ok, %Request{status: 200}, upstreams}
      end)

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/pki/ca/local" ->
        {:ok, %Request{status: 200}, ca_info}
      end)

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/pki/ca/local/certificates" ->
        {:ok, %Request{status: 200}, certs}
      end)

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/id/route-1" ->
        {:ok, %Request{status: 200}, %{"@id" => "route-1"}}
      end)

      assert {:ok, ^upstreams} = Api.get_upstreams()
      assert {:ok, ^ca_info} = Api.get_pki_ca("local")
      assert {:ok, ^certs} = Api.get_pki_certificates("local")
      assert {:ok, %{"@id" => "route-1"}} = Api.get_by_id("route-1")
    end
  end
end
