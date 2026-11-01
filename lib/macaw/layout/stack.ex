defmodule Macaw.Layout.Stack do
  @moduledoc """
  The stack (spec/06 §3.3), the built-in layout `:stack`: one column, the cells in the
  order the surface gives, `{:stack, order: ["header", "chart", "table"]}`. It is what the
  grid collapses to on a narrow screen, chosen on purpose. A cell has no place.

      iex> Macaw.Layout.Stack.container(%{order: ["a"]})
      "mw-stack"
  """

  @behaviour Macaw.Layout

  alias Macaw.Layout.Ordered

  @impl Macaw.Layout
  def name, do: "stack"

  @impl Macaw.Layout
  def options(given), do: Ordered.options(given)

  @impl Macaw.Layout
  def place(given), do: Ordered.place(given, "stack")

  @impl Macaw.Layout
  def faults(cells, options), do: Ordered.faults(cells, options)

  @impl Macaw.Layout
  def order(cells, options), do: Ordered.order(cells, options)

  @impl Macaw.Layout
  def container(_options), do: "mw-stack"

  @impl Macaw.Layout
  def classes(_place, _options), do: "mw-cell"

  @impl Macaw.Layout
  def size(_place, _options, width, row_height), do: Ordered.size(width, row_height)

  @impl Macaw.Layout
  def stylesheet(_options), do: stylesheet()

  @doc """
  The stack's static stylesheet: one column of rows at least `var(--mw-grid-row, 4rem)`
  high, the grid's gap between them.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    ".mw-stack{display:grid;grid-template-columns:minmax(0,1fr);" <>
      "grid-auto-rows:minmax(var(--mw-grid-row,4rem),auto);gap:var(--mw-grid-gap,1rem)}\n"
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())
end
