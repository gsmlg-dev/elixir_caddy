defmodule Caddy.Config.Global.Timeouts do
  @moduledoc """
  Represents server timeout configuration within a Caddy server block.

  Used inside `servers { }` block to configure various timeout values.

  ## Examples

      timeouts = %Timeouts{
        read_body: "10s",
        read_header: "5s",
        write: "30s",
        idle: "2m"
      }

  ## Rendering

  Renders as a nested block within server configuration:

      timeouts {
        read_body 10s
        read_header 5s
        write 30s
        idle 2m
      }

  """

  @type t :: %__MODULE__{
          read_body: String.t() | nil,
          read_header: String.t() | nil,
          write: String.t() | nil,
          idle: String.t() | nil
        }

  defstruct read_body: nil,
            read_header: nil,
            write: nil,
            idle: nil

  @doc """
  Create a new timeouts configuration with defaults.

  ## Examples

      iex> Timeouts.new()
      %Timeouts{}

      iex> Timeouts.new(read_body: "10s", idle: "2m")
      %Timeouts{read_body: "10s", idle: "2m"}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Global.Timeouts do
  @moduledoc """
  Caddyfile protocol implementation for Timeouts configuration.

  Renders the timeouts block with proper formatting.
  """

  @doc """
  Convert timeouts configuration to Caddyfile format.

  Returns empty string if no timeout options are set.

  ## Examples

      iex> timeouts = %Caddy.Config.Global.Timeouts{read_body: "10s"}
      iex> Caddy.Caddyfile.to_caddyfile(timeouts)
      "timeouts {\\n  read_body 10s\\n}"

      iex> timeouts = %Caddy.Config.Global.Timeouts{}
      iex> Caddy.Caddyfile.to_caddyfile(timeouts)
      ""

  """
  def to_caddyfile(timeouts) do
    options = build_options(timeouts)

    if Enum.empty?(options) do
      ""
    else
      options_text = Enum.map_join(options, "\n", &"  #{&1}")
      "timeouts {\n#{options_text}\n}"
    end
  end

  defp build_options(timeouts) do
    []
    |> maybe_add("read_body", timeouts.read_body)
    |> maybe_add("read_header", timeouts.read_header)
    |> maybe_add("write", timeouts.write)
    |> maybe_add("idle", timeouts.idle)
    |> Enum.reverse()
  end

  defp maybe_add(options, _key, nil), do: options
  defp maybe_add(options, key, value), do: ["#{key} #{value}" | options]
end
