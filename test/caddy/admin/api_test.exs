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

  # ============================================================================
  # get/1
  # ============================================================================

  describe "get/1" do
    test "returns the response body on success" do
      path = "some/path"
      expected_resp = %Request{status: 200, body: "body"}

      expect(Caddy.Admin.RequestMock, :get, 1, fn ^path ->
        {:ok, expected_resp, "body"}
      end)

      assert %{body: "body", status: 200} = Api.get(path)
    end

    test "returns zero status on connection error" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/failing/path" ->
        {:error, :econnrefused}
      end)

      assert %{status: 0, body: nil} = Api.get("/failing/path")
    end

    test "returns zero status on timeout" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/timeout/path" ->
        {:error, :timeout}
      end)

      assert %{status: 0, body: nil} = Api.get("/timeout/path")
    end
  end

  # ============================================================================
  # load/1
  # ============================================================================

  describe "load/1" do
    test "loads binary config" do
      config = "{}"
      expected_resp = %Request{status: 200, body: "body"}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", ^config, "application/json" ->
        {:ok, expected_resp, "body"}
      end)

      assert %{body: "body", status: 200} = Api.load(config)
    end

    test "loads map config by merging with current" do
      config = %{"foo" => "bar"}
      expected_resp = %Request{status: 200, body: "body"}

      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{}, %{}}
      end)

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _, "application/json" ->
        {:ok, expected_resp, "body"}
      end)

      assert %{body: "body", status: 200} = Api.load(config)
    end

    test "returns zero status on error" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _, "application/json" ->
        {:error, :econnrefused}
      end)

      assert %{status: 0, body: nil} = Api.load("{}")
    end

    test "handles invalid config response" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", _, "application/json" ->
        {:ok, %Request{status: 400, body: "invalid config"}, "invalid config"}
      end)

      result = Api.load("{invalid}")
      assert result.status == 400
    end
  end

  # ============================================================================
  # stop/0
  # ============================================================================

  describe "stop/0" do
    test "stops the server successfully" do
      expected_resp = %Request{status: 200, body: "body"}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/stop", "", "application/json" ->
        {:ok, expected_resp, "body"}
      end)

      assert %{body: "body", status: 200} = Api.stop()
    end

    test "returns zero status on error" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/stop", "", "application/json" ->
        {:error, :econnrefused}
      end)

      assert %{status: 0, body: nil} = Api.stop()
    end
  end

  # ============================================================================
  # get_config/0 and get_config/1
  # ============================================================================

  describe "get_config/0" do
    test "returns full config" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{}, %{"admin" => %{}, "apps" => %{}}}
      end)

      assert %{"admin" => %{}, "apps" => %{}} = Api.get_config()
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:error, :econnrefused}
      end)

      assert nil == Api.get_config()
    end
  end

  describe "get_config/1" do
    test "returns config at path" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/apps/http" ->
        {:ok, %Request{}, %{"servers" => %{}}}
      end)

      assert %{"servers" => %{}} = Api.get_config("apps/http")
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/nonexistent" ->
        {:error, :not_found}
      end)

      assert nil == Api.get_config("nonexistent")
    end
  end

  # ============================================================================
  # post_config/1 and post_config/2
  # ============================================================================

  describe "post_config/1" do
    test "posts config to root path" do
      data = %{"admin" => %{"listen" => ":2019"}}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/", body, "application/json" ->
        assert Jason.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      assert ^data = Api.post_config(data)
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/", _, "application/json" ->
        {:error, :econnrefused}
      end)

      assert nil == Api.post_config(%{"foo" => "bar"})
    end
  end

  describe "post_config/2" do
    test "posts config to specific path" do
      path = "apps/http/servers"
      data = %{"srv0" => %{"listen" => [":443"]}}

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/apps/http/servers", _, _ ->
        {:ok, %Request{}, data}
      end)

      assert ^data = Api.post_config(path, data)
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/some/path", _, _ ->
        {:error, :timeout}
      end)

      assert nil == Api.post_config("some/path", %{})
    end
  end

  # ============================================================================
  # put_config/1 and put_config/2
  # ============================================================================

  describe "put_config/1" do
    test "puts config to root path" do
      data = %{"admin" => %{"listen" => ":2019"}}

      expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/", body, "application/json" ->
        assert Jason.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      assert ^data = Api.put_config(data)
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/", _, "application/json" ->
        {:error, :econnrefused}
      end)

      assert nil == Api.put_config(%{"foo" => "bar"})
    end
  end

  describe "put_config/2" do
    test "puts config to specific path" do
      path = "apps/http/servers/srv0"
      data = %{"listen" => [":8080"]}

      expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/apps/http/servers/srv0", _, _ ->
        {:ok, %Request{}, data}
      end)

      assert ^data = Api.put_config(path, data)
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/some/path", _, _ ->
        {:error, :timeout}
      end)

      assert nil == Api.put_config("some/path", %{})
    end
  end

  # ============================================================================
  # patch_config/1 and patch_config/2
  # ============================================================================

  describe "patch_config/1" do
    test "patches config at root path" do
      data = %{"admin" => %{"listen" => ":2020"}}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/", body, "application/json" ->
        assert Jason.decode!(body) == data
        {:ok, %Request{status: 200}, data}
      end)

      assert ^data = Api.patch_config(data)
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/", _, "application/json" ->
        {:error, :econnrefused}
      end)

      assert nil == Api.patch_config(%{"foo" => "bar"})
    end
  end

  describe "patch_config/2" do
    test "patches config at specific path" do
      path = "apps/http/servers/srv0"
      data = %{"listen" => [":9000"]}

      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/apps/http/servers/srv0", _, _ ->
        {:ok, %Request{}, data}
      end)

      assert ^data = Api.patch_config(path, data)
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/some/path", _, _ ->
        {:error, :timeout}
      end)

      assert nil == Api.patch_config("some/path", %{})
    end
  end

  # ============================================================================
  # delete_config/0 and delete_config/1
  # ============================================================================

  describe "delete_config/0" do
    test "deletes entire config" do
      expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/", "", "application/json" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert %{} = Api.delete_config()
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/", "", "application/json" ->
        {:error, :econnrefused}
      end)

      assert nil == Api.delete_config()
    end
  end

  describe "delete_config/1" do
    test "deletes config at specific path" do
      expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/apps/http",
                                                     "",
                                                     "application/json" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert %{} = Api.delete_config("apps/http")
    end

    test "returns nil on error" do
      expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/some/path",
                                                     "",
                                                     "application/json" ->
        {:error, :not_found}
      end)

      assert nil == Api.delete_config("some/path")
    end
  end

  # ============================================================================
  # adapt/1
  # ============================================================================

  describe "adapt/1" do
    test "adapts caddyfile to JSON config" do
      caddyfile = "localhost:8080 { respond \"Hello\" }"

      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", ^caddyfile, "application/json" ->
        {:ok, %Request{status: 200}, %{"apps" => %{"http" => %{}}}}
      end)

      assert %{"apps" => %{"http" => %{}}} = Api.adapt(caddyfile)
    end

    test "returns empty map on error" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _, "application/json" ->
        {:error, :econnrefused}
      end)

      assert %{} = Api.adapt("invalid")
    end

    test "handles syntax errors in caddyfile" do
      expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", _, "application/json" ->
        {:ok, %Request{status: 400}, %{"error" => "syntax error"}}
      end)

      assert %{"error" => "syntax error"} = Api.adapt("{ invalid syntax")
    end
  end

  # ============================================================================
  # health_check/0
  # ============================================================================

  describe "health_check/0" do
    test "returns healthy status with loaded config" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, %{"apps" => %{"http" => %{}}}}
      end)

      assert {:ok, %{status: :healthy, config_loaded: true}} = Api.health_check()
    end

    test "returns healthy status with empty config" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 200}, %{}}
      end)

      assert {:ok, %{status: :healthy, config_loaded: false}} = Api.health_check()
    end

    test "returns error for non-200 status" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:ok, %Request{status: 500}, nil}
      end)

      assert {:error, "Server returned status 500"} = Api.health_check()
    end

    test "returns error for connection failure" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:error, :econnrefused}
      end)

      assert {:error, "Connection failed: :econnrefused"} = Api.health_check()
    end

    test "returns error for timeout" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
        {:error, :timeout}
      end)

      assert {:error, "Connection failed: :timeout"} = Api.health_check()
    end
  end

  # ============================================================================
  # server_info/0
  # ============================================================================

  describe "server_info/0" do
    test "returns server details" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:ok, %Request{status: 200}, %{"version" => "2.7.6"}}
      end)

      assert {:ok, %{"version" => "2.7.6"}} = Api.server_info()
    end

    test "returns error for non-200 status" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:ok, %Request{status: 503}, nil}
      end)

      assert {:error, "Server returned status 503"} = Api.server_info()
    end

    test "handles connection errors" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:error, :timeout}
      end)

      assert {:error, "Connection failed: :timeout"} = Api.server_info()
    end

    test "handles connection refused" do
      expect(Caddy.Admin.RequestMock, :get, 1, fn "/" ->
        {:error, :econnrefused}
      end)

      assert {:error, "Connection failed: :econnrefused"} = Api.server_info()
    end
  end
end
