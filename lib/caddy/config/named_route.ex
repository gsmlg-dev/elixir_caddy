defmodule Caddy.Config.NamedRoute do
  @moduledoc """
  Represents a Caddy named route.

  Named routes use the `&(name)` syntax and can be invoked from multiple
  places in the configuration to reuse route definitions.

  ## Examples

      # Define a named route
      route = NamedRoute.new("common_headers", \"\"\"
        header Cache-Control "public, max-age=3600"
        header X-Frame-Options DENY
      \"\"\")
      # Renders as:
      # &(common_headers) {
      #   header Cache-Control "public, max-age=3600"
      #   header X-Frame-Options DENY
      # }

      # Invoke the named route
      # invoke &(common_headers)

  ## Usage

  Named routes are defined once and can be invoked multiple times
  using the `invoke` directive. This helps reduce configuration
  duplication.

  """

  @type t :: %__MODULE__{
          name: String.t(),
          directives: String.t()
        }

  defstruct [:name, :directives]

  @doc """
  Create a new named route.

  ## Parameters

    - `name` - Route name (without `&()` syntax)
    - `directives` - Caddyfile directives as a string

  ## Examples

      iex> NamedRoute.new("error_handler", "respond 500")
      %NamedRoute{name: "error_handler", directives: "respond 500"}

  """
  @spec new(String.t(), String.t()) :: t()
  def new(name, directives) when is_binary(name) and is_binary(directives) do
    %__MODULE__{name: name, directives: directives}
  end

  @doc """
  Validate a named route.

  ## Examples

      iex> NamedRoute.validate(%NamedRoute{name: "my_route", directives: "respond 200"})
      {:ok, %NamedRoute{name: "my_route", directives: "respond 200"}}

      iex> NamedRoute.validate(%NamedRoute{name: "", directives: "respond 200"})
      {:error, "name cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{name: name, directives: directives} = route) do
    cond do
      name == "" or name == nil ->
        {:error, "name cannot be empty"}

      not is_binary(name) ->
        {:error, "name must be a string"}

      not valid_name?(name) ->
        {:error, "name must contain only alphanumeric characters, underscores, and hyphens"}

      directives == "" or directives == nil ->
        {:error, "directives cannot be empty"}

      not is_binary(directives) ->
        {:error, "directives must be a string"}

      true ->
        {:ok, route}
    end
  end

  @doc """
  Check if a string is a valid route name.

  Valid names contain only alphanumeric characters, underscores, and hyphens.

  ## Examples

      iex> NamedRoute.valid_name?("my_route")
      true

      iex> NamedRoute.valid_name?("my-route")
      true

      iex> NamedRoute.valid_name?("my route")
      false

  """
  @spec valid_name?(String.t()) :: boolean()
  def valid_name?(name) when is_binary(name) do
    Regex.match?(~r/^[A-Za-z0-9_-]+$/, name)
  end

  def valid_name?(_), do: false

  @doc """
  Generate an invoke directive for this named route.

  ## Examples

      iex> route = NamedRoute.new("common_headers", "header X-Test true")
      iex> NamedRoute.invoke(route)
      "invoke &(common_headers)"

  """
  @spec invoke(t()) :: String.t()
  def invoke(%__MODULE__{name: name}) do
    "invoke &(#{name})"
  end

  @doc """
  Generate an invoke directive for a route by name.

  ## Examples

      iex> NamedRoute.invoke_by_name("common_headers")
      "invoke &(common_headers)"

  """
  @spec invoke_by_name(String.t()) :: String.t()
  def invoke_by_name(name) when is_binary(name) do
    "invoke &(#{name})"
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.NamedRoute do
  @moduledoc """
  Caddyfile protocol implementation for NamedRoute.
  """

  def to_caddyfile(%{name: name, directives: directives}) do
    start_time = System.monotonic_time()

    # Indent each line of directives
    indented =
      directives
      |> String.trim()
      |> String.split("\n")
      |> Enum.map_join("\n", &"  #{String.trim(&1)}")

    result = "&(#{name}) {\n#{indented}\n}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.NamedRoute,
      result_size: byte_size(result)
    })

    result
  end
end
