defmodule Caddy.Config.Matcher.RemoteIp do
  @moduledoc """
  Represents a Caddy remote_ip matcher.

  Matches requests by the immediate peer (remote) IP address.

  ## Examples

      # Match single IP
      matcher = RemoteIp.new(["192.168.1.1"])
      # Renders as: remote_ip 192.168.1.1

      # Match CIDR range
      matcher = RemoteIp.new(["192.168.0.0/16"])
      # Renders as: remote_ip 192.168.0.0/16

      # Match multiple ranges
      matcher = RemoteIp.new(["192.168.0.0/16", "10.0.0.0/8"])
      # Renders as: remote_ip 192.168.0.0/16 10.0.0.0/8

  ## Note

  This matches the immediate peer IP. For the actual client IP behind proxies,
  use `client_ip` matcher instead (which respects X-Forwarded-For headers).

  """

  @type t :: %__MODULE__{
          ranges: [String.t()]
        }

  defstruct ranges: []

  @doc """
  Create a new remote_ip matcher.

  ## Parameters

    - `ranges` - List of IP addresses or CIDR ranges

  ## Examples

      iex> RemoteIp.new(["192.168.1.1"])
      %RemoteIp{ranges: ["192.168.1.1"]}

      iex> RemoteIp.new(["10.0.0.0/8", "172.16.0.0/12"])
      %RemoteIp{ranges: ["10.0.0.0/8", "172.16.0.0/12"]}

  """
  @spec new([String.t()]) :: t()
  def new(ranges) when is_list(ranges) do
    %__MODULE__{ranges: ranges}
  end

  @doc """
  Validate a remote_ip matcher.

  ## Examples

      iex> RemoteIp.validate(%RemoteIp{ranges: ["192.168.1.1"]})
      {:ok, %RemoteIp{ranges: ["192.168.1.1"]}}

      iex> RemoteIp.validate(%RemoteIp{ranges: []})
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

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.RemoteIp do
  @moduledoc """
  Caddyfile protocol implementation for RemoteIp matcher.
  """

  def to_caddyfile(%{ranges: ranges}) do
    start_time = System.monotonic_time()
    result = "remote_ip #{Enum.join(ranges, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.RemoteIp,
      result_size: byte_size(result)
    })

    result
  end
end
