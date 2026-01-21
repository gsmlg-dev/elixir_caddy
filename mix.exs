defmodule Caddy.MixProject do
  use Mix.Project

  @source_url "https://github.com/gsmlg-dev/elixir_caddy.git"
  @version "2.2.0"

  def project do
    [
      app: :caddy,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      name: "Caddy",
      description: "Run Caddy Reverse Proxy Server in supervisor tree",
      aliases: aliases(),
      package: package(),
      deps: deps(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        ignore_warnings: "dialyzer.ignore-warnings"
      ]
    ]
  end

  def application do
    if Mix.env() == :test do
      [
        extra_applications: [:logger]
      ]
    else
      [
        mod: {Caddy.Application, []},
        extra_applications: [:logger]
      ]
    end
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Jonathan Gao"],
      licenses: ["MIT"],
      files: ~w(lib LICENSE mix.exs README.md),
      links: %{
        Github: @source_url,
        Changelog: "https://hexdocs.pm/caddy/changelog.html"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  defp aliases do
    [
      lint: ["credo --strict", "dialyzer"],
      publish: [
        "format",
        fn _ ->
          File.rm_rf!("priv")
          File.mkdir!("priv")
        end,
        "hex.publish --yes"
      ]
    ]
  end
end
