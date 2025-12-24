defmodule Caddy.Config.Matcher.Protocol do
  @moduledoc """
  Represents a Caddy protocol matcher.

  Matches requests by protocol or HTTP version.

  ## Examples

      # Match HTTPS only
      matcher = Protocol.new("https")
      # Renders as: protocol https

      # Match HTTP/2 and above
      matcher = Protocol.new("http/2+")
      # Renders as: protocol http/2+

      # Match gRPC
      matcher = Protocol.new("grpc")
      # Renders as: protocol grpc

  ## Supported Protocols

  - `http` - HTTP (plaintext)
  - `https` - HTTPS (TLS)
  - `grpc` - gRPC over HTTP/2
  - `http/1.0`, `http/1.1`, `http/2`, `http/3` - Specific HTTP versions
  - `http/2+` - HTTP/2 or higher

  """

  @type t :: %__MODULE__{
          protocol: String.t()
        }

  defstruct [:protocol]

  @doc """
  Create a new protocol matcher.

  ## Parameters

    - `protocol` - Protocol string (http, https, grpc, http/N, http/N+)

  ## Examples

      iex> Protocol.new("https")
      %Protocol{protocol: "https"}

      iex> Protocol.new("http/2+")
      %Protocol{protocol: "http/2+"}

  """
  @spec new(String.t()) :: t()
  def new(protocol) when is_binary(protocol) do
    %__MODULE__{protocol: protocol}
  end

  @doc """
  Validate a protocol matcher.

  ## Examples

      iex> Protocol.validate(%Protocol{protocol: "https"})
      {:ok, %Protocol{protocol: "https"}}

      iex> Protocol.validate(%Protocol{protocol: ""})
      {:error, "protocol cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{protocol: protocol} = matcher) do
    valid_protocols = ~w(http https grpc http/1.0 http/1.1 http/2 http/3 http/2+ http/3+)

    cond do
      protocol == "" or protocol == nil ->
        {:error, "protocol cannot be empty"}

      not is_binary(protocol) ->
        {:error, "protocol must be a string"}

      protocol not in valid_protocols ->
        {:error, "invalid protocol: #{protocol}"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Protocol do
  @moduledoc """
  Caddyfile protocol implementation for Protocol matcher.
  """

  def to_caddyfile(%{protocol: protocol}) do
    start_time = System.monotonic_time()
    result = "protocol #{protocol}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Protocol,
      result_size: byte_size(result)
    })

    result
  end
end
