defmodule Macaw.ValidateTest do
  # Validating a surface: the static pass (spec/06 §3.4).
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Surface.Validated
  alias Macaw.Test.{Note, Rows, Series, SurfacePackage}

  @registry Registry.new!([SurfacePackage])
  @params %{"agg" => %{type: :category, values: ["max", "mean"], default: "mean"}}

  defp sources(extra \\ %{}) do
    Map.merge(
      %{"latency" => {%Rows{params: @params}, nil}, "down" => {%Rows{mode: :undescribable}, nil}},
      extra
    )
  end

  defp surface(cells) do
    {:ok, s} = Surface.new(name: "ops", title: "Ops", cells: cells)
    s
  end

  defp place(x, y), do: %{x: x, y: y, w: 6, h: 2}

  @tag verifies: "validate-pass"
  test "a surface of known components bound to described sources validates" do
    s =
      surface(%{
        "note" => %{component: "test.note", settings: %{"text" => "Hi"}, place: place(0, 2)},
        "lat" => %{
          component: "test.series",
          place: place(6, 0),
          slots: %{
            "points" => %{source: "latency", fields: %{"y" => "v"}, params: %{"agg" => "max"}}
          }
        },
        "first" => %{component: "test.note", kind: :navigation, place: place(0, 0)}
      })

    assert {:ok, %Validated{surface: ^s, order: ["first", "lat", "note"], cells: cells}} =
             Surface.validate(s, @registry, sources())

    assert %{module: Note, settings: %{"text" => "Hi"}, slots: %{}} = cells["note"]
    assert %{module: Series, declarations: %{slots: %{"points" => _}}} = cells["lat"]

    assert %{
             source: "latency",
             fields: %{"y" => "v"},
             params: %{"agg" => "max"},
             description: description
           } =
             cells["lat"].slots["points"]

    assert description.schema == Rows.default_schema()

    # Params default from the description.
    s2 =
      surface(%{
        "lat" => %{
          component: "test.series",
          place: place(0, 0),
          slots: %{"points" => %{source: "latency", fields: %{"y" => "v"}}}
        }
      })

    assert {:ok, %{cells: %{"lat" => %{slots: %{"points" => %{params: %{"agg" => "mean"}}}}}}} =
             Surface.validate(s2, @registry, sources())
  end

  @tag verifies: "validate-faults"
  test "every fault of a bad surface at once, by path" do
    s =
      surface(%{
        "a" => %{component: "test.nothing", place: place(0, 0)},
        "b" => %{component: "test.series", kind: :control, place: place(6, 0)},
        "c" => %{
          component: "test.note",
          settings: %{"text" => 7, "size" => 1},
          place: place(0, 2)
        },
        "d" => %{component: "test.series", place: place(6, 2)},
        "e" => %{
          component: "test.note",
          place: place(0, 4),
          slots: %{"extra" => %{source: "latency"}}
        },
        "f" => %{
          component: "test.series",
          place: place(6, 4),
          slots: %{"points" => %{source: "nowhere"}}
        },
        "g" => %{
          component: "test.series",
          place: place(0, 6),
          slots: %{"points" => %{source: "down"}}
        },
        "h" => %{
          component: "test.series",
          place: place(6, 6),
          slots: %{
            "points" => %{source: "latency", fields: %{"y" => "host"}, params: %{"agg" => "sum"}}
          }
        },
        "i" => %{component: "test.note", place: %{x: 3, y: 6, w: 6, h: 1}}
      })

    assert {:error, faults} = Surface.validate(s, @registry, sources())

    assert faults == [
             {[:cells, "a", :component], {:unknown_component, "test.nothing"}},
             {[:cells, "b", :kind], {:kind_not_offered, :control, [:content]}},
             {[:cells, "b", :slots, "points"], :unbound},
             {[:cells, "c", :settings, "size"], :unknown_param},
             {[:cells, "c", :settings, "text"], {:type, :text}},
             {[:cells, "d", :slots, "points"], :unbound},
             {[:cells, "e", :slots, "extra"], :unknown_slot},
             {[:cells, "f", :slots, "points", :source], {:unknown_source, "nowhere"}},
             {[:cells, "g", :slots, "points", :source], {:describe, :unreachable}},
             {[:cells, "h", :place], {:overlap, "i"}},
             {[:cells, "h", :slots, "points", :fields, "y"], {:type, [:number], :category}},
             {[:cells, "h", :slots, "points", :params, "agg"], {:enum, ["max", "mean"]}},
             {[:cells, "i", :place], {:overlap, "g"}}
           ]
  end

  @tag verifies: "validate-independent"
  test "one cell failing every check reports each, and what it couldn't check" do
    s =
      surface(%{
        "x" => %{
          component: "test.series",
          kind: :control,
          settings: %{"label" => 7},
          place: place(0, 0),
          slots: %{
            "points" => %{source: "nowhere"},
            "extra" => %{source: "latency", params: %{"agg" => "sum"}}
          }
        },
        "y" => %{
          component: "test.nothing",
          place: place(6, 0),
          slots: %{"points" => %{source: "down"}}
        }
      })

    assert {:error, faults} = Surface.validate(s, @registry, sources())

    assert faults == [
             {[:cells, "x", :kind], {:kind_not_offered, :control, [:content]}},
             {[:cells, "x", :settings, "label"], {:type, :text}},
             {[:cells, "x", :slots], {:unchecked, :settings}},
             {[:cells, "x", :slots, "extra", :params, "agg"], {:enum, ["max", "mean"]}},
             {[:cells, "x", :slots, "points", :source], {:unknown_source, "nowhere"}},
             {[:cells, "y", :component], {:unknown_component, "test.nothing"}},
             {[:cells, "y", :slots], {:unchecked, :component}},
             {[:cells, "y", :slots, "points", :source], {:describe, :unreachable}}
           ]
  end
end
