defmodule Macaw.FeedTest do
  # The built-in feed (spec/05 §6.6), through macaw_component's kit too, and every built-in on
  # one surface.
  use ExUnit.Case, async: true

  alias Macaw.Builtin.{Feed, Text}
  alias Macaw.Component
  alias Macaw.Component.{Assigns, Context, Drawn}
  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.{Registry, Surface}

  @now ~U[2026-11-04 12:00:00Z]

  @schema Schema.new!(%{
            "at" => %{type: :time, window: true},
            "what" => %{type: :text},
            "more" => %{type: :text},
            "how" => %{
              type: :category,
              values: [%{value: "err", name: "Error"}, "ok", "note"],
              status: %{"err" => :bad, "ok" => :good}
            },
            "n" => %{type: :number}
          })

  # Oldest first, as a source holds them.
  @rows (for i <- 1..5 do
           %{
             "at" => DateTime.add(~U[2026-11-04 11:00:00Z], i * 60),
             "what" => "event <#{i}>",
             "more" => if(i == 5, do: "the body"),
             "how" => Enum.at(["ok", "note", "ok", "note", "err"], i - 1),
             "n" => i
           }
         end)

  @fields %{"t" => "at", "title" => "what", "body" => "more", "level" => "how"}

  defmodule Kit do
    use ExUnit.Case, async: true

    use Macaw.Component.Conformance,
      component: Macaw.Builtin.Feed,
      now: ~U[2026-11-04 12:00:00Z],
      fixtures: [
        %{
          bindings: %{"rows" => %{"t" => "at", "title" => "what"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!([%{"at" => ~U[2026-11-04 11:00:00Z], "what" => "a"}],
                types: %{"at" => :time, "what" => :text}
              )
          }
        },
        %{
          settings: %{"label" => "Log", "limit" => 2},
          bindings: %{"rows" => %{"t" => "at", "title" => "what", "level" => "how"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!(
                [%{"at" => ~U[2026-11-04 11:00:00Z], "what" => "a", "how" => "ok"}],
                types: %{"at" => :time, "what" => :text, "how" => :category}
              )
          }
        }
      ]
  end

  defp html(settings, opts \\ []) do
    {:ok, settings} = Component.settings(Feed, settings)
    {:ok, declarations} = Component.declarations(Feed, settings)

    {:ok, context} =
      Context.new(
        mode: :socketless,
        instance: "f1",
        size: {300, 128},
        now: @now,
        heading_level: 3,
        bindings: %{"rows" => Keyword.get(opts, :fields, @fields)},
        schemas: %{"rows" => @schema}
      )

    {:ok, assigns} =
      Assigns.new(
        context: context,
        settings: settings,
        declarations: declarations,
        drawn: Keyword.get(opts, :drawn, :live),
        deliveries: %{"rows" => Keyword.get(opts, :delivery, Delivery.new!(Enum.reverse(@rows)))},
        value: nil
      )

    assigns |> then(&Feed.render(:content, &1)) |> Phoenix.HTML.safe_to_string()
  end

  defp page(settings, supports) do
    sources = %{"s" => {%Macaw.Test.Rows{schema: @schema, rows: @rows, supports: supports}, nil}}

    surface =
      Surface.build!("p",
        cells: [
          {"macaw.feed", source: "s", settings: settings, fields: Map.delete(@fields, "t")}
        ]
      )

    {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)

    v
    |> Surface.render(sources: sources, now: @now, ceiling: 1_000)
    |> Phoenix.HTML.safe_to_string()
  end

  defp titles(html),
    do: Regex.scan(~r/class="mw-feed-title">([^<]*)</, html) |> Enum.map(&List.last/1)

  @tag verifies: "feed-declares"
  test "the feed's parameters, roles, reading load, order, budget and membership are as declared" do
    assert {:ok, %{"label" => "", "limit" => 20}} = Component.settings(Feed, %{})
    {:ok, info} = Component.info(Feed)
    assert {info.name, info.kinds} == {"macaw.feed", [:content]}
    {:ok, d} = Component.declarations(Feed, %{})
    assert d.reading == :scan
    assert Map.keys(d.slots) == ["rows"]
    assert Feed in Macaw.Builtin.__members__()

    assert Component.resolve_order(Feed, "rows", %{}, @fields) == {:ok, [{"at", :desc}]}
    assert {:ok, 3} = Component.budget(Feed, "rows", %{"limit" => 3}, {300, 128})

    for bad <- [0, -1, 2.5] do
      assert {:error, [{["limit"], {:type, :pos_integer}}]} =
               Component.declarations(Feed, %{"limit" => bad})
    end
  end

  @tag verifies: "feed-declares"
  test "a surface checks the roles against the source's schema" do
    sources = %{"s" => {%Macaw.Test.Rows{schema: @schema, rows: @rows}, nil}}
    registry = Registry.new!([Macaw.Builtin])

    cell = fn fields ->
      Surface.build!("p", cells: [{"macaw.feed", source: "s", fields: fields}])
    end

    assert {:ok, _} = Surface.validate(cell.(%{"title" => "what"}), registry, sources)
    assert {:error, faults} = Surface.validate(cell.(%{"title" => "n"}), registry, sources)
    assert Enum.any?(faults, &match?({[:cells, _, :fields, "title" | _], _}, &1))
    assert {:error, faults} = Surface.validate(cell.(%{"title" => "nope"}), registry, sources)
    assert Enum.any?(faults, &match?({[:cells, _, :fields, "title" | _], _}, &1))
  end

  @tag verifies: "feed-reads"
  test "on a surface, the newest limit rows, newest first, whoever orders them, with no capped notice" do
    for supports <- [[:budget, :order], []] do
      html = page(%{"limit" => 2}, supports)

      assert titles(html) == ["event &lt;5&gt;", "event &lt;4&gt;"],
             "#{inspect(supports)}: #{html}"

      refute html =~ Drawn.words(:capped), inspect(supports)
    end
  end

  @tag verifies: "feed-reads"
  test "a sample and a source's own capped keep the notice" do
    capped = Drawn.words(:capped)
    sample = Delivery.new!(@rows, served: [reduced_by: :source, ordered: :sample])
    assert html(%{}, drawn: :capped, delivery: sample) =~ capped
    short = Delivery.new!(@rows, served: [capped: true])
    assert html(%{}, drawn: :capped, delivery: short) =~ capped
    whole = Delivery.new!(@rows, served: [reduced_by: :runtime, ordered: :runtime])
    refute html(%{}, drawn: :capped, delivery: whole) =~ capped
  end

  @tag verifies: "feed-markup"
  test "a heading with a label, then times, titles, bodies and a level's role and words" do
    html = html(%{"label" => "Log <1>", "limit" => 5})

    assert html =~ ~s(<div class="mw-feed"><h3 class="mw-feed-label">Log &lt;1&gt;</h3><ol>)
    # Its role, its display name, and a body when it has one.
    assert html =~
             ~s(<li class="mw-feed-item mw-feed-bad"><time datetime="2026-11-04T11:05:00Z">2026-11-04T11:05:00Z</time><p class="mw-feed-title">event &lt;5&gt;</p><p class="mw-feed-level">Error</p><p class="mw-feed-body">the body</p></li>)

    # A role from the schema with no name, and no role: neutral, its words still shown.
    assert html =~ ~s(mw-feed-item mw-feed-good)
    assert html =~ ~s(mw-feed-item mw-feed-neutral)
    assert html =~ ~s(<p class="mw-feed-level">note</p>)
    refute html =~ "style="
    refute html(%{}) =~ "<h3"
  end

  @tag verifies: "feed-markup"
  test "with no level or body bound, an item is its time and title" do
    html = html(%{"limit" => 1}, fields: %{"t" => "at", "title" => "what"})

    assert html ==
             ~s(<div class="mw-feed"><ol><li class="mw-feed-item"><time datetime="2026-11-04T11:05:00Z">2026-11-04T11:05:00Z</time><p class="mw-feed-title">event &lt;5&gt;</p></li></ol></div>)
  end

  @tag verifies: "feed-markup"
  test "stale draws its notice above the list; other states the notice alone; no rows no_data" do
    [notice, _list] = String.split(html(%{}, drawn: :stale), ~s(<div class="mw-feed">), parts: 2)
    assert notice =~ Drawn.words(:stale)

    for drawn <- [:loading, :down, :invalid, :no_data],
        do: refute(html(%{}, drawn: drawn) =~ "<ol>")

    assert html(%{}, delivery: Delivery.new!([])) =~ Drawn.words(:no_data)
  end

  @tag verifies: "feed-stylesheet"
  test "the stylesheet styles what it emits, in the theme's colors only, at its address" do
    css = Feed.stylesheet()
    assert Feed.stylesheet_path() == Macaw.Component.Stylesheet.path(css)

    selectors =
      [".mw-feed{", ".mw-feed-label{", ".mw-feed ol{", ".mw-feed-item{", ".mw-feed-title"] ++
        Enum.map(Macaw.Builtin.StatusGrid.roles(), &".mw-feed-#{&1}{")

    for selector <- selectors, do: assert(css =~ selector, "no rule for #{selector}")
    refute css =~ "url("
    refute css =~ "@import"

    for [_, value] <- Regex.scan(~r/color:([^;}]+)[;}]/, css),
        do: assert(value =~ ~r/var\(--mw-[a-z-]+,#[0-9a-f]+\)/, value)
  end

  @tag verifies: "status-grid-markup"
  test "a state's role and words, one way for the grid and the feed" do
    assert Text.role(@schema, "how", "err") == "bad"
    assert Text.role(@schema, "how", "note") == "neutral"
    assert Text.role(@schema, "how", nil) == "neutral"
    assert Text.role(nil, "how", "err") == "neutral"
    assert Text.words(@schema, "how", "err") == "Error"
    assert Text.words(@schema, "how", "ok") == "ok"
    assert Text.words(@schema, "how", nil) == "–"
    assert Text.words(nil, "how", "err") == "err"
  end

  @tag verifies: "builtins-end-to-end"
  test "every built-in on one surface validates and renders in every mode, with no inline style" do
    grid =
      Schema.new!(%{
        "host" => %{type: :category, identity: true},
        "state" => %{type: :category, status: %{"up" => :good}}
      })

    sources = %{
      "s" => {%Macaw.Test.Rows{schema: @schema, rows: @rows, supports: [:budget, :order]}, nil},
      "g" => {%Macaw.Test.Rows{schema: grid, rows: [%{"host" => "a", "state" => "up"}]}, nil}
    }

    surface =
      Surface.build!("all",
        cells: [
          {"macaw.table", source: "s"},
          {"macaw.status_grid", source: "g", fields: %{"name" => "host", "status" => "state"}},
          {"macaw.stat", source: "s", fields: %{"value" => "n"}},
          {"macaw.meter", source: "s", settings: %{"max" => 10}, fields: %{"value" => "n"}},
          {"macaw.record", source: "g", settings: %{"identity" => "a"}},
          {"macaw.feed", source: "s", fields: %{"title" => "what"}}
        ]
      )

    {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)
    names = for {name, _} <- Registry.components(Registry.new!([Macaw.Builtin])), do: name

    assert Enum.sort(names) ==
             ~w(macaw.feed macaw.meter macaw.record macaw.stat macaw.status_grid macaw.table)

    for mode <- [:live, :socketless, :neutral, :print] do
      html =
        v
        |> Surface.render(sources: sources, now: @now, ceiling: 1_000, mode: mode)
        |> Phoenix.HTML.safe_to_string()

      for mark <- ["<table", "mw-status-good", "<data", "<meter", "<dl>", "<ol>"],
          do: assert(html =~ mark, "#{mode}: no #{mark}")

      refute html =~ "style="
    end
  end
end
