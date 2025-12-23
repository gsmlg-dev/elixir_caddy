defmodule Caddy.Config.Global.PKI do
  @moduledoc """
  Represents PKI (certificate authority) configuration in Caddy global options.

  Used to configure internal certificate authorities for local/development TLS.

  ## Examples

      pki = %PKI{
        ca_id: "local",
        name: "My Company Internal CA",
        root_cn: "My Company Root CA",
        intermediate_cn: "My Company Intermediate CA",
        intermediate_lifetime: "30d"
      }

  ## Rendering

  Renders as a pki block:

      pki {
        ca local {
          name "My Company Internal CA"
          root_cn "My Company Root CA"
          intermediate_cn "My Company Intermediate CA"
          intermediate_lifetime 30d
        }
      }

  """

  @type t :: %__MODULE__{
          ca_id: String.t(),
          name: String.t() | nil,
          root_cn: String.t() | nil,
          intermediate_cn: String.t() | nil,
          intermediate_lifetime: String.t() | nil
        }

  defstruct ca_id: "local",
            name: nil,
            root_cn: nil,
            intermediate_cn: nil,
            intermediate_lifetime: nil

  @doc """
  Create a new PKI configuration with defaults.

  ## Examples

      iex> PKI.new()
      %PKI{ca_id: "local"}

      iex> PKI.new(ca_id: "internal", name: "My CA")
      %PKI{ca_id: "internal", name: "My CA"}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Global.PKI do
  @moduledoc """
  Caddyfile protocol implementation for PKI configuration.

  Renders the pki block with proper formatting.
  """

  @doc """
  Convert PKI configuration to Caddyfile format.

  Always renders a pki block (ca_id defaults to "local").

  ## Examples

      iex> pki = %Caddy.Config.Global.PKI{name: "My CA"}
      iex> Caddy.Caddyfile.to_caddyfile(pki)
      "pki {\\n  ca local {\\n    name \\"My CA\\"\\n  }\\n}"

      iex> pki = %Caddy.Config.Global.PKI{}
      iex> Caddy.Caddyfile.to_caddyfile(pki)
      ""

  """
  def to_caddyfile(pki) do
    ca_options = build_ca_options(pki)

    if Enum.empty?(ca_options) do
      ""
    else
      ca_options_text = Enum.map_join(ca_options, "\n", &"    #{&1}")

      """
      pki {
        ca #{pki.ca_id} {
      #{ca_options_text}
        }
      }
      """
      |> String.trim_trailing()
    end
  end

  defp build_ca_options(pki) do
    []
    |> maybe_add_quoted("name", pki.name)
    |> maybe_add_quoted("root_cn", pki.root_cn)
    |> maybe_add_quoted("intermediate_cn", pki.intermediate_cn)
    |> maybe_add("intermediate_lifetime", pki.intermediate_lifetime)
    |> Enum.reverse()
  end

  defp maybe_add(options, _key, nil), do: options
  defp maybe_add(options, key, value), do: ["#{key} #{value}" | options]

  defp maybe_add_quoted(options, _key, nil), do: options
  defp maybe_add_quoted(options, key, value), do: ["#{key} \"#{value}\"" | options]
end
