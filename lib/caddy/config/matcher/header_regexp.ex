defmodule Caddy.Config.Matcher.HeaderRegexp do
  @moduledoc """
  Represents a Caddy header_regexp matcher.

  Matches requests by HTTP header values using RE2 regular expressions.

  ## Examples

      # Match Authorization header with regex
      matcher = HeaderRegexp.new("Authorization", "^Bearer\\s+(.+)$")
      # Renders as: header_regexp Authorization ^Bearer\s+(.+)$

      # Named capture for cookie extraction
      matcher = HeaderRegexp.new("Cookie", "session=([a-f0-9]+)", "session")
      # Renders as: header_regexp session Cookie session=([a-f0-9]+)

  ## Captured Values

  Named captures can be accessed via placeholders like `{re.name.group}`.

  """

  @type t :: %__MODULE__{
          field: String.t(),
          pattern: String.t(),
          name: String.t() | nil
        }

  defstruct [:field, :pattern, name: nil]

  @doc """
  Create a new header_regexp matcher.

  ## Parameters

    - `field` - Header field name
    - `pattern` - RE2 regular expression pattern
    - `name` - Optional capture name for referencing matches

  ## Examples

      iex> HeaderRegexp.new("Authorization", "^Bearer")
      %HeaderRegexp{field: "Authorization", pattern: "^Bearer", name: nil}

      iex> HeaderRegexp.new("Cookie", "session=(.+)", "session")
      %HeaderRegexp{field: "Cookie", pattern: "session=(.+)", name: "session"}

  """
  @spec new(String.t(), String.t(), String.t() | nil) :: t()
  def new(field, pattern, name \\ nil) do
    %__MODULE__{field: field, pattern: pattern, name: name}
  end

  @doc """
  Validate a header_regexp matcher.

  ## Examples

      iex> HeaderRegexp.validate(%HeaderRegexp{field: "Auth", pattern: "^Bearer"})
      {:ok, %HeaderRegexp{field: "Auth", pattern: "^Bearer"}}

      iex> HeaderRegexp.validate(%HeaderRegexp{field: "", pattern: "test"})
      {:error, "field cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{field: field, pattern: pattern} = matcher) do
    cond do
      field == "" or field == nil ->
        {:error, "field cannot be empty"}

      pattern == "" or pattern == nil ->
        {:error, "pattern cannot be empty"}

      not is_binary(field) ->
        {:error, "field must be a string"}

      not is_binary(pattern) ->
        {:error, "pattern must be a string"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.HeaderRegexp do
  @moduledoc """
  Caddyfile protocol implementation for HeaderRegexp matcher.
  """

  def to_caddyfile(%{field: field, pattern: pattern, name: nil}) do
    start_time = System.monotonic_time()
    result = "header_regexp #{field} #{pattern}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.HeaderRegexp,
      result_size: byte_size(result)
    })

    result
  end

  def to_caddyfile(%{field: field, pattern: pattern, name: name}) do
    start_time = System.monotonic_time()
    result = "header_regexp #{name} #{field} #{pattern}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.HeaderRegexp,
      result_size: byte_size(result)
    })

    result
  end
end
