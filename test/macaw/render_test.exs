defmodule Macaw.RenderTest do
  # Fetching and rendering a surface (spec/06 §3.5, §3.6).
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Data.{Delivery, Table}
  alias Macaw.Test.{Rows, SurfacePackage}

  @registry Registry.new!([SurfacePackage])
  @now ~U[2026-10-28 12:00:00Z]

  defp rows(n),
    do:
      for(
        i <- 1..n,
        do: %{"t" => DateTime.add(@now, i * 60), "v" => i * 1.0, "host" => "h#{rem(i, 3)}"}
      )

  defp validated(cells, sources, title \\ "Operations") do
    {:ok, s} = Surface.new(name: "ops", title: title, cells: cells)
    {:ok, v} = Surface.validate(s, @registry, sources)
    v
  end

  defp series(x, y, w, source, params \\ %{}),
    do: %{
      component: "test.series",
      place: %{x: x, y: y, w: w, h: 2},
      slots: %{"points" => %{source: source, fields: %{"y" => "v"}, params: params}}
    }

  defp env(sources, extra \\ []),
    do: Keyword.merge([sources: sources, now: @now, ceiling: 1_000], extra)

  @tag verifies: "fetch-budgets"
  test "each slot is fetched at its budget at its cell's size, clamped to the ceiling" do
    sources = %{"lat" => {%Rows{rows: rows(500), notify: self(), name: "lat"}, nil}}
    # Series' budget is a tenth of its width: 6 columns of 1200 px is 600 px, 60 rows.
    v = validated(%{"a" => series(0, 0, 6, "lat")}, sources)
    fetched = Surface.fetch(v, env(sources))
    assert_received {:fetched, "lat", 60, %{}}
    assert Table.size(fetched["a"].deliveries["points"] |> Macaw.Data.Delivery.table!()) == 60
    assert fetched["a"].drawn == :capped

    # Wide enough to ask more than the ceiling: clamped and marked runtime.
    fetched = Surface.fetch(v, env(sources, width: 24_000, ceiling: 100))
    assert_received {:fetched, "lat", 100, %{}}
    assert fetched["a"].deliveries["points"].served.reduced_by == :runtime
  end

  @tag verifies: "fetch-budgets"
  test "slots sharing a source and params are fetched once, at the largest budget, each reduced" do
    sources = %{
      "lat" =>
        {%Rows{
           rows: rows(500),
           notify: self(),
           name: "lat",
           params: %{"p" => %{type: :number, default: 1}}
         }, nil}
    }

    v =
      validated(
        %{
          "wide" => series(0, 0, 12, "lat"),
          "narrow" => series(0, 2, 2, "lat"),
          "other" => series(2, 2, 2, "lat", %{"p" => 2})
        },
        sources
      )

    fetched = Surface.fetch(v, env(sources))
    assert_received {:fetched, "lat", 120, %{"p" => 1}}
    assert_received {:fetched, "lat", 20, %{"p" => 2}}
    refute_received {:fetched, "lat", _, _}
    assert Table.size(fetched["wide"].deliveries["points"] |> Macaw.Data.Delivery.table!()) == 120
    # LTTB reduces each host's series, never past the reader's budget.
    assert Table.size(fetched["narrow"].deliveries["points"] |> Macaw.Data.Delivery.table!()) in 1..20
    assert fetched["narrow"].deliveries["points"].served.reduced_by == :runtime
  end

  @tag verifies: "fetch-drawn"
  @tag :capture_log
  test "each failure draws its state; a cell's state is its slots' highest; no slots is live" do
    sources = %{
      "error" => {%Rows{mode: :error}, nil},
      "crash" => {%Rows{mode: :crash}, nil},
      "hang" => {%Rows{mode: :hang}, nil},
      "capped" => {%Rows{mode: :capped, rows: rows(3)}, nil},
      "empty" => {%Rows{rows: []}, nil},
      "fine" => {%Rows{rows: rows(3)}, nil}
    }

    cells =
      for(
        {name, i} <- Enum.with_index(Map.keys(sources)),
        into: %{},
        do: {name, series(0, i * 2, 12, name)}
      )
      |> Map.put("note", %{component: "test.note", place: %{x: 0, y: 20, w: 12, h: 1}})

    fetched = Surface.fetch(validated(cells, sources), env(sources, timeout: 100))

    assert Map.new(fetched, fn {cell, %{drawn: d}} -> {cell, d} end) == %{
             "error" => :down,
             "crash" => :down,
             "hang" => :loading,
             "capped" => :capped,
             "empty" => :no_data,
             "fine" => :live,
             "note" => :live
           }

    assert fetched["hang"].deliveries == %{}
  end

  @tag verifies: "fetch-drawn"
  test "a component's bad budget draws its cell invalid" do
    defmodule BadBudget do
      @moduledoc false
      use Macaw.Component, name: "test.bad_budget", kinds: [:content]
      @impl true
      def declarations(_s), do: {:ok, slots: %{"rows" => %{}}}
      @impl true
      def budget(_slot, _s, _size), do: 0
      @impl true
      def render(:content, a), do: Macaw.Component.Drawn.render(a.drawn, a.context)
    end

    defmodule BadPackage do
      @moduledoc false
      def __members__, do: [Macaw.RenderTest.BadBudget]
    end

    sources = %{"fine" => {%Rows{rows: rows(3), notify: self()}, nil}}

    {:ok, s} =
      Surface.new(
        name: "s",
        cells: %{
          "b" => %{
            component: "test.bad_budget",
            place: %{x: 0, y: 0, w: 1, h: 1},
            slots: %{"rows" => %{source: "fine"}}
          }
        }
      )

    {:ok, v} = Surface.validate(s, Registry.new!([BadPackage]), sources)
    assert Surface.fetch(v, env(sources))["b"].drawn == :invalid
    refute_received {:fetched, _, _, _}
  end

  @tag verifies: "render-markup"
  test "a surface renders its title and its cells in reading order, nothing inline, in every mode" do
    sources = %{"lat" => {%Rows{rows: rows(5)}, nil}}

    v =
      validated(
        %{
          "b" => %{component: "test.note", place: %{x: 6, y: 0, w: 6, h: 1}},
          "a" => series(0, 0, 6, "lat"),
          "c" => %{
            component: "test.note",
            settings: %{"text" => "<b>"},
            place: %{x: 0, y: 2, w: 12, h: 1}
          }
        },
        sources
      )

    for mode <- Macaw.Component.Mode.all() do
      html = v |> Surface.render(env(sources, mode: mode)) |> Phoenix.HTML.safe_to_string()

      assert html =~
               ~s(<div class="mw-surface" id="ops"><h2 class="mw-surface-title">Operations</h2><div class="mw-grid">)

      assert [_, a, b, c] = String.split(html, ~s(<div class="mw-cell ))
      assert a =~ ~s(mw-col-1 mw-span-6 mw-row-1 mw-rows-2" id="ops-a">)
      assert b =~ ~s(mw-col-7 mw-span-6 mw-row-1 mw-rows-1" id="ops-b">)
      assert c =~ ~s(id="ops-c"><p>&lt;b&gt;</p>)
      refute html =~ "style"
      refute html =~ "<script"
    end

    html =
      %{"n" => %{component: "test.note", place: %{x: 0, y: 0, w: 1, h: 1}}}
      |> validated(%{}, nil)
      |> Surface.render(env(%{}, heading_level: 3))
      |> Phoenix.HTML.safe_to_string()

    refute html =~ "mw-surface-title"
  end

  @tag verifies: "render-cells"
  test "each cell renders with its context, its drawn state and its deliveries or value" do
    sources = %{"lat" => {%Rows{rows: rows(7)}, nil}, "error" => {%Rows{mode: :error}, nil}}

    v =
      validated(
        %{
          "a" => series(0, 0, 6, "lat"),
          "down" => series(6, 0, 6, "error"),
          "count" => %{
            component: "test.counter",
            place: %{x: 0, y: 2, w: 4, h: 1},
            slots: %{"rows" => %{source: "lat"}}
          }
        },
        sources
      )

    html = v |> Surface.render(env(sources, heading_level: 3)) |> Phoenix.HTML.safe_to_string()
    # The series' own heading is one below the surface's title.
    assert html =~ ~s(<h3 class="mw-surface-title">) and html =~ "<h4>Series</h4><p>7 points</p>"
    assert html =~ ~s(data-mw-drawn="down")
    assert html =~ "<p>7 rows</p>"

    # Without a title, cells take the title's level.
    v2 = validated(%{"a" => series(0, 0, 6, "lat")}, sources, nil)

    assert v2 |> Surface.render(env(sources)) |> Phoenix.HTML.safe_to_string() =~
             "<h2>Series</h2>"

    # The contained value saw its instance, declared size and the delivery.
    fetched = Surface.fetch(v, env(sources))
    assert %Delivery{} = fetched["count"].deliveries["rows"]

    html =
      v |> Surface.render(fetched, env(sources, mode: :neutral)) |> Phoenix.HTML.safe_to_string()

    assert html =~ ~s(id="ops-count"><p>7 rows</p>)
  end

  @tag verifies: "render-bindings"
  test "each cell's context carries its slots' bindings, resolved, for pure and contained cells" do
    schema =
      Macaw.Data.Schema.new!(%{
        "t" => %{type: :time},
        "v" => %{type: :number},
        "w" => %{type: :number}
      })

    rows = for i <- 1..3, do: %{"t" => DateTime.add(@now, i * 60), "v" => 1.0, "w" => i * 10.0}
    sources = %{"lat" => {%Rows{schema: schema, rows: rows}, nil}}
    registry = Registry.new!([SurfacePackage, Macaw.Test.BoundPackage])
    slot = %{source: "lat", fields: %{"y" => "w"}}

    {:ok, s} =
      Surface.new(
        name: "ops",
        cells: %{
          "pure" => %{
            component: "test.bound",
            place: %{x: 0, y: 0, w: 6, h: 2},
            slots: %{"points" => slot}
          },
          "held" => %{
            component: "test.bound_counter",
            place: %{x: 6, y: 0, w: 6, h: 2},
            slots: %{"points" => slot}
          }
        }
      )

    {:ok, v} = Surface.validate(s, registry, sources)
    # The unbound window role holds the window field; the unbound optional role is absent.
    assert v.cells["pure"].slots["points"].fields == %{"x" => "t", "y" => "w"}

    html = v |> Surface.render(env(sources)) |> Phoenix.HTML.safe_to_string()
    assert html =~ "<p>x=t y=w label=nil sum=60.0</p>"
    assert html =~ "<p>reads w</p>"
  end
end
