defmodule Caddy.Config.Matcher.Header do
  @moduledoc """
  Represents a Caddy header matcher.

  Matches requests by HTTP header field values.

  ## Examples

      # Match header presence
      matcher = Header.new("Authorization")
      # Renders as: header Authorization

      # Match header with specific value
      matcher = Header.new("Content-Type", ["application/json"])
      # Renders as: header Content-Type application/json

      # Match header with wildcard
      matcher = Header.new("Accept", ["*json*"])
      # Renders as: header Accept *json*

  ## Wildcard Support

  - `*` matches any sequence of characters
  - `*json*` matches `application/json`, `text/json`, etc.

  """

  @type t :: %__MODULE__{
          field: String.t(),
          values: [String.t()]
        }

  defstruct [:field, values: []]

  @doc """
  Create a new header matcher.

  ## Parameters

    - `field` - Header field name
    - `values` - Optional list of values to match (empty = check presence only)

  ## Examples

      iex> Header.new("Authorization")
      %Header{field: "Authorization", values: []}

      iex> Header.new("Content-Type", ["application/json"])
      %Header{field: "Content-Type", values: ["application/json"]}

  """
  @spec new(String.t(), [String.t()]) :: t()
  def new(field, values \\ []) do
    %__MODULE__{field: field, values: values}
  end

  @doc """
  Validate a header matcher.

  ## Examples

      iex> Header.validate(%Header{field: "Authorization"})
      {:ok, %Header{field: "Authorization"}}

      iex> Header.validate(%Header{field: ""})
      {:error, "field cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{field: field, values: values} = matcher) do
    cond do
      field == "" or field == nil ->
        {:error, "field cannot be empty"}

      not is_binary(field) ->
        {:error, "field must be a string"}

      values != [] and not Enum.all?(values, &is_binary/1) ->
        {:error, "all values must be strings"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Header do
  @moduledoc """
  Caddyfile protocol implementation for Header matcher.
  """

  def to_caddyfile(%{field: field, values: []}) do
    start_time = System.monotonic_time()
    result = "header #{field}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Header,
      result_size: byte_size(result)
    })

    result
  end

  def to_caddyfile(%{field: field, values: values}) do
    start_time = System.monotonic_time()
    result = "header #{field} #{Enum.join(values, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Header,
      result_size: byte_size(result)
    })

    result
  end
end
