defmodule Caddy.Config.EnvVar do
  @moduledoc """
  Represents a Caddy environment variable placeholder.

  Environment variables in Caddy use `{$VAR}` or `{$VAR:default}` syntax.

  ## Examples

      # Simple environment variable
      env = EnvVar.new("DATABASE_URL")
      # Renders as: {$DATABASE_URL}

      # With default value
      env = EnvVar.new("PORT", "8080")
      # Renders as: {$PORT:8080}

      # In configuration
      port_env = EnvVar.new("APP_PORT", "3000")
      site_address = "localhost:\#{Caddyfile.to_caddyfile(port_env)}"
      # Results in: localhost:{$APP_PORT:3000}

  ## Usage

  Environment variables are resolved by Caddy at runtime from the process
  environment. When a default value is provided, Caddy uses that value
  if the variable is not set.

  """

  @type t :: %__MODULE__{
          name: String.t(),
          default: String.t() | nil
        }

  defstruct [:name, default: nil]

  @doc """
  Create a new environment variable placeholder.

  ## Parameters

    - `name` - Environment variable name (without `$`)
    - `default` - Optional default value if variable is unset

  ## Examples

      iex> EnvVar.new("DATABASE_URL")
      %EnvVar{name: "DATABASE_URL", default: nil}

      iex> EnvVar.new("PORT", "8080")
      %EnvVar{name: "PORT", default: "8080"}

  """
  @spec new(String.t(), String.t() | nil) :: t()
  def new(name, default \\ nil) when is_binary(name) do
    %__MODULE__{name: name, default: default}
  end

  @doc """
  Validate an environment variable.

  ## Examples

      iex> EnvVar.validate(%EnvVar{name: "PORT"})
      {:ok, %EnvVar{name: "PORT"}}

      iex> EnvVar.validate(%EnvVar{name: ""})
      {:error, "name cannot be empty"}

      iex> EnvVar.validate(%EnvVar{name: "INVALID-NAME"})
      {:error, "name must contain only alphanumeric characters and underscores"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{name: name, default: default} = env_var) do
    cond do
      name == "" or name == nil ->
        {:error, "name cannot be empty"}

      not is_binary(name) ->
        {:error, "name must be a string"}

      not valid_name?(name) ->
        {:error, "name must contain only alphanumeric characters and underscores"}

      default != nil and not is_binary(default) ->
        {:error, "default must be a string or nil"}

      true ->
        {:ok, env_var}
    end
  end

  @doc """
  Check if a string is a valid environment variable name.

  Valid names contain only alphanumeric characters and underscores,
  and cannot start with a digit.

  ## Examples

      iex> EnvVar.valid_name?("DATABASE_URL")
      true

      iex> EnvVar.valid_name?("my-var")
      false

  """
  @spec valid_name?(String.t()) :: boolean()
  def valid_name?(name) when is_binary(name) do
    Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_]*$/, name)
  end

  def valid_name?(_), do: false
end

defimpl Caddy.Caddyfile, for: Caddy.Config.EnvVar do
  @moduledoc """
  Caddyfile protocol implementation for EnvVar.
  """

  def to_caddyfile(%{name: name, default: nil}) do
    start_time = System.monotonic_time()
    result = "{$#{name}}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.EnvVar,
      result_size: byte_size(result)
    })

    result
  end

  def to_caddyfile(%{name: name, default: default}) do
    start_time = System.monotonic_time()
    result = "{$#{name}:#{default}}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.EnvVar,
      result_size: byte_size(result)
    })

    result
  end
end
