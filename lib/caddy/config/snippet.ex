defmodule Caddy.Config.Snippet do
  @moduledoc """
  Represents a reusable Caddyfile snippet.

  Snippets are named configuration blocks that can be imported into sites
  with optional arguments using `{args[0]}`, `{args[1]}`, etc.

  ## Examples

      # Define a logging snippet
      snippet = Snippet.new("log-zone", \"\"\"
      log {
        format json
        output file /srv/logs/{args[0]}/{args[1]}/access.log {
          roll_size 50mb
          roll_keep 5
          roll_keep_for 720h
        }
      }
      \"\"\")

      # Use in a site with import
      import log-zone "app" "production"

  ## Rendering

  Snippets are rendered with parentheses around the name:

      (log-zone) {
        log {
          format json
          output file /srv/logs/{args[0]}/{args[1]}/access.log {
            roll_size 50mb
            roll_keep 5
            roll_keep_for 720h
          }
        }
      }

  """

  @type t :: %__MODULE__{
          name: String.t(),
          content: String.t(),
          description: String.t() | nil
        }

  defstruct [
    :name,
    :content,
    description: nil
  ]

  @doc """
  Create a new snippet.

  ## Parameters

    - `name` - The snippet name (used in import directives)
    - `content` - The snippet content (can include `{args[n]}` placeholders)
    - `opts` - Optional keyword list with `:description`

  ## Examples

      iex> Snippet.new("cors", "header Access-Control-Allow-Origin *")
      %Snippet{name: "cors", content: "header Access-Control-Allow-Origin *"}

      iex> Snippet.new("log", "log { format json }", description: "JSON logging")
      %Snippet{name: "log", content: "log { format json }", description: "JSON logging"}

  """
  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(name, content, opts \\ []) do
    %__MODULE__{
      name: name,
      content: String.trim(content),
      description: opts[:description]
    }
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Snippet do
  @moduledoc """
  Caddyfile protocol implementation for Snippet.

  Renders a snippet as a named block with parentheses:

      (snippet-name) {
        content here
      }
  """

  @doc """
  Convert a snippet to Caddyfile format.

  ## Examples

      iex> snippet = %Caddy.Config.Snippet{name: "test", content: "respond 200"}
      iex> Caddy.Caddyfile.to_caddyfile(snippet)
      "(test) {\\n  respond 200\\n}"

  """
  def to_caddyfile(snippet) do
    content = indent(snippet.content)

    """
    (#{snippet.name}) {
    #{content}
    }
    """
    |> String.trim_trailing()
  end

  defp indent(text) do
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      # Don't indent empty lines
      if String.trim(line) == "", do: "", else: "  #{line}"
    end)
    |> Enum.join("\n")
  end
end
