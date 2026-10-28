defmodule Macaw.SurfaceTest do
  # The surface document and its cells (spec/06 §3.1, §3.2).
  use ExUnit.Case, async: true

  alias Macaw.Layers.Fragment
  alias Macaw.Surface
  alias Macaw.Surface.Cell

  doctest Macaw.Surface

  @place %{x: 0, y: 0, w: 6, h: 2}

  defp surface(attrs \\ []) do
    {:ok, s} =
      Surface.new(
        Keyword.merge(
          [
            name: "ops",
            title: "Operations",
            cells: %{
              "latency" => %{
                component: "macaw.table",
                settings: %{"caption" => "Latency", "title" => "spelled like a key"},
                slots: %{
                  "rows" => %{
                    source: "latency",
                    fields: %{"x" => "t", "y" => ["p50", "p99"]},
                    params: %{"agg" => "max"}
                  }
                },
                place: @place
              },
              "title" => %{component: "macaw.table", kind: "content", place: %{@place | x: 6}}
            }
          ],
          attrs
        )
      )

    s
  end

  @tag verifies: "surface-new"
  test "a surface builds from its keys, title and layout defaulted" do
    assert %Surface{name: "ops", title: "Operations", layout: :grid} = surface()

    assert {:ok, %Surface{title: nil, layout: :grid}} =
             Surface.new(name: :ops, cells: %{latency: %{component: :x, place: @place}})

    assert {:ok, %Surface{cells: %{"latency" => %Cell{component: "x"}}}} =
             Surface.new(%{name: "ops", cells: %{"latency" => %{component: "x", place: @place}}})
  end

  @tag verifies: "surface-new"
  test "every fault of a bad surface at once, by path; no atom made from a name" do
    assert {:error, faults} =
             Surface.new(
               name: "Ops Board",
               title: "",
               layout: :flow,
               tint_scheme: 1,
               cells: %{
                 "Bad Name" => %{component: "x", place: @place},
                 "a" => %{place: @place},
                 "b" => %{component: "x"}
               }
             )

    assert faults == [
             {[:cells, "Bad Name"], {:type, :name}},
             {[:cells, "a", :component], :required},
             {[:cells, "b", :place], :required},
             {[:layout], {:unknown_layout, :flow}},
             {[:name], {:type, :name}},
             {[:tint_scheme], :unknown_key},
             {[:title], {:type, :string}}
           ]

    assert Surface.new(cells: %{}) == {:error, [{[:cells], :empty}, {[:name], :required}]}
    assert Surface.new(name: "a") == {:error, [{[:cells], :required}]}

    name = "never_an_atom_#{System.unique_integer([:positive])}"

    assert {:ok, _} =
             Surface.new(
               name: "ops",
               cells: %{name => %{component: name, settings: %{name => name}, place: @place}}
             )

    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  @tag verifies: "cells-shape"
  test "a cell builds with its defaults, kind from an atom or its spelling" do
    assert {:ok, %Cell{kind: :content, settings: %{}, slots: %{}, place: nil}} =
             Cell.new(component: "x")

    assert {:ok, %Cell{kind: :navigation}} = Cell.new(component: "x", kind: "navigation")
    assert {:ok, %Cell{kind: :control}} = Cell.new(component: :x, kind: :control)
    assert Cell.keys() == [:component, :kind, :settings, :slots, :place]

    assert {:ok,
            %Cell{
              slots: %{"rows" => %{source: "s", fields: %{"y" => ["a", "b"]}, params: %{}}},
              settings: %{"n" => %{"deep" => [1, nil, true]}}
            }} =
             Cell.new(
               component: "x",
               slots: %{rows: %{source: :s, fields: %{y: [:a, "b"]}}},
               settings: %{n: %{deep: [1, nil, true]}}
             )
  end

  @tag verifies: "cells-shape"
  test "every fault of a bad cell at its path" do
    assert {:error, faults} =
             Cell.new(
               kind: :widget,
               settings: %{"when" => ~U[2026-10-28 00:00:00Z], "who" => :alice},
               slots: %{
                 "rows" => %{fields: %{"x" => 1}, params: %{"p" => {1, 2}}, tint: 1},
                 "other" => :nope
               },
               place: %{x: 0, y: "0", w: 6, depth: 1},
               extra: 1
             )

    assert faults == [
             {[:component], :required},
             {[:extra], :unknown_key},
             {[:kind], {:unknown_kind, :widget}},
             {[:place, :depth], :unknown_key},
             {[:place, :h], :required},
             {[:place, :y], {:type, :integer}},
             {[:settings, "when"], {:not_plain, ~U[2026-10-28 00:00:00Z]}},
             {[:settings, "who"], {:not_plain, :alice}},
             {[:slots, "other"], {:type, :map}},
             {[:slots, "rows", :fields, "x"], {:type, :name}},
             {[:slots, "rows", :params, "p"], {:not_plain, {1, 2}}},
             {[:slots, "rows", :source], :required},
             {[:slots, "rows", :tint], :unknown_key}
           ]
  end

  @tag verifies: "surface-forms"
  test "a surface round-trips through its map and JSON forms, names that spell keys included" do
    s = surface()
    assert Surface.from_map(Surface.to_map(s)) == {:ok, s}
    assert {:ok, json} = Surface.to_json(s)
    assert Surface.from_json(json) == {:ok, s}
    assert %{"$version" => 1, "surface" => %{"cells" => %{"title" => _}}} = JSON.decode!(json)
    assert Surface.current() == 1
  end

  @tag verifies: "surface-forms"
  test "the gates refuse a newer version, a document past a limit and an unknown key" do
    assert {:error, [{[], {:newer_schema, 2, 1}}]} =
             Surface.from_json(~s({"$version": 2, "surface": {}}))

    assert {:error, [{["other"], :unknown_key}]} =
             Surface.from_json(~s({"$version": 1, "surface": {}, "other": 1}))

    assert {:error, [{[:surface], :required}]} = Surface.from_json(~s({"$version": 1}))

    assert {:error, [{[], {:limit, _, _, _} = _}]} =
             Surface.from_json(
               ~s({"$version": 1, "surface": {"name": "#{String.duplicate("a", 100)}"}}),
               limits: [bytes: 20]
             )

    assert {:error, faults} =
             Surface.from_map(%{surface: %{name: "ops", cells: %{"a" => %{component: "x"}}}})

    assert faults == [{[:cells, "a", :place], :required}]
  end

  @tag verifies: "surface-fragment"
  test "stacking a layer adds and replaces cells by name and overrides the title" do
    lower = Surface.fragment(surface())

    higher = %{
      surface: %{
        title: "Overridden",
        cells: %{
          "latency" => %{component: "other", place: @place},
          "extra" => %{component: "x", place: %{@place | y: 2}}
        }
      }
    }

    stacked = Fragment.stack(Surface, [lower, higher])
    assert {:ok, s} = Surface.from_map(Map.put(stacked, :version, 1))
    assert s.title == "Overridden"
    assert Map.keys(s.cells) |> Enum.sort() == ["extra", "latency", "title"]
    assert s.cells["latency"].component == "other"
    assert s.cells["latency"].settings == %{}
  end
end
