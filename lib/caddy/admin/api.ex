defmodule Caddy.Admin.Api do
  @moduledoc """
  High-level interface to the Caddy Admin API.

  All functions return tagged tuples: `{:ok, value}` on success or
  `{:error, reason}` on failure.
  """

  alias Caddy.Admin.Request

  @type response :: Request.t()
  @type result(value) :: {:ok, value} | {:error, term()}

  defp request_module, do: Application.get_env(:caddy, :request_module, Caddy.Admin.Request)

  @doc """
  Send a GET request to an Admin API path.
  """
  @spec get(binary()) :: result(response())
  def get(path), do: request(:get, path, nil, nil, :request, %{method: :get, path: path})

  @doc """
  Sets or replaces the active configuration.

  Map inputs are loaded directly. This avoids shallow-merging new config into the
  current runtime config.
  """
  @spec load(map() | binary(), keyword()) :: result(response())
  def load(conf, opts \\ [])

  def load(conf, opts) when is_map(conf) do
    conf
    |> JSON.encode!()
    |> load(opts)
  end

  def load(conf, opts) when is_binary(conf) do
    request(:post, "/load", conf, "application/json", :load, %{payload_size: byte_size(conf)},
      headers: headers_from_opts(opts)
    )
  end

  @doc """
  Stops the active configuration and exits the Caddy process.
  """
  @spec stop() :: result(response())
  def stop do
    request(:post, "/stop", "", "application/json", :stop, %{method: :post})
  end

  @doc """
  Exports the config at the named path.
  """
  @spec get_config() :: result(map())
  def get_config, do: get_config_path("/")

  @spec get_config(binary()) :: result(term())
  def get_config(path) when is_binary(path), do: get_config_path("/config/#{path}")

  @doc """
  Exports config with the response ETag for later `If-Match` updates.
  """
  @spec get_config_with_etag() :: result(%{config: term(), etag: binary() | nil})
  def get_config_with_etag, do: get_config_with_etag_path("/config/")

  @spec get_config_with_etag(binary()) :: result(%{config: term(), etag: binary() | nil})
  def get_config_with_etag(path) when is_binary(path),
    do: get_config_with_etag_path("/config/#{path}")

  @doc """
  Post config at the root path or a named path.
  """
  @spec post_config(map(), keyword()) :: result(term())
  def post_config(data, opts \\ [])

  def post_config(data, opts) when is_map(data) and is_list(opts),
    do: post_config_path("/", data, opts)

  def post_config(path, data) when is_binary(path) and is_map(data),
    do: post_config_path(path, data, [])

  @spec post_config(binary(), map(), keyword()) :: result(term())
  def post_config(path, data, opts) when is_binary(path) and is_map(data) and is_list(opts) do
    post_config_path(path, data, opts)
  end

  @doc """
  Put config at the root path or a named path.
  """
  @spec put_config(map(), keyword()) :: result(term())
  def put_config(data, opts \\ [])

  def put_config(data, opts) when is_map(data) and is_list(opts),
    do: put_config_path("/", data, opts)

  def put_config(path, data) when is_binary(path) and is_map(data),
    do: put_config_path(path, data, [])

  @spec put_config(binary(), map(), keyword()) :: result(term())
  def put_config(path, data, opts) when is_binary(path) and is_map(data) and is_list(opts) do
    put_config_path(path, data, opts)
  end

  @doc """
  Patch config at the root path or a named path.
  """
  @spec patch_config(map(), keyword()) :: result(term())
  def patch_config(data, opts \\ [])

  def patch_config(data, opts) when is_map(data) and is_list(opts),
    do: patch_config_path("/", data, opts)

  def patch_config(path, data) when is_binary(path) and is_map(data),
    do: patch_config_path(path, data, [])

  @spec patch_config(binary(), map(), keyword()) :: result(term())
  def patch_config(path, data, opts) when is_binary(path) and is_map(data) and is_list(opts) do
    patch_config_path(path, data, opts)
  end

  @doc """
  Delete config at the root path or a named path.
  """
  @spec delete_config(keyword()) :: result(term())
  def delete_config(opts \\ [])

  @spec delete_config(binary(), keyword()) :: result(term())
  def delete_config(path) when is_binary(path), do: delete_config_path(path, [])
  def delete_config(opts) when is_list(opts), do: delete_config_path("/", opts)
  def delete_config(path, opts) when is_binary(path), do: delete_config_path(path, opts)

  @doc """
  Adapts a Caddyfile to JSON without running it.
  """
  @spec adapt(binary()) :: result(map())
  def adapt(conf) do
    with {:ok, response} <-
           request(:post, "/adapt", conf, "application/json", :adapt, %{
             payload_size: byte_size(conf)
           }) do
      {:ok, response.body}
    end
  end

  @doc """
  Cheap liveness check using Caddy's root Admin API endpoint.
  """
  @spec health_check() :: result(map())
  def health_check do
    start_time = System.monotonic_time()

    case request_module().get("/") do
      {:ok, %{status: status}, _body} when status in 200..299 ->
        duration = System.monotonic_time() - start_time
        Caddy.Telemetry.emit_api_event(:health_check, %{duration: duration, status: status}, %{})
        {:ok, %{status: :healthy}}

      {:ok, %{status: status}, body} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(
          :health_check_error,
          %{duration: duration, status: status},
          %{}
        )

        {:error, {:http_error, status, body}}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_api_event(:health_check_error, %{duration: duration}, %{
          error: reason
        })

        {:error, {:connection_failed, reason}}
    end
  end

  @doc """
  Fetch Prometheus metrics from Caddy's metrics endpoint.
  """
  @spec get_metrics(binary()) :: result(binary())
  def get_metrics(endpoint \\ "/metrics") do
    case get(endpoint) do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{body: body}} when is_map(body) -> {:ok, JSON.encode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get detailed server info.
  """
  @spec server_info() :: result(map() | binary())
  def server_info do
    case get("/") do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get current reverse-proxy upstream status.
  """
  @spec get_upstreams() :: result(term())
  def get_upstreams, do: get_body("/reverse_proxy/upstreams")

  @doc """
  Get information about a PKI CA.
  """
  @spec get_pki_ca(binary()) :: result(term())
  def get_pki_ca(ca_id) when is_binary(ca_id), do: get_body("/pki/ca/#{ca_id}")

  @doc """
  Get the certificate chain for a PKI CA.
  """
  @spec get_pki_certificates(binary()) :: result(term())
  def get_pki_certificates(ca_id) when is_binary(ca_id) do
    get_body("/pki/ca/#{ca_id}/certificates")
  end

  @doc """
  Get config by Caddy `@id`.
  """
  @spec get_by_id(binary()) :: result(term())
  def get_by_id(id) when is_binary(id), do: get_body("/id/#{id}")

  @doc """
  Patch config by Caddy `@id`.
  """
  @spec patch_by_id(binary(), map(), keyword()) :: result(term())
  def patch_by_id(id, data, opts \\ []) when is_binary(id) and is_map(data) do
    data_string = JSON.encode!(data)

    with {:ok, response} <-
           request(
             :patch,
             "/id/#{id}",
             data_string,
             "application/json",
             :patch_id,
             %{
               id: id,
               payload_size: byte_size(data_string)
             },
             headers: headers_from_opts(opts)
           ) do
      {:ok, response.body}
    end
  end

  @doc """
  Delete config by Caddy `@id`.
  """
  @spec delete_by_id(binary(), keyword()) :: result(term())
  def delete_by_id(id, opts \\ []) when is_binary(id) do
    with {:ok, response} <-
           request(:delete, "/id/#{id}", "", "application/json", :delete_id, %{id: id},
             headers: headers_from_opts(opts)
           ) do
      {:ok, response.body}
    end
  end

  defp get_config_path("/"), do: get_config_path("/config/")

  defp get_config_path(path) do
    with {:ok, response} <- request(:get, path, nil, nil, :get_config, %{path: path}) do
      {:ok, response.body}
    end
  end

  defp get_config_with_etag_path(path) do
    with {:ok, response} <- request(:get, path, nil, nil, :get_config, %{path: path}) do
      {:ok, %{config: response.body, etag: response_etag(response)}}
    end
  end

  defp get_body(path) do
    with {:ok, response} <- get(path) do
      {:ok, response.body}
    end
  end

  defp post_config_path(path, data, opts) do
    config_request(:post, config_path(path), data, opts, :post_config)
  end

  defp put_config_path(path, data, opts) do
    config_request(:put, config_path(path), data, opts, :put_config)
  end

  defp patch_config_path(path, data, opts) do
    config_request(:patch, config_path(path), data, opts, :patch_config)
  end

  defp delete_config_path(path, opts) do
    with {:ok, response} <-
           request(
             :delete,
             config_path(path),
             "",
             "application/json",
             :delete_config,
             %{path: path},
             headers: headers_from_opts(opts)
           ) do
      {:ok, response.body}
    end
  end

  defp config_request(method, path, data, opts, event) do
    data_string = JSON.encode!(data)

    with {:ok, response} <-
           request(
             method,
             path,
             data_string,
             "application/json",
             event,
             %{
               path: path,
               payload_size: byte_size(data_string)
             },
             headers: headers_from_opts(opts)
           ) do
      {:ok, response.body}
    end
  end

  defp config_path("/"), do: "/config/"
  defp config_path(path) when is_binary(path), do: "/config/#{path}"

  defp request(method, path, data, content_type, event, metadata, opts \\ []) do
    start_time = System.monotonic_time()
    headers = Keyword.get(opts, :headers, [])

    result =
      case dispatch_request(method, path, data, content_type, headers) do
        {:ok, resp, body} when resp.status in 200..299 ->
          {:ok, %{resp | body: body}}

        {:ok, resp, body} ->
          {:error, {:http_error, resp.status, body}}

        {:error, reason} ->
          {:error, reason}
      end

    duration = System.monotonic_time() - start_time
    emit_request_event(event, result, duration, metadata)
    result
  end

  defp dispatch_request(:get, path, _data, _content_type, []), do: request_module().get(path)

  defp dispatch_request(:get, path, _data, _content_type, headers),
    do: request_module().get(path, headers)

  defp dispatch_request(:post, path, data, content_type, []),
    do: request_module().post(path, data, content_type)

  defp dispatch_request(:post, path, data, content_type, headers),
    do: request_module().post(path, data, content_type, headers)

  defp dispatch_request(:put, path, data, content_type, []),
    do: request_module().put(path, data, content_type)

  defp dispatch_request(:put, path, data, content_type, headers),
    do: request_module().put(path, data, content_type, headers)

  defp dispatch_request(:patch, path, data, content_type, []),
    do: request_module().patch(path, data, content_type)

  defp dispatch_request(:patch, path, data, content_type, headers),
    do: request_module().patch(path, data, content_type, headers)

  defp dispatch_request(:delete, path, data, content_type, []),
    do: request_module().delete(path, data, content_type)

  defp dispatch_request(:delete, path, data, content_type, headers),
    do: request_module().delete(path, data, content_type, headers)

  defp emit_request_event(event, {:ok, response}, duration, metadata) do
    Caddy.Telemetry.emit_api_event(
      event,
      %{duration: duration, status: response.status},
      metadata
    )
  end

  defp emit_request_event(event, {:error, reason}, duration, metadata) do
    Caddy.Telemetry.emit_api_event(
      :"#{event}_error",
      %{duration: duration},
      Map.put(metadata, :error, reason)
    )
  end

  defp headers_from_opts(opts) do
    case Keyword.get(opts, :if_match) do
      nil -> []
      etag -> [{"If-Match", etag}]
    end
  end

  defp response_etag(%{headers: headers}) do
    Enum.find_value(headers, fn
      {:Etag, value} -> value
      {:ETag, value} -> value
      {"Etag", value} -> value
      {"ETag", value} -> value
      {"etag", value} -> value
      _ -> nil
    end)
  end
end
