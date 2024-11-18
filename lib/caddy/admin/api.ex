defmodule Caddy.Admin.Api do
  @moduledoc """

  Control Caddy Server through admin socket

  ### Admin API

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
  require Logger

  alias Caddy.Admin.Request

  @doc """
  Get info from caddy server
  """
  def get(path) do
    {:ok, resp, body} = Request.get("#{path}")
    resp |> Map.put(:body, body)
  end

  @doc """
  Sets or replaces the active configuration
  """
  @spec load(Map.t() | String.t()) :: Caddy.Admin.Request.t()
  def load(conf) when is_map(conf) do
    get_config()
    |> Map.merge(conf)
    |> Jason.encode!()
    |> load()
  end

  def load(conf) when is_binary(conf) do
    {:ok, resp, body} = Request.post("/load", conf)
    resp |> Map.put(:body, body)
  end

  @doc """
  Stops the active configuration and exits the process
  """
  def stop() do
    {:ok, resp, body} = Request.post("/stop", "")
    resp |> Map.put(:body, body)
  end

  @doc """
  Exports the config at the named path
  """
  def get_config(path) when is_binary(path) do
    {:ok, _resp, body} = Request.get("/config/#{path}")
    body
  end
  def get_config() do
    {:ok, _resp, body} = Request.get("/config/")
    body
  end

  @doc """
  Post the config at the named path
  """
  def post_config(path, data) when is_binary(path) do
    data_string = Jason.encode!(data)
    {:ok, resp, body} = Request.post("/config/#{path}", data_string)
    Logger.debug(inspect(resp))
    body
  end
  def post_config(data) do
    data_string = Jason.encode!(data)
    {:ok, resp, body} = Request.post("/config/", data_string)
    Logger.debug(inspect(resp))
    body
  end

  @doc """
  Put the config at the named path
  """
  def put_config(path, data) when is_binary(path) do
    data_string = Jason.encode!(data)
    {:ok, resp, body} = Request.put("/config/#{path}", data_string)
    Logger.debug(inspect(resp))
    body
  end
  def put_config(data) do
    data_string = Jason.encode!(data)
    {:ok, resp, body} = Request.put("/config/", data_string)
    Logger.debug(inspect(resp))
    body
  end

  @doc """
  Patch the config at the named path
  """
  def patch_config(path, data) when is_binary(path) do
    data_string = Jason.encode!(data)
    {:ok, resp, body} = Request.patch("/config/#{path}", data_string)
    Logger.debug(inspect(resp))
    body
  end
  def patch_config(data) do
    data_string = Jason.encode!(data)
    {:ok, resp, body} = Request.patch("/config/", data_string)
    Logger.debug(inspect(resp))
    body
  end

  @doc """
  Delete the config at the named path
  """
  def delete_config(path) when is_binary(path) do
    {:ok, resp, body} = Request.delete("/config/#{path}")
    Logger.debug(inspect(resp))
    body
  end
  def delete_config() do
    {:ok, resp, body} = Request.delete("/config/")
    Logger.debug(inspect(resp))
    body
  end

  @doc """
  Adapts a configuration to JSON without running it
  """
  @spec adapt(binary) :: Map.t()
  def adapt(conf) do
    {:ok, resp, json_conf} = Request.post("/adapt", conf)
    Logger.debug(inspect(resp))
    json_conf
  end
end
