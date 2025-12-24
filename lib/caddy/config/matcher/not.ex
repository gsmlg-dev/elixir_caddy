defmodule Caddy.Config.Matcher.Not do
  @moduledoc """
  Represents a Caddy not matcher.

  Negates the result of other matchers.

  ## Examples

      # Negate single matcher
      alias Caddy.Config.Matcher.Path
      matcher = Not.new([Path.new(["/admin/*"])])
      # Renders as: not path /admin/*

      # Negate multiple matchers (all must NOT match)
      alias Caddy.Config.Matcher.{Path, Method}
      matcher = Not.new([
        Path.new(["/admin/*"]),
        Method.new(["DELETE"])
      ])
      # Renders as:
      # not {
      #   path /admin/*
      #   method DELETE
      # }

  ## Logic

  The `not` matcher negates its contained matchers. When multiple matchers
  are inside `not`, ALL must be false for the `not` to match (they are AND'ed
  before negation).

  """

  @type t :: %__MODULE__{
          matchers: [struct()]
        }

  defstruct matchers: []

  @doc """
  Create a new not matcher.

  ## Parameters

    - `matchers` - List of matchers to negate

  ## Examples

      alias Caddy.Config.Matcher.Path

      iex> Not.new([Path.new(["/admin/*"])])
      %Not{matchers: [%Path{paths: ["/admin/*"]}]}

  """
  @spec new([struct()]) :: t()
  def new(matchers) when is_list(matchers) do
    %__MODULE__{matchers: matchers}
  end

  @doc """
  Validate a not matcher.

  ## Examples

      alias Caddy.Config.Matcher.Path

      iex> Not.validate(%Not{matchers: [%Path{paths: ["/admin/*"]}]})
      {:ok, %Not{matchers: [%Path{paths: ["/admin/*"]}]}}

      iex> Not.validate(%Not{matchers: []})
      {:error, "matchers cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{matchers: matchers} = matcher) do
    cond do
      matchers == [] ->
        {:error, "matchers cannot be empty"}

      not is_list(matchers) ->
        {:error, "matchers must be a list"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Not do
  @moduledoc """
  Caddyfile protocol implementation for Not matcher.
  """

  alias Caddy.Caddyfile

  def to_caddyfile(%{matchers: matchers}) do
    start_time = System.monotonic_time()

    result =
      if length(matchers) == 1 do
        # Single matcher - inline form
        inner = Caddyfile.to_caddyfile(hd(matchers))
        "not #{inner}"
      else
        # Multiple matchers - block form
        inner =
          matchers
          |> Enum.map_join("\n", fn m -> "  #{Caddyfile.to_caddyfile(m)}" end)

        "not {\n#{inner}\n}"
      end

    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Not,
      result_size: byte_size(result)
    })

    result
  end
end
