defmodule Caddy.Admin.Api do
  @moduledoc false
  require Logger

  defp request_module, do: Application.get_env(:caddy, :request_module, Caddy.Admin.Request)

  @doc """
  ## Admin API

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
  def api(), do: nil

  @doc """
  Get info from caddy server
  """
  def get(path) do
    start_time = System.monotonic_time()

    case request_module().get("#{path}") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:request, %{duration: duration, status: resp.status}, %{
          method: :get,
          path: path
        })

        resp |> Map.put(:body, body)

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:error, %{duration: duration}, %{
          method: :get,
          path: path,
          error: reason
        })

        %{status: 0, body: nil}
    end
  end

  @doc """
  Sets or replaces the active configuration
  """
  @spec load(map() | binary()) :: Caddy.Admin.Request.t()
  def load(conf)

  def load(conf) when is_map(conf) do
    get_config()
    |> Map.merge(conf)
    |> Jason.encode!()
    |> load()
  end

  def load(conf) when is_binary(conf) do
    start_time = System.monotonic_time()

    case request_module().post("/load", conf, "application/json") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:load, %{duration: duration, status: resp.status}, %{
          payload_size: byte_size(conf)
        })

        resp |> Map.put(:body, body)

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:load_error, %{duration: duration}, %{
          error: reason,
          payload_size: byte_size(conf)
        })

        %{status: 0, body: nil}
    end
  end

  @doc """
  Stops the active configuration and exits the process
  """
  def stop() do
    start_time = System.monotonic_time()

    case request_module().post("/stop", "", "application/json") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:stop, %{duration: duration, status: resp.status}, %{
          method: :post
        })

        resp |> Map.put(:body, body)

      {:error, reason} ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_api_event(:stop_error, %{duration: duration}, %{error: reason})
        %{status: 0, body: nil}
    end
  end

  @doc """
  Exports the config at the named path
  """
  def get_config(path) when is_binary(path) do
    start_time = System.monotonic_time()

    case request_module().get("/config/#{path}") do
      {:ok, _resp, body} ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_api_event(:get_config, %{duration: duration}, %{path: path})
        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:get_config_error, %{duration: duration}, %{
          path: path,
          error: reason
        })

        nil
    end
  end

  def get_config() do
    start_time = System.monotonic_time()

    case request_module().get("/config/") do
      {:ok, _resp, body} ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_api_event(:get_config, %{duration: duration}, %{path: "/"})
        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:get_config_error, %{duration: duration}, %{
          path: "/",
          error: reason
        })

        nil
    end
  end

  @doc """
  Post the config at the named path
  """
  def post_config(path, data) when is_binary(path) do
    start_time = System.monotonic_time()
    data_string = Jason.encode!(data)

    case request_module().post("/config/#{path}", data_string, "application/json") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :post_config,
          %{duration: duration, status: resp.status},
          %{path: path, payload_size: byte_size(data_string)}
        )

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:post_config_error, %{duration: duration}, %{
          path: path,
          error: reason,
          payload_size: byte_size(data_string)
        })

        nil
    end
  end

  def post_config(data) do
    start_time = System.monotonic_time()
    data_string = Jason.encode!(data)

    case request_module().post("/config/", data_string) do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :post_config,
          %{duration: duration, status: resp.status},
          %{path: "/", payload_size: byte_size(data_string)}
        )

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:post_config_error, %{duration: duration}, %{
          path: "/",
          error: reason,
          payload_size: byte_size(data_string)
        })

        nil
    end
  end

  @doc """
  Put the config at the named path
  """
  def put_config(path, data) when is_binary(path) do
    start_time = System.monotonic_time()
    data_string = Jason.encode!(data)

    case request_module().put("/config/#{path}", data_string, "application/json") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:put_config, %{duration: duration, status: resp.status}, %{
          path: path,
          payload_size: byte_size(data_string)
        })

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:put_config_error, %{duration: duration}, %{
          path: path,
          error: reason,
          payload_size: byte_size(data_string)
        })

        nil
    end
  end

  def put_config(data) do
    start_time = System.monotonic_time()
    data_string = Jason.encode!(data)

    case request_module().put("/config/", data_string) do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:put_config, %{duration: duration, status: resp.status}, %{
          path: "/",
          payload_size: byte_size(data_string)
        })

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:put_config_error, %{duration: duration}, %{
          path: "/",
          error: reason,
          payload_size: byte_size(data_string)
        })

        nil
    end
  end

  @doc """
  Patch the config at the named path
  """
  def patch_config(path, data) when is_binary(path) do
    start_time = System.monotonic_time()
    data_string = Jason.encode!(data)

    case request_module().patch("/config/#{path}", data_string, "application/json") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :patch_config,
          %{duration: duration, status: resp.status},
          %{path: path, payload_size: byte_size(data_string)}
        )

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:patch_config_error, %{duration: duration}, %{
          path: path,
          error: reason,
          payload_size: byte_size(data_string)
        })

        nil
    end
  end

  def patch_config(data) do
    start_time = System.monotonic_time()
    data_string = Jason.encode!(data)

    case request_module().patch("/config/", data_string) do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :patch_config,
          %{duration: duration, status: resp.status},
          %{path: "/", payload_size: byte_size(data_string)}
        )

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:patch_config_error, %{duration: duration}, %{
          path: "/",
          error: reason,
          payload_size: byte_size(data_string)
        })

        nil
    end
  end

  @doc """
  Delete the config at the named path
  """
  def delete_config(path) when is_binary(path) do
    start_time = System.monotonic_time()

    case request_module().delete("/config/#{path}", "", "application/json") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :delete_config,
          %{duration: duration, status: resp.status},
          %{path: path}
        )

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:delete_config_error, %{duration: duration}, %{
          path: path,
          error: reason
        })

        nil
    end
  end

  def delete_config() do
    start_time = System.monotonic_time()

    case request_module().delete("/config/") do
      {:ok, resp, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :delete_config,
          %{duration: duration, status: resp.status},
          %{path: "/"}
        )

        body

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:delete_config_error, %{duration: duration}, %{
          path: "/",
          error: reason
        })

        nil
    end
  end

  @doc """
  Adapts a configuration to JSON without running it
  """
  @spec adapt(binary) :: map()
  def adapt(conf) do
    start_time = System.monotonic_time()

    case request_module().post("/adapt", conf, "application/json") do
      {:ok, resp, json_conf} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:adapt, %{duration: duration, status: resp.status}, %{
          payload_size: byte_size(conf)
        })

        json_conf

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:adapt_error, %{duration: duration}, %{
          error: reason,
          payload_size: byte_size(conf)
        })

        %{}
    end
  end

  @doc """
  Check server health status
  """
  @spec health_check() :: {:ok, map()} | {:error, binary()}
  def health_check() do
    start_time = System.monotonic_time()

    case request_module().get("/config/") do
      {:ok, %{status: 200}, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:health_check, %{duration: duration, status: 200}, %{
          method: :get
        })

        {:ok, %{status: :healthy, config_loaded: body != %{}}}

      {:ok, %{status: status}, _} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:health_check, %{duration: duration, status: status}, %{
          method: :get
        })

        {:error, "Server returned status #{status}"}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:health_check_error, %{duration: duration}, %{
          error: reason
        })

        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get detailed server info including version and uptime
  """
  @spec server_info() :: {:ok, map()} | {:error, binary()}
  def server_info() do
    start_time = System.monotonic_time()

    case request_module().get("/") do
      {:ok, %{status: 200}, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:server_info, %{duration: duration, status: 200}, %{
          method: :get
        })

        {:ok, body}

      {:ok, %{status: status}, _} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:server_info, %{duration: duration, status: status}, %{
          method: :get
        })

        {:error, "Server returned status #{status}"}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:server_info_error, %{duration: duration}, %{error: reason})

        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end
end
