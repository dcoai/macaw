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
end
