defmodule Caddy.MixProject do
  use Mix.Project

  def project do
    [
      app: :caddy,
      version: "1.0.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      name: "Caddy",
      description: "Run Caddy HTTP Server in supervisor tree",
      aliases: aliases(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Jonathan Gao"],
      licenses: ["MIT"],
      files: ~w(lib priv LICENSE mix.exs README.md),
      links: %{
        Changelog: "https://hexdocs.pm/caddy/changelog.html"
      }
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, publish this package, run:
  #
  #     $ mix publish
  #
  defp aliases do
    [
      setup: ["deps.get", "assets.setup"],
      publish: [
        "format",
        fn _ ->
          File.rm_rf!("priv")
          File.mkdir!("priv")
        end,
        "hex.publish"
      ]
    ]
  end
end
