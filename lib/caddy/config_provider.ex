defmodule Caddy.ConfigProvider do
  @moduledoc """
  Agent-based configuration provider for Caddy reverse proxy server.

  Manages Caddy configuration using simple text-based Caddyfile format.
  The configuration is stored as raw Caddyfile text, keeping things simple.
  """

  use Agent

  alias Caddy.Config

  @doc "Start config agent"
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(args) do
    # Handle nested list from supervisor child spec {Module, [args]}
    args = if is_list(args) and length(args) == 1 and is_list(hd(args)), do: hd(args), else: args
    Agent.start_link(fn -> init(args) end, name: __MODULE__)
  end

  @doc "Replace current configuration"
  @spec set_config(Config.t()) :: :ok | {:error, term()}
  def set_config(%Config{} = config) do
    case Config.validate_config(config) do
      :ok ->
        start_time = System.monotonic_time()
        Agent.update(__MODULE__, fn _ -> config end)
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:set, %{duration: duration}, %{})

        :ok

      {:error, reason} ->
        Caddy.Telemetry.emit_config_change(:set_error, %{}, %{error: reason})
        {:error, reason}
    end
  end

  @doc "Get current configuration"
  @spec get_config() :: Config.t()
  def get_config do
    start_time = System.monotonic_time()
    config = Agent.get(__MODULE__, & &1)
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:get, %{duration: duration}, %{})

    config
  end

  @doc "Get config value by key"
  @spec get(atom()) :: term()
  def get(name) do
    Agent.get(__MODULE__, &Map.get(&1, name))
  end

  @doc "Set Caddy binary path"
  @spec set_bin(binary()) :: :ok | {:error, binary()}
  def set_bin(caddy_bin) do
    case Config.validate_bin(caddy_bin) do
      :ok ->
        Agent.update(__MODULE__, &%{&1 | bin: caddy_bin})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Set binary path and restart server"
  @spec set_bin!(binary()) :: :ok | {:error, term()}
  def set_bin!(caddy_bin) do
    Agent.update(__MODULE__, &%{&1 | bin: caddy_bin})
    Caddy.Supervisor.restart_server()
  end

  # ============================================================================
  # Global Options
  # ============================================================================

  @doc "Set global options content (without braces)"
  @spec set_global(binary()) :: :ok
  def set_global(content) when is_binary(content) do
    Agent.update(__MODULE__, &%{&1 | global: content})
  end

  @doc "Get global options content"
  @spec get_global() :: binary()
  def get_global do
    Agent.get(__MODULE__, & &1.global)
  end

  # ============================================================================
  # Additionals Management (snippets, matchers, etc.)
  # ============================================================================

  @doc "Add an additional (snippet, matcher, etc.)"
  @spec add_additional(binary(), binary()) :: :ok
  def add_additional(name, content) when is_binary(name) and is_binary(content) do
    Agent.update(__MODULE__, fn state ->
      new_item = %{name: name, content: content}
      %{state | additionals: state.additionals ++ [new_item]}
    end)
  end

  @doc "Update an existing additional by name, or add if not found"
  @spec update_additional(binary(), binary()) :: :ok
  def update_additional(name, content) when is_binary(name) and is_binary(content) do
    Agent.update(__MODULE__, fn state ->
      case Enum.find_index(state.additionals, &(&1.name == name)) do
        nil ->
          new_item = %{name: name, content: content}
          %{state | additionals: state.additionals ++ [new_item]}

        index ->
          new_additionals =
            List.update_at(state.additionals, index, fn item ->
              %{item | content: content}
            end)

          %{state | additionals: new_additionals}
      end
    end)
  end

  @doc "Remove an additional by name"
  @spec remove_additional(binary()) :: :ok
  def remove_additional(name) when is_binary(name) do
    Agent.update(__MODULE__, fn state ->
      new_additionals = Enum.reject(state.additionals, &(&1.name == name))
      %{state | additionals: new_additionals}
    end)
  end

  @doc "Get all additionals"
  @spec get_additionals() :: list(Config.additional())
  def get_additionals do
    Agent.get(__MODULE__, & &1.additionals)
  end

  @doc "Get an additional by name"
  @spec get_additional(binary()) :: Config.additional() | nil
  def get_additional(name) when is_binary(name) do
    Agent.get(__MODULE__, fn state ->
      Enum.find(state.additionals, &(&1.name == name))
    end)
  end

  # ============================================================================
  # Site Management
  # ============================================================================

  @doc "Add a site configuration"
  @spec add_site(binary(), binary()) :: :ok
  def add_site(address, config) when is_binary(address) and is_binary(config) do
    Agent.update(__MODULE__, fn state ->
      new_site = %{address: address, config: config}
      %{state | sites: state.sites ++ [new_site]}
    end)
  end

  @doc "Update an existing site by address, or add if not found"
  @spec update_site(binary(), binary()) :: :ok
  def update_site(address, config) when is_binary(address) and is_binary(config) do
    Agent.update(__MODULE__, fn state ->
      case Enum.find_index(state.sites, &(&1.address == address)) do
        nil ->
          new_site = %{address: address, config: config}
          %{state | sites: state.sites ++ [new_site]}

        index ->
          new_sites =
            List.update_at(state.sites, index, fn site ->
              %{site | config: config}
            end)

          %{state | sites: new_sites}
      end
    end)
  end

  @doc "Remove a site by address"
  @spec remove_site(binary()) :: :ok
  def remove_site(address) when is_binary(address) do
    Agent.update(__MODULE__, fn state ->
      new_sites = Enum.reject(state.sites, &(&1.address == address))
      %{state | sites: new_sites}
    end)
  end

  @doc "Get all sites"
  @spec get_sites() :: list(Config.site())
  def get_sites do
    Agent.get(__MODULE__, & &1.sites)
  end

  @doc "Get a site by address"
  @spec get_site(binary()) :: Config.site() | nil
  def get_site(address) when is_binary(address) do
    Agent.get(__MODULE__, fn state ->
      Enum.find(state.sites, &(&1.address == address))
    end)
  end

  # ============================================================================
  # Caddyfile (Assembled)
  # ============================================================================

  @doc """
  Set the Caddyfile content by parsing it into 3 parts.

  This provides backward compatibility - pass a complete Caddyfile text
  and it will be parsed into global, additionals, and sites components.
  """
  @spec set_caddyfile(binary()) :: :ok
  def set_caddyfile(caddyfile) when is_binary(caddyfile) do
    {global, additionals, sites} = parse_caddyfile(caddyfile)

    Agent.update(__MODULE__, fn config ->
      %{config | global: global, additionals: additionals, sites: sites}
    end)
  end

  @doc "Get the assembled Caddyfile content from 3 parts"
  @spec get_caddyfile() :: binary()
  def get_caddyfile do
    Agent.get(__MODULE__, &Config.to_caddyfile(&1))
  end

  @doc """
  Append content to the Caddyfile.

  Parses the content and merges with existing configuration.
  Site blocks are added, additionals are appended.
  """
  @spec append_caddyfile(binary()) :: :ok
  def append_caddyfile(content) when is_binary(content) do
    {_global, additionals_new, sites_new} = parse_caddyfile(content)

    Agent.update(__MODULE__, fn config ->
      # Append additionals
      new_additionals = config.additionals ++ additionals_new

      # Append sites
      new_sites = config.sites ++ sites_new

      %{config | additionals: new_additionals, sites: new_sites}
    end)
  end

  # ============================================================================
  # Caddyfile Parser
  # ============================================================================

  @doc """
  Parse a Caddyfile text into its 3 components.

  Returns `{global, additionals, sites}` tuple where additionals is a list of
  `%{name: name, content: content}` maps.
  """
  @spec parse_caddyfile(binary()) :: {binary(), list(Config.additional()), list(Config.site())}
  def parse_caddyfile(caddyfile) when is_binary(caddyfile) do
    caddyfile = String.trim(caddyfile)

    if caddyfile == "" do
      {"", [], []}
    else
      do_parse_caddyfile(caddyfile)
    end
  end

  defp do_parse_caddyfile(caddyfile) do
    # Split into blocks, handling nested braces
    blocks = split_into_blocks(caddyfile)

    # Categorize blocks
    {global, additionals, sites, _counter} =
      Enum.reduce(blocks, {"", [], [], 1}, fn block, {global, additionals, sites, counter} ->
        block = String.trim(block)

        cond do
          # Global block starts with just {
          String.starts_with?(block, "{") and not has_address_prefix?(block) ->
            content = extract_block_content(block)
            {content, additionals, sites, counter}

          # Named snippet like (name) { ... }
          Regex.match?(~r/^\(([^)]+)\)\s*\{/, block) ->
            name = extract_snippet_name(block)
            item = %{name: name, content: block}
            {global, additionals ++ [item], sites, counter + 1}

          # Site block: address { ... }
          site_block?(block) ->
            {address, config} = parse_site_block(block)
            {global, additionals, sites ++ [%{address: address, config: config}], counter}

          # Other content (comments, standalone directives, etc.)
          String.trim(block) != "" ->
            name = "additional_#{counter}"
            item = %{name: name, content: block}
            {global, additionals ++ [item], sites, counter + 1}

          true ->
            {global, additionals, sites, counter}
        end
      end)

    {global, additionals, sites}
  end

  defp extract_snippet_name(block) do
    case Regex.run(~r/^\(([^)]+)\)/, block) do
      [_, name] -> name
      _ -> "snippet"
    end
  end

  defp has_address_prefix?(block) do
    # Check if block starts with an address before the opening brace
    case Regex.run(~r/^([^\s{]+)\s*\{/, block) do
      [_, _address] -> true
      _ -> false
    end
  end

  defp site_block?(block) do
    # A site block has an address followed by { ... }
    Regex.match?(~r/^[^\s(]+(\s+[^\s{]+)*\s*\{/, block) and
      not Regex.match?(~r/^\([^)]+\)\s*\{/, block)
  end

  defp parse_site_block(block) do
    case Regex.run(~r/^(.+?)\s*\{(.*)\}$/s, block) do
      [_, address, content] ->
        {String.trim(address), unindent_content(content)}

      _ ->
        # Fallback for edge cases
        {block, ""}
    end
  end

  defp extract_block_content(block) do
    case Regex.run(~r/^\{(.*)\}$/s, block) do
      [_, content] -> unindent_content(content)
      _ -> ""
    end
  end

  defp unindent_content(content) do
    content
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&String.trim_leading(&1, " \t"))
    |> Enum.map(&String.trim_leading(&1, "\t"))
    |> Enum.join("\n")
    |> String.trim()
  end

  defp split_into_blocks(caddyfile) do
    # Simple block splitter that respects brace nesting
    chars = String.graphemes(caddyfile)
    do_split_blocks(chars, 0, "", [])
  end

  defp do_split_blocks([], _depth, current, blocks) do
    current = String.trim(current)
    if current != "", do: blocks ++ [current], else: blocks
  end

  defp do_split_blocks(["{" | rest], depth, current, blocks) do
    do_split_blocks(rest, depth + 1, current <> "{", blocks)
  end

  defp do_split_blocks(["}" | rest], depth, current, blocks) when depth > 1 do
    do_split_blocks(rest, depth - 1, current <> "}", blocks)
  end

  defp do_split_blocks(["}" | rest], 1, current, blocks) do
    # End of a block
    block = String.trim(current <> "}")
    blocks = if block != "", do: blocks ++ [block], else: blocks
    do_split_blocks(rest, 0, "", blocks)
  end

  defp do_split_blocks(["\n" | rest], 0, current, blocks) do
    # At depth 0, newlines might separate blocks
    trimmed = String.trim(current)

    if trimmed != "" and not String.ends_with?(trimmed, "{") do
      # This could be a standalone directive
      do_split_blocks(rest, 0, current <> "\n", blocks)
    else
      do_split_blocks(rest, 0, current <> "\n", blocks)
    end
  end

  defp do_split_blocks([char | rest], depth, current, blocks) do
    do_split_blocks(rest, depth, current <> char, blocks)
  end

  @doc "Backup current configuration"
  @spec backup_config() :: :ok | {:error, term()}
  def backup_config do
    config = get_config()
    backup_file = Config.backup_json_file()
    start_time = System.monotonic_time()

    with :ok <- Config.ensure_dir_exists(backup_file),
         {:ok, json} <- Jason.encode(config, pretty: true),
         :ok <- File.write(backup_file, json) do
      duration = System.monotonic_time() - start_time

      Caddy.Telemetry.emit_config_change(
        :backup,
        %{duration: duration, file_size: byte_size(json)},
        %{file_path: backup_file}
      )

      :ok
    else
      error ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:backup_error, %{duration: duration}, %{
          error: inspect(error)
        })

        error
    end
  end

  @doc "Restore configuration from backup"
  @spec restore_config() :: {:ok, Config.t()} | {:error, term()}
  def restore_config do
    backup_file = Config.backup_json_file()
    start_time = System.monotonic_time()

    case load_saved_config(backup_file) do
      %{} = config_map when map_size(config_map) > 0 ->
        config = map_to_config(config_map)
        _result = set_config(config)
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:restore, %{duration: duration}, %{
          file_path: backup_file,
          success: true
        })

        {:ok, config}

      _ ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:restore_error, %{duration: duration}, %{
          file_path: backup_file,
          error: "No backup found"
        })

        {:error, :no_backup}
    end
  end

  @doc "Save current configuration"
  @spec save_config() :: :ok | {:error, term()}
  def save_config do
    config = get_config()
    start_time = System.monotonic_time()

    with :ok <- Config.ensure_dir_exists(Config.saved_json_file()),
         {:ok, json} <- Jason.encode(config, pretty: true),
         :ok <- File.write(Config.saved_json_file(), json) do
      duration = System.monotonic_time() - start_time

      Caddy.Telemetry.emit_config_change(
        :save,
        %{duration: duration, file_size: byte_size(json)},
        %{file_path: Config.saved_json_file()}
      )

      :ok
    else
      error ->
        duration = System.monotonic_time() - start_time

        Caddy.Telemetry.emit_config_change(:save_error, %{duration: duration}, %{
          error: inspect(error)
        })

        error
    end
  end

  @doc "Initialize configuration"
  @spec init(keyword()) :: Config.t()
  def init(args) do
    bin =
      cond do
        Keyword.keyword?(args) and Keyword.has_key?(args, :caddy_bin) ->
          Keyword.get(args, :caddy_bin)

        :os.type() == {:unix, :linux} ->
          "/usr/bin/caddy"

        :os.type() == {:unix, :darwin} ->
          "/opt/homebrew/bin/caddy"

        true ->
          System.find_executable("caddy")
      end

    Config.ensure_path_exists()

    base_config =
      case load_saved_config(Config.saved_json_file()) do
        %{} = saved_config when map_size(saved_config) > 0 ->
          map_to_config(saved_config)

        _ ->
          default = Config.default_config()
          %Config{default | bin: bin}
      end

    # Override bin if provided in args (args take precedence over saved config)
    config = if bin, do: %Config{base_config | bin: bin}, else: base_config

    case Config.validate_config(config) do
      :ok ->
        config

      {:error, reason} ->
        Caddy.Telemetry.log_warning("Invalid saved configuration: #{reason}, using defaults",
          module: __MODULE__,
          error: reason
        )

        default = Config.default_config()
        %Config{default | bin: bin}
    end
  end

  @doc "Convert caddyfile to JSON"
  @spec adapt(binary()) :: {:ok, map()} | {:error, term()}
  def adapt(caddyfile_text) do
    caddy_bin = get(:bin)
    Config.adapt(caddyfile_text, caddy_bin)
  end

  # Private functions

  defp load_saved_config(file_path) do
    Config.load_saved_config(file_path)
  end

  defp map_to_config(map) when is_map(map) do
    # Support old format (caddyfile), intermediate format (additional string), and new format (additionals list)
    case {Map.get(map, "caddyfile") || Map.get(map, :caddyfile),
          Map.get(map, "global") || Map.get(map, :global)} do
      {nil, nil} ->
        # Empty config
        %Config{
          bin: Map.get(map, "bin") || Map.get(map, :bin),
          global: "",
          additionals: [],
          sites: [],
          env: normalize_env(Map.get(map, "env") || Map.get(map, :env) || [])
        }

      {caddyfile, nil} when is_binary(caddyfile) ->
        # Old format - parse caddyfile into 3 parts
        {global, additionals, sites} = parse_caddyfile(caddyfile)

        %Config{
          bin: Map.get(map, "bin") || Map.get(map, :bin),
          global: global,
          additionals: additionals,
          sites: sites,
          env: normalize_env(Map.get(map, "env") || Map.get(map, :env) || [])
        }

      _ ->
        # New format - check for additionals list or additional string
        additionals =
          normalize_additionals(
            Map.get(map, "additionals") || Map.get(map, :additionals) ||
              Map.get(map, "additional") || Map.get(map, :additional) || []
          )

        %Config{
          bin: Map.get(map, "bin") || Map.get(map, :bin),
          global: Map.get(map, "global") || Map.get(map, :global) || "",
          additionals: additionals,
          sites: normalize_sites(Map.get(map, "sites") || Map.get(map, :sites) || []),
          env: normalize_env(Map.get(map, "env") || Map.get(map, :env) || [])
        }
    end
  end

  defp normalize_additionals(additionals) when is_list(additionals) do
    additionals
    |> Enum.with_index(1)
    |> Enum.map(fn
      {%{"name" => name, "content" => content}, _idx} -> %{name: name, content: content}
      {%{name: _, content: _} = item, _idx} -> item
      {content, idx} when is_binary(content) -> %{name: "additional_#{idx}", content: content}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Backward compatibility: convert old string format to list
  defp normalize_additionals(additional) when is_binary(additional) do
    if String.trim(additional) == "" do
      []
    else
      [%{name: "additional_1", content: additional}]
    end
  end

  defp normalize_additionals(_), do: []

  defp normalize_sites(sites) when is_list(sites) do
    Enum.map(sites, fn
      %{"address" => addr, "config" => config} -> %{address: addr, config: config}
      %{address: _, config: _} = site -> site
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_sites(_), do: []

  defp normalize_env(env) when is_list(env) do
    Enum.map(env, fn
      [k, v] -> {k, v}
      {k, v} -> {k, v}
      other -> other
    end)
  end

  defp normalize_env(_), do: []
end
