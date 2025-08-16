import Config

config :logger,
  level: :debug,
  truncate: 4096

# Caddy path configuration examples
# Uncomment and modify as needed:

# Base directory for all caddy files (default: ~/.local/share/caddy)
# config :caddy, :base_path, "/custom/caddy/path"

# Individual path overrides
# config :caddy, :priv_path, "/custom/priv/path"
# config :caddy, :etc_path, "/custom/etc/path"
# config :caddy, :run_path, "/custom/run/path"
# config :caddy, :tmp_path, "/custom/tmp/path"
# config :caddy, :xdg_config_home, "/custom/config/path"
# config :caddy, :xdg_data_home, "/custom/data/path"

# Individual file overrides
# config :caddy, :env_file, "/custom/path/envfile"
# config :caddy, :init_file, "/custom/path/init.json"
# config :caddy, :pid_file, "/custom/path/caddy.pid"
# config :caddy, :socket_file, "/custom/path/caddy.sock"
# config :caddy, :saved_json_file, "/custom/path/autosave.json"
# config :caddy, :backup_json_file, "/custom/path/backup.json"
