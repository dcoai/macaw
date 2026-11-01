defmodule Macaw.ListCellsTest do
  # Cells as a list (spec/06 §3.2): the list's order kept, names derived where none is
  # given, and a stack as the placement when no cell has a place (spec/06 §3.3).
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Macaw.{Registry, Surface}

  @registry Registry.new!([Macaw.Test.Package])
  @rows %{"rows" => %{source: "services"}}

  defp note(text), do: %{component: "test.note", settings: %{"text" => text}}

  @tag verifies: "surface-list"
  test "listed cells with no place expand to a stack in the list's order, named from their parts" do
    {:ok, short} =
      Surface.new(
        name: "status",
        cells: [
          %{component: "macaw.table", slots: @rows},
          [component: "test.note", settings: %{"text" => "hi"}]
        ]
      )

    {:ok, explicit} =
      Surface.new(
        name: "status",
        layout: {:stack, order: ["table_services", "note"]},
        cells: %{
          "table_services" => %{component: "macaw.table", slots: @rows},
          "note" => note("hi")
        }
      )

    assert short == explicit
    assert Surface.to_map(short) == Surface.to_map(explicit)
    assert Surface.from_map(Surface.to_map(short)) == {:ok, explicit}

    # The order is the list's, which is the reading order and the DOM order.
    {:ok, s} = Surface.new(name: "ops", cells: [note("C"), Map.put(note("A"), :name, "a")])
    assert s.layout == {"stack", %{order: ["note", "a"]}}
    assert {:ok, v} = Surface.validate(s, @registry, %{})

    html =
      v
      |> Surface.render(sources: %{}, now: ~U[2026-11-01 00:00:00Z], ceiling: 100)
      |> Phoenix.HTML.safe_to_string()

    assert html =~
             ~s(<div class="mw-stack"><div class="mw-cell" id="ops-note"><p>C</p></div><div class="mw-cell" id="ops-a"><p>A</p>)
  end

  @tag verifies: "surface-list"
  test "derived names are deterministic, numbered past every name taken, and an explicit name wins" do
    {:ok, s} =
      Surface.new(
        name: "ops",
        cells: [note("1"), note("2"), Map.put(note("3"), :name, "note_2"), note("4")]
      )

    assert s.layout == {"stack", %{order: ["note", "note_3", "note_2", "note_4"]}}
    assert s.cells["note_3"].settings == %{"text" => "2"}

    # Twice the same document, twice the same names.
    assert Surface.new(name: "ops", cells: [note("1"), note("2")]) ==
             Surface.new(name: "ops", cells: [note("1"), note("2")])

    # A flow named with no order takes the list's; a list of placed cells is a grid.
    {:ok, flow} = Surface.new(name: "ops", layout: :flow, cells: [note("1"), note("2")])
    assert flow.layout == {"flow", %{order: ["note", "note_2"]}}

    place = %{x: 0, y: 0, w: 12, h: 1}
    {:ok, grid} = Surface.new(name: "ops", cells: [Map.put(note("1"), :place, place)])
    assert grid.layout == :grid and Map.keys(grid.cells) == ["note"]
  end

  @tag verifies: "surface-list"
  test "a list that places some cells and not others, and every bad listed cell, are faults by path" do
    place = %{x: 0, y: 0, w: 12, h: 1}

    assert Surface.new(name: "ops", cells: [Map.put(note("1"), :place, place), note("2")]) ==
             {:error, [{[:cells], :place_mixed}]}

    assert {:error, faults} =
             Surface.new(
               name: "ops",
               cells: [
                 Map.put(note("a"), :name, "a"),
                 Map.put(note("b"), :name, :a),
                 Map.put(note("c"), :name, "Not A Name"),
                 %{settings: %{}},
                 :nope,
                 %{component: "test.note", tint: 1}
               ]
             )

    assert faults == [
             {[:cells, 1, :name], {:duplicate, "a"}},
             {[:cells, 2, :name], {:type, :name}},
             {[:cells, 3, :component], :required},
             {[:cells, 4], {:type, :map}},
             {[:cells, "note", :tint], :unknown_key}
           ]

    assert Surface.new(name: "ops", cells: []) == {:error, [{[:cells], :empty}]}
  end

  # A listed entry, and the fault it gives at its index (nil for a good one).
  defp entry do
    one_of([
      constant({%{component: "test.note"}, :unplaced}),
      map(
        integer(0..60),
        &{%{component: "test.note", place: %{x: 0, y: &1, w: 1, h: 1}}, :placed}
      ),
      constant({%{settings: %{}}, {[:component], :required}}),
      constant({%{name: "Bad Name", component: "test.note"}, {[:name], {:type, :name}}}),
      constant({:nope, {[], {:type, :map}}})
    ])
  end

  @tag verifies: "surface-list"
  property "a list's faults are its entries' own, and :place_mixed only when it places some cells and not others" do
    check all(entries <- list_of(entry(), min_length: 1, max_length: 6)) do
      own =
        for {{_attrs, {path, reason}}, i} <- Enum.with_index(entries),
            do: {[:cells, i | path], reason}

      kinds = for {_attrs, kind} <- entries, kind in [:placed, :unplaced], uniq: true, do: kind
      mixed = if length(kinds) == 2, do: [{[:cells], :place_mixed}], else: []
      expected = Macaw.Layers.Fault.sort(own ++ mixed)

      case Surface.new(name: "ops", cells: Enum.map(entries, &elem(&1, 0))) do
        {:ok, _surface} -> assert expected == []
        {:error, faults} -> assert faults == expected
      end
    end
  end
end
