defmodule Caddy.Admin.Resources do
  @moduledoc """
  Domain-specific helpers for common Caddy configuration paths.

  Provides typed access to Caddy's JSON configuration structure,
  making it easier to work with apps, servers, routes, and TLS settings.

  ## Examples

      # Get all HTTP servers
      {:ok, servers} = Caddy.Admin.Resources.get_http_servers()

      # Add a route to a server
      route = %{"match" => [%{"path" => ["/api/*"]}], "handle" => [...]}
      {:ok, _} = Caddy.Admin.Resources.add_route("srv0", route)

      # Get TLS configuration
      {:ok, tls} = Caddy.Admin.Resources.get_tls()

  ## Caddy Config Structure

  The typical Caddy JSON config structure:

      %{
        "admin" => %{"listen" => "unix//tmp/caddy.sock"},
        "apps" => %{
          "http" => %{
            "servers" => %{
              "srv0" => %{
                "listen" => [":443"],
                "routes" => [...]
              }
            }
          },
          "tls" => %{...}
        }
      }
  """

  alias Caddy.Admin.Api

  # ============================================================================
  # Apps
  # ============================================================================

  @doc """
  Get all configured apps.

  Returns the apps section of the Caddy config.
  """
  @spec get_apps() :: {:ok, map()} | {:error, term()}
  def get_apps do
    case Api.get_config("apps") do
      nil -> {:error, :not_found}
      apps when is_map(apps) -> {:ok, apps}
    end
  end

  @doc """
  Get a specific app by name.

  ## Examples

      {:ok, http_app} = Caddy.Admin.Resources.get_app("http")
      {:ok, tls_app} = Caddy.Admin.Resources.get_app("tls")
  """
  @spec get_app(String.t()) :: {:ok, map()} | {:error, term()}
  def get_app(name) when is_binary(name) do
    case Api.get_config("apps/#{name}") do
      nil -> {:error, :not_found}
      app when is_map(app) -> {:ok, app}
    end
  end

  @doc """
  Set or replace a specific app configuration.
  """
  @spec set_app(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def set_app(name, config) when is_binary(name) and is_map(config) do
    case Api.patch_config("apps/#{name}", config) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Delete a specific app.
  """
  @spec delete_app(String.t()) :: :ok | {:error, term()}
  def delete_app(name) when is_binary(name) do
    case Api.delete_config("apps/#{name}") do
      nil -> {:error, :failed}
      _ -> :ok
    end
  end

  # ============================================================================
  # HTTP Servers
  # ============================================================================

  @doc """
  Get all HTTP servers.

  Returns the servers map from the HTTP app.
  """
  @spec get_http_servers() :: {:ok, map()} | {:error, term()}
  def get_http_servers do
    case Api.get_config("apps/http/servers") do
      nil -> {:error, :not_found}
      servers when is_map(servers) -> {:ok, servers}
    end
  end

  @doc """
  Get a specific HTTP server by name.

  ## Examples

      {:ok, server} = Caddy.Admin.Resources.get_http_server("srv0")
  """
  @spec get_http_server(String.t()) :: {:ok, map()} | {:error, term()}
  def get_http_server(name) when is_binary(name) do
    case Api.get_config("apps/http/servers/#{name}") do
      nil -> {:error, :not_found}
      server when is_map(server) -> {:ok, server}
    end
  end

  @doc """
  Set or replace an HTTP server configuration.
  """
  @spec set_http_server(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def set_http_server(name, config) when is_binary(name) and is_map(config) do
    case Api.patch_config("apps/http/servers/#{name}", config) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Create a new HTTP server.
  """
  @spec create_http_server(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_http_server(name, config) when is_binary(name) and is_map(config) do
    case Api.put_config("apps/http/servers/#{name}", config) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Delete an HTTP server.
  """
  @spec delete_http_server(String.t()) :: :ok | {:error, term()}
  def delete_http_server(name) when is_binary(name) do
    case Api.delete_config("apps/http/servers/#{name}") do
      nil -> {:error, :failed}
      _ -> :ok
    end
  end

  # ============================================================================
  # Routes
  # ============================================================================

  @doc """
  Get all routes for an HTTP server.
  """
  @spec get_routes(String.t()) :: {:ok, list()} | {:error, term()}
  def get_routes(server_name) when is_binary(server_name) do
    case Api.get_config("apps/http/servers/#{server_name}/routes") do
      nil -> {:error, :not_found}
      routes when is_list(routes) -> {:ok, routes}
    end
  end

  @doc """
  Get a specific route by index.
  """
  @spec get_route(String.t(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
  def get_route(server_name, index)
      when is_binary(server_name) and is_integer(index) and index >= 0 do
    case Api.get_config("apps/http/servers/#{server_name}/routes/#{index}") do
      nil -> {:error, :not_found}
      route when is_map(route) -> {:ok, route}
    end
  end

  @doc """
  Add a route to an HTTP server (appends to routes array).

  ## Examples

      route = %{
        "match" => [%{"path" => ["/api/*"]}],
        "handle" => [%{"handler" => "reverse_proxy", "upstreams" => [%{"dial" => "localhost:3000"}]}]
      }
      {:ok, _} = Caddy.Admin.Resources.add_route("srv0", route)
  """
  @spec add_route(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def add_route(server_name, route) when is_binary(server_name) and is_map(route) do
    case Api.post_config("apps/http/servers/#{server_name}/routes", route) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Update a route at a specific index.
  """
  @spec update_route(String.t(), non_neg_integer(), map()) :: {:ok, map()} | {:error, term()}
  def update_route(server_name, index, route)
      when is_binary(server_name) and is_integer(index) and index >= 0 and is_map(route) do
    case Api.patch_config("apps/http/servers/#{server_name}/routes/#{index}", route) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Insert a route at a specific index.
  """
  @spec insert_route(String.t(), non_neg_integer(), map()) :: {:ok, map()} | {:error, term()}
  def insert_route(server_name, index, route)
      when is_binary(server_name) and is_integer(index) and index >= 0 and is_map(route) do
    case Api.put_config("apps/http/servers/#{server_name}/routes/#{index}", route) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Delete a route at a specific index.
  """
  @spec delete_route(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def delete_route(server_name, index)
      when is_binary(server_name) and is_integer(index) and index >= 0 do
    case Api.delete_config("apps/http/servers/#{server_name}/routes/#{index}") do
      nil -> {:error, :failed}
      _ -> :ok
    end
  end

  # ============================================================================
  # TLS
  # ============================================================================

  @doc """
  Get TLS app configuration.
  """
  @spec get_tls() :: {:ok, map()} | {:error, term()}
  def get_tls do
    case Api.get_config("apps/tls") do
      nil -> {:error, :not_found}
      tls when is_map(tls) -> {:ok, tls}
    end
  end

  @doc """
  Set TLS app configuration.
  """
  @spec set_tls(map()) :: {:ok, map()} | {:error, term()}
  def set_tls(config) when is_map(config) do
    case Api.patch_config("apps/tls", config) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  @doc """
  Get TLS automation configuration.
  """
  @spec get_tls_automation() :: {:ok, map()} | {:error, term()}
  def get_tls_automation do
    case Api.get_config("apps/tls/automation") do
      nil -> {:error, :not_found}
      automation when is_map(automation) -> {:ok, automation}
    end
  end

  @doc """
  Set TLS automation configuration.
  """
  @spec set_tls_automation(map()) :: {:ok, map()} | {:error, term()}
  def set_tls_automation(config) when is_map(config) do
    case Api.patch_config("apps/tls/automation", config) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  # ============================================================================
  # Admin Settings
  # ============================================================================

  @doc """
  Get admin settings.
  """
  @spec get_admin() :: {:ok, map()} | {:error, term()}
  def get_admin do
    case Api.get_config("admin") do
      nil -> {:error, :not_found}
      admin when is_map(admin) -> {:ok, admin}
    end
  end

  @doc """
  Set admin settings.
  """
  @spec set_admin(map()) :: {:ok, map()} | {:error, term()}
  def set_admin(config) when is_map(config) do
    case Api.patch_config("admin", config) do
      nil -> {:error, :failed}
      result -> {:ok, result}
    end
  end

  # ============================================================================
  # Reverse Proxy Upstreams
  # ============================================================================

  @doc """
  Get current status of reverse proxy upstreams.

  This endpoint returns health status of configured upstream servers.
  """
  @spec get_upstreams() :: {:ok, map()} | {:error, term()}
  def get_upstreams do
    case Api.get("/reverse_proxy/upstreams") do
      %{status: status, body: body} when status in 200..299 -> {:ok, body}
      %{status: 0} -> {:error, :connection_failed}
      %{status: status} -> {:error, {:http_error, status}}
      _ -> {:error, :connection_failed}
    end
  end

  # ============================================================================
  # PKI / Certificates
  # ============================================================================

  @doc """
  Get information about a PKI CA.

  ## Examples

      {:ok, ca_info} = Caddy.Admin.Resources.get_pki_ca("local")
  """
  @spec get_pki_ca(String.t()) :: {:ok, map()} | {:error, term()}
  def get_pki_ca(ca_id) when is_binary(ca_id) do
    case Api.get("/pki/ca/#{ca_id}") do
      %{status: status, body: body} when status in 200..299 -> {:ok, body}
      %{status: status} -> {:error, {:http_error, status}}
      _ -> {:error, :connection_failed}
    end
  end

  @doc """
  Get the certificate chain of a PKI CA.
  """
  @spec get_pki_certificates(String.t()) :: {:ok, list()} | {:error, term()}
  def get_pki_certificates(ca_id) when is_binary(ca_id) do
    case Api.get("/pki/ca/#{ca_id}/certificates") do
      %{status: status, body: body} when status in 200..299 -> {:ok, body}
      %{status: status} -> {:error, {:http_error, status}}
      _ -> {:error, :connection_failed}
    end
  end
end
