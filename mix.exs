defmodule Macaw.MixProject do
  use Mix.Project

  @version "0.1.0-dev"

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
      package: [licenses: ["MIT"]],
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # `test/support` holds the test components and sources surfaces are checked with.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # The document kernel, fragments and themes (spec/00 §4).
      {:macaw_layers, git: "git@gitlab.conet.yarina.org:dco-tek/macaw_layers.git", tag: "v0.2.0"},
      # The data model, sources, deliveries and finishing (spec/00 §4).
      {:macaw_data, git: "git@gitlab.conet.yarina.org:dco-tek/macaw_data.git", tag: "v0.5.1"},
      # The component contract (spec/00 §4).
      {:macaw_component,
       git: "git@gitlab.conet.yarina.org:dco-tek/macaw_component.git", tag: "v0.1.0"},
      {:phoenix_html, "~> 4.1"},
      # The component kit reads renders with it; the built-in table is checked by the kit.
      {:lazy_html, "~> 0.1", only: :test},
      {:stream_data, "~> 1.1", only: :test},
      # Spec, tests and code kept aligned (spec/00 §4.1); dev/test only.
      {:surfex, "~> 0.10.0", only: [:dev, :test], runtime: false}
    ]
  end
end
