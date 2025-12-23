defmodule Caddy.Config.Matcher.PathRegexp do
  @moduledoc """
  Represents a Caddy path_regexp matcher.

  Matches requests by URI path using RE2 regular expressions.

  ## Examples

      # Simple pattern
      matcher = PathRegexp.new("^/api/v[0-9]+")
      # Renders as: path_regexp ^/api/v[0-9]+

      # Named capture
      matcher = PathRegexp.new("^/users/([0-9]+)", "user_id")
      # Renders as: path_regexp user_id ^/users/([0-9]+)

  ## Captured Values

  Named captures can be accessed via placeholders like `{re.name.group}`.

  """

  @type t :: %__MODULE__{
          pattern: String.t(),
          name: String.t() | nil
        }

  defstruct [:pattern, name: nil]

  @doc """
  Create a new path_regexp matcher.

  ## Parameters

    - `pattern` - RE2 regular expression pattern
    - `name` - Optional capture name for referencing matches

  ## Examples

      iex> PathRegexp.new("^/api/v[0-9]+")
      %PathRegexp{pattern: "^/api/v[0-9]+", name: nil}

      iex> PathRegexp.new("^/users/([0-9]+)", "user_id")
      %PathRegexp{pattern: "^/users/([0-9]+)", name: "user_id"}

  """
  @spec new(String.t(), String.t() | nil) :: t()
  def new(pattern, name \\ nil) do
    %__MODULE__{pattern: pattern, name: name}
  end

  @doc """
  Validate a path_regexp matcher.

  ## Examples

      iex> PathRegexp.validate(%PathRegexp{pattern: "^/api"})
      {:ok, %PathRegexp{pattern: "^/api"}}

      iex> PathRegexp.validate(%PathRegexp{pattern: ""})
      {:error, "pattern cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{pattern: pattern} = matcher) do
    cond do
      pattern == "" or pattern == nil ->
        {:error, "pattern cannot be empty"}

      not is_binary(pattern) ->
        {:error, "pattern must be a string"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.PathRegexp do
  @moduledoc """
  Caddyfile protocol implementation for PathRegexp matcher.
  """

  def to_caddyfile(%{pattern: pattern, name: nil}) do
    start_time = System.monotonic_time()
    result = "path_regexp #{pattern}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.PathRegexp,
      result_size: byte_size(result)
    })

    result
  end

  def to_caddyfile(%{pattern: pattern, name: name}) do
    start_time = System.monotonic_time()
    result = "path_regexp #{name} #{pattern}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.PathRegexp,
      result_size: byte_size(result)
    })

    result
  end
end
