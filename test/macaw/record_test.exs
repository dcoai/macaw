defmodule Macaw.RecordTest do
  # The built-in record (spec/05 §6.5), through macaw_component's kit too.
  use ExUnit.Case, async: true

  alias Macaw.Builtin.{Record, Text}
  alias Macaw.Component
  alias Macaw.Component.{Assigns, Context, Drawn}
  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.{Registry, Surface}

  @now ~U[2026-11-04 12:00:00Z]

  @schema Schema.new!(%{
            "host" => %{type: :category, identity: true, label: "Host"},
            "at" => %{type: :time, window: true, label: "Seen"},
            "p50" => %{type: :number, unit: "us", label: "Median"}
          })

  # Newest last, as a source holds them.
  @rows [
    %{"host" => "a", "at" => ~U[2026-11-04 11:00:00Z], "p50" => 10},
    %{"host" => "b", "at" => ~U[2026-11-04 11:01:00Z], "p50" => nil},
    %{"host" => "c", "at" => ~U[2026-11-04 11:02:00Z], "p50" => 30}
  ]

  defmodule Kit do
    use ExUnit.Case, async: true

    use Macaw.Component.Conformance,
      component: Macaw.Builtin.Record,
      now: ~U[2026-11-04 12:00:00Z],
      fixtures: [
        %{
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!([%{"host" => "a", "p50" => 1}],
                types: %{"host" => :category, "p50" => :number}
              )
          }
        },
        %{
          settings: %{"label" => "Host"},
          bindings: %{"rows" => %{"fields" => ["p50"], "t" => "at"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!(
                [%{"at" => ~U[2026-11-04 11:00:00Z], "host" => "a", "p50" => 1}],
                types: %{"at" => :time, "host" => :category, "p50" => :number}
              )
          }
        }
      ]
  end

  defp html(settings, opts \\ []) do
    {:ok, settings} = Component.settings(Record, settings)
    {:ok, declarations} = Component.declarations(Record, settings)

    {:ok, context} =
      Context.new(
        mode: :socketless,
        instance: "r1",
        size: {300, 128},
        now: @now,
        heading_level: 3,
        bindings: Keyword.get(opts, :bindings, %{"rows" => %{"t" => "at"}}),
        schemas: Keyword.get(opts, :schemas, %{"rows" => @schema})
      )

    {:ok, assigns} =
      Assigns.new(
        context: context,
        settings: settings,
        declarations: declarations,
        drawn: Keyword.get(opts, :drawn, :live),
        deliveries: %{"rows" => Keyword.get(opts, :delivery, Delivery.new!(@rows))},
        value: nil
      )

    assigns |> then(&Record.render(:content, &1)) |> Phoenix.HTML.safe_to_string()
  end

  defp page(settings, supports, bindings \\ %{}) do
    sources = %{"s" => {%Macaw.Test.Rows{schema: @schema, rows: @rows, supports: supports}, nil}}

    surface =
      Surface.build!("p",
        cells: [{"macaw.record", source: "s", settings: settings, fields: bindings}]
      )

    {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)

    v
    |> Surface.render(sources: sources, now: @now, ceiling: 1_000)
    |> Phoenix.HTML.safe_to_string()
  end

  @tag verifies: "record-declares"
  test "the record's parameters, roles, reading load, order, budget and membership are as declared" do
    assert {:ok, %{"label" => "", "identity" => "", "pick" => "first"}} =
             Component.settings(Record, %{})

    {:ok, info} = Component.info(Record)
    assert {info.name, info.kinds} == {"macaw.record", [:content]}
    {:ok, d} = Component.declarations(Record, %{})
    assert d.reading == :scan
    assert Map.keys(d.slots) == ["rows"]
    assert Record in Macaw.Builtin.__members__()

    bound = %{"t" => "at"}

    assert Component.resolve_order(Record, "rows", %{"identity" => "", "pick" => "last"}, bound) ==
             {:ok, [{"at", :desc}]}

    assert Component.resolve_order(Record, "rows", %{"identity" => "", "pick" => "first"}, bound) ==
             {:ok, [{"at", :asc}]}

    assert Component.resolve_order(Record, "rows", %{"identity" => "b"}, bound) == {:ok, []}
    assert {:ok, 1} = Component.budget(Record, "rows", %{"identity" => ""}, {300, 128})
    assert {:ok, nil} = Component.budget(Record, "rows", %{"identity" => "b"}, {300, 128})
  end

  @tag verifies: "record-declares"
  test "a surface checks the fields role against the source's schema" do
    sources = %{"s" => {%Macaw.Test.Rows{schema: @schema, rows: @rows}, nil}}

    surface =
      Surface.build!("p",
        cells: [{"macaw.record", source: "s", fields: %{"fields" => ["host", "nope"]}}]
      )

    assert {:error, faults} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)
    assert Enum.any?(faults, &match?({[:cells, _, :fields, "fields" | _], _}, &1))
  end

  @tag verifies: "record-markup"
  test "a definition list of labels and units, a value as the table writes it, nil empty" do
    html = html(%{"identity" => "b", "label" => "One <host>"})

    assert html =~
             ~s(<div class="mw-record"><h3 class="mw-record-label">One &lt;host&gt;</h3><dl>)

    assert html =~ "<dt>Host</dt><dd>b</dd>"
    assert html =~ "<dt>Seen</dt><dd>2026-11-04T11:01:00Z</dd>"
    # A unit's display symbol; a gap is empty, never zero.
    assert html =~ "<dt>Median (µs)</dt><dd></dd>"
    refute html =~ "style="
    refute html(%{"identity" => "b"}) =~ "<h3"
  end

  @tag verifies: "record-markup"
  test "the fields role chooses the fields and their order" do
    html = html(%{"identity" => "c"}, bindings: %{"rows" => %{"fields" => ["p50", "host"]}})
    assert html =~ "<dl><dt>Median (µs)</dt><dd>30</dd><dt>Host</dt><dd>c</dd></dl>"
  end

  @tag verifies: "record-markup"
  test "a row by identity; no match is no data; no single identity field is invalid" do
    assert html(%{"identity" => "c"}) =~ "<dd>c</dd>"
    assert html(%{"identity" => "zz"}) =~ Drawn.words(:no_data)
    refute html(%{"identity" => "zz"}) =~ "<dl>"

    two =
      Schema.new!(%{
        "a" => %{type: :category, identity: true},
        "b" => %{type: :category, identity: true}
      })

    assert html(%{"identity" => "c"}, schemas: %{"rows" => two}) =~ Drawn.words(:invalid)
    assert html(%{"identity" => "c"}, schemas: %{}) =~ Drawn.words(:invalid)
  end

  @tag verifies: "record-reads"
  test "on a surface, first and last are the oldest and newest, from a source that orders or not" do
    for supports <- [[:budget, :order], []] do
      assert page(%{}, supports) =~ "<dd>a</dd>", inspect(supports)
      assert page(%{"pick" => "last"}, supports) =~ "<dd>c</dd>", inspect(supports)
      assert page(%{"identity" => "b"}, supports) =~ "<dd>b</dd>", inspect(supports)
    end
  end

  @tag verifies: "record-reads"
  test "last with no time field is invalid, not an arbitrary row called the last; first still answers" do
    plain = Schema.new!(%{"host" => %{type: :category}})
    delivery = Delivery.new!([%{"host" => "a"}])
    opts = [bindings: %{}, schemas: %{"rows" => plain}, delivery: delivery]

    assert html(%{"pick" => "last"}, opts) =~ Drawn.words(:invalid)
    assert html(%{}, opts) =~ "<dd>a</dd>"
  end

  @tag verifies: "record-markup"
  test "a picked row is the whole answer, with no notice; a sample, a capped source, a lookup and stale keep theirs" do
    capped = Drawn.words(:capped)

    for supports <- [[:budget, :order], []] do
      refute page(%{"pick" => "last"}, supports) =~ capped, inspect(supports)
    end

    sample = Delivery.new!(@rows, served: [reduced_by: :source, ordered: :sample])
    assert html(%{}, drawn: :capped, delivery: sample) =~ capped

    short = Delivery.new!(@rows, served: [capped: true])
    assert html(%{}, drawn: :capped, delivery: short) =~ capped

    assert html(%{"identity" => "a"}, drawn: :capped) =~ capped
    assert html(%{}, drawn: :stale) =~ Drawn.words(:stale)

    for drawn <- [:loading, :down, :invalid, :no_data],
        do: refute(html(%{}, drawn: drawn) =~ "<dl>")

    assert html(%{}, delivery: Delivery.new!([])) =~ Drawn.words(:no_data)
  end

  @tag verifies: "record-stylesheet"
  test "the stylesheet styles what it emits, in the theme's colors only, at its address" do
    css = Record.stylesheet()
    assert Record.stylesheet_path() == Macaw.Component.Stylesheet.path(css)

    for selector <- [
          ".mw-record{",
          ".mw-record-label{",
          ".mw-record dl{",
          ".mw-record dt{",
          ".mw-record dd{"
        ],
        do: assert(css =~ selector, "no rule for #{selector}")

    refute css =~ "url("
    refute css =~ "@import"

    for [_, value] <- Regex.scan(~r/color:([^;}]+)[;}]/, css),
        do: assert(value =~ ~r/var\(--mw-[a-z-]+,#[0-9a-f]+\)/, value)
  end

  @tag verifies: "table-markup"
  test "a value is written one way: times, points, nil and the rest" do
    assert Text.value(nil) == ""
    assert Text.value(~U[2026-11-04 11:00:00.000000Z]) == "2026-11-04T11:00:00Z"
    assert Text.value(~U[2026-11-04 11:00:00.5Z]) == "2026-11-04T11:00:00.5Z"
    assert Text.value(~N[2026-11-04 11:00:00]) == "2026-11-04T11:00:00"
    assert Text.value(~D[2026-11-04]) == "2026-11-04"
    assert Text.value({1.5, 2}) == "1.5, 2"
    assert Text.value(:up) == "up"
    assert Text.value(3) == "3"
  end
end
