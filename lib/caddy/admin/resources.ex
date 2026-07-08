defmodule Caddy.Admin.Resources do
  @moduledoc """
  Domain-specific helpers for common Caddy Admin API resources.

  Provides typed access to Caddy's JSON configuration structure and selected
  operational endpoints such as upstream health and PKI certificates.
  """

  alias Caddy.Admin.Api

  # ============================================================================
  # Apps
  # ============================================================================

  @doc "Get all configured apps."
  @spec get_apps() :: {:ok, map()} | {:error, term()}
  def get_apps, do: expect_map(Api.get_config("apps"))

  @doc "Get a specific app by name."
  @spec get_app(String.t()) :: {:ok, map()} | {:error, term()}
  def get_app(name) when is_binary(name), do: expect_map(Api.get_config("apps/#{name}"))

  @doc "Set or replace a specific app configuration."
  @spec set_app(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def set_app(name, config) when is_binary(name) and is_map(config) do
    Api.patch_config("apps/#{name}", config)
  end

  @doc "Delete a specific app."
  @spec delete_app(String.t()) :: :ok | {:error, term()}
  def delete_app(name) when is_binary(name), do: delete_result(Api.delete_config("apps/#{name}"))

  # ============================================================================
  # HTTP Servers
  # ============================================================================

  @doc "Get all HTTP servers."
  @spec get_http_servers() :: {:ok, map()} | {:error, term()}
  def get_http_servers, do: expect_map(Api.get_config("apps/http/servers"))

  @doc "Get a specific HTTP server by name."
  @spec get_http_server(String.t()) :: {:ok, map()} | {:error, term()}
  def get_http_server(name) when is_binary(name) do
    expect_map(Api.get_config("apps/http/servers/#{name}"))
  end

  @doc "Set or replace an HTTP server configuration."
  @spec set_http_server(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def set_http_server(name, config) when is_binary(name) and is_map(config) do
    Api.patch_config("apps/http/servers/#{name}", config)
  end

  @doc "Create a new HTTP server."
  @spec create_http_server(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def create_http_server(name, config) when is_binary(name) and is_map(config) do
    Api.put_config("apps/http/servers/#{name}", config)
  end

  @doc "Delete an HTTP server."
  @spec delete_http_server(String.t()) :: :ok | {:error, term()}
  def delete_http_server(name) when is_binary(name) do
    delete_result(Api.delete_config("apps/http/servers/#{name}"))
  end

  # ============================================================================
  # Routes
  # ============================================================================

  @doc "Get all routes for an HTTP server."
  @spec get_routes(String.t()) :: {:ok, list()} | {:error, term()}
  def get_routes(server_name) when is_binary(server_name) do
    expect_list(Api.get_config("apps/http/servers/#{server_name}/routes"))
  end

  @doc "Get a specific route by index."
  @spec get_route(String.t(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
  def get_route(server_name, index)
      when is_binary(server_name) and is_integer(index) and index >= 0 do
    expect_map(Api.get_config("apps/http/servers/#{server_name}/routes/#{index}"))
  end

  @doc "Add a route to an HTTP server."
  @spec add_route(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def add_route(server_name, route) when is_binary(server_name) and is_map(route) do
    Api.post_config("apps/http/servers/#{server_name}/routes", route)
  end

  @doc "Update a route at a specific index."
  @spec update_route(String.t(), non_neg_integer(), map()) :: {:ok, term()} | {:error, term()}
  def update_route(server_name, index, route)
      when is_binary(server_name) and is_integer(index) and index >= 0 and is_map(route) do
    Api.patch_config("apps/http/servers/#{server_name}/routes/#{index}", route)
  end

  @doc "Insert a route at a specific index."
  @spec insert_route(String.t(), non_neg_integer(), map()) :: {:ok, term()} | {:error, term()}
  def insert_route(server_name, index, route)
      when is_binary(server_name) and is_integer(index) and index >= 0 and is_map(route) do
    Api.put_config("apps/http/servers/#{server_name}/routes/#{index}", route)
  end

  @doc "Delete a route at a specific index."
  @spec delete_route(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def delete_route(server_name, index)
      when is_binary(server_name) and is_integer(index) and index >= 0 do
    delete_result(Api.delete_config("apps/http/servers/#{server_name}/routes/#{index}"))
  end

  # ============================================================================
  # TLS
  # ============================================================================

  @doc "Get TLS app configuration."
  @spec get_tls() :: {:ok, map()} | {:error, term()}
  def get_tls, do: expect_map(Api.get_config("apps/tls"))

  @doc "Set TLS app configuration."
  @spec set_tls(map()) :: {:ok, term()} | {:error, term()}
  def set_tls(config) when is_map(config), do: Api.patch_config("apps/tls", config)

  @doc "Get TLS automation configuration."
  @spec get_tls_automation() :: {:ok, map()} | {:error, term()}
  def get_tls_automation, do: expect_map(Api.get_config("apps/tls/automation"))

  @doc "Set TLS automation configuration."
  @spec set_tls_automation(map()) :: {:ok, term()} | {:error, term()}
  def set_tls_automation(config) when is_map(config) do
    Api.patch_config("apps/tls/automation", config)
  end

  # ============================================================================
  # Admin Settings
  # ============================================================================

  @doc "Get admin settings."
  @spec get_admin() :: {:ok, map()} | {:error, term()}
  def get_admin, do: expect_map(Api.get_config("admin"))

  @doc "Set admin settings."
  @spec set_admin(map()) :: {:ok, term()} | {:error, term()}
  def set_admin(config) when is_map(config), do: Api.patch_config("admin", config)

  # ============================================================================
  # Reverse Proxy Upstreams
  # ============================================================================

  @doc """
  Get current status of reverse proxy upstreams.

  This endpoint returns health status of configured upstream servers.
  """
  @spec get_upstreams() :: {:ok, term()} | {:error, term()}
  def get_upstreams, do: Api.get_upstreams()

  # ============================================================================
  # PKI / Certificates
  # ============================================================================

  @doc "Get information about a PKI CA."
  @spec get_pki_ca(String.t()) :: {:ok, term()} | {:error, term()}
  def get_pki_ca(ca_id) when is_binary(ca_id), do: Api.get_pki_ca(ca_id)

  @doc "Get the certificate chain of a PKI CA."
  @spec get_pki_certificates(String.t()) :: {:ok, term()} | {:error, term()}
  def get_pki_certificates(ca_id) when is_binary(ca_id), do: Api.get_pki_certificates(ca_id)

  @doc """
  List certificates known to a Caddy PKI CA.

  The default CA is `"local"`. Certificate maps are returned as Caddy exposes
  them, with telemetry emitted for any certificate whose expiry is within
  `config :caddy, :cert_expiry_warning_days` (default: 30 days).
  """
  @spec certificates(String.t()) :: {:ok, [map()]} | {:error, term()}
  def certificates(ca_id \\ "local") when is_binary(ca_id) do
    with {:ok, response} <- get_pki_certificates(ca_id) do
      certs = normalize_certificates(response)
      Enum.each(certs, &emit_certificate_visibility(ca_id, &1))
      {:ok, certs}
    end
  end

  @doc "Get a config node by Caddy `@id`."
  @spec get_by_id(String.t()) :: {:ok, term()} | {:error, term()}
  def get_by_id(id) when is_binary(id), do: Api.get_by_id(id)

  @doc "Patch a config node by Caddy `@id`."
  @spec patch_by_id(String.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def patch_by_id(id, data, opts \\ []) when is_binary(id) and is_map(data) do
    Api.patch_by_id(id, data, opts)
  end

  @doc "Delete a config node by Caddy `@id`."
  @spec delete_by_id(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_by_id(id, opts \\ []) when is_binary(id) do
    delete_result(Api.delete_by_id(id, opts))
  end

  defp expect_map({:ok, value}) when is_map(value), do: {:ok, value}
  defp expect_map({:ok, _value}), do: {:error, :unexpected_response}
  defp expect_map({:error, {:http_error, 404, _body}}), do: {:error, :not_found}
  defp expect_map({:error, reason}), do: {:error, reason}

  defp expect_list({:ok, value}) when is_list(value), do: {:ok, value}
  defp expect_list({:ok, _value}), do: {:error, :unexpected_response}
  defp expect_list({:error, {:http_error, 404, _body}}), do: {:error, :not_found}
  defp expect_list({:error, reason}), do: {:error, reason}

  defp delete_result({:ok, _value}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}

  defp normalize_certificates(%{"certificates" => certs}) when is_list(certs),
    do: normalize_certificates(certs)

  defp normalize_certificates(%{"certificate" => cert}), do: normalize_certificates([cert])

  defp normalize_certificates(certs) when is_list(certs),
    do: Enum.map(certs, &normalize_certificate/1)

  defp normalize_certificates(cert) when is_map(cert), do: [normalize_certificate(cert)]
  defp normalize_certificates(_other), do: []

  defp normalize_certificate(cert) when is_map(cert), do: cert
  defp normalize_certificate(cert) when is_binary(cert), do: %{"certificate" => cert}

  defp emit_certificate_visibility(ca_id, cert) do
    case certificate_expires_in_days(cert) do
      nil ->
        :ok

      days ->
        Caddy.Telemetry.emit_tls_event(:certificate_seen, %{}, %{
          ca_id: ca_id,
          days_until_expiry: days
        })

        if days <= certificate_warning_days() do
          Caddy.Telemetry.emit_tls_event(:certificate_expiring, %{}, %{
            ca_id: ca_id,
            days_until_expiry: days,
            certificate: cert
          })
        end
    end
  end

  defp certificate_expires_in_days(cert) do
    cert
    |> expiry_value()
    |> parse_expiry()
    |> days_until()
  end

  defp expiry_value(cert) do
    cert["not_after"] || cert["notAfter"] || cert["expires_at"] || cert["expiration"] ||
      cert[:not_after]
  end

  defp parse_expiry(nil), do: nil

  defp parse_expiry(value) when is_integer(value) do
    DateTime.from_unix(value)
  end

  defp parse_expiry(value) when is_binary(value) do
    DateTime.from_iso8601(value)
  end

  defp parse_expiry(_value), do: nil

  defp days_until({:ok, datetime, _offset}), do: DateTime.diff(datetime, DateTime.utc_now(), :day)
  defp days_until({:ok, datetime}), do: DateTime.diff(datetime, DateTime.utc_now(), :day)
  defp days_until(_other), do: nil

  defp certificate_warning_days do
    Application.get_env(:caddy, :cert_expiry_warning_days, 30)
  end
end
