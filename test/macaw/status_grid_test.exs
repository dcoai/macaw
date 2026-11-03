defmodule Macaw.StatusGridTest do
  # The built-in status grid (spec/05 §6.2), through macaw_component's kit too.
  use ExUnit.Case, async: true

  alias Macaw.Builtin.StatusGrid
  alias Macaw.Component
  alias Macaw.Component.{Assigns, Context}
  alias Macaw.Data.{Delivery, Schema}

  @now ~U[2026-11-03 12:00:00Z]

  @schema Schema.new!(%{
            "host" => %{type: :category, identity: true, label: "Host"},
            "state" => %{
              type: :category,
              values: [%{value: "up", name: "Up"}, "degraded", "down", "unknown"],
              status: %{"up" => :good, "degraded" => :warning, "down" => :bad}
            },
            "p50" => %{type: :number, unit: "ms", label: "Median"}
          })

  @rows [
    %{"host" => "web-2", "state" => "down", "p50" => nil},
    %{"host" => "api", "state" => "up", "p50" => 42},
    %{"host" => "db", "state" => "unknown", "p50" => 7},
    %{"host" => "web-1", "state" => "degraded", "p50" => 130},
    %{"host" => "cache", "state" => nil, "p50" => 1}
  ]

  use Macaw.Component.Conformance,
    component: Macaw.Builtin.StatusGrid,
    now: ~U[2026-11-03 12:00:00Z],
    fixtures: [
      %{
        deliveries: %{
          "rows" =>
            Delivery.new!([%{"name" => "a", "status" => "up"}],
              types: %{"name" => :category, "status" => :category}
            )
        }
      },
      %{
        settings: %{"label" => "Hosts"},
        deliveries: %{
          "rows" =>
            Delivery.new!(
              [%{"name" => "a b", "status" => "down"}, %{"name" => "c", "status" => nil}],
              types: %{"name" => :category, "status" => :category}
            )
        }
      }
    ]

  @bindings %{"rows" => %{"name" => "host", "status" => "state", "detail" => "p50"}}

  defp html(settings, drawn \\ :live, rows \\ @rows, schemas \\ %{"rows" => @schema}) do
    {:ok, settings} = Component.settings(StatusGrid, settings)
    {:ok, declarations} = Component.declarations(StatusGrid, settings)

    {:ok, context} =
      Context.new(
        mode: :socketless,
        instance: "g1",
        size: {600, 256},
        now: @now,
        heading_level: 3,
        bindings: @bindings,
        schemas: schemas
      )

    {:ok, assigns} =
      Assigns.new(
        context: context,
        settings: settings,
        declarations: declarations,
        drawn: drawn,
        deliveries: %{"rows" => Delivery.new!(rows)},
        value: nil
      )

    assigns |> then(&StatusGrid.render(:content, &1)) |> Phoenix.HTML.safe_to_string()
  end

  @tag verifies: "status-grid-declares"
  test "the grid's parameters, roles and reading load are as declared" do
    assert {:ok, %{"label" => ""}} = Component.settings(StatusGrid, %{})
    {:ok, info} = Component.info(StatusGrid)
    assert {info.name, info.kinds} == {"macaw.status_grid", [:content]}

    {:ok, d} = Component.declarations(StatusGrid, %{})
    assert d.reading == :glance
    assert Map.keys(d.slots) == ["rows"]
    assert {:ok, nil} = Component.budget(StatusGrid, "rows", %{}, {600, 256})
    assert Macaw.Builtin.StatusGrid in Macaw.Builtin.__members__()
  end

  @tag verifies: "status-grid-markup"
  test "one tile per thing in name order, its role from the schema, its words always shown" do
    html = html(%{"label" => "Hosts"})

    assert html =~ ~s(<div class="mw-status-grid"><h3>Hosts</h3><ul>)

    # In the name field's order, as a source orders a category: by its spelling.
    names = Regex.scan(~r/class="mw-status-name">([^<]*)</, html) |> Enum.map(&List.last/1)
    assert names == ["api", "cache", "db", "web-1", "web-2"]

    for {host, role, words} <- [
          {"api", "good", "Up"},
          {"web-1", "warning", "degraded"},
          {"web-2", "bad", "down"},
          {"db", "neutral", "unknown"},
          {"cache", "neutral", "–"}
        ] do
      id = "g1-s-" <> Base.url_encode64(host, padding: false)

      assert html =~
               ~s(<li class="mw-status-tile mw-status-#{role}" id="#{id}"><p class="mw-status-name">#{host}</p><p class="mw-status-state">#{words}</p>),
             "#{host}: #{html}"
    end

    # The detail with its unit's symbol; none for a nil detail.
    assert html =~ ~s(<p class="mw-status-detail">42 ms</p>)
    refute html =~ ~s(web-2</p><p class="mw-status-state">down</p><p class="mw-status-detail">)

    # No label, no heading; no inline style anywhere.
    refute html(%{}) =~ "<h3>"
    refute html =~ "style="
  end

  @tag verifies: "status-grid-markup"
  test "a role that spells no class is drawn neutral; with no schema the tiles are as delivered" do
    odd =
      Schema.new!(%{
        "host" => %{type: :category, identity: true},
        "state" => %{type: :category, status: %{"up" => "Not A Class!", "down" => "maintenance"}}
      })

    rows = [%{"host" => "b", "state" => "up"}, %{"host" => "a", "state" => "down"}]
    html = html(%{}, :live, rows, %{"rows" => odd})
    assert html =~ ~s(mw-status-neutral" id="g1-s-Yg")
    # A theme's own word is still a class: the theme may style it.
    assert html =~ ~s(mw-status-maintenance" id="g1-s-YQ")

    plain = html(%{}, :live, rows, %{})
    names = Regex.scan(~r/class="mw-status-name">([^<]*)</, plain) |> Enum.map(&List.last/1)
    assert names == ["b", "a"]
  end

  @tag verifies: "status-grid-markup"
  test "every non-live state draws its notice; capped and stale draw it above the tiles" do
    for drawn <- [:capped, :stale] do
      html = html(%{}, drawn)
      assert html =~ "mw-status-tile"
      [notice, _rest] = String.split(html, ~s(<div class="mw-status-grid">), parts: 2)
      assert notice != ""
    end

    for drawn <- [:loading, :down, :invalid, :no_data] do
      html = html(%{}, drawn)
      refute html =~ "mw-status-tile"
      assert html != ""
    end

    assert html(%{}, :live, []) == html(%{}, :no_data, [])
  end

  @tag verifies: "status-grid-declares"
  test "a surface checks the roles against the source's schema before anything is fetched" do
    sources = %{"hosts" => {%Macaw.Test.Rows{schema: @schema, rows: @rows}, nil}}
    registry = Macaw.Registry.new!([Macaw.Builtin])

    cell = fn fields ->
      Macaw.Surface.build!("hosts",
        cells: [{"macaw.status_grid", source: "hosts", fields: fields}]
      )
    end

    {:ok, v} =
      Macaw.Surface.validate(cell.(%{"name" => "host", "status" => "state"}), registry, sources)

    html =
      v
      |> Macaw.Surface.render(sources: sources, now: @now, ceiling: 1_000)
      |> Phoenix.HTML.safe_to_string()

    assert html =~ ~s(mw-status-good)

    # A status bound to a number, and a field the source lacks, are faults at their roles.
    assert {:error, faults} =
             Macaw.Surface.validate(
               cell.(%{"name" => "host", "status" => "p50"}),
               registry,
               sources
             )

    assert Enum.any?(faults, &match?({[:cells, _, :fields, "status" | _], _}, &1))

    assert {:error, faults} =
             Macaw.Surface.validate(
               cell.(%{"name" => "hots", "status" => "state"}),
               registry,
               sources
             )

    assert Enum.any?(faults, &match?({[:cells, _, :fields, "name" | _], _}, &1))
  end

  @tag verifies: "status-grid-stylesheet"
  test "the stylesheet styles what the grid emits, in the theme's colors only, at its address" do
    css = StatusGrid.stylesheet()
    assert StatusGrid.stylesheet_path() == Macaw.Component.Stylesheet.path(css)

    for selector <-
          [".mw-status-grid{", ".mw-status-grid ul{", ".mw-status-tile{", ".mw-status-name{"] ++
            Enum.map(StatusGrid.roles(), &".mw-status-#{&1}{"),
        do: assert(css =~ selector, "no rule for #{selector}")

    refute css =~ "url("
    refute css =~ "@import"

    for [_, property, value] <-
          Regex.scan(~r/([a-z-]*color|border[a-z-]*):([^;}]+)[;}]/, css),
        value =~ ~r/#[0-9a-f]{3,6}|rgb|hsl/i,
        do:
          assert(
            value =~ ~r/var\(--mw-[a-z-]+,#[0-9a-f]+\)/,
            "#{property}:#{value} is not a theme property"
          )
  end
end
