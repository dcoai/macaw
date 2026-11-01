defmodule Macaw.SourceShorthandTest do
  # A cell's single source (spec/06 §3.2, §3.4): `source:` binds a component's one slot,
  # resolved at validation, kept short in the document.
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Test.Rows

  # A component with two slots, which the shorthand can't choose between.
  defmodule Pair do
    use Macaw.Component, name: "test.pair", kinds: [:content]

    @impl true
    def declarations(_settings),
      do: {:ok, slots: %{"left" => %{}, "right" => %{}}}

    @impl true
    def render(:content, _assigns), do: {:safe, "<p>pair</p>"}
  end

  defmodule PairPackage do
    def __members__, do: [Pair]
  end

  @now ~U[2026-11-01 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin, Macaw.Test.Package, PairPackage])
  @sources %{
    "lat" =>
      {%Rows{
         rows: [
           %{"t" => @now, "v" => 1.0, "host" => "a"},
           %{"t" => @now, "v" => 2.0, "host" => "b"}
         ]
       }, nil}
  }

  # On the grid: a stacked bound cell isn't fetched yet (#232).
  @place %{x: 0, y: 0, w: 12, h: 4}

  defp html(cells) do
    {:ok, s} = Surface.new(name: "ops", cells: Enum.map(cells, &Map.put(&1, :place, @place)))
    {:ok, v} = Surface.validate(s, @registry, @sources)

    v
    |> Surface.render(sources: @sources, now: @now, ceiling: 1_000)
    |> Phoenix.HTML.safe_to_string()
  end

  @tag verifies: "cells-source"
  test "source: binds a one-slot component, and validates and renders as the explicit binding" do
    short = [%{component: "macaw.table", source: "lat", fields: %{"columns" => ["host"]}}]

    explicit = [
      %{
        name: "table_lat",
        component: "macaw.table",
        slots: %{"rows" => %{source: "lat", fields: %{"columns" => ["host"]}}}
      }
    ]

    assert html(short) == html(explicit)
    assert html(short) =~ ~s(value="host">host</button></th></tr>)

    # Validated holds the explicit binding.
    {:ok, s} = Surface.new(name: "ops", cells: short)
    assert {:ok, v} = Surface.validate(s, @registry, @sources)

    assert %{"rows" => %{source: "lat", fields: %{"columns" => ["host"]}}} =
             v.cells["table_lat"].slots
  end

  @tag verifies: "cells-source"
  test "a component with no slot or several, and source beside slots, are faults by path" do
    {:ok, s} =
      Surface.new(
        name: "ops",
        cells: [
          %{component: "test.note", source: "lat"},
          %{component: "test.pair", source: "lat"}
        ]
      )

    assert Surface.validate(s, @registry, @sources) ==
             {:error,
              [
                {[:cells, "note_lat", :source], {:ambiguous_slot, []}},
                {[:cells, "pair_lat", :source], {:ambiguous_slot, ["left", "right"]}}
              ]}

    assert {:error, [{[:cells, "a", :source], :source_and_slots}]} =
             Surface.new(
               name: "ops",
               cells: %{
                 "a" => %{
                   component: "macaw.table",
                   source: "lat",
                   slots: %{"rows" => %{source: "lat"}},
                   place: %{x: 0, y: 0, w: 1, h: 1}
                 }
               }
             )

    assert {:error, faults} =
             Surface.new(
               name: "ops",
               cells: [%{component: "macaw.table", fields: %{"x" => "t"}, params: %{}}]
             )

    assert faults == [
             {[:cells, "table", :fields], {:requires, :source}},
             {[:cells, "table", :params], {:requires, :source}}
           ]
  end

  @tag verifies: "cells-source"
  test "the shorthand's source, params and fields are checked at the cell's own keys" do
    {:ok, s} =
      Surface.new(name: "ops", cells: [%{name: "t", component: "macaw.table", source: "nope"}])

    assert Surface.validate(s, @registry, @sources) ==
             {:error, [{[:cells, "t", :source], {:unknown_source, "nope"}}]}

    {:ok, s} =
      Surface.new(
        name: "ops",
        cells: [
          %{name: "t", component: "macaw.table", source: "lat", fields: %{"columns" => ["hots"]}}
        ]
      )

    assert {:error, [{[:cells, "t", :fields, "columns" | _], _}]} =
             Surface.validate(s, @registry, @sources)

    # An unknown component leaves the slot unresolved, and says so.
    {:ok, s} =
      Surface.new(name: "ops", cells: [%{name: "t", component: "nobody.here", source: "lat"}])

    assert Surface.validate(s, @registry, @sources) ==
             {:error,
              [
                {[:cells, "t", :component], {:unknown_component, "nobody.here"}},
                {[:cells, "t", :source], {:unchecked, :component}}
              ]}
  end

  @tag verifies: "cells-source"
  test "the shorthand round-trips as itself through the map and JSON forms" do
    {:ok, s} =
      Surface.new(
        name: "ops",
        cells: [%{component: "macaw.table", source: "lat", fields: %{"columns" => ["host", "v"]}}]
      )

    assert s.cells["table_lat"].source == %{
             source: "lat",
             fields: %{"columns" => ["host", "v"]},
             params: %{}
           }

    assert s.cells["table_lat"].slots == %{}

    node = Surface.to_map(s).surface.cells["table_lat"]
    assert node.source == "lat" and node.fields == %{"columns" => ["host", "v"]}
    refute Map.has_key?(node, :params) or node.slots != %{}

    assert Surface.from_map(Surface.to_map(s)) == {:ok, s}
    assert {:ok, json} = Surface.to_json(s)
    assert JSON.decode!(json)["surface"]["cells"]["table_lat"]["source"] == "lat"
    assert Surface.from_json(json) == {:ok, s}
  end
end
