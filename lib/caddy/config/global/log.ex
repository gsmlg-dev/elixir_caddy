defmodule Caddy.Config.Global.Log do
  @moduledoc """
  Represents a named logger configuration in Caddy global options.

  Used inside the global options block to configure logging behavior.

  ## Examples

      # Default logger to file
      log = %Log{
        output: "file /var/log/caddy/access.log",
        format: :json,
        level: :INFO
      }

      # Named logger with filtering
      admin_log = %Log{
        name: "admin",
        output: "stdout",
        format: :console,
        include: ["admin.*"]
      }

  ## Rendering

  Renders as a log block:

      log {
        output file /var/log/caddy/access.log
        format json
        level INFO
      }

  Or for named loggers:

      log admin {
        output stdout
        format console
        include admin.*
      }

  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          output: String.t() | map() | nil,
          format: atom() | map() | nil,
          level: atom() | nil,
          include: [String.t()] | nil,
          exclude: [String.t()] | nil
        }

  defstruct name: nil,
            output: nil,
            format: nil,
            level: nil,
            include: nil,
            exclude: nil

  @doc """
  Create a new log configuration with defaults.

  ## Examples

      iex> Log.new()
      %Log{}

      iex> Log.new(output: "stdout", format: :json)
      %Log{output: "stdout", format: :json}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Global.Log do
  @moduledoc """
  Caddyfile protocol implementation for Log configuration.

  Renders the log block with proper formatting.
  """

  @doc """
  Convert log configuration to Caddyfile format.

  Returns empty string if no log options are set.

  ## Examples

      iex> log = %Caddy.Config.Global.Log{output: "stdout", format: :json}
      iex> Caddy.Caddyfile.to_caddyfile(log)
      "log {\\n  output stdout\\n  format json\\n}"

      iex> log = %Caddy.Config.Global.Log{name: "admin", output: "stdout"}
      iex> Caddy.Caddyfile.to_caddyfile(log)
      "log admin {\\n  output stdout\\n}"

  """
  def to_caddyfile(log) do
    options = build_options(log)

    if Enum.empty?(options) do
      ""
    else
      options_text = Enum.map_join(options, "\n", &"  #{&1}")
      header = if log.name, do: "log #{log.name}", else: "log"
      "#{header} {\n#{options_text}\n}"
    end
  end

  defp build_options(log) do
    []
    |> maybe_add_output(log.output)
    |> maybe_add_format(log.format)
    |> maybe_add_level(log.level)
    |> maybe_add_list("include", log.include)
    |> maybe_add_list("exclude", log.exclude)
    |> Enum.reverse()
  end

  defp maybe_add_output(options, nil), do: options

  defp maybe_add_output(options, output) when is_binary(output),
    do: ["output #{output}" | options]

  defp maybe_add_output(options, output) when is_map(output) do
    # For complex output configurations, render as nested block
    # This is a simplified version; can be expanded for more complex cases
    ["output #{inspect(output)}" | options]
  end

  defp maybe_add_format(options, nil), do: options
  defp maybe_add_format(options, format) when is_atom(format), do: ["format #{format}" | options]

  defp maybe_add_format(options, format) when is_map(format) do
    ["format #{inspect(format)}" | options]
  end

  defp maybe_add_level(options, nil), do: options
  defp maybe_add_level(options, level), do: ["level #{level}" | options]

  defp maybe_add_list(options, _key, nil), do: options
  defp maybe_add_list(options, _key, []), do: options

  defp maybe_add_list(options, key, values) when is_list(values) do
    ["#{key} #{Enum.join(values, " ")}" | options]
  end
end
