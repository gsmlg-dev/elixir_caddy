defprotocol Caddy.Caddyfile do
  @moduledoc """
  Protocol for converting data structures to Caddyfile format.

  Any struct can implement this protocol to be rendered as valid Caddyfile configuration.

  ## Examples

      iex> Caddy.Caddyfile.to_caddyfile("plain string")
      "plain string"

      iex> config = %Caddy.Config.Site{host_name: "example.com", directives: ["respond 200"]}
      iex> Caddy.Caddyfile.to_caddyfile(config)
      "example.com {\\n  respond 200\\n}"

  """

  @fallback_to_any true

  @doc """
  Convert the data structure to Caddyfile string format.

  Returns a string representation suitable for use in a Caddyfile.
  """
  @spec to_caddyfile(t()) :: String.t()
  def to_caddyfile(data)
end

defimpl Caddy.Caddyfile, for: BitString do
  @moduledoc """
  Default implementation for strings - returns the string as-is.

  This provides backward compatibility with existing string-based configurations.
  """

  def to_caddyfile(string) when is_binary(string), do: string
end

defimpl Caddy.Caddyfile, for: Any do
  @moduledoc """
  Fallback implementation for types that don't implement the protocol.

  Returns an empty string by default.
  """

  def to_caddyfile(_), do: ""
end
