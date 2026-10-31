defmodule Macaw.TableTest do
  # The built-in table (spec/05 §6.1), through macaw_component's kit too.
  use ExUnit.Case, async: true

  alias Macaw.Builtin.Table
  alias Macaw.Component
  alias Macaw.Component.{Assigns, Context}
  alias Macaw.Data.Delivery

  @now ~U[2026-10-28 12:00:00Z]
  @rows [
    %{"host" => "b", "ms" => 30, "seen" => ~U[2026-10-28 10:00:00Z]},
    %{"host" => "a", "ms" => nil, "seen" => ~U[2026-10-28 11:00:00Z]},
    %{"host" => "c", "ms" => 10, "seen" => nil}
  ]
  @delivery Delivery.new(@rows, types: %{"host" => :category, "ms" => :number, "seen" => :time})

  use Macaw.Component.Conformance,
    component: Macaw.Builtin.Table,
    now: ~U[2026-10-28 12:00:00Z],
    fixtures: [
      %{
        deliveries: %{
          "rows" =>
            Delivery.new([%{"host" => "a", "ms" => 1}],
              types: %{"host" => :category, "ms" => :number}
            )
        }
      },
      %{
        settings: %{"identity" => "host", "sort" => "ms", "caption" => "Hosts"},
        deliveries: %{
          "rows" =>
            Delivery.new([%{"host" => "a b", "ms" => 2}, %{"host" => "c", "ms" => 1}],
              types: %{"host" => :category, "ms" => :number}
            )
        },
        events: ["sort", "select"]
      }
    ]

  defp html(settings, drawn \\ :live, bindings \\ %{}, schemas \\ %{}) do
    {:ok, settings} = Component.settings(Table, settings)
    {:ok, declarations} = Component.declarations(Table, settings)

    {:ok, context} =
      Context.new(
        mode: :socketless,
        instance: "t1",
        size: {600, 320},
        now: @now,
        bindings: bindings,
        schemas: schemas
      )

    {:ok, assigns} =
      Assigns.new(
        context: context,
        settings: settings,
        declarations: declarations,
        drawn: drawn,
        deliveries: %{"rows" => @delivery},
        value: nil
      )

    assigns |> then(&Table.render(:content, &1)) |> Phoenix.HTML.safe_to_string()
  end

  @tag verifies: "table-declares"
  test "the table's parameters, slot, events, selection, observations, reading load and budget" do
    assert {:ok,
            %{
              "caption" => %{default: "Table"},
              "identity" => %{default: ""},
              "sort" => %{bindable: true},
              "order" => %{values: ["asc", "desc"], bindable: true}
            }} =
             Component.parameters(Table)

    assert {:ok, d} = Component.declarations(Table, %{})
    assert Map.keys(d.slots) == ["rows"]

    assert %{many: true, optional: true, type: [:time, :number, :category, :text, :color, :point]} =
             d.slots["rows"].requires["columns"]

    assert {d.events, d.writes, d.observes, d.reading} ==
             {["sort", "select"], %{"selection" => :identity}, [:activate, :select], :scan}

    assert Component.budget(Table, "rows", %{}, {600, 320}) == {:ok, 40}
    assert Component.budget(Table, "rows", %{}, {600, 32}) == {:ok, 10}
    assert {:ok, %{name: "macaw.table", kinds: [:content]}} = Component.info(Table)
    assert Macaw.Builtin.__members__() == [Table]
  end

  @tag verifies: "table-markup"
  test "a caption, scoped sort buttons, rows in delivered or sorted order, nil last" do
    plain = html(%{"caption" => "Hosts <all>"})
    assert plain =~ ~s(<caption>Hosts &lt;all&gt;</caption>)

    assert plain =~
             ~s(<th scope="col"><button type="button" data-mw-event="sort" value="host">host</button></th>)

    assert order(plain) == ["b", "a", "c"]

    assert order(html(%{"sort" => "ms"})) == ["c", "b", "a"]
    assert order(html(%{"sort" => "ms", "order" => "desc"})) == ["b", "c", "a"]
    assert order(html(%{"sort" => "seen"})) == ["b", "a", "c"]

    assert html(%{"sort" => "ms", "order" => "desc"}) =~
             ~s(<th scope="col" aria-sort="descending"><button)

    assert html(%{"sort" => "ms"}) =~ ~s(<th scope="col" aria-sort="ascending"><button)
    assert order(html(%{"sort" => "nope"})) == ["b", "a", "c"]
    assert plain =~ "<td>2026-10-28T10:00:00Z</td>" and plain =~ "<td></td>"
  end

  @tag verifies: "table-columns"
  test "the columns role chooses the columns and their order; unbound shows every column" do
    headers = fn html ->
      for [_, h] <- Regex.scan(~r/data-mw-event="sort" value="([^"]+)"/, html), do: h
    end

    assert headers.(html(%{})) == ["host", "ms", "seen"]

    chosen = html(%{"identity" => "host"}, :live, %{"rows" => %{"columns" => ["seen", "host"]}})
    assert headers.(chosen) == ["seen", "host"]
    refute chosen =~ "<td>30</td>"

    # The first shown cell holds the select button, whichever column it is.
    assert chosen =~
             ~s(<td><button type="button" data-mw-event="select" value="b">Select b</button> 2026-10-28T10:00:00Z</td><td>b</td>)

    # Sorting by a field not shown still sorts.
    sorted = html(%{"sort" => "ms"}, :live, %{"rows" => %{"columns" => ["host"]}})
    assert sorted =~ "<td>c</td></tr><tr><td>b</td></tr><tr><td>a</td>"
  end

  @tag verifies: "table-columns"
  test "a surface binds the columns; a field its source lacks is a fault at validation" do
    sources = %{
      "lat" => {%Macaw.Test.Rows{rows: [%{"t" => @now, "v" => 1.0, "host" => "a"}]}, nil}
    }

    registry = Macaw.Registry.new!([Macaw.Builtin])

    surface = fn columns ->
      {:ok, s} =
        Macaw.Surface.new(
          name: "hosts",
          cells: %{
            "t" => %{
              component: "macaw.table",
              place: %{x: 0, y: 0, w: 12, h: 4},
              slots: %{"rows" => %{source: "lat", fields: %{"columns" => columns}}}
            }
          }
        )

      s
    end

    {:ok, v} = Macaw.Surface.validate(surface.(["host", "v"]), registry, sources)

    html =
      v
      |> Macaw.Surface.render(sources: sources, now: @now, ceiling: 1_000)
      |> Phoenix.HTML.safe_to_string()

    assert html =~
             ~s|value="host">host</button></th><th scope="col"><button type="button" data-mw-event="sort" value="v">v (ms)</button></th></tr>|

    refute html =~ ~s(value="t">)

    assert {:error, [{[:cells, "t", :slots, "rows", :fields, "columns" | _], _}]} =
             Macaw.Surface.validate(surface.(["host", "hots"]), registry, sources)
  end

  @tag verifies: "table-headers"
  test "a header is the field's label with its unit after it; the sort value stays the field" do
    schema =
      Macaw.Data.Schema.new!(%{
        "host" => %{type: :category, label: "Host <name>"},
        "ms" => %{type: :number, quantity: :duration, label: "Request time", unit: "s"},
        "seen" => %{type: :time}
      })

    html = html(%{"sort" => "ms"}, :live, %{}, %{"rows" => schema})

    assert html =~ ~s(value="host">Host &lt;name&gt;</button></th>)

    assert html =~
             ~s|<th scope="col" aria-sort="ascending"><button type="button" data-mw-event="sort" value="ms">Request time (s)</button></th>|

    assert html =~ ~s(value="seen">seen</button></th>)

    # No schema for the slot: every header is its field.
    plain = html(%{}, :live)
    for f <- ["host", "ms", "seen"], do: assert(plain =~ ~s(value="#{f}">#{f}</button>))
  end

  @tag verifies: "table-stylesheet"
  test "the stylesheet styles what the table emits, in the theme's colors only, at its address" do
    css = Table.stylesheet()
    assert Table.stylesheet_path() == Macaw.Component.Stylesheet.path(css)

    for selector <- [
          ".mw-table{",
          ".mw-table caption",
          ".mw-table th,",
          ".mw-table td{",
          ".mw-table th button",
          ~s(.mw-table th[aria-sort="ascending"]),
          ~s(.mw-table th[aria-sort="descending"]),
          ".mw-table td button"
        ],
        do: assert(css =~ selector, "no rule for #{selector}")

    refute css =~ "url("
    refute css =~ "@import"

    for [_, property, value] <-
          Regex.scan(~r/([a-z-]*color|border[a-z-]*|outline):([^;}]+)[;}]/, css),
        value =~ ~r/#[0-9a-f]{3,6}|rgb|hsl/i,
        do:
          assert(
            value =~ ~r/var\(--mw-[a-z-]+,#[0-9a-f]+\)/,
            "#{property}:#{value} is not a theme property"
          )
  end

  @tag verifies: "table-markup"
  test "an identity gives select buttons and stable ids; a non-live state draws its notice" do
    with_identity = html(%{"identity" => "host"})
    assert with_identity =~ ~s(<tr id="t1-r-#{Base.url_encode64("b", padding: false)}">)

    assert with_identity =~
             ~s(<button type="button" data-mw-event="select" value="b">Select b</button>)

    assert with_identity == html(%{"identity" => "host"})
    refute html(%{}) =~ "data-mw-event=\"select\""

    assert html(%{}, :loading) =~ ~s(data-mw-drawn="loading")
    refute html(%{}, :loading) =~ "<table"
    capped = html(%{}, :capped)
    assert capped =~ ~s(data-mw-drawn="capped") and capped =~ "<table"
  end

  @tag verifies: "table-markup"
  test "end to end: a surface of tables over in-memory sources validates and renders in every mode" do
    rows =
      for i <- 1..30,
          do: %{"t" => DateTime.add(@now, i), "v" => i * 1.0, "host" => "h#{rem(i, 4)}"}

    sources = %{
      "lat" => {%Macaw.Test.Rows{rows: rows}, nil},
      "none" => {%Macaw.Test.Rows{rows: []}, nil}
    }

    {:ok, surface} =
      Macaw.Surface.new(
        name: "hosts",
        title: "Hosts",
        cells: %{
          "all" => %{
            component: "macaw.table",
            settings: %{"caption" => "All", "sort" => "v", "order" => "desc"},
            place: %{x: 0, y: 0, w: 8, h: 4},
            slots: %{"rows" => %{source: "lat"}}
          },
          "empty" => %{
            component: "macaw.table",
            place: %{x: 8, y: 0, w: 4, h: 4},
            slots: %{"rows" => %{source: "none"}}
          }
        }
      )

    {:ok, validated} =
      Macaw.Surface.validate(surface, Macaw.Registry.new!([Macaw.Builtin]), sources)

    for mode <- Macaw.Component.Mode.all() do
      html =
        validated
        |> Macaw.Surface.render(sources: sources, now: @now, ceiling: 1_000, mode: mode)
        |> Phoenix.HTML.safe_to_string()

      assert html =~ ~s(<h2 class="mw-surface-title">Hosts</h2>)
      assert html =~ ~s(id="hosts-all"><table class="mw-table"><caption>All</caption>)
      assert length(Regex.scan(~r/<tr>/, html)) == 1 + 30
      assert html =~ ~s(id="hosts-empty"><p class="mw-drawn mw-drawn-no-data")
      refute html =~ "style="
    end
  end

  defp order(html),
    do:
      for(
        [_, host] <-
          Regex.scan(~r/<tr[^>]*><td>(?:<button[^>]*>[^<]*<\/button> )?([a-c])<\/td>/, html),
        do: host
      )
end
