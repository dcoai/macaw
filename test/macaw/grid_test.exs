defmodule Macaw.GridTest do
  # The grid (spec/06 §3.3).
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Macaw.Grid

  doctest Grid

  defp cells(places), do: Map.new(places, fn {name, place} -> {name, %{place: place}} end)
  defp p(x, y, w, h), do: %{x: x, y: y, w: w, h: h}

  @tag verifies: "grid-rules"
  test "placements in bounds pass; each bound broken is a fault" do
    assert {Grid.columns(), Grid.rows()} == {12, 64}

    assert Grid.faults(
             cells(%{"a" => p(0, 0, 6, 2), "b" => p(6, 0, 6, 2), "c" => p(0, 2, 12, 62)})
           ) == []

    for {place, what} <- [
          {p(-1, 0, 1, 1), {:x, -1}},
          {p(12, 0, 1, 1), {:x, 12}},
          {p(0, 0, 0, 1), {:w, 0}},
          {p(0, 0, 13, 1), {:w, 13}},
          {p(8, 0, 6, 1), {:x_plus_w, 14}},
          {p(0, -1, 1, 1), {:y, -1}},
          {p(0, 0, 1, 0), {:h, 0}},
          {p(0, 60, 1, 5), {:y_plus_h, 65}}
        ] do
      {key, value} = what

      assert {[:cells, "a", :place], {:out_of_bounds, key, value}} in Grid.faults(
               cells(%{"a" => place})
             ),
             inspect(place)
    end

    # A place that isn't four integers is the cell's own fault.
    assert {:error, [{[:cells, "a", :place, :w], {:type, :integer}}]} =
             Macaw.Surface.new(
               name: "s",
               cells: %{"a" => %{component: "x", place: %{x: 0, y: 0, w: 1.5, h: 1}}}
             )
  end

  @tag verifies: "grid-rules"
  test "an overlap is named at the later cell; reading order sorts by y, x and name" do
    grid =
      cells(%{
        "wide" => p(0, 0, 8, 2),
        "side" => p(6, 1, 6, 2),
        "below" => p(0, 2, 4, 1),
        "b" => p(8, 0, 4, 1),
        "a" => p(8, 3, 4, 1)
      })

    assert Grid.faults(grid) == [{[:cells, "side", :place], {:overlap, "wide"}}]
    assert Grid.order(grid) == ["wide", "b", "side", "below", "a"]
    assert Grid.order(cells(%{"z" => p(0, 0, 1, 1), "a" => p(0, 0, 1, 1)})) == ["a", "z"]
  end

  @tag verifies: "grid-rules"
  property "two generated placements overlap exactly when their rectangles intersect" do
    check all(
            x1 <- integer(0..11),
            w1 <- integer(1..4),
            y1 <- integer(0..10),
            h1 <- integer(1..4),
            x2 <- integer(0..11),
            w2 <- integer(1..4),
            y2 <- integer(0..10),
            h2 <- integer(1..4)
          ) do
      a = p(x1, y1, min(w1, 12 - x1), h1)
      b = p(x2, y2, min(w2, 12 - x2), h2)

      cells =
        Enum.filter(
          MapSet.new(for(c <- a.x..(a.x + a.w - 1), r <- a.y..(a.y + a.h - 1), do: {c, r})),
          fn cell ->
            cell in MapSet.new(
              for(c <- b.x..(b.x + b.w - 1), r <- b.y..(b.y + b.h - 1), do: {c, r})
            )
          end
        )

      overlap? =
        Enum.any?(
          Grid.faults(%{"a" => %{place: a}, "b" => %{place: b}}),
          &match?({_, {:overlap, _}}, &1)
        )

      assert overlap? == (cells != [])
    end
  end

  @tag verifies: "grid-classes"
  test "classes name the place; the stylesheet has a rule for each and the stacking query" do
    assert Grid.classes(p(11, 63, 1, 1)) == "mw-cell mw-col-12 mw-span-1 mw-row-64 mw-rows-1"
    css = Grid.stylesheet()

    for place <- [p(0, 0, 12, 64), p(11, 63, 1, 1), p(5, 10, 3, 7)],
        class <- String.split(Grid.classes(place)) -- ["mw-cell"] do
      assert css =~ "\n.#{class}{", class
    end

    assert css =~ ".mw-grid{display:grid;grid-template-columns:repeat(12,minmax(0,1fr));"

    assert css =~
             "@container (max-width: 40rem){.mw-grid>.mw-cell{grid-column:1/-1;grid-row:auto}}"

    assert css =~ ".mw-surface{container-type:inline-size}"
    refute css =~ "style="
    assert Grid.stylesheet_path() == Macaw.Component.Stylesheet.path(css)
    assert Grid.stylesheet() == css
  end

  @tag verifies: "grid-classes"
  test "a cell's size is its share of the width and its rows' height" do
    assert Grid.size(p(0, 0, 6, 2), 1200, 64) == {600.0, 128}
    assert Grid.size(p(3, 1, 12, 1), 960, 48) == {960.0, 48}
  end

  @tag verifies: "grid-columns"
  test "a grid of 6 or 24 columns places and faults on its own bounds, and sizes by its width" do
    assert Grid.widths() == [6, 12, 24]
    assert Grid.options(%{}) == {:ok, %{columns: 12}}
    assert Grid.options(columns: 24) == {:ok, %{columns: 24}}

    for bad <- [7, 0, "24", nil] do
      assert Grid.options(columns: bad) ==
               {:error, [{[:layout, :options, :columns], {:enum, [6, 12, 24]}}]}
    end

    wide = %{columns: 24}
    assert Grid.faults(cells(%{"a" => p(20, 0, 4, 1), "b" => p(0, 0, 13, 1)}), wide) == []

    assert Grid.faults(cells(%{"a" => p(23, 0, 2, 1)}), wide) ==
             [{[:cells, "a", :place], {:out_of_bounds, :x_plus_w, 25}}]

    # The same place on the default 12 is out of bounds.
    assert {[:cells, "a", :place], {:out_of_bounds, :x, 20}} in Grid.faults(
             cells(%{"a" => p(20, 0, 4, 1)}),
             %{columns: 12}
           )

    assert Grid.faults(cells(%{"a" => p(0, 0, 7, 1)}), %{columns: 6}) ==
             [
               {[:cells, "a", :place], {:out_of_bounds, :w, 7}},
               {[:cells, "a", :place], {:out_of_bounds, :x_plus_w, 7}}
             ]

    assert Grid.size(p(0, 0, 6, 2), wide, 1200, 64) == {300.0, 128}
    assert Grid.size(p(0, 0, 3, 1), %{columns: 6}, 1200, 64) == {600.0, 64}
    assert Grid.container(%{columns: 12}) == "mw-grid"
    assert Grid.container(wide) == "mw-grid mw-grid-24"

    # One sheet for every width: each width's columns, and a rule for every class a
    # placement on the widest can name.
    css = Grid.stylesheet()
    assert Grid.stylesheet(wide) == css and Grid.stylesheet(%{columns: 6}) == css
    assert css =~ ".mw-grid-6{grid-template-columns:repeat(6,minmax(0,1fr))}"
    assert css =~ ".mw-grid-24{grid-template-columns:repeat(24,minmax(0,1fr))}"

    for class <- String.split(Grid.classes(p(23, 63, 1, 1))) -- ["mw-cell"],
        do: assert(css =~ "." <> class <> "{")

    assert css =~ ".mw-span-24{"
    refute css =~ ".mw-col-25{"
  end

  @tag verifies: "grid-columns"
  test "a surface on 24 columns validates, renders its container's width, and round-trips its layout" do
    note = %{"a" => %{component: "test.note", place: p(18, 0, 6, 1)}}

    {:ok, s} =
      Macaw.Surface.new(
        name: "ops",
        layout: {:grid, columns: 24},
        cells: note
      )

    assert s.layout == {"grid", %{columns: 24}}
    registry = Macaw.Registry.new!([Macaw.Test.Package])
    assert {:ok, v} = Macaw.Surface.validate(s, registry, %{})
    assert v.layout == {Grid, %{columns: 24}}

    html =
      v
      |> Macaw.Surface.render(sources: %{}, now: ~U[2026-11-01 00:00:00Z], ceiling: 100)
      |> Phoenix.HTML.safe_to_string()

    assert html =~ ~s(<div class="mw-grid mw-grid-24"><div class="mw-cell mw-col-19 mw-span-6 )

    # The layout's forms: a tag in JSON, the term in the value.
    assert {:ok, json} = Macaw.Surface.to_json(s)
    assert JSON.decode!(json)["surface"]["layout"] == %{"$layout" => ["grid", %{"columns" => 24}]}
    assert Macaw.Surface.from_json(json) == {:ok, s}
    assert Macaw.Surface.from_map(Macaw.Surface.to_map(s)) == {:ok, s}

    {:ok, plain} = Macaw.Surface.new(name: "ops", cells: note)
    assert {:ok, json} = Macaw.Surface.to_json(plain)
    assert Macaw.Surface.from_json(json) == {:ok, plain}

    # A width outside the set is a fault by path, in the value and in JSON alike.
    bad =
      String.replace(
        json,
        ~s("layout":{"$atom":"grid"}),
        ~s("layout":{"$layout":["grid",{"columns":7}]})
      )

    refute bad == json

    assert Macaw.Surface.from_json(bad) ==
             {:error, [{[:surface, :layout, :options, :columns], {:enum, [6, 12, 24]}}]}

    assert {:error, [{[:layout, :options, :columns], {:enum, [6, 12, 24]}}]} =
             Macaw.Surface.new(name: "ops", layout: {:grid, columns: 7}, cells: note)
  end
end
