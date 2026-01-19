defmodule Caddy.ConfigManager.Behaviour do
  @moduledoc """
  Behaviour for ConfigManager, enabling Mox-based testing.

  Defines the contract for configuration management operations
  that coordinate between in-memory and runtime Caddy config.
  """

  @type source :: :memory | :runtime | :both
  @type sync_opts :: keyword()
  @type sync_status :: :in_sync | {:drift_detected, map()}

  @doc "Get configuration from specified source"
  @callback get_config(source :: source()) :: {:ok, map()} | {:error, term()}

  @doc "Get JSON config from running Caddy"
  @callback get_runtime_config() :: {:ok, map()} | {:error, term()}

  @doc "Get JSON config from running Caddy at specific path"
  @callback get_runtime_config(path :: String.t()) :: {:ok, map()} | {:error, term()}

  @doc "Get in-memory config in specified format"
  @callback get_memory_config(format :: :caddyfile | :json) ::
              {:ok, binary() | map()} | {:error, term()}

  @doc "Set Caddyfile in memory with optional sync to Caddy"
  @callback set_caddyfile(caddyfile :: binary(), opts :: sync_opts()) ::
              :ok | {:error, term()}

  @doc "Push in-memory config to running Caddy"
  @callback sync_to_caddy() :: :ok | {:error, term()}

  @doc "Push in-memory config to running Caddy with options"
  @callback sync_to_caddy(opts :: sync_opts()) :: :ok | {:error, term()}

  @doc "Pull running Caddy config to memory"
  @callback sync_from_caddy() :: :ok | {:error, term()}

  @doc "Check if in-memory and runtime configs are in sync"
  @callback check_sync_status() :: {:ok, sync_status()}

  @doc "Apply JSON config directly to running Caddy"
  @callback apply_runtime_config(config :: map()) :: :ok | {:error, term()}

  @doc "Apply JSON config to running Caddy at specific path"
  @callback apply_runtime_config(path :: String.t(), config :: map()) ::
              :ok | {:error, term()}

  @doc "Validate config without applying"
  @callback validate_config(caddyfile :: binary()) :: :ok | {:error, term()}

  @doc "Rollback to last known good config"
  @callback rollback() :: :ok | {:error, term()}
end
