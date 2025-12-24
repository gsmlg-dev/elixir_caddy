defmodule Caddy.Config.Matcher.ClientIp do
  @moduledoc """
  Represents a Caddy client_ip matcher.

  Matches requests by the client IP address, respecting X-Forwarded-For headers
  when behind trusted proxies.

  ## Examples

      # Match single IP
      matcher = ClientIp.new(["192.168.1.1"])
      # Renders as: client_ip 192.168.1.1

      # Match CIDR range
      matcher = ClientIp.new(["192.168.0.0/16"])
      # Renders as: client_ip 192.168.0.0/16

      # Match private ranges
      matcher = ClientIp.new(["private_ranges"])
      # Renders as: client_ip private_ranges

  ## Shortcuts

  - `private_ranges` - Matches all RFC 1918 private ranges
  - `forwarded` - Uses the X-Forwarded-For header

  """

  @type t :: %__MODULE__{
          ranges: [String.t()]
        }

  defstruct ranges: []

  @doc """
  Create a new client_ip matcher.

  ## Parameters

    - `ranges` - List of IP addresses, CIDR ranges, or shortcuts

  ## Examples

      iex> ClientIp.new(["192.168.1.1"])
      %ClientIp{ranges: ["192.168.1.1"]}

      iex> ClientIp.new(["private_ranges"])
      %ClientIp{ranges: ["private_ranges"]}

  """
  @spec new([String.t()]) :: t()
  def new(ranges) when is_list(ranges) do
    %__MODULE__{ranges: ranges}
  end

  @doc """
  Validate a client_ip matcher.

  ## Examples

      iex> ClientIp.validate(%ClientIp{ranges: ["192.168.1.1"]})
      {:ok, %ClientIp{ranges: ["192.168.1.1"]}}

      iex> ClientIp.validate(%ClientIp{ranges: []})
      {:error, "ranges cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{ranges: ranges} = matcher) do
    cond do
      ranges == [] ->
        {:error, "ranges cannot be empty"}

      not Enum.all?(ranges, &is_binary/1) ->
        {:error, "all ranges must be strings"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.ClientIp do
  @moduledoc """
  Caddyfile protocol implementation for ClientIp matcher.
  """

  def to_caddyfile(%{ranges: ranges}) do
    start_time = System.monotonic_time()
    result = "client_ip #{Enum.join(ranges, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.ClientIp,
      result_size: byte_size(result)
    })

    result
  end
end
