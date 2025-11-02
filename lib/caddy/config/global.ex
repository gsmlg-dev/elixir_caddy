defmodule Caddy.Config.Global do
  @moduledoc """
  Represents Caddy global configuration block.

  The global options block is the first configuration block in a Caddyfile,
  and is used to set options that apply globally (or not specific to any one site).

  ## Examples

      global = %Global{
        admin: "unix//var/run/caddy.sock",
        debug: true,
        email: "admin@example.com"
      }

  ## Rendering

  Renders as a block wrapped in curly braces:

      {
        debug
        admin unix//var/run/caddy.sock
        email admin@example.com
      }

  """

  @type t :: %__MODULE__{
          admin: String.t() | :off | nil,
          debug: boolean(),
          email: String.t() | nil,
          acme_ca: String.t() | nil,
          storage: String.t() | nil,
          extra_options: [String.t()]
        }

  defstruct [
    admin: nil,
    debug: false,
    email: nil,
    acme_ca: nil,
    storage: nil,
    extra_options: []
  ]

  @doc """
  Create a new global configuration with defaults.

  ## Examples

      iex> Global.new()
      %Global{debug: false, extra_options: []}

      iex> Global.new(debug: true, admin: "unix//tmp/caddy.sock")
      %Global{debug: true, admin: "unix//tmp/caddy.sock"}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Global do
  @moduledoc """
  Caddyfile protocol implementation for Global configuration.

  Renders the global options block with proper formatting.
  """

  @doc """
  Convert global configuration to Caddyfile format.

  Returns empty string if no options are set.

  ## Examples

      iex> global = %Caddy.Config.Global{debug: true}
      iex> Caddy.Caddyfile.to_caddyfile(global)
      "{\\n  debug\\n}"

      iex> global = %Caddy.Config.Global{}
      iex> Caddy.Caddyfile.to_caddyfile(global)
      ""

  """
  def to_caddyfile(global) do
    options = build_options(global)

    if Enum.empty?(options) do
      ""
    else
      options_text =
        options
        |> Enum.map(&("  #{&1}"))
        |> Enum.join("\n")

      """
      {
      #{options_text}
      }
      """
      |> String.trim_trailing()
    end
  end

  defp build_options(global) do
    options = []

    # Debug flag
    options = if global.debug, do: ["debug" | options], else: options

    # Admin endpoint
    options =
      cond do
        global.admin == :off -> ["admin off" | options]
        is_binary(global.admin) -> ["admin #{global.admin}" | options]
        true -> options
      end

    # Email for ACME
    options = if global.email, do: ["email #{global.email}" | options], else: options

    # ACME CA
    options = if global.acme_ca, do: ["acme_ca #{global.acme_ca}" | options], else: options

    # Storage
    options = if global.storage, do: ["storage #{global.storage}" | options], else: options

    # Extra options (user-defined)
    options = options ++ global.extra_options

    # Reverse to maintain intuitive order (debug first, etc.)
    Enum.reverse(options)
  end
end
