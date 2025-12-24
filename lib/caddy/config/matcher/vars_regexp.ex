defmodule Caddy.Config.Matcher.VarsRegexp do
  @moduledoc """
  Represents a Caddy vars_regexp matcher.

  Matches requests by variable values using RE2 regular expressions.

  ## Examples

      # Match variable with regex
      matcher = VarsRegexp.new("{custom_var}", "^prefix")
      # Renders as: vars_regexp {custom_var} ^prefix

      # Named capture
      matcher = VarsRegexp.new("{http.request.uri}", "^/api/v([0-9]+)", "version")
      # Renders as: vars_regexp version {http.request.uri} ^/api/v([0-9]+)

  ## Captured Values

  Named captures can be accessed via placeholders like `{re.name.group}`.

  """

  @type t :: %__MODULE__{
          variable: String.t(),
          pattern: String.t(),
          name: String.t() | nil
        }

  defstruct [:variable, :pattern, name: nil]

  @doc """
  Create a new vars_regexp matcher.

  ## Parameters

    - `variable` - Variable name or placeholder
    - `pattern` - RE2 regular expression pattern
    - `name` - Optional capture name for referencing matches

  ## Examples

      iex> VarsRegexp.new("{debug}", "^(true|1)$")
      %VarsRegexp{variable: "{debug}", pattern: "^(true|1)$", name: nil}

      iex> VarsRegexp.new("{path}", "^/v([0-9]+)", "version")
      %VarsRegexp{variable: "{path}", pattern: "^/v([0-9]+)", name: "version"}

  """
  @spec new(String.t(), String.t(), String.t() | nil) :: t()
  def new(variable, pattern, name \\ nil) do
    %__MODULE__{variable: variable, pattern: pattern, name: name}
  end

  @doc """
  Validate a vars_regexp matcher.

  ## Examples

      iex> VarsRegexp.validate(%VarsRegexp{variable: "{x}", pattern: "^test"})
      {:ok, %VarsRegexp{variable: "{x}", pattern: "^test"}}

      iex> VarsRegexp.validate(%VarsRegexp{variable: "", pattern: "test"})
      {:error, "variable cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{variable: variable, pattern: pattern} = matcher) do
    cond do
      variable == "" or variable == nil ->
        {:error, "variable cannot be empty"}

      pattern == "" or pattern == nil ->
        {:error, "pattern cannot be empty"}

      not is_binary(variable) ->
        {:error, "variable must be a string"}

      not is_binary(pattern) ->
        {:error, "pattern must be a string"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.VarsRegexp do
  @moduledoc """
  Caddyfile protocol implementation for VarsRegexp matcher.
  """

  def to_caddyfile(%{variable: variable, pattern: pattern, name: nil}) do
    start_time = System.monotonic_time()
    result = "vars_regexp #{variable} #{pattern}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.VarsRegexp,
      result_size: byte_size(result)
    })

    result
  end

  def to_caddyfile(%{variable: variable, pattern: pattern, name: name}) do
    start_time = System.monotonic_time()
    result = "vars_regexp #{name} #{variable} #{pattern}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.VarsRegexp,
      result_size: byte_size(result)
    })

    result
  end
end
