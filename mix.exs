defmodule Macaw.MixProject do
  use Mix.Project

  @source_url "https://github.com/dcoai/macaw"
  @version "0.1.1"

  def project do
    [
      app: :macaw,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Macaw's core: composing pages out of independent components that share typed data and interactive state.",
      source_url: @source_url,
      package: package(),
      docs: [main: "readme", extras: ["README.md", "CHANGELOG.md"], source_ref: "v#{@version}"]
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
      {:macaw_layers,
       git: "git@gitlab.conet.yarina.org:dco-tek/macaw/macaw_layers.git", tag: "v0.2.0"},
      # The data model, sources, deliveries and finishing (spec/00 §4).
      {:macaw_data,
       git: "git@gitlab.conet.yarina.org:dco-tek/macaw/macaw_data.git", tag: "v0.5.2"},
      # The component contract (spec/00 §4).
      {:macaw_component,
       git: "git@gitlab.conet.yarina.org:dco-tek/macaw/macaw_component.git", tag: "v0.1.1"},
      {:phoenix_html, "~> 4.1"},
      # The component kit reads renders with it; the built-in table is checked by the kit.
      {:lazy_html, "~> 0.1", only: :test},
      {:stream_data, "~> 1.1", only: :test},
      # Docs for Hex (macaw_compose#155); dev only.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      # Spec, tests and code kept aligned (spec/00 §4.1); dev/test only.
      {:surfex, "~> 0.10.0", only: [:dev, :test], runtime: false}
    ]
  end
end
