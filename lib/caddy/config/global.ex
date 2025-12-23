defmodule Caddy.Config.Global do
  @moduledoc """
  Represents Caddy global configuration block.

  The global options block is the first configuration block in a Caddyfile,
  and is used to set options that apply globally (or not specific to any one site).

  ## Field Categories

  ### General Options
  - `debug` - Enable debug mode
  - `http_port` - HTTP port (default: 80)
  - `https_port` - HTTPS port (default: 443)
  - `default_bind` - Default bind addresses
  - `order` - Directive ordering
  - `storage` - Certificate storage configuration
  - `storage_clean_interval` - Interval for storage cleanup
  - `admin` - Admin API endpoint
  - `persist_config` - Persist config changes (default: true)
  - `grace_period` - Graceful shutdown duration
  - `shutdown_delay` - Delay before shutdown starts

  ### TLS/Certificate Options
  - `auto_https` - Automatic HTTPS mode
  - `email` - ACME account email
  - `default_sni` - Default SNI for TLS
  - `local_certs` - Use locally-trusted certificates
  - `skip_install_trust` - Skip installing root CA in system trust store
  - `acme_ca` - ACME CA directory URL
  - `acme_ca_root` - ACME CA root certificate
  - `acme_eab` - ACME External Account Binding
  - `acme_dns` - ACME DNS challenge provider
  - `on_demand_tls` - On-demand TLS configuration
  - `key_type` - Key type for certificates
  - `cert_issuer` - Certificate issuer configuration
  - `renew_interval` - Certificate renewal check interval
  - `cert_lifetime` - Certificate lifetime
  - `ocsp_interval` - OCSP stapling refresh interval
  - `ocsp_stapling` - Enable/disable OCSP stapling
  - `preferred_chains` - Preferred certificate chains

  ### Nested Configuration
  - `servers` - Per-listener server configuration
  - `log` - Logging configuration
  - `pki` - PKI/CA configuration

  ## Examples

      global = %Global{
        admin: "unix//var/run/caddy.sock",
        debug: true,
        email: "admin@example.com"
      }

      # With new options
      global = Global.new(
        debug: true,
        http_port: 8080,
        https_port: 8443,
        auto_https: :disable_redirects
      )

  ## Rendering

  Renders as a block wrapped in curly braces:

      {
        debug
        admin unix//var/run/caddy.sock
        email admin@example.com
      }

  """

  alias Caddy.Config.Global.{Log, PKI, Server}

  @type t :: %__MODULE__{
          # Existing fields (backward compatible)
          admin: String.t() | :off | nil,
          debug: boolean(),
          email: String.t() | nil,
          acme_ca: String.t() | nil,
          storage: String.t() | nil,
          extra_options: [String.t()],

          # New general options
          http_port: integer() | nil,
          https_port: integer() | nil,
          default_bind: [String.t()] | nil,
          order: [{atom(), atom(), atom()}] | nil,
          storage_clean_interval: String.t() | nil,
          persist_config: boolean() | nil,
          grace_period: String.t() | nil,
          shutdown_delay: String.t() | nil,

          # New TLS/certificate options
          auto_https: atom() | nil,
          default_sni: String.t() | nil,
          local_certs: boolean() | nil,
          skip_install_trust: boolean() | nil,
          acme_ca_root: String.t() | nil,
          acme_eab: map() | nil,
          acme_dns: {atom(), String.t()} | nil,
          on_demand_tls: map() | nil,
          key_type: atom() | nil,
          cert_issuer: [map()] | nil,
          renew_interval: String.t() | nil,
          cert_lifetime: String.t() | nil,
          ocsp_interval: String.t() | nil,
          ocsp_stapling: boolean() | nil,
          preferred_chains: atom() | map() | nil,

          # Nested options
          servers: %{String.t() => Server.t()} | nil,
          log: [Log.t()] | nil,
          pki: PKI.t() | nil
        }

  defstruct admin: nil,
            debug: false,
            email: nil,
            acme_ca: nil,
            storage: nil,
            extra_options: [],

            # New general options
            http_port: nil,
            https_port: nil,
            default_bind: nil,
            order: nil,
            storage_clean_interval: nil,
            persist_config: nil,
            grace_period: nil,
            shutdown_delay: nil,

            # New TLS/certificate options
            auto_https: nil,
            default_sni: nil,
            local_certs: nil,
            skip_install_trust: nil,
            acme_ca_root: nil,
            acme_eab: nil,
            acme_dns: nil,
            on_demand_tls: nil,
            key_type: nil,
            cert_issuer: nil,
            renew_interval: nil,
            cert_lifetime: nil,
            ocsp_interval: nil,
            ocsp_stapling: nil,
            preferred_chains: nil,

            # Nested options
            servers: nil,
            log: nil,
            pki: nil

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

  ## Rendering Order

  1. Boolean flags (debug, local_certs, skip_install_trust)
  2. Admin configuration
  3. Port configuration (http_port, https_port)
  4. Bind configuration (default_bind)
  5. Storage configuration
  6. TLS/ACME configuration
  7. General options (grace_period, shutdown_delay, etc.)
  8. Logging configuration (log blocks)
  9. Server configuration (servers blocks)
  10. PKI configuration (pki block)
  11. `extra_options` (raw lines, last for plugin options)
  """

  alias Caddy.Caddyfile

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
    start_time = System.monotonic_time()
    options = build_options(global)

    result =
      if Enum.empty?(options) do
        ""
      else
        options_text =
          options
          |> Enum.map_join("\n", &indent_option/1)

        """
        {
        #{options_text}
        }
        """
        |> String.trim_trailing()
      end

    # Emit telemetry event for config rendering (FR-040)
    duration = System.monotonic_time() - start_time

    Caddy.Telemetry.emit_config_change(:render, %{duration: duration}, %{
      module: Caddy.Config.Global,
      options_count: length(options),
      result_size: byte_size(result)
    })

    result
  end

  # Indent a single option or multi-line block
  defp indent_option(option) do
    option
    |> String.split("\n")
    |> Enum.map_join("\n", &"  #{&1}")
  end

  defp build_options(global) do
    []
    # Boolean flags first
    |> add_boolean_flag("debug", global.debug)
    |> add_boolean_flag("local_certs", global.local_certs)
    |> add_boolean_flag("skip_install_trust", global.skip_install_trust)
    # Admin endpoint
    |> add_admin(global.admin)
    # Port configuration
    |> add_option("http_port", global.http_port)
    |> add_option("https_port", global.https_port)
    # Bind configuration
    |> add_list("default_bind", global.default_bind)
    # Storage configuration
    |> add_option("storage", global.storage)
    |> add_option("storage_clean_interval", global.storage_clean_interval)
    # TLS/ACME configuration
    |> add_option("email", global.email)
    |> add_option("acme_ca", global.acme_ca)
    |> add_option("acme_ca_root", global.acme_ca_root)
    |> add_acme_eab(global.acme_eab)
    |> add_acme_dns(global.acme_dns)
    |> add_on_demand_tls(global.on_demand_tls)
    |> add_auto_https(global.auto_https)
    |> add_option("default_sni", global.default_sni)
    |> add_atom("key_type", global.key_type)
    |> add_cert_issuer(global.cert_issuer)
    |> add_option("renew_interval", global.renew_interval)
    |> add_option("cert_lifetime", global.cert_lifetime)
    |> add_option("ocsp_interval", global.ocsp_interval)
    |> add_ocsp_stapling(global.ocsp_stapling)
    |> add_preferred_chains(global.preferred_chains)
    # General options
    |> add_persist_config(global.persist_config)
    |> add_option("grace_period", global.grace_period)
    |> add_option("shutdown_delay", global.shutdown_delay)
    |> add_order(global.order)
    # Logging configuration
    |> add_logs(global.log)
    # Server configuration
    |> add_servers(global.servers)
    # PKI configuration
    |> add_pki(global.pki)
    # Extra options (user-defined, last)
    |> add_extra_options(global.extra_options)
    |> Enum.reverse()
  end

  # Helper functions for building options

  defp add_boolean_flag(options, _key, nil), do: options
  defp add_boolean_flag(options, _key, false), do: options
  defp add_boolean_flag(options, key, true), do: [key | options]

  defp add_option(options, _key, nil), do: options
  defp add_option(options, key, value), do: ["#{key} #{value}" | options]

  defp add_atom(options, _key, nil), do: options
  defp add_atom(options, key, value) when is_atom(value), do: ["#{key} #{value}" | options]

  defp add_list(options, _key, nil), do: options
  defp add_list(options, _key, []), do: options
  defp add_list(options, key, values), do: ["#{key} #{Enum.join(values, " ")}" | options]

  defp add_admin(options, nil), do: options
  defp add_admin(options, :off), do: ["admin off" | options]
  defp add_admin(options, value), do: ["admin #{value}" | options]

  defp add_auto_https(options, nil), do: options
  defp add_auto_https(options, value) when is_atom(value), do: ["auto_https #{value}" | options]

  defp add_persist_config(options, nil), do: options
  defp add_persist_config(options, true), do: options
  defp add_persist_config(options, false), do: ["persist_config off" | options]

  defp add_ocsp_stapling(options, nil), do: options
  defp add_ocsp_stapling(options, true), do: options
  defp add_ocsp_stapling(options, false), do: ["ocsp_stapling off" | options]

  defp add_acme_eab(options, nil), do: options

  defp add_acme_eab(options, %{key_id: key_id, mac_key: mac_key}) do
    block = """
    acme_eab {
      key_id #{key_id}
      mac_key #{mac_key}
    }
    """

    [String.trim_trailing(block) | options]
  end

  defp add_acme_dns(options, nil), do: options

  defp add_acme_dns(options, {provider, credentials}) do
    ["acme_dns #{provider} #{credentials}" | options]
  end

  defp add_on_demand_tls(options, nil), do: options

  defp add_on_demand_tls(options, %{ask: ask}) do
    block = """
    on_demand_tls {
      ask #{ask}
    }
    """

    [String.trim_trailing(block) | options]
  end

  defp add_on_demand_tls(options, config) when is_map(config) do
    lines = Enum.map_join(config, "\n", fn {k, v} -> "  #{k} #{v}" end)
    ["on_demand_tls {\n#{lines}\n}" | options]
  end

  defp add_cert_issuer(options, nil), do: options
  defp add_cert_issuer(options, []), do: options

  defp add_cert_issuer(options, issuers) when is_list(issuers) do
    blocks =
      Enum.map(issuers, fn issuer ->
        name = Map.get(issuer, :name, "acme")
        opts = Map.delete(issuer, :name)

        if map_size(opts) == 0 do
          "cert_issuer #{name}"
        else
          inner = Enum.map_join(opts, "\n", fn {k, v} -> "  #{k} #{v}" end)
          "cert_issuer #{name} {\n#{inner}\n}"
        end
      end)

    Enum.reduce(blocks, options, fn block, acc -> [block | acc] end)
  end

  defp add_preferred_chains(options, nil), do: options
  defp add_preferred_chains(options, :smallest), do: ["preferred_chains smallest" | options]

  defp add_preferred_chains(options, config) when is_map(config) do
    lines = Enum.map_join(config, "\n", fn {k, v} -> "  #{k} #{v}" end)
    ["preferred_chains {\n#{lines}\n}" | options]
  end

  defp add_order(options, nil), do: options
  defp add_order(options, []), do: options

  defp add_order(options, orders) when is_list(orders) do
    blocks =
      Enum.map(orders, fn {directive, position, reference} ->
        "order #{directive} #{position} #{reference}"
      end)

    Enum.reduce(blocks, options, fn block, acc -> [block | acc] end)
  end

  defp add_logs(options, nil), do: options
  defp add_logs(options, []), do: options

  defp add_logs(options, logs) when is_list(logs) do
    blocks =
      logs
      |> Enum.map(&Caddyfile.to_caddyfile/1)
      |> Enum.reject(&(&1 == ""))

    Enum.reduce(blocks, options, fn block, acc -> [block | acc] end)
  end

  defp add_servers(options, nil), do: options
  defp add_servers(options, servers) when map_size(servers) == 0, do: options

  defp add_servers(options, servers) when is_map(servers) do
    blocks =
      Enum.map(servers, fn {listener, server} ->
        server_content = Caddyfile.to_caddyfile(server)

        if server_content == "" do
          "servers #{listener} {\n}"
        else
          inner =
            server_content
            |> String.split("\n")
            |> Enum.map_join("\n", &"  #{&1}")

          "servers #{listener} {\n#{inner}\n}"
        end
      end)

    Enum.reduce(blocks, options, fn block, acc -> [block | acc] end)
  end

  defp add_pki(options, nil), do: options

  defp add_pki(options, pki) do
    pki_content = Caddyfile.to_caddyfile(pki)

    if pki_content == "" do
      options
    else
      [pki_content | options]
    end
  end

  defp add_extra_options(options, []), do: options
  defp add_extra_options(options, extra), do: Enum.reverse(extra) ++ options
end
