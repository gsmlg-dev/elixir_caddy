defmodule Caddy.Config.Matcher.Query do
  @moduledoc """
  Represents a Caddy query matcher.

  Matches requests by query string parameters.

  ## Examples

      # Match query parameter with specific value
      matcher = Query.new(%{"page" => "1"})
      # Renders as: query page=1

      # Match query parameter presence (any value)
      matcher = Query.new(%{"search" => "*"})
      # Renders as: query search=*

      # Match multiple parameters
      matcher = Query.new(%{"page" => "1", "sort" => "asc"})
      # Renders as: query page=1 sort=asc

  ## Wildcard Support

  - `*` matches any value for a parameter
  - Empty string `""` matches the query with no value

  """

  @type t :: %__MODULE__{
          params: %{String.t() => String.t()}
        }

  defstruct params: %{}

  @doc """
  Create a new query matcher.

  ## Parameters

    - `params` - Map of query parameter names to expected values

  ## Examples

      iex> Query.new(%{"page" => "1"})
      %Query{params: %{"page" => "1"}}

      iex> Query.new(%{"search" => "*", "limit" => "10"})
      %Query{params: %{"search" => "*", "limit" => "10"}}

  """
  @spec new(%{String.t() => String.t()}) :: t()
  def new(params) when is_map(params) do
    %__MODULE__{params: params}
  end

  @doc """
  Validate a query matcher.

  ## Examples

      iex> Query.validate(%Query{params: %{"page" => "1"}})
      {:ok, %Query{params: %{"page" => "1"}}}

      iex> Query.validate(%Query{params: %{}})
      {:error, "params cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{params: params} = matcher) do
    cond do
      params == %{} ->
        {:error, "params cannot be empty"}

      not Enum.all?(params, fn {k, v} -> is_binary(k) and is_binary(v) end) ->
        {:error, "all keys and values must be strings"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Query do
  @moduledoc """
  Caddyfile protocol implementation for Query matcher.
  """

  def to_caddyfile(%{params: params}) do
    start_time = System.monotonic_time()

    pairs =
      params
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{v}" end)

    result = "query #{pairs}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Query,
      result_size: byte_size(result)
    })

    result
  end
end
