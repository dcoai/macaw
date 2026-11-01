defmodule Macaw.PlaceFaultsTest do
  # Every fault at once (spec/06 §3.1, §3.3, #236): a layout's options and its cells'
  # places are judged apart, so a bad option never hides a bad place.
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Macaw.{Registry, Surface}

  @enum {:enum, [6, 12, 24]}

  # A grid's columns, and the fault each gives (none for a width the grid takes).
  defp columns,
    do: member_of([{6, []}, {12, []}, {24, []}, {7, [@enum]}, {10, [@enum]}, {"12", [@enum]}])

  # A cell's place on the grid, and the faults its shape gives at the cell's place.
  defp grid_place do
    one_of([
      map(integer(0..60), &{%{x: 0, y: &1, w: 1, h: 1}, []}),
      constant({nil, [{[], :required}]}),
      constant({%{x: "0", y: 0, w: 1, h: 1}, [{[:x], {:type, :integer}}]}),
      constant({%{x: 0, y: 0, w: 1}, [{[:h], :required}]}),
      constant({:nope, [{[], {:type, :map}}]})
    ])
  end

  defp cell(place),
    do: if(place, do: %{component: "test.note", place: place}, else: %{component: "test.note"})

  defp expected(option_faults, at, cells) do
    places =
      for {{_place, faults}, i} <- Enum.with_index(cells),
          {path, reason} <- faults,
          do: {[:cells, "c#{i}", :place | path], reason}

    Macaw.Layers.Fault.sort(for(r <- option_faults, do: {at, r}) ++ places)
  end

  @tag verifies: "layout-behavior"
  property "a grid's bad columns never hide a cell's bad place: every fault at once" do
    check all(
            {n, option_faults} <- columns(),
            cells <- list_of(grid_place(), min_length: 1, max_length: 4)
          ) do
      attrs = Map.new(Enum.with_index(cells), fn {{place, _}, i} -> {"c#{i}", cell(place)} end)
      want = expected(option_faults, [:layout, :options, :columns], cells)

      case Surface.new(name: "ops", layout: {:grid, columns: n}, cells: attrs) do
        {:ok, _surface} -> assert want == []
        {:error, faults} -> assert faults == want
      end
    end
  end

  @tag verifies: "layout-behavior"
  property "a stack's bad order never hides a cell's place it doesn't take" do
    place =
      one_of([
        constant({nil, []}),
        constant({%{x: 0, y: 0, w: 1, h: 1}, [{[], {:not_taken, "stack"}}]})
      ])

    order = member_of([{["c0"], []}, {"c0", [{:type, {:list, :name}}]}])

    check all(
            {given, option_faults} <- order,
            cells <- list_of(place, min_length: 1, max_length: 4)
          ) do
      attrs = Map.new(Enum.with_index(cells), fn {{p, _}, i} -> {"c#{i}", cell(p)} end)
      want = expected(option_faults, [:layout, :options, :order], cells)

      case Surface.new(name: "ops", layout: {:stack, order: given}, cells: attrs) do
        {:ok, _surface} -> assert want == []
        {:error, faults} -> assert faults == want
      end
    end
  end

  # A layout only a registry knows, which takes no options and a place `%{slot: n}`.
  defmodule Slots do
    @behaviour Macaw.Layout
    def name, do: "slots"
    def options(given) when given == %{}, do: {:ok, %{}}
    def options(_given), do: {:error, [{[:layout, :options], :unknown_key}]}
    def place(%{slot: n} = place) when is_integer(n), do: {:ok, place}
    def place(_other), do: {:error, [{[:slot], :required}]}
    def faults(_cells, _options), do: []
    def order(cells, _options), do: cells |> Map.keys() |> Enum.sort()
    def container(_options), do: "mw-slots"
    def classes(_place, _options), do: "mw-cell"
    def size(_place, _options, width, row_height), do: {width, row_height}
    def stylesheet(_options), do: ""
  end

  @tag verifies: "layout-registry"
  test "at validation too, a registry's layout with bad options still judges its places" do
    {:ok, s} =
      Surface.new(
        name: "ops",
        layout: {:slots, wide: true},
        cells: %{"a" => %{component: "test.note"}}
      )

    registry = Registry.new!([Macaw.Test.Package], layouts: [Slots])

    assert Surface.validate(s, registry, %{}) ==
             {:error,
              [{[:cells, "a", :place, :slot], :required}, {[:layout, :options], :unknown_key}]}
  end

  @tag verifies: "surface-show"
  test "show/2 answers a failed new/1's faults, so a pipe from new/1 or build/2 works" do
    assert [name: "ops", cells: []] |> Surface.new() |> Surface.show(sources: %{}) ==
             {:error, [{[:cells], :empty}]}

    assert Surface.build("ops", cells: []) |> Surface.show(sources: %{}) ==
             {:error, [{[:cells], :empty}]}
  end
end
