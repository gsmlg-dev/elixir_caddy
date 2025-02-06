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
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
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
