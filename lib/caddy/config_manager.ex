defmodule Caddy.ConfigManager do
  @moduledoc """
  Unified configuration manager coordinating in-memory and runtime Caddy config.

  Provides a single interface for:
  - Reading config from both sources (in-memory ConfigProvider and runtime Admin.Api)
  - Syncing between sources (manual by default)
  - Detecting drift between sources
  - Atomic updates with rollback on failure

  ## Sources

  - `:memory` - The in-memory Caddyfile stored in `Caddy.ConfigProvider`
  - `:runtime` - The JSON config in the running Caddy process via Admin API
  - `:both` - Returns both sources for comparison

  ## Sync Strategies

  By default, sync is manual. Users explicitly call `sync_to_caddy/0` or `sync_from_caddy/0`.

  ## Examples

      # Get config from preferred source
      {:ok, config} = Caddy.ConfigManager.get_config(:memory)
      {:ok, config} = Caddy.ConfigManager.get_config(:runtime)

      # Update and sync
      :ok = Caddy.ConfigManager.set_caddyfile(new_caddyfile, sync: true)

      # Manual sync
      :ok = Caddy.ConfigManager.sync_to_caddy()
      :ok = Caddy.ConfigManager.sync_from_caddy()

      # Check for drift
      {:ok, :in_sync} = Caddy.ConfigManager.check_sync_status()
      {:ok, {:drift_detected, diff}} = Caddy.ConfigManager.check_sync_status()

      # Rollback to last known good config
      :ok = Caddy.ConfigManager.rollback()
  """

  use GenServer

  @behaviour Caddy.ConfigManager.Behaviour

  alias Caddy.Admin.Api
  alias Caddy.ConfigProvider
  alias Caddy.Telemetry

  @type source :: :memory | :runtime | :both
  @type sync_status :: :in_sync | {:drift_detected, map()}

  # ============================================================================
  # Client API
  # ============================================================================

  @doc "Start the ConfigManager GenServer"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args \\ []) do
    # Handle nested list from supervisor child spec {Module, [args]}
    args = if is_list(args) and length(args) == 1 and is_list(hd(args)), do: hd(args), else: args
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Get configuration from specified source.

  ## Sources

  - `:memory` - Returns the in-memory config as JSON (adapted from Caddyfile)
  - `:runtime` - Returns the running Caddy's JSON config
  - `:both` - Returns both configs in a map

  ## Examples

      {:ok, config} = Caddy.ConfigManager.get_config(:runtime)
      {:ok, %{memory: mem_config, runtime: rt_config}} = Caddy.ConfigManager.get_config(:both)
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec get_config(source()) :: {:ok, map()} | {:error, term()}
  def get_config(source \\ :runtime)

  def get_config(:memory) do
    get_memory_config(:json)
  end

  def get_config(:runtime) do
    get_runtime_config()
  end

  def get_config(:both) do
    with {:ok, memory_config} <- get_memory_config(:json),
         {:ok, runtime_config} <- get_runtime_config() do
      {:ok, %{memory: memory_config, runtime: runtime_config}}
    end
  end

  @doc """
  Get JSON config from running Caddy.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec get_runtime_config() :: {:ok, map()} | {:error, term()}
  def get_runtime_config do
    start_time = System.monotonic_time()

    case Api.get_config() do
      nil ->
        duration = System.monotonic_time() - start_time

        Telemetry.emit_config_manager_event(:get_runtime, %{duration: duration}, %{
          success: false,
          error: :not_available
        })

        {:error, :caddy_not_available}

      config when is_map(config) ->
        duration = System.monotonic_time() - start_time
        Telemetry.emit_config_manager_event(:get_runtime, %{duration: duration}, %{success: true})
        {:ok, config}
    end
  end

  @doc """
  Get JSON config from running Caddy at specific path.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec get_runtime_config(String.t()) :: {:ok, map()} | {:error, term()}
  def get_runtime_config(path) when is_binary(path) do
    start_time = System.monotonic_time()

    case Api.get_config(path) do
      nil ->
        duration = System.monotonic_time() - start_time

        Telemetry.emit_config_manager_event(:get_runtime, %{duration: duration}, %{
          success: false,
          path: path
        })

        {:error, :not_found}

      config ->
        duration = System.monotonic_time() - start_time

        Telemetry.emit_config_manager_event(:get_runtime, %{duration: duration}, %{
          success: true,
          path: path
        })

        {:ok, config}
    end
  end

  @doc """
  Get in-memory config in specified format.

  ## Formats

  - `:caddyfile` - Returns raw Caddyfile text
  - `:json` - Returns JSON map (adapted from Caddyfile)
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec get_memory_config(:caddyfile | :json) :: {:ok, binary() | map()} | {:error, term()}
  def get_memory_config(:caddyfile) do
    {:ok, ConfigProvider.get_caddyfile()}
  end

  def get_memory_config(:json) do
    caddyfile = ConfigProvider.get_caddyfile()

    case ConfigProvider.adapt(caddyfile) do
      {:ok, json_config} -> {:ok, json_config}
      {:error, reason} -> {:error, {:adaptation_failed, reason}}
    end
  end

  @doc """
  Set Caddyfile in memory with optional sync to Caddy.

  ## Options

  - `:sync` - If true, immediately sync to running Caddy (default: false)
  - `:validate` - If true, validate before setting (default: true)
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec set_caddyfile(binary(), keyword()) :: :ok | {:error, term()}
  def set_caddyfile(caddyfile, opts \\ []) when is_binary(caddyfile) do
    validate? = Keyword.get(opts, :validate, true)
    sync? = Keyword.get(opts, :sync, false)

    with :ok <- maybe_validate(caddyfile, validate?),
         :ok <- ConfigProvider.set_caddyfile(caddyfile),
         :ok <- maybe_sync(sync?) do
      :ok
    end
  end

  @doc """
  Push in-memory config to running Caddy.

  Adapts the Caddyfile to JSON and loads it into the running Caddy instance.

  ## Options

  - `:backup` - If true, backup current runtime config before sync (default: true)
  - `:force` - If true, skip validation (default: false)
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec sync_to_caddy() :: :ok | {:error, term()}
  def sync_to_caddy, do: sync_to_caddy([])

  @impl Caddy.ConfigManager.Behaviour
  @spec sync_to_caddy(keyword()) :: :ok | {:error, term()}
  def sync_to_caddy(opts) do
    GenServer.call(__MODULE__, {:sync_to_caddy, opts})
  end

  @doc """
  Pull running Caddy config to memory.

  Note: This stores the JSON config as-is. The in-memory format becomes JSON,
  not Caddyfile text. Use with caution as it changes the config format.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec sync_from_caddy() :: :ok | {:error, term()}
  def sync_from_caddy do
    GenServer.call(__MODULE__, :sync_from_caddy)
  end

  @doc """
  Check if in-memory and runtime configs are in sync.

  Returns `:in_sync` if configs match, or `{:drift_detected, diff}` with
  information about the differences.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec check_sync_status() :: {:ok, sync_status()}
  def check_sync_status do
    GenServer.call(__MODULE__, :check_sync_status)
  end

  @doc """
  Apply JSON config directly to running Caddy (bypasses in-memory).

  Use this for runtime-only changes that don't need to persist.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec apply_runtime_config(map()) :: :ok | {:error, term()}
  def apply_runtime_config(config) when is_map(config) do
    GenServer.call(__MODULE__, {:apply_runtime_config, "/", config})
  end

  @impl Caddy.ConfigManager.Behaviour
  @spec apply_runtime_config(String.t(), map()) :: :ok | {:error, term()}
  def apply_runtime_config(path, config) when is_binary(path) and is_map(config) do
    GenServer.call(__MODULE__, {:apply_runtime_config, path, config})
  end

  @doc """
  Validate config without applying.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec validate_config(binary()) :: :ok | {:error, term()}
  def validate_config(caddyfile) when is_binary(caddyfile) do
    start_time = System.monotonic_time()

    result = ConfigProvider.adapt(caddyfile)
    duration = System.monotonic_time() - start_time

    case result do
      {:ok, _} ->
        Telemetry.emit_config_manager_event(:validate, %{duration: duration}, %{valid: true})
        :ok

      {:error, reason} ->
        Telemetry.emit_config_manager_event(:validate, %{duration: duration}, %{
          valid: false,
          error: reason
        })

        {:error, {:invalid_config, reason}}
    end
  end

  @doc """
  Rollback to last known good config.

  Restores the last successfully synced configuration.
  """
  @impl Caddy.ConfigManager.Behaviour
  @spec rollback() :: :ok | {:error, term()}
  def rollback do
    GenServer.call(__MODULE__, :rollback)
  end

  @doc """
  Get current state information.
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_args) do
    state = %{
      last_sync_time: nil,
      last_sync_status: nil,
      last_known_good_config: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:sync_to_caddy, opts}, _from, state) do
    backup? = Keyword.get(opts, :backup, true)
    force? = Keyword.get(opts, :force, false)

    start_time = System.monotonic_time()

    result =
      with {:ok, _backup} <- maybe_backup_runtime(backup?, state),
           {:ok, caddyfile} <- {:ok, ConfigProvider.get_caddyfile()},
           :ok <- if(force?, do: :ok, else: maybe_validate(caddyfile, true)),
           {:ok, json_config} <- ConfigProvider.adapt(caddyfile),
           %{status: status} when status in 200..299 <- Api.load(Jason.encode!(json_config)) do
        :ok
      else
        %{status: status, body: body} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end

    duration = System.monotonic_time() - start_time

    case result do
      :ok ->
        Telemetry.emit_config_manager_event(:sync_to_caddy, %{duration: duration}, %{
          success: true
        })

        new_state =
          state
          |> Map.put(:last_sync_time, DateTime.utc_now())
          |> Map.put(:last_sync_status, :success)
          |> maybe_update_last_known_good()

        {:reply, :ok, new_state}

      {:error, reason} ->
        Telemetry.emit_config_manager_event(:sync_to_caddy, %{duration: duration}, %{
          success: false,
          error: reason
        })

        new_state =
          state
          |> Map.put(:last_sync_time, DateTime.utc_now())
          |> Map.put(:last_sync_status, {:failed, reason})

        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:sync_from_caddy, _from, state) do
    start_time = System.monotonic_time()

    result =
      case Api.get_config() do
        nil ->
          {:error, :caddy_not_available}

        config when is_map(config) ->
          # Store as JSON string in caddyfile field
          # Note: This is a compromise - we store JSON, not Caddyfile
          json_str = Jason.encode!(config, pretty: true)
          ConfigProvider.set_caddyfile(json_str)
          {:ok, config}
      end

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, _} ->
        Telemetry.emit_config_manager_event(:sync_from_caddy, %{duration: duration}, %{
          success: true
        })

        new_state =
          state
          |> Map.put(:last_sync_time, DateTime.utc_now())
          |> Map.put(:last_sync_status, :success)

        {:reply, :ok, new_state}

      {:error, reason} ->
        Telemetry.emit_config_manager_event(:sync_from_caddy, %{duration: duration}, %{
          success: false,
          error: reason
        })

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:check_sync_status, _from, state) do
    start_time = System.monotonic_time()

    result =
      with {:ok, memory_json} <- get_memory_config(:json),
           {:ok, runtime_json} <- get_runtime_config() do
        if configs_equivalent?(memory_json, runtime_json) do
          {:ok, :in_sync}
        else
          diff = compute_diff(memory_json, runtime_json)
          {:ok, {:drift_detected, diff}}
        end
      else
        {:error, reason} -> {:error, reason}
      end

    duration = System.monotonic_time() - start_time

    status =
      case result do
        {:ok, :in_sync} -> :in_sync
        {:ok, {:drift_detected, _}} -> :drift_detected
        {:error, _} -> :error
      end

    Telemetry.emit_config_manager_event(:drift_check, %{duration: duration}, %{status: status})

    {:reply, result, state}
  end

  @impl true
  def handle_call({:apply_runtime_config, path, config}, _from, state) do
    start_time = System.monotonic_time()

    result =
      case path do
        "/" ->
          case Api.load(Jason.encode!(config)) do
            %{status: status} when status in 200..299 -> :ok
            %{status: status, body: body} -> {:error, {:http_error, status, body}}
          end

        _ ->
          case Api.patch_config(path, config) do
            nil -> {:error, :patch_failed}
            _ -> :ok
          end
      end

    duration = System.monotonic_time() - start_time

    Telemetry.emit_config_manager_event(:apply, %{duration: duration}, %{
      path: path,
      success: result == :ok
    })

    {:reply, result, state}
  end

  @impl true
  def handle_call(:rollback, _from, state) do
    start_time = System.monotonic_time()

    result =
      case state.last_known_good_config do
        nil ->
          {:error, :no_rollback_available}

        config ->
          case Api.load(Jason.encode!(config)) do
            %{status: status} when status in 200..299 -> :ok
            %{status: status, body: body} -> {:error, {:http_error, status, body}}
          end
      end

    duration = System.monotonic_time() - start_time

    Telemetry.emit_config_manager_event(:rollback, %{duration: duration}, %{
      success: result == :ok
    })

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp maybe_validate(_caddyfile, false), do: :ok

  defp maybe_validate(caddyfile, true) do
    case ConfigProvider.adapt(caddyfile) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:validation_failed, reason}}
    end
  end

  defp maybe_sync(false), do: :ok
  defp maybe_sync(true), do: sync_to_caddy()

  defp maybe_backup_runtime(false, _state), do: {:ok, nil}

  defp maybe_backup_runtime(true, _state) do
    case Api.get_config() do
      nil -> {:ok, nil}
      config -> {:ok, config}
    end
  end

  defp maybe_update_last_known_good(state) do
    case Api.get_config() do
      nil -> state
      config -> Map.put(state, :last_known_good_config, config)
    end
  end

  defp configs_equivalent?(a, b) when is_map(a) and is_map(b) do
    # Normalize by removing transient fields and comparing
    normalize_config(a) == normalize_config(b)
  end

  defp configs_equivalent?(_, _), do: false

  defp normalize_config(config) when is_map(config) do
    config
    |> Map.drop(["etag"])
    |> Enum.map(fn {k, v} -> {k, normalize_config(v)} end)
    |> Enum.into(%{})
  end

  defp normalize_config(config) when is_list(config) do
    Enum.map(config, &normalize_config/1)
  end

  defp normalize_config(config), do: config

  defp compute_diff(memory, runtime) do
    memory_keys = Map.keys(memory) |> MapSet.new()
    runtime_keys = Map.keys(runtime) |> MapSet.new()

    only_in_memory = MapSet.difference(memory_keys, runtime_keys) |> MapSet.to_list()
    only_in_runtime = MapSet.difference(runtime_keys, memory_keys) |> MapSet.to_list()

    common_keys = MapSet.intersection(memory_keys, runtime_keys) |> MapSet.to_list()

    different_values =
      common_keys
      |> Enum.filter(fn key ->
        normalize_config(Map.get(memory, key)) != normalize_config(Map.get(runtime, key))
      end)

    %{
      only_in_memory: only_in_memory,
      only_in_runtime: only_in_runtime,
      different_values: different_values
    }
  end
end
