defmodule Caddy.Config.NamedMatcher do
  @moduledoc """
  Represents a Caddy named matcher.

  Named matchers use the `@name` syntax and can contain multiple matcher
  definitions that are combined with AND logic.

  ## Examples

      # Single matcher
      alias Caddy.Config.Matcher.Path
      matcher = NamedMatcher.new("api", [Path.new(["/api/*"])])
      # Renders as:
      # @api path /api/*

      # Multiple matchers (AND logic)
      alias Caddy.Config.Matcher.{Path, Method}
      matcher = NamedMatcher.new("api_write", [
        Path.new(["/api/*"]),
        Method.new(["POST", "PUT", "DELETE"])
      ])
      # Renders as:
      # @api_write {
      #   path /api/*
      #   method POST PUT DELETE
      # }

  ## Usage in Routes

  After defining a named matcher, reference it in routes:

      @api path /api/*
      handle @api {
        reverse_proxy backend:8080
      }

  ## Supported Matcher Types

  All matcher types from `Caddy.Config.Matcher.*` are supported:
  - Path, PathRegexp
  - Header, HeaderRegexp
  - Method
  - Query
  - Host
  - Protocol
  - RemoteIp, ClientIp
  - Vars, VarsRegexp
  - Expression
  - File
  - Not

  """

  @type t :: %__MODULE__{
          name: String.t(),
          matchers: [struct()]
        }

  defstruct [:name, matchers: []]

  @doc """
  Create a new named matcher.

  ## Parameters

    - `name` - Matcher name (without `@` prefix)
    - `matchers` - List of matcher structs to combine with AND logic

  ## Examples

      alias Caddy.Config.Matcher.Path

      iex> NamedMatcher.new("api", [Path.new(["/api/*"])])
      %NamedMatcher{name: "api", matchers: [%Path{paths: ["/api/*"]}]}

  """
  @spec new(String.t(), [struct()]) :: t()
  def new(name, matchers) when is_binary(name) and is_list(matchers) do
    %__MODULE__{name: name, matchers: matchers}
  end

  @doc """
  Validate a named matcher.

  ## Examples

      alias Caddy.Config.Matcher.Path

      iex> NamedMatcher.validate(%NamedMatcher{name: "api", matchers: [%Path{paths: ["/api/*"]}]})
      {:ok, %NamedMatcher{name: "api", matchers: [%Path{paths: ["/api/*"]}]}}

      iex> NamedMatcher.validate(%NamedMatcher{name: "", matchers: []})
      {:error, "name cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{name: name, matchers: matchers} = matcher) do
    cond do
      name == "" or name == nil ->
        {:error, "name cannot be empty"}

      not is_binary(name) ->
        {:error, "name must be a string"}

      not valid_name?(name) ->
        {:error, "name must contain only alphanumeric characters, underscores, and hyphens"}

      matchers == [] ->
        {:error, "matchers cannot be empty"}

      not is_list(matchers) ->
        {:error, "matchers must be a list"}

      true ->
        {:ok, matcher}
    end
  end

  @doc """
  Check if a string is a valid matcher name.

  Valid names contain only alphanumeric characters, underscores, and hyphens.

  ## Examples

      iex> NamedMatcher.valid_name?("api_v2")
      true

      iex> NamedMatcher.valid_name?("api-v2")
      true

      iex> NamedMatcher.valid_name?("@api")
      false

  """
  @spec valid_name?(String.t()) :: boolean()
  def valid_name?(name) when is_binary(name) do
    Regex.match?(~r/^[A-Za-z0-9_-]+$/, name)
  end

  def valid_name?(_), do: false
end

defimpl Caddy.Caddyfile, for: Caddy.Config.NamedMatcher do
  @moduledoc """
  Caddyfile protocol implementation for NamedMatcher.
  """

  alias Caddy.Caddyfile

  def to_caddyfile(%{name: name, matchers: matchers}) do
    start_time = System.monotonic_time()

    result =
      if length(matchers) == 1 do
        # Single matcher - inline form
        inner = Caddyfile.to_caddyfile(hd(matchers))
        "@#{name} #{inner}"
      else
        # Multiple matchers - block form
        inner =
          matchers
          |> Enum.map_join("\n", fn m -> "  #{Caddyfile.to_caddyfile(m)}" end)

        "@#{name} {\n#{inner}\n}"
      end

    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.NamedMatcher,
      result_size: byte_size(result)
    })

    result
  end
end
