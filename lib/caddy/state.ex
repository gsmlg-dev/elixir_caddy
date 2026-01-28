defmodule Caddy.State do
  @moduledoc """
  Application state machine for Caddy configuration lifecycle.

  Tracks the operational state of the Elixir Caddy library, providing
  clear visibility into whether the system is ready to serve requests.

  ## States

  | State | Description | Allowed Operations |
  |-------|-------------|-------------------|
  | `:initializing` | Library starting up | None (transient) |
  | `:unconfigured` | No Caddyfile set | `set_caddyfile/1`, `get_state/0` |
  | `:configured` | Caddyfile set, not synced | `sync_to_caddy/0`, `set_caddyfile/1`, `clear_config/0` |
  | `:synced` | Configuration pushed successfully | All operations |
  | `:degraded` | Was synced, Caddy not responding | `sync_to_caddy/0`, health checks |

  ## State Transitions

  ```
  :initializing → :unconfigured (startup, no saved config)
  :initializing → :configured (startup, has saved config)
  :unconfigured → :configured (set_caddyfile)
  :configured → :synced (sync_to_caddy success)
  :configured → :configured (sync_to_caddy failure - stays with error)
  :synced → :configured (set_caddyfile - new config needs sync)
  :synced → :degraded (health check failure)
  :degraded → :synced (health check success or sync success)
  :configured → :unconfigured (clear_config)
  ```

  ## Behavior by Mode

  | Mode | Empty Config Behavior |
  |------|----------------------|
  | **External** (default) | Valid - stays in `:unconfigured` |
  | **Embedded** | Cannot start Caddy without config |
  """

  @type state ::
          :initializing
          | :unconfigured
          | :configured
          | :synced
          | :degraded

  @type transition_event ::
          :startup_empty
          | :startup_with_config
          | :config_set
          | :config_cleared
          | :sync_success
          | :sync_failure
          | :health_ok
          | :health_fail

  @valid_transitions %{
    initializing: [:unconfigured, :configured],
    unconfigured: [:configured],
    configured: [:synced, :unconfigured],
    synced: [:configured, :degraded],
    degraded: [:synced]
  }

  @doc """
  Get the initial state based on whether there is saved configuration.
  """
  @spec initial_state(has_config :: boolean()) :: state()
  def initial_state(true), do: :configured
  def initial_state(false), do: :unconfigured

  @doc """
  Compute the next state given a transition event.

  Returns `{:ok, new_state}` for valid transitions, or
  `{:error, :invalid_transition}` for invalid ones.
  """
  @spec transition(state(), transition_event()) :: {:ok, state()} | {:error, :invalid_transition}
  def transition(current_state, event) do
    case do_transition(current_state, event) do
      nil -> {:error, :invalid_transition}
      new_state -> {:ok, new_state}
    end
  end

  @doc """
  Compute the next state, raising on invalid transition.
  """
  @spec transition!(state(), transition_event()) :: state()
  def transition!(current_state, event) do
    case transition(current_state, event) do
      {:ok, new_state} ->
        new_state

      {:error, :invalid_transition} ->
        raise ArgumentError,
              "Invalid state transition: #{current_state} + #{event}"
    end
  end

  @doc """
  Check if a transition from `from_state` to `to_state` is valid.
  """
  @spec valid_transition?(state(), state()) :: boolean()
  def valid_transition?(from_state, to_state) do
    to_state in Map.get(@valid_transitions, from_state, [])
  end

  @doc """
  Check if the given state indicates the system is ready to serve.
  """
  @spec ready?(state()) :: boolean()
  def ready?(:synced), do: true
  def ready?(_), do: false

  @doc """
  Check if the given state indicates configuration is present.
  """
  @spec configured?(state()) :: boolean()
  def configured?(:configured), do: true
  def configured?(:synced), do: true
  def configured?(:degraded), do: true
  def configured?(_), do: false

  @doc """
  Check if the given state indicates a problem.
  """
  @spec degraded?(state()) :: boolean()
  def degraded?(:degraded), do: true
  def degraded?(_), do: false

  @doc """
  Get human-readable description of a state.
  """
  @spec describe(state()) :: String.t()
  def describe(:initializing), do: "Library starting up"
  def describe(:unconfigured), do: "No Caddyfile configured, waiting for configuration"
  def describe(:configured), do: "Caddyfile set, pending sync to Caddy"
  def describe(:synced), do: "Configuration synced to Caddy, operational"
  def describe(:degraded), do: "Configuration synced but Caddy not responding"

  # Private transition logic

  defp do_transition(:initializing, :startup_empty), do: :unconfigured
  defp do_transition(:initializing, :startup_with_config), do: :configured

  defp do_transition(:unconfigured, :config_set), do: :configured

  defp do_transition(:configured, :sync_success), do: :synced
  defp do_transition(:configured, :sync_failure), do: :configured
  defp do_transition(:configured, :config_cleared), do: :unconfigured
  defp do_transition(:configured, :config_set), do: :configured

  defp do_transition(:synced, :config_set), do: :configured
  defp do_transition(:synced, :health_fail), do: :degraded
  defp do_transition(:synced, :health_ok), do: :synced
  defp do_transition(:synced, :sync_success), do: :synced

  defp do_transition(:degraded, :health_ok), do: :synced
  defp do_transition(:degraded, :sync_success), do: :synced
  defp do_transition(:degraded, :sync_failure), do: :degraded
  defp do_transition(:degraded, :config_set), do: :configured

  defp do_transition(_, _), do: nil
end
