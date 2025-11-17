defmodule Caddy.Config.Site do
  @moduledoc """
  Represents a Caddy virtual host (site) configuration.

  Inspired by NixOS virtualHosts pattern, providing a structured way to define site configurations.

  ## Examples

      site = %Site{
        host_name: "example.com",
        listen: ":443",
        server_aliases: ["www.example.com"],
        tls: :auto,
        imports: [Import.snippet("log-zone", ["app", "prod"])],
        directives: ["reverse_proxy localhost:3000"]
      }

  ## Rendering

      :443 example.com www.example.com {
        import log-zone "app" "prod"
        reverse_proxy localhost:3000
      }

  """

  alias Caddy.Config.Import

  @type tls_config :: :off | :internal | :auto | {String.t(), String.t()}
  @type directive :: String.t() | {String.t(), String.t()}

  @type t :: %__MODULE__{
          host_name: String.t(),
          listen: String.t() | nil,
          server_aliases: [String.t()],
          tls: tls_config(),
          imports: [Import.t()],
          directives: [directive()],
          extra_config: String.t()
        }

  defstruct [
    :host_name,
    listen: nil,
    server_aliases: [],
    tls: :auto,
    imports: [],
    directives: [],
    extra_config: ""
  ]

  @doc """
  Create a new site with the given hostname.

  ## Examples

      iex> Site.new("example.com")
      %Site{host_name: "example.com", tls: :auto}

  """
  @spec new(String.t()) :: t()
  def new(host_name) do
    %__MODULE__{host_name: host_name}
  end

  @doc """
  Set the listen address for the site.

  ## Examples

      iex> site |> Site.listen(":443")
      %Site{listen: ":443"}

  """
  @spec listen(t(), String.t()) :: t()
  def listen(site, address) do
    %{site | listen: address}
  end

  @doc """
  Add server aliases (alternative domain names).

  ## Examples

      iex> site |> Site.add_alias("www.example.com")
      %Site{server_aliases: ["www.example.com"]}

      iex> site |> Site.add_alias(["www.example.com", "example.org"])
      %Site{server_aliases: ["www.example.com", "example.org"]}

  """
  @spec add_alias(t(), String.t() | [String.t()]) :: t()
  def add_alias(site, aliases) when is_list(aliases) do
    %{site | server_aliases: site.server_aliases ++ aliases}
  end

  def add_alias(site, alias_name) when is_binary(alias_name) do
    %{site | server_aliases: site.server_aliases ++ [alias_name]}
  end

  @doc """
  Set TLS configuration.

  ## Examples

      iex> site |> Site.tls(:internal)
      %Site{tls: :internal}

      iex> site |> Site.tls({"/path/to/cert.pem", "/path/to/key.pem"})
      %Site{tls: {"/path/to/cert.pem", "/path/to/key.pem"}}

  """
  @spec tls(t(), tls_config()) :: t()
  def tls(site, config) do
    %{site | tls: config}
  end

  @doc """
  Import a snippet with optional arguments.

  ## Examples

      iex> site |> Site.import_snippet("log-zone", ["app", "prod"])
      %Site{imports: [%Import{snippet: "log-zone", args: ["app", "prod"]}]}

  """
  @spec import_snippet(t(), String.t(), [String.t()]) :: t()
  def import_snippet(site, name, args \\ []) do
    import_directive = Import.snippet(name, args)
    %{site | imports: site.imports ++ [import_directive]}
  end

  @doc """
  Import from a file path.

  ## Examples

      iex> site |> Site.import_file("/etc/caddy/common.conf")
      %Site{imports: [%Import{path: "/etc/caddy/common.conf"}]}

  """
  @spec import_file(t(), String.t()) :: t()
  def import_file(site, path) do
    import_directive = Import.file(path)
    %{site | imports: site.imports ++ [import_directive]}
  end

  @doc """
  Add a reverse proxy directive.

  ## Examples

      iex> site |> Site.reverse_proxy("localhost:3000")
      %Site{directives: ["reverse_proxy localhost:3000"]}

  """
  @spec reverse_proxy(t(), String.t()) :: t()
  def reverse_proxy(site, target) do
    add_directive(site, "reverse_proxy #{target}")
  end

  @doc """
  Add a custom directive.

  ## Examples

      iex> site |> Site.add_directive("encode gzip")
      %Site{directives: ["encode gzip"]}

      iex> site |> Site.add_directive({"header", "X-Custom-Header value"})
      %Site{directives: [{"header", "X-Custom-Header value"}]}

  """
  @spec add_directive(t(), directive()) :: t()
  def add_directive(site, directive) do
    %{site | directives: site.directives ++ [directive]}
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Site do
  @moduledoc """
  Caddyfile protocol implementation for Site.

  Renders a complete site block with address line and directives.
  """

  alias Caddy.Caddyfile

  def to_caddyfile(site) do
    address = build_address_line(site)
    directives = build_directives(site)

    """
    #{address} {
    #{directives}
    }
    """
    |> String.trim_trailing()
  end

  defp build_address_line(site) do
    # Listen address (first if present)
    parts = if site.listen, do: [site.listen], else: []

    # Hostname (always present)
    parts = parts ++ [site.host_name]

    # Server aliases (after hostname)
    parts = parts ++ site.server_aliases

    Enum.join(parts, " ")
  end

  defp build_directives(site) do
    parts = []

    # TLS directive (only if not auto, which is default)
    parts =
      if site.tls && site.tls != :auto do
        [format_tls(site.tls) | parts]
      else
        parts
      end

    # Import directives
    import_parts = Enum.map(site.imports, &Caddyfile.to_caddyfile/1)
    parts = parts ++ import_parts

    # Custom directives
    parts = parts ++ Enum.map(site.directives, &format_directive/1)

    # Extra config
    parts =
      if site.extra_config != "" do
        parts ++ [site.extra_config]
      else
        parts
      end

    parts
    |> Enum.map(&indent/1)
    |> Enum.join("\n")
  end

  defp format_tls(:off), do: "tls off"
  defp format_tls(:internal), do: "tls internal"
  defp format_tls({cert, key}), do: "tls #{cert} #{key}"

  defp format_directive(str) when is_binary(str), do: str
  defp format_directive({name, value}), do: "#{name} #{value}"

  defp indent(text) do
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      if String.trim(line) == "", do: "", else: "  #{line}"
    end)
    |> Enum.join("\n")
  end
end
