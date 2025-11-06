defmodule Caddy.Config.Import do
  @moduledoc """
  Represents an import directive within a site block.

  Import directives allow reusing snippet configurations with optional arguments.

  ## Examples

      # Simple import (no arguments)
      %Import{snippet: "cors-headers"}
      # Renders as: import cors-headers

      # Import with arguments
      %Import{snippet: "log-zone", args: ["app", "production"]}
      # Renders as: import log-zone "app" "production"

      # Import from file
      %Import{path: "/etc/caddy/common.conf"}
      # Renders as: import /etc/caddy/common.conf

  ## Helper Functions

      Import.snippet("cors")
      Import.snippet("log-zone", ["app", "prod"])
      Import.file("/etc/caddy/common.conf")

  """

  @type t :: %__MODULE__{
          snippet: String.t() | nil,
          path: String.t() | nil,
          args: [String.t()]
        }

  defstruct [
    snippet: nil,
    path: nil,
    args: []
  ]

  @doc """
  Create an import directive for a snippet.

  ## Parameters

    - `name` - Snippet name to import
    - `args` - Optional list of arguments to pass to the snippet

  ## Examples

      iex> Import.snippet("cors")
      %Import{snippet: "cors", args: []}

      iex> Import.snippet("log-zone", ["app", "production"])
      %Import{snippet: "log-zone", args: ["app", "production"]}

  """
  @spec snippet(String.t(), [String.t()]) :: t()
  def snippet(name, args \\ []) do
    %__MODULE__{snippet: name, args: args}
  end

  @doc """
  Create an import directive for a file path.

  ## Parameters

    - `path` - File path to import

  ## Examples

      iex> Import.file("/etc/caddy/common.conf")
      %Import{path: "/etc/caddy/common.conf"}

  """
  @spec file(String.t()) :: t()
  def file(path) do
    %__MODULE__{path: path}
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Import do
  @moduledoc """
  Caddyfile protocol implementation for Import.

  Renders import directives:
    - `import snippet-name`
    - `import snippet-name "arg1" "arg2"`
    - `import /path/to/file`
  """

  @doc """
  Convert an import to Caddyfile format.

  ## Examples

      iex> import = %Caddy.Config.Import{snippet: "cors"}
      iex> Caddy.Caddyfile.to_caddyfile(import)
      "import cors"

      iex> import = %Caddy.Config.Import{snippet: "log", args: ["app"]}
      iex> Caddy.Caddyfile.to_caddyfile(import)
      "import log \\"app\\""

  """
  def to_caddyfile(import) do
    cond do
      import.snippet && Enum.empty?(import.args) ->
        "import #{import.snippet}"

      import.snippet && !Enum.empty?(import.args) ->
        args_str = Enum.map_join(import.args, " ", &quote_arg/1)
        "import #{import.snippet} #{args_str}"

      import.path ->
        "import #{import.path}"

      true ->
        ""
    end
  end

  defp quote_arg(arg) when is_binary(arg) do
    # Quote arguments to handle spaces and special characters
    "\"#{arg}\""
  end
end
