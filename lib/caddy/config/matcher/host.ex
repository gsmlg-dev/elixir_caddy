defmodule Caddy.Config.Matcher.Host do
  @moduledoc """
  Represents a Caddy host matcher.

  Matches requests by the Host header value.

  ## Examples

      # Match single host
      matcher = Host.new(["example.com"])
      # Renders as: host example.com

      # Match multiple hosts
      matcher = Host.new(["api.example.com", "api.example.org"])
      # Renders as: host api.example.com api.example.org

  ## Hostname Formats

  - Plain hostnames: `example.com`
  - Subdomains: `api.example.com`
  - Wildcards are NOT supported in host matcher (use path matcher for patterns)

  """

  @type t :: %__MODULE__{
          hosts: [String.t()]
        }

  defstruct hosts: []

  @doc """
  Create a new host matcher.

  ## Parameters

    - `hosts` - List of hostnames to match

  ## Examples

      iex> Host.new(["example.com"])
      %Host{hosts: ["example.com"]}

      iex> Host.new(["api.example.com", "api.example.org"])
      %Host{hosts: ["api.example.com", "api.example.org"]}

  """
  @spec new([String.t()]) :: t()
  def new(hosts) when is_list(hosts) do
    %__MODULE__{hosts: hosts}
  end

  @doc """
  Validate a host matcher.

  ## Examples

      iex> Host.validate(%Host{hosts: ["example.com"]})
      {:ok, %Host{hosts: ["example.com"]}}

      iex> Host.validate(%Host{hosts: []})
      {:error, "hosts cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{hosts: hosts} = matcher) do
    cond do
      hosts == [] ->
        {:error, "hosts cannot be empty"}

      not Enum.all?(hosts, &is_binary/1) ->
        {:error, "all hosts must be strings"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Host do
  @moduledoc """
  Caddyfile protocol implementation for Host matcher.
  """

  def to_caddyfile(%{hosts: hosts}) do
    start_time = System.monotonic_time()
    result = "host #{Enum.join(hosts, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Host,
      result_size: byte_size(result)
    })

    result
  end
end
