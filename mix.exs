defmodule Macaw.MixProject do
  use Mix.Project

  @source_url "https://github.com/dcoai/macaw"
  @version "0.3.0"

  # The tutorial, in reading order: its overview, then one chapter per file.
  @tutorial [
    "guides/tutorial.md",
    "guides/tutorial/01-first-surface.md",
    "guides/tutorial/02-sources.md",
    "guides/tutorial/03-schemas-and-data.md",
    "guides/tutorial/04-surfaces.md",
    "guides/tutorial/05-the-table.md",
    "guides/tutorial/06-components.md",
    "guides/tutorial/07-testing.md",
    "guides/tutorial/08-documents.md",
    "guides/tutorial/09-themes.md",
    "guides/tutorial/10-phoenix.md",
    "guides/tutorial/11-operations-and-derived.md"
  ]

  def project do
    [
      app: :macaw,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # A Hex package is built only from the clean, pushed release tag (dco-tek/macaw/macaw#190).
      aliases: ["hex.publish": ["cmd elixir ci/release_guard.exs #{@version}", "hex.publish"]],
      description:
        "Macaw's core: composing pages out of independent components that share typed data and interactive state.",
      source_url: @source_url,
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md" | @tutorial] ++ ["CHANGELOG.md"],
        groups_for_extras: [Tutorial: @tutorial],
        source_ref: "v#{@version}",
        logo: "brand/logo/macaw_scarlet.svg",
        assets: %{"brand/logo" => "brand/logo"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # `test/support` holds the test components and sources surfaces are checked with.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Published on Hex from its public home, mirrored from GitLab (dco-tek/macaw/macaw#155).
  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Changelog" => "https://hexdocs.pm/macaw/changelog.html"},
      files: ~w(lib spec mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp deps do
    [
      # The document kernel, fragments and themes (spec/00 §4).
      {:macaw_layers, "~> 0.4.0"},
      # The data model, sources, deliveries and finishing (spec/00 §4).
      {:macaw_data, "~> 0.11.0"},
      # The component contract (spec/00 §4).
      {:macaw_component, "~> 0.5.0"},
      {:phoenix_html, "~> 4.1"},
      # The component kit reads renders with it; the built-in table is checked by the kit.
      {:lazy_html, "~> 0.1", only: :test},
      {:stream_data, "~> 1.1", only: :test},
      # Docs for Hex (macaw_compose#155); dev only.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      # Spec, tests and code kept aligned (spec/00 §4.1); dev/test only.
      {:surfex, "~> 0.11.0", only: [:dev, :test], runtime: false}
    ]
  end
end
