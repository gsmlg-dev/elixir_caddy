defmodule Caddy.MixProject do
  use Mix.Project

  @source_url "https://github.com/gsmlg-dev/elixir_caddy.git"
  @version "2.0.0"

  def project do
    [
      app: :caddy,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      name: "Caddy",
      description: "Run Caddy Reverse Proxy Server in supervisor tree",
      aliases: aliases(),
      package: package(),
      deps: deps(),
      docs: docs()
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
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false},
      {:mox, "~> 1.0", only: :test}
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
