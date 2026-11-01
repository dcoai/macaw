defmodule Macaw.LayoutTest do
  # A layout is a behavior (spec/06 §3.3): the grid on it, a closed layout registry
  # (spec/12 §1.1), and nothing reaching the grid but through it.
  use ExUnit.Case, async: true

  alias Macaw.{Grid, Layout, Registry, Surface}
  alias Macaw.Test.Package

  doctest Layout

  # An adopter's layout: one column, a place naming its row, in row order.
  defmodule Rows do
    @behaviour Macaw.Layout
    def name, do: "rows"
    def options(given) when given == %{}, do: {:ok, %{}}
    def options(_given), do: {:error, [{[:layout, :options], :unknown_key}]}
    def place(%{row: n} = place) when is_integer(n) and n >= 0, do: {:ok, place}
    def place(nil), do: {:error, [{[], :required}]}
    def place(_other), do: {:error, [{[:row], {:type, :integer}}]}

    def faults(cells, _options) do
      for {rows, [_ | _] = names} <- Enum.group_by(cells, &elem(&1, 1).place.row, &elem(&1, 0)),
          name <- tl(Enum.sort(names)),
          do: {[:cells, name, :place], {:taken, rows}}
    end

    def order(cells, _options),
      do: cells |> Enum.sort_by(fn {name, c} -> {c.place.row, name} end) |> Enum.map(&elem(&1, 0))

    def classes(%{row: n}, _options), do: "mw-cell mw-rows-row-#{n + 1}"
    def size(_place, _options, width, row_height), do: {width, row_height}
    def stylesheet(_options), do: ".mw-rows-row-1{grid-row:1}\n"
  end

  # Not a layout, and a second layout named "grid".
  defmodule Impostor do
    @behaviour Macaw.Layout
    def name, do: "grid"
    def options(_), do: {:ok, %{}}
    def place(p), do: {:ok, p}
    def faults(_, _), do: []
    def order(cells, _), do: Map.keys(cells)
    def classes(_, _), do: ""
    def size(_, _, w, h), do: {w, h}
    def stylesheet(_), do: ""
  end

  defp surface(layout, cells) do
    {:ok, s} = Surface.new(name: "ops", layout: layout, cells: cells)
    s
  end

  defp note(place), do: %{component: "test.note", place: place}

  @tag verifies: "layout-behavior"
  test "the grid is the built-in layout, its callbacks the grid's own rules" do
    assert Layout.builtins() == [Grid]
    assert Layout.builtin(:grid) == Grid and Layout.builtin("grid") == Grid
    assert Layout.builtin("flow") == nil

    place = %{x: 1, y: 2, w: 3, h: 4}
    cells = %{"a" => %{place: place}, "b" => %{place: %{place | x: 2}}}
    assert Grid.faults(cells, %{}) == Grid.faults(cells)
    assert Grid.order(cells, %{}) == Grid.order(cells)
    assert Grid.classes(place, %{}) == Grid.classes(place)
    assert Grid.size(place, %{}, 1200, 64) == Grid.size(place, 1200, 64)
    assert Grid.stylesheet(%{}) == Grid.stylesheet()
    assert Grid.place(nil) == {:error, [{[], :required}]}
    assert Grid.place(:x) == {:error, [{[], {:type, :map}}]}
    assert Grid.options(columns: 24) == {:error, [{[:layout, :options, :columns], :unknown_key}]}

    # The grid with no options is held as it always was; with options, refused by the grid.
    assert surface(:grid, %{"a" => note(place)}).layout == :grid
    assert surface("grid", %{"a" => note(place)}).layout == :grid

    assert {:error, [{[:layout, :options, :columns], :unknown_key}]} =
             Surface.new(name: "ops", layout: {:grid, columns: 24}, cells: %{"a" => note(place)})
  end

  @tag verifies: "layout-registry"
  test "a layout no registry holds is unknown at validation; an adopter's works once registered" do
    s = surface(:rows, %{"b" => note(%{row: 1}), "a" => note(%{row: 0})})
    # Its places are held as given until a registry says which layout reads them.
    assert s.layout == "rows" and s.cells["a"].place == %{row: 0}

    assert Surface.validate(s, Registry.new!([Package]), %{}) ==
             {:error, [{[:layout], {:unknown, :layout}}]}

    registry = Registry.new!([Package], layouts: [Rows])
    assert Registry.layout(registry, "rows") == {:ok, Rows}
    assert Registry.layout(registry, :grid) == {:ok, Grid}
    assert Registry.layouts(registry) == [{"grid", Grid}, {"rows", Rows}]
    assert Registry.layout(Registry.new!([]), "rows") == :error

    assert {:ok, v} = Surface.validate(s, registry, %{})
    assert v.layout == {Rows, %{}} and v.order == ["a", "b"]

    html =
      v
      |> Surface.render(sources: %{}, now: ~U[2026-11-01 00:00:00Z], ceiling: 100)
      |> Phoenix.HTML.safe_to_string()

    assert [_, a, b] = String.split(html, ~s(<div class="mw-cell ))
    assert a =~ ~s(mw-rows-row-1" id="ops-a">) and b =~ ~s(mw-rows-row-2" id="ops-b">)

    # Its places and placement are judged at validation, every fault by path.
    bad = surface(:rows, %{"a" => note(%{row: 0}), "b" => note(%{row: 0}), "c" => note(:x)})

    assert Surface.validate(bad, registry, %{}) ==
             {:error,
              [
                {[:cells, "b", :place], {:taken, 0}},
                {[:cells, "c", :place, :row], {:type, :integer}}
              ]}
  end

  @tag verifies: "layout-registry"
  test "a registry's layouts are layouts, each name once" do
    assert Registry.new([], layouts: [String]) ==
             {:error, [{[:layouts, String], :not_a_layout}]}

    assert Registry.new([], layouts: [Impostor]) ==
             {:error, [{[:layouts], {:duplicate_layout, "grid", [Grid, Impostor]}}]}

    assert {:error, [{[:layouts], {:not_a_list, :rows}}]} = Registry.new([], layouts: :rows)
    assert Registry.layouts(Registry.new!([], layouts: [Rows, Rows])) |> length() == 2
  end

  @tag verifies: "layout-behavior"
  test "nothing reaches the grid but through Macaw.Layout" do
    callers =
      for path <- Path.wildcard("lib/**/*.ex"),
          path not in ["lib/macaw/grid.ex", "lib/macaw/layout.ex"],
          File.read!(path) =~ ~r/\bGrid\.[a-z_]|alias Macaw\.Grid|\\\\ Macaw\.Grid/,
          do: path

    assert callers == []
  end
end
