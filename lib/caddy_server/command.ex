defmodule CaddyServer.Command do
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

  alias CaddyServer.Req

  def get(path) do
    {:ok, resp, body} = Req.get("#{path}")
    resp |> Map.put(:body, body)
  end

  @spec load(any) :: CaddyServer.Req.t()
  def load(conf) when is_map(conf) do
    conf
    |> Map.put("admin", CaddyServer.Command.get_config("admin"))
    |> Jason.encode!()
    |> load()
  end

  def load(conf) when is_binary(conf) do
    {:ok, resp, body} = Req.post("/load", conf)
    resp |> Map.put(:body, body)
  end

  def stop() do
    {:ok, resp, body} = Req.post("/stop", "")
    resp |> Map.put(:body, body)
  end

  def get_config(path) do
    {:ok, resp, body} = Req.get("/config/#{path}")
    resp |> Map.put(:body, body)
    resp.body
  end

  def get_config() do
    {:ok, resp, body} = Req.get("/config/")
    resp |> Map.put(:body, body)
    resp.body
  end

  def adapt(conf) do
    {:ok, _resp, json_conf} = Req.post("/adapt", conf)
    json_conf
  end
end
