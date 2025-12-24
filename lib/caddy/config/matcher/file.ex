defmodule Caddy.Config.Matcher.File do
  @moduledoc """
  Represents a Caddy file matcher.

  Matches requests based on file existence on disk.

  ## Examples

      # Simple file check
      matcher = File.new(try_files: ["{path}", "{path}.html"])
      # Renders as:
      # file {
      #   try_files {path} {path}.html
      # }

      # With root directory
      matcher = File.new(root: "/srv/www", try_files: ["{path}", "=404"])
      # Renders as:
      # file {
      #   root /srv/www
      #   try_files {path} =404
      # }

  ## Try Policy

  - `:first_exist` - Use first file that exists (default)
  - `:smallest_size` - Use smallest existing file
  - `:largest_size` - Use largest existing file
  - `:most_recently_modified` - Use most recently modified file

  """

  @type try_policy :: :first_exist | :smallest_size | :largest_size | :most_recently_modified

  @type t :: %__MODULE__{
          root: String.t() | nil,
          try_files: [String.t()],
          try_policy: try_policy() | nil,
          split_path: [String.t()]
        }

  defstruct root: nil,
            try_files: [],
            try_policy: nil,
            split_path: []

  @doc """
  Create a new file matcher.

  ## Parameters

    - `opts` - Keyword list with `:root`, `:try_files`, `:try_policy`, `:split_path`

  ## Examples

      iex> File.new(try_files: ["{path}"])
      %File{try_files: ["{path}"]}

      iex> File.new(root: "/srv", try_files: ["{path}"], try_policy: :smallest_size)
      %File{root: "/srv", try_files: ["{path}"], try_policy: :smallest_size}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Validate a file matcher.

  ## Examples

      iex> File.validate(%File{try_files: ["{path}"]})
      {:ok, %File{try_files: ["{path}"]}}

      iex> File.validate(%File{try_files: []})
      {:error, "try_files cannot be empty"}

  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{try_files: try_files, try_policy: try_policy} = matcher) do
    valid_policies = [:first_exist, :smallest_size, :largest_size, :most_recently_modified, nil]

    cond do
      try_files == [] ->
        {:error, "try_files cannot be empty"}

      not Enum.all?(try_files, &is_binary/1) ->
        {:error, "all try_files must be strings"}

      try_policy not in valid_policies ->
        {:error, "invalid try_policy: #{inspect(try_policy)}"}

      true ->
        {:ok, matcher}
    end
  end
end

defimpl Caddy.Caddyfile, for: Caddy.Config.Matcher.File do
  @moduledoc """
  Caddyfile protocol implementation for File matcher.
  """

  def to_caddyfile(file) do
    start_time = System.monotonic_time()
    lines = build_lines(file)

    result =
      if length(lines) == 1 do
        "file #{hd(lines)}"
      else
        inner = Enum.map_join(lines, "\n", &"  #{&1}")

        "file {\n#{inner}\n}"
      end

    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Matcher.File,
      result_size: byte_size(result)
    })

    result
  end

  defp build_lines(file) do
    lines = []

    lines =
      if file.root do
        ["root #{file.root}" | lines]
      else
        lines
      end

    lines =
      if file.try_files != [] do
        ["try_files #{Enum.join(file.try_files, " ")}" | lines]
      else
        lines
      end

    lines =
      if file.try_policy do
        policy_str = Atom.to_string(file.try_policy)
        ["try_policy #{policy_str}" | lines]
      else
        lines
      end

    lines =
      if file.split_path != [] do
        ["split_path #{Enum.join(file.split_path, " ")}" | lines]
      else
        lines
      end

    Enum.reverse(lines)
  end
end
