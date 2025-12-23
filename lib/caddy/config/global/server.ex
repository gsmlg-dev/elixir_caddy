defmodule Caddy.Config.Global.Server do
  @moduledoc """
  Represents server configuration within a Caddy servers block.

  Used inside `servers { }` block to configure server-specific options.

  ## Examples

      alias Caddy.Config.Global.{Server, Timeouts}

      server = %Server{
        name: "https",
        protocols: [:h1, :h2, :h3],
        timeouts: %Timeouts{
          read_body: "10s",
          read_header: "5s",
          write: "30s",
          idle: "2m"
        },
        trusted_proxies: {:static, ["private_ranges"]},
        client_ip_headers: ["X-Forwarded-For", "X-Real-IP"]
      }

  ## Rendering

  Renders as a nested block within servers configuration:

      servers :443 {
        name https
        protocols h1 h2 h3
        timeouts {
          read_body 10s
          read_header 5s
          write 30s
          idle 2m
        }
        trusted_proxies static private_ranges
        client_ip_headers X-Forwarded-For X-Real-IP
      }

  """

  alias Caddy.Config.Global.Timeouts

  @type t :: %__MODULE__{
          name: String.t() | nil,
          protocols: [atom()] | nil,
          timeouts: Timeouts.t() | nil,
          trusted_proxies: {atom(), [String.t()]} | nil,
          trusted_proxies_strict: boolean() | nil,
          client_ip_headers: [String.t()] | nil,
          max_header_size: String.t() | nil,
          keepalive_interval: String.t() | nil,
          log_credentials: boolean() | nil,
          strict_sni_host: atom() | nil
        }

  defstruct name: nil,
            protocols: nil,
            timeouts: nil,
            trusted_proxies: nil,
            trusted_proxies_strict: nil,
            client_ip_headers: nil,
            max_header_size: nil,
            keepalive_interval: nil,
            log_credentials: nil,
            strict_sni_host: nil

  @doc """
  Create a new server configuration with defaults.

  ## Examples

      iex> Server.new()
      %Server{}

      iex> Server.new(name: "https", protocols: [:h1, :h2])
      %Server{name: "https", protocols: [:h1, :h2]}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Global.Server do
  @moduledoc """
  Caddyfile protocol implementation for Server configuration.

  Renders the server block contents (without the outer servers wrapper).
  """

  alias Caddy.Caddyfile

  @doc """
  Convert server configuration to Caddyfile format.

  Returns the server block contents for embedding within a servers block.

  ## Examples

      iex> server = %Caddy.Config.Global.Server{name: "https"}
      iex> Caddy.Caddyfile.to_caddyfile(server)
      "name https"

      iex> server = %Caddy.Config.Global.Server{}
      iex> Caddy.Caddyfile.to_caddyfile(server)
      ""

  """
  def to_caddyfile(server) do
    options = build_options(server)

    if Enum.empty?(options) do
      ""
    else
      Enum.join(options, "\n")
    end
  end

  defp build_options(server) do
    []
    |> maybe_add("name", server.name)
    |> maybe_add_protocols(server.protocols)
    |> maybe_add_timeouts(server.timeouts)
    |> maybe_add_trusted_proxies(server.trusted_proxies)
    |> maybe_add_flag("trusted_proxies_strict", server.trusted_proxies_strict)
    |> maybe_add_list("client_ip_headers", server.client_ip_headers)
    |> maybe_add("max_header_size", server.max_header_size)
    |> maybe_add("keepalive_interval", server.keepalive_interval)
    |> maybe_add_flag("log_credentials", server.log_credentials)
    |> maybe_add_strict_sni_host(server.strict_sni_host)
    |> Enum.reverse()
  end

  defp maybe_add(options, _key, nil), do: options
  defp maybe_add(options, key, value), do: ["#{key} #{value}" | options]

  defp maybe_add_protocols(options, nil), do: options
  defp maybe_add_protocols(options, []), do: options

  defp maybe_add_protocols(options, protocols) when is_list(protocols) do
    protocol_str = Enum.map_join(protocols, " ", &to_string/1)
    ["protocols #{protocol_str}" | options]
  end

  defp maybe_add_timeouts(options, nil), do: options

  defp maybe_add_timeouts(options, %Caddy.Config.Global.Timeouts{} = timeouts) do
    timeouts_str = Caddyfile.to_caddyfile(timeouts)

    if timeouts_str == "" do
      options
    else
      # Indent the timeouts block for proper nesting
      indented =
        timeouts_str
        |> String.split("\n")
        |> Enum.map_join("\n", fn
          "timeouts {" -> "timeouts {"
          "}" -> "}"
          line -> line
        end)

      [indented | options]
    end
  end

  defp maybe_add_trusted_proxies(options, nil), do: options

  defp maybe_add_trusted_proxies(options, {type, values}) when is_list(values) do
    ["trusted_proxies #{type} #{Enum.join(values, " ")}" | options]
  end

  defp maybe_add_flag(options, _key, nil), do: options
  defp maybe_add_flag(options, _key, false), do: options
  defp maybe_add_flag(options, key, true), do: [key | options]

  defp maybe_add_list(options, _key, nil), do: options
  defp maybe_add_list(options, _key, []), do: options

  defp maybe_add_list(options, key, values) when is_list(values) do
    ["#{key} #{Enum.join(values, " ")}" | options]
  end

  defp maybe_add_strict_sni_host(options, nil), do: options

  defp maybe_add_strict_sni_host(options, value) when is_atom(value) do
    ["strict_sni_host #{value}" | options]
  end
end
