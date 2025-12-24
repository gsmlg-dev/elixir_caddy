defmodule Caddy.Config.Matcher.Method do
  @moduledoc """
  Represents a Caddy method matcher.

  Matches requests by HTTP method (verb).

  ## Examples

      # Match single method
      matcher = Method.new(["GET"])
      # Renders as: method GET

      # Match multiple methods
      matcher = Method.new(["GET", "POST", "PUT"])
      # Renders as: method GET POST PUT

  ## Supported Methods

  Standard HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, CONNECT, TRACE

  """

  @type t :: %__MODULE__{
          verbs: [String.t()]
        }

  defstruct verbs: []

  @doc """
  Create a new method matcher.

  ## Parameters

    - `verbs` - List of HTTP methods (should be uppercase)

  ## Examples

      iex> Method.new(["GET"])
      %Method{verbs: ["GET"]}

      iex> Method.new(["POST", "PUT", "DELETE"])
      %Method{verbs: ["POST", "PUT", "DELETE"]}

  """
  @spec new([String.t()]) :: t()
  def new(verbs) when is_list(verbs) do
    %__MODULE__{verbs: verbs}
  end

  @doc """
  Validate a method matcher.

  ## Examples

      iex> Method.validate(%Method{verbs: ["GET"]})
      {:ok, %Method{verbs: ["GET"]}}

      iex> Method.validate(%Method{verbs: []})
      {:error, "verbs cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{verbs: verbs} = matcher) do
    cond do
      verbs == [] ->
        {:error, "verbs cannot be empty"}

      not Enum.all?(verbs, &is_binary/1) ->
        {:error, "all verbs must be strings"}

      not Enum.all?(verbs, &(String.upcase(&1) == &1)) ->
        {:error, "all verbs must be uppercase"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.Method do
  @moduledoc """
  Caddyfile protocol implementation for Method matcher.
  """

  def to_caddyfile(%{verbs: verbs}) do
    start_time = System.monotonic_time()
    result = "method #{Enum.join(verbs, " ")}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.Method,
      result_size: byte_size(result)
    })

    result
  end
end
