defmodule Caddy.Config.Matcher.Vars do
  @moduledoc """
  Represents a Caddy vars matcher.

  Matches requests by variable or placeholder values.

  ## Examples

      # Match custom variable
      matcher = Vars.new("{custom_var}", ["value1", "value2"])
      # Renders as: vars {custom_var} value1 value2

      # Match request variable
      matcher = Vars.new("{http.request.uri.query.debug}", ["true", "1"])
      # Renders as: vars {http.request.uri.query.debug} true 1

  ## Placeholder Syntax

  Variables use curly brace syntax: `{variable.name}`

  """

  @type t :: %__MODULE__{
          variable: String.t(),
          values: [String.t()]
        }

  defstruct [:variable, values: []]

  @doc """
  Create a new vars matcher.

  ## Parameters

    - `variable` - Variable name or placeholder
    - `values` - List of values to match against

  ## Examples

      iex> Vars.new("{debug}", ["true"])
      %Vars{variable: "{debug}", values: ["true"]}

      iex> Vars.new("{level}", ["1", "2", "3"])
      %Vars{variable: "{level}", values: ["1", "2", "3"]}

  """
  @spec new(String.t(), [String.t()]) :: t()
  def new(variable, values) when is_binary(variable) and is_list(values) do
    %__MODULE__{variable: variable, values: values}
  end

  @doc """
  Validate a vars matcher.

  ## Examples

      iex> Vars.validate(%Vars{variable: "{debug}", values: ["true"]})
      {:ok, %Vars{variable: "{debug}", values: ["true"]}}

      iex> Vars.validate(%Vars{variable: "", values: ["true"]})
      {:error, "variable cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{variable: variable, values: values} = matcher) do
    cond do
      variable == "" or variable == nil ->
        {:error, "variable cannot be empty"}

      values == [] ->
        {:error, "values cannot be empty"}

      not is_binary(variable) ->
        {:error, "variable must be a string"}

      not Enum.all?(values, &is_binary/1) ->
        {:error, "all values must be strings"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Vars do
  @moduledoc """
  Caddyfile protocol implementation for Vars matcher.
  """

  def to_caddyfile(%{variable: variable, values: values}) do
    start_time = System.monotonic_time()
    result = "vars #{variable} #{Enum.join(values, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Vars,
      result_size: byte_size(result)
    })

    result
  end
end
