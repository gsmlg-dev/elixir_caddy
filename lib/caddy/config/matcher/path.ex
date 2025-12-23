defmodule Caddy.Config.Matcher.Path do
  @moduledoc """
  Represents a Caddy path matcher.

  Matches requests by URI path using glob patterns.

  ## Examples

      # Match a single path
      matcher = Path.new(["/api/*"])
      # Renders as: path /api/*

      # Match multiple paths
      matcher = Path.new(["/api/*", "/v1/*", "/static/*"])
      # Renders as: path /api/* /v1/* /static/*

  ## Pattern Syntax

  - `*` matches any sequence within a path segment
  - `/api/*` matches `/api/users`, `/api/posts`, etc.
  - Exact paths match exactly: `/about` matches only `/about`

  """

  @type t :: %__MODULE__{
          paths: [String.t()]
        }

  defstruct paths: []

  @doc """
  Create a new path matcher.

  ## Parameters

    - `paths` - List of path patterns to match

  ## Examples

      iex> Path.new(["/api/*"])
      %Path{paths: ["/api/*"]}

      iex> Path.new(["/css/*", "/js/*", "/images/*"])
      %Path{paths: ["/css/*", "/js/*", "/images/*"]}

  """
  @spec new([String.t()]) :: t()
  def new(paths) when is_list(paths) do
    %__MODULE__{paths: paths}
  end

  @doc """
  Validate a path matcher.

  ## Examples

      iex> Path.validate(%Path{paths: ["/api/*"]})
      {:ok, %Path{paths: ["/api/*"]}}

      iex> Path.validate(%Path{paths: []})
      {:error, "paths cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{paths: paths} = matcher) do
    cond do
      paths == [] ->
        {:error, "paths cannot be empty"}

      not Enum.all?(paths, &is_binary/1) ->
        {:error, "all paths must be strings"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Path do
  @moduledoc """
  Caddyfile protocol implementation for Path matcher.
  """

  def to_caddyfile(%{paths: paths}) do
    start_time = System.monotonic_time()
    result = "path #{Enum.join(paths, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Path,
      result_size: byte_size(result)
    })

    result
  end
end
