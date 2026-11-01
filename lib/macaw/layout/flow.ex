defmodule Macaw.Layout.Flow do
  @moduledoc """
  The flow (spec/06 §3.3), the built-in layout `:flow`: sections for prose, in the order
  the surface gives, `{:flow, order: ["intro", "chart", "notes"]}`, each as tall as its
  content. A cell has no place.

      iex> Macaw.Layout.Flow.container(%{order: ["a"]})
      "mw-flow"
  """

  @behaviour Macaw.Layout

  alias Macaw.Layout.Ordered

  @impl Macaw.Layout
  def name, do: "flow"

  @impl Macaw.Layout
  def options(given), do: Ordered.options(given)

  @impl Macaw.Layout
  def place(given), do: Ordered.place(given, "flow")

  @impl Macaw.Layout
  def faults(cells, options), do: Ordered.faults(cells, options)

  @impl Macaw.Layout
  def order(cells, options), do: Ordered.order(cells, options)

  @impl Macaw.Layout
  def container(_options), do: "mw-flow"

  @impl Macaw.Layout
  def classes(_place, _options), do: "mw-cell mw-section"

  @impl Macaw.Layout
  def size(_place, _options, width, row_height), do: Ordered.size(width, row_height)

  @impl Macaw.Layout
  def stylesheet(_options), do: stylesheet()

  @doc """
  The flow's static stylesheet: block sections, each its content's height, with
  `var(--mw-flow-gap, 1.5rem)` between them.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    ".mw-flow{display:flow-root}\n" <>
      ".mw-flow>.mw-section+.mw-section{margin-block-start:var(--mw-flow-gap,1.5rem)}\n"
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())
end
