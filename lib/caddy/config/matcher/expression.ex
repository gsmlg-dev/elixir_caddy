defmodule Caddy.Config.Matcher.Expression do
  @moduledoc """
  Represents a Caddy expression matcher.

  Matches requests using CEL (Common Expression Language) expressions.

  ## Examples

      # Match POST/PUT/PATCH methods
      matcher = Expression.new("{method}.startsWith(\"P\")")
      # Renders as: expression {method}.startsWith("P")

      # Complex condition
      matcher = Expression.new("{path}.startsWith(\"/api\") && {method} == \"GET\"")
      # Renders as: expression {path}.startsWith("/api") && {method} == "GET"

  ## CEL Syntax

  CEL expressions can use Caddy placeholders and support:
  - String operations: `.startsWith()`, `.endsWith()`, `.contains()`
  - Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
  - Logical operators: `&&`, `||`, `!`

  """

  @type t :: %__MODULE__{
          expression: String.t()
        }

  defstruct [:expression]

  @doc """
  Create a new expression matcher.

  ## Parameters

    - `expression` - CEL expression string

  ## Examples

      iex> Expression.new("{method} == \"GET\"")
      %Expression{expression: "{method} == \"GET\""}

      iex> Expression.new("{path}.startsWith(\"/api\")")
      %Expression{expression: "{path}.startsWith(\"/api\")"}

  """
  @spec new(String.t()) :: t()
  def new(expression) when is_binary(expression) do
    %__MODULE__{expression: expression}
  end

  @doc """
  Validate an expression matcher.

  ## Examples

      iex> Expression.validate(%Expression{expression: "{x} == 1"})
      {:ok, %Expression{expression: "{x} == 1"}}

      iex> Expression.validate(%Expression{expression: ""})
      {:error, "expression cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{expression: expression} = matcher) do
    cond do
      expression == "" or expression == nil ->
        {:error, "expression cannot be empty"}

      not is_binary(expression) ->
        {:error, "expression must be a string"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Expression do
  @moduledoc """
  Caddyfile protocol implementation for Expression matcher.
  """

  def to_caddyfile(%{expression: expression}) do
    start_time = System.monotonic_time()
    result = "expression #{expression}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Expression,
      result_size: byte_size(result)
    })

    result
  end
end
