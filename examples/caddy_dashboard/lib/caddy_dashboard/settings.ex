defmodule CaddyDashboard.Settings do
  @moduledoc """
  Manages dashboard settings including Caddy operating mode.

  Settings are stored in a JSON file and loaded on application startup.
  Changes to settings are applied to Application config and persisted to file.
  """

  @settings_file "dashboard_settings.json"

  @default_settings %{
    "mode" => "external",
    # External mode settings
    "admin_url" => "http://localhost:2019",
    "health_interval" => 30_000,
    "commands" => %{
      "start" => "",
      "stop" => "",
      "restart" => "",
      "status" => ""
    },
    # Embedded mode settings
    "embedded" => %{
      "caddy_bin" => "",
      "base_path" => "",
      "auto_start" => true,
      "dump_log" => false
    }
  }

  @doc """
  Get the settings file path.
  """
  def settings_file do
    Path.join(Caddy.Config.etc_path(), @settings_file)
  end

  @doc """
  Load settings from file. Returns default settings if file doesn't exist.
  """
  @spec load() :: map()
  def load do
    case File.read(settings_file()) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, settings} -> Map.merge(@default_settings, settings)
          {:error, _} -> @default_settings
        end

      {:error, _} ->
        @default_settings
    end
  end

  @doc """
  Save settings to file.
  """
  @spec save(map()) :: :ok | {:error, term()}
  def save(settings) do
    file = settings_file()

    with :ok <- Caddy.Config.ensure_dir_exists(file),
         {:ok, json} <- Jason.encode(settings, pretty: true),
         :ok <- File.write(file, json) do
      :ok
    end
  end

  @doc """
  Apply settings to Application config.
  """
  @spec apply_to_config(map()) :: :ok
  def apply_to_config(settings) do
    mode = String.to_existing_atom(settings["mode"] || "external")
    Application.put_env(:caddy, :mode, mode)

    # External mode settings
    Application.put_env(:caddy, :admin_url, settings["admin_url"])
    Application.put_env(:caddy, :health_interval, settings["health_interval"])

    commands =
      (settings["commands"] || %{})
      |> Enum.reject(fn {_k, v} -> v == "" or is_nil(v) end)
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)

    Application.put_env(:caddy, :commands, commands)

    # Embedded mode settings
    embedded = settings["embedded"] || %{}

    if embedded["base_path"] && embedded["base_path"] != "" do
      Application.put_env(:caddy, :base_path, embedded["base_path"])
    end

    if embedded["dump_log"] do
      Application.put_env(:caddy, :dump_log, embedded["dump_log"])
    end

    :ok
  end

  @doc """
  Get default settings.
  """
  def default_settings, do: @default_settings

  @doc """
  Get current settings from Application config.
  """
  @spec current() :: map()
  def current do
    commands = Caddy.Config.commands()

    commands_map =
      %{"start" => "", "stop" => "", "restart" => "", "status" => ""}
      |> Map.merge(
        commands
        |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Enum.into(%{})
      )

    # Get embedded mode settings
    caddy_bin =
      try do
        config = Caddy.get_config()
        config.bin || detect_caddy_bin()
      rescue
        _ -> detect_caddy_bin()
      end

    %{
      "mode" => Atom.to_string(Caddy.Config.mode()),
      "admin_url" => Caddy.Config.admin_url(),
      "health_interval" => Caddy.Config.health_interval(),
      "commands" => commands_map,
      "embedded" => %{
        "caddy_bin" => caddy_bin || "",
        "base_path" => Caddy.Config.base_path(),
        "auto_start" => Application.get_env(:caddy, :start, true),
        "dump_log" => Application.get_env(:caddy, :dump_log, false)
      }
    }
  end

  defp detect_caddy_bin do
    cond do
      :os.type() == {:unix, :linux} -> "/usr/bin/caddy"
      :os.type() == {:unix, :darwin} -> "/opt/homebrew/bin/caddy"
      true -> System.find_executable("caddy")
    end
  end

  @doc """
  Update settings, apply to config, and save to file.
  """
  @spec update(map()) :: :ok | {:error, term()}
  def update(settings) do
    with :ok <- apply_to_config(settings),
         :ok <- save(settings) do
      :ok
    end
  end

  @doc """
  Initialize settings on application startup.
  Loads from file and applies to Application config.
  """
  def init do
    settings = load()
    apply_to_config(settings)
    :ok
  end
end
