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

  test "get/1 returns the response body" do
    path = "some/path"
    expected_resp = %Request{status: 200, body: "body"}

    expect(Caddy.Admin.RequestMock, :get, 1, fn ^path ->
      {:ok, expected_resp, "body"}
    end)

    assert %{body: "body", status: 200} = Api.get(path)
  end

  test "load/1 with a binary" do
    config = "{}"
    expected_resp = %Request{status: 200, body: "body"}

    expect(Caddy.Admin.RequestMock, :post, 1, fn "/load", ^config, "application/json" ->
      {:ok, expected_resp, "body"}
    end)

    assert %{body: "body", status: 200} = Api.load(config)
  end

  test "load/1 with a map" do
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

  test "stop/0" do
    expected_resp = %Request{status: 200, body: "body"}

    expect(Caddy.Admin.RequestMock, :post, 1, fn "/stop", "", "application/json" ->
      {:ok, expected_resp, "body"}
    end)

    assert %{body: "body", status: 200} = Api.stop()
  end

  test "get_config/1" do
    path = "some/path"

    expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/some/path" ->
      {:ok, %Request{}, "body"}
    end)

    assert "body" == Api.get_config(path)
  end

  test "get_config/0" do
    expect(Caddy.Admin.RequestMock, :get, 1, fn "/config/" ->
      {:ok, %Request{}, "body"}
    end)

    assert "body" == Api.get_config()
  end

  test "post_config/2" do
    path = "some/path"
    data = %{"foo" => "bar"}

    expect(Caddy.Admin.RequestMock, :post, 1, fn "/config/some/path", _, _ ->
      {:ok, %Request{}, "body"}
    end)

    assert "body" == Api.post_config(path, data)
  end

  test "put_config/2" do
    path = "some/path"
    data = %{"foo" => "bar"}

    expect(Caddy.Admin.RequestMock, :put, 1, fn "/config/some/path", _, _ ->
      {:ok, %Request{}, "body"}
    end)

    assert "body" == Api.put_config(path, data)
  end

  test "patch_config/2" do
    path = "some/path"
    data = %{"foo" => "bar"}

    expect(Caddy.Admin.RequestMock, :patch, 1, fn "/config/some/path", _, _ ->
      {:ok, %Request{}, "body"}
    end)

    assert "body" == Api.patch_config(path, data)
  end

  test "delete_config/1" do
    path = "some/path"

    expect(Caddy.Admin.RequestMock, :delete, 1, fn "/config/some/path", "", "application/json" ->
      {:ok, %Request{}, "body"}
    end)

    assert "body" == Api.delete_config(path)
  end

  test "adapt/1" do
    config = "{}"

    expect(Caddy.Admin.RequestMock, :post, 1, fn "/adapt", ^config, "application/json" ->
      {:ok, %Request{}, %{"adapted" => true}}
    end)

    assert %{"adapted" => true} == Api.adapt(config)
  end
end
