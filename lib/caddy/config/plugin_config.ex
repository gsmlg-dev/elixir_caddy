defmodule Caddy.Config.PluginConfig do
  @moduledoc """
  Represents a Caddy plugin configuration block.

  Plugin configurations allow configuring third-party or standard Caddy
  plugins with their specific options.

  ## Examples

      # Simple plugin configuration
      plugin = PluginConfig.new("crowdsec", %{
        api_url: "http://localhost:8080",
        api_key: "your-api-key"
      })

      # Plugin with nested configuration
      plugin = PluginConfig.new("rate_limit", %{
        zone: "myzone",
        rate: "10r/s",
        burst: 20
      })

  ## Common Plugins

  - `crowdsec` - Security bouncer
  - `rate_limit` - Request rate limiting
  - `cache` - Response caching
  - `transform` - Request/response transformation
  - `dns` - DNS providers for ACME challenges

  """

  @type t :: %__MODULE__{
          name: String.t(),
          config: map()
        }

  defstruct [:name, config: %{}]

  @doc """
  Create a new plugin configuration.

  ## Parameters

    - `name` - Plugin name
    - `config` - Map of configuration options

  ## Examples

      iex> PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      %PluginConfig{name: "crowdsec", config: %{api_url: "http://localhost:8080"}}

  """
  @spec new(String.t(), map()) :: t()
  def new(name, config \\ %{}) when is_binary(name) and is_map(config) do
    %__MODULE__{name: name, config: config}
  end

  @doc """
  Validate a plugin configuration.

  ## Examples

      iex> PluginConfig.validate(%PluginConfig{name: "crowdsec", config: %{}})
      {:ok, %PluginConfig{name: "crowdsec", config: %{}}}

      iex> PluginConfig.validate(%PluginConfig{name: "", config: %{}})
      {:error, "name cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{name: name, config: config} = plugin) do
    cond do
      name == "" or name == nil ->
        {:error, "name cannot be empty"}

      not is_binary(name) ->
        {:error, "name must be a string"}

      not valid_name?(name) ->
        {:error, "name must contain only alphanumeric characters, underscores, and hyphens"}

      not is_map(config) ->
        {:error, "config must be a map"}

      true ->
        {:ok, plugin}
    end
  end

  @doc """
  Check if a string is a valid plugin name.

  Valid names contain only alphanumeric characters, underscores, and hyphens.

  ## Examples

      iex> PluginConfig.valid_name?("crowdsec")
      true

      iex> PluginConfig.valid_name?("rate-limit")
      true

      iex> PluginConfig.valid_name?("plugin name")
      false

  """
  @spec valid_name?(String.t()) :: boolean()
  def valid_name?(name) when is_binary(name) do
    Regex.match?(~r/^[A-Za-z0-9_-]+$/, name)
  end

  def valid_name?(_), do: false

  @doc """
  Merge additional configuration into an existing plugin config.

  ## Examples

      iex> plugin = PluginConfig.new("crowdsec", %{api_url: "http://localhost:8080"})
      iex> PluginConfig.merge(plugin, %{api_key: "secret"})
      %PluginConfig{name: "crowdsec", config: %{api_url: "http://localhost:8080", api_key: "secret"}}

  """
  @spec merge(t(), map()) :: t()
  def merge(%__MODULE__{config: existing} = plugin, additional) when is_map(additional) do
    %{plugin | config: Map.merge(existing, additional)}
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.PluginConfig do
  @moduledoc """
  Caddyfile protocol implementation for PluginConfig.
  """

  def to_caddyfile(%{name: name, config: config}) when map_size(config) == 0 do
    start_time = System.monotonic_time()
    result = name
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.PluginConfig,
      result_size: byte_size(result)
    })

    result
  end

  def to_caddyfile(%{name: name, config: config}) do
    start_time = System.monotonic_time()

    options =
      config
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join("\n", fn opt -> "  #{format_option(opt)}" end)

    result = "#{name} {\n#{options}\n}"
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.PluginConfig,
      result_size: byte_size(result)
    })

    result
  end

  defp format_option({key, value}) when is_binary(value) do
    key_str = to_string(key)

    if String.contains?(value, " ") do
      "#{key_str} \"#{value}\""
    else
      "#{key_str} #{value}"
    end
  end

  defp format_option({key, value}) when is_integer(value) or is_float(value) do
    "#{to_string(key)} #{value}"
  end

  defp format_option({key, true}) do
    to_string(key)
  end

  defp format_option({key, false}) do
    "#{to_string(key)} off"
  end

  defp format_option({key, value}) when is_atom(value) do
    "#{to_string(key)} #{to_string(value)}"
  end

  defp format_option({key, values}) when is_list(values) do
    formatted = Enum.map_join(values, " ", &to_string/1)
    "#{to_string(key)} #{formatted}"
  end

  defp format_option({key, value}) when is_map(value) do
    # Nested map - render as block
    nested =
      value
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join("\n", fn {k, v} -> "    #{to_string(k)} #{format_value(v)}" end)

    "#{to_string(key)} {\n#{nested}\n  }"
  end

  defp format_value(value) when is_binary(value) do
    if String.contains?(value, " "), do: "\"#{value}\"", else: value
  end

  defp format_value(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp format_value(true), do: "on"
  defp format_value(false), do: "off"
  defp format_value(value) when is_atom(value), do: to_string(value)

  defp format_value(value) when is_list(value), do: Enum.map_join(value, " ", &to_string/1)
end
