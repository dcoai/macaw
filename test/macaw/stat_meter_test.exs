defmodule Macaw.StatMeterTest do
  # The built-in stat and meter (spec/05 §6.3, §6.4), through macaw_component's kit too.
  use ExUnit.Case, async: true

  alias Macaw.Builtin.{Meter, Reading, Stat}
  alias Macaw.Component
  alias Macaw.Component.{Assigns, Context}
  alias Macaw.Data.{Delivery, Ops, Schema}
  alias Macaw.{Registry, Surface}

  @now ~U[2026-11-04 12:00:00Z]

  # Newest first, as an order of `[{t, :desc}]` delivers them.
  @rows [
    %{"at" => ~U[2026-11-04 11:03:00Z], "p50" => 30},
    %{"at" => ~U[2026-11-04 11:02:00Z], "p50" => nil},
    %{"at" => ~U[2026-11-04 11:01:00Z], "p50" => 10},
    %{"at" => ~U[2026-11-04 11:00:00Z], "p50" => 20}
  ]

  @schema Schema.new!(%{
            "at" => %{type: :time, window: true},
            "p50" => %{type: :number, unit: "ms", label: "Median"}
          })

  @bindings %{"rows" => %{"value" => "p50", "t" => "at"}}
  defmodule StatKit do
    use ExUnit.Case, async: true

    use Macaw.Component.Conformance,
      component: Macaw.Builtin.Stat,
      now: ~U[2026-11-04 12:00:00Z],
      fixtures: [
        %{
          bindings: %{"rows" => %{"value" => "p50", "t" => "at"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!([%{"at" => ~U[2026-11-04 11:00:00Z], "p50" => 2}],
                types: %{"at" => :time, "p50" => :number}
              )
          }
        },
        %{
          settings: %{"label" => "Errors", "reduce" => "sum", "digits" => "2"},
          bindings: %{"rows" => %{"value" => "p50"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!([%{"p50" => 2}, %{"p50" => 3}], types: %{"p50" => :number})
          }
        }
      ]
  end

  defmodule MeterKit do
    use ExUnit.Case, async: true

    use Macaw.Component.Conformance,
      component: Macaw.Builtin.Meter,
      now: ~U[2026-11-04 12:00:00Z],
      fixtures: [
        %{
          settings: %{"max" => 10},
          bindings: %{"rows" => %{"value" => "p50", "t" => "at"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!([%{"at" => ~U[2026-11-04 11:00:00Z], "p50" => 2}],
                types: %{"at" => :time, "p50" => :number}
              )
          }
        },
        %{
          settings: %{"max" => 10, "min" => 1, "reduce" => "sum", "low" => 2, "high" => 4},
          bindings: %{"rows" => %{"value" => "p50"}},
          deliveries: %{
            "rows" =>
              Macaw.Data.Delivery.new!([%{"p50" => 2}, %{"p50" => 3}], types: %{"p50" => :number})
          }
        }
      ]
  end

  defp html(module, settings, drawn \\ :live, rows \\ @rows, bindings \\ @bindings) do
    {:ok, settings} = Component.settings(module, settings)
    {:ok, declarations} = Component.declarations(module, settings)

    {:ok, context} =
      Context.new(
        mode: :socketless,
        instance: "c1",
        size: {300, 128},
        now: @now,
        heading_level: 3,
        bindings: bindings,
        schemas: %{"rows" => @schema}
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

    assigns |> then(&module.render(:content, &1)) |> Phoenix.HTML.safe_to_string()
  end

  @tag verifies: "stat-declares"
  test "the stat's parameters, roles, reading load and membership are as declared" do
    assert {:ok, %{"label" => "", "reduce" => "latest", "digits" => ""}} =
             Component.settings(Stat, %{})

    {:ok, info} = Component.info(Stat)
    assert {info.name, info.kinds} == {"macaw.stat", [:content]}
    {:ok, d} = Component.declarations(Stat, %{})
    assert d.reading == :glance
    assert Map.keys(d.slots) == ["rows"]
    assert Stat in Macaw.Builtin.__members__()

    assert {:error, [{["digits"], {:enum, _digits}}]} =
             Component.declarations(Stat, %{"digits" => "9"})
  end

  @tag verifies: "stat-reduce"
  test "latest and delta ask for time order; latest needs one row; the rest ask for neither" do
    assert Component.resolve_order(Stat, "rows", %{"reduce" => "latest"}, %{
             "t" => "at",
             "value" => "p50"
           }) ==
             {:ok, [{"at", :desc}]}

    assert {:ok, [{"at", :desc}]} =
             Component.resolve_order(Stat, "rows", %{"reduce" => "delta"}, %{
               "t" => "at",
               "value" => "p50"
             })

    assert {:ok, []} =
             Component.resolve_order(Stat, "rows", %{"reduce" => "sum"}, %{
               "t" => "at",
               "value" => "p50"
             })

    assert {:ok, 1} = Component.budget(Stat, "rows", %{"reduce" => "latest"}, {300, 128})
    assert {:ok, nil} = Component.budget(Stat, "rows", %{"reduce" => "sum"}, {300, 128})
  end

  @tag verifies: "stat-reduce"
  test "each reduce answers Ops.aggregate/3's number over the readings, nil dropped" do
    readings = [30, 10, 20]

    for reduce <- ~w(sum mean min max median count) do
      {:ok, expected} = Ops.aggregate(readings, reduce)
      html = html(Stat, %{"reduce" => reduce})
      assert html =~ ~s(<data value="#{expected}">), "#{reduce}: #{html}"
    end

    # Newest first, so the last reading in time minus the first: 30 - 20.
    assert html(Stat, %{"reduce" => "delta"}) =~ ~s(<data value="10">)
    assert html(Stat, %{"reduce" => "latest"}) =~ ~s(<data value="30">30</data>)
  end

  @tag verifies: "stat-markup"
  test "the heading, the unit's symbol, the digits; a count has no unit" do
    html = html(Stat, %{})

    assert html ==
             ~s(<div class="mw-stat"><h3 class="mw-stat-label">Median</h3><p class="mw-stat-value"><data value="30">30</data><span class="mw-stat-unit">ms</span></p></div>)

    assert html(Stat, %{"label" => "Slow <p50>"}) =~ "Slow &lt;p50&gt;</h3>"
    assert html(Stat, %{"reduce" => "mean", "digits" => "2"}) =~ ~s(>20.00</data>)
    assert html(Stat, %{"reduce" => "mean", "digits" => "0"}) =~ ~s(>20</data>)
    refute html(Stat, %{"reduce" => "count"}) =~ "mw-stat-unit"
    refute html =~ "style="
  end

  @tag verifies: "stat-markup"
  test "absence is never zero: gaps show an en dash; a count of none is zero" do
    gaps = [%{"at" => ~U[2026-11-04 11:00:00Z], "p50" => nil}]

    for reduce <- ~w(latest sum mean min max median delta) do
      html = html(Stat, %{"reduce" => reduce}, :live, gaps)
      assert html =~ ~s(<p class="mw-stat-value">–</p>), "#{reduce}: #{html}"
      refute html =~ "<data"
    end

    assert html(Stat, %{"reduce" => "count"}, :live, gaps) =~ ~s(<data value="0">0</data>)
  end

  @tag verifies: "stat-markup"
  test "latest or delta with no time field draws invalid, not an arbitrary row called newest" do
    no_time = %{"rows" => %{"value" => "p50"}}

    for reduce <- ~w(latest delta) do
      html = html(Stat, %{"reduce" => reduce}, :live, @rows, no_time)
      refute html =~ "<data"
      assert html =~ Macaw.Component.Drawn.words(:invalid)
    end

    assert html(Stat, %{"reduce" => "sum"}, :live, @rows, no_time) =~ ~s(<data value="60">)
  end

  @tag verifies: ["stat-markup", "meter-markup"]
  test "capped and stale draw the notice above the number; other states the notice alone" do
    for drawn <- [:capped, :stale] do
      [notice, _rest] = String.split(html(Stat, %{}, drawn), ~s(<div class="mw-stat">), parts: 2)
      assert notice != ""
      assert html(Meter, %{"max" => 100}, drawn) =~ "<meter"
    end

    for drawn <- [:loading, :down, :invalid, :no_data] do
      refute html(Stat, %{}, drawn) =~ "<data"
      refute html(Meter, %{"max" => 100}, drawn) =~ "<meter"
    end
  end

  @tag verifies: "meter-declares"
  test "the meter's range is checked at its name" do
    {:ok, info} = Component.info(Meter)
    assert {info.name, info.kinds} == {"macaw.meter", [:content]}
    assert Meter in Macaw.Builtin.__members__()

    assert {:error, [{["max"], :required}]} = Component.settings(Meter, %{})

    assert {:error, [{["max"], {:not_above, 5, 5}}]} =
             Component.declarations(Meter, %{"min" => 5, "max" => 5})

    assert {:ok, _} = Component.declarations(Meter, %{"min" => -5, "max" => 10})
  end

  @tag verifies: "meter-markup"
  test "a native meter named by its heading, the true value and unit beside it, none when absent" do
    html = html(Meter, %{"max" => 100})

    assert html ==
             ~s(<div class="mw-meter"><h3 class="mw-meter-label" id="c1-label">Median</h3><meter aria-labelledby="c1-label" value="30" min="0" max="100">30</meter><p class="mw-meter-value">30 ms</p></div>)

    # Out of range: <meter> clamps the bar; the text tells the truth.
    over = html(Meter, %{"max" => 10})
    assert over =~ ~s(value="30" min="0" max="10")
    assert over =~ ~s(<p class="mw-meter-value">30 ms</p>)

    gaps = [%{"at" => ~U[2026-11-04 11:00:00Z], "p50" => nil}]
    absent = html(Meter, %{"max" => 10}, :live, gaps)
    refute absent =~ "<meter"
    assert absent =~ ~s(<p class="mw-meter-value">–</p>)
  end

  @tag verifies: "meter-declares"
  test "low, high and optimum are optional numbers checked against the range and each other" do
    {:ok, parameters} = Component.parameters(Meter)

    for name <- ~w(low high optimum) do
      assert %{type: :number, default: nil} = parameters[name]
      refute parameters[name][:bindable]
    end

    assert {:ok, %{"low" => nil, "high" => nil, "optimum" => nil}} =
             Component.settings(Meter, %{"max" => 10})

    range = %{"min" => 0, "max" => 10}

    assert {:ok, _} =
             Component.declarations(
               Meter,
               Map.merge(range, %{"low" => 0, "high" => 10, "optimum" => 5})
             )

    assert {:ok, _} = Component.declarations(Meter, Map.merge(range, %{"low" => 5, "high" => 5}))

    for name <- ~w(low high optimum), value <- [-1, 11] do
      assert {:error, [{[^name], {:outside_range, ^value, 0, 10}}]} =
               Component.declarations(Meter, Map.put(range, name, value))
    end

    assert {:error, [{["high"], {:below_low, 7, 3}}]} =
             Component.declarations(Meter, Map.merge(range, %{"low" => 7, "high" => 3}))

    assert {:error, faults} =
             Component.declarations(Meter, Map.merge(range, %{"low" => 20, "high" => 3}))

    assert {["low"], {:outside_range, 20, 0, 10}} in faults
    assert {["high"], {:below_low, 20, 3}} in faults
  end

  @tag verifies: "meter-markup"
  test "a given threshold is written on the meter, and an absent one is left out" do
    given = html(Meter, %{"max" => 100, "low" => 20, "high" => 80, "optimum" => 10})

    assert given =~
             ~s(<meter aria-labelledby="c1-label" value="30" min="0" max="100" low="20" high="80" optimum="10">)

    assert html(Meter, %{"max" => 100, "high" => 80}) =~ ~s(max="100" high="80">)

    # A threshold of zero is a value, not an absence.
    assert html(Meter, %{"min" => -5, "max" => 100, "low" => 0}) =~ ~s(low="0")

    refute html(Meter, %{"max" => 100}) =~ ~r/low=|high=|optimum=/
  end

  @tag verifies: "meter-markup"
  test "a value past low or high says so in words, so color is never the only cue" do
    words = ~s(<span class="mw-meter-band">)

    assert html(Meter, %{"max" => 100, "high" => 20}) =~
             ~s(<p class="mw-meter-value">30 ms #{words}high</span></p>)

    assert html(Meter, %{"max" => 100, "low" => 40}) =~
             ~s(<p class="mw-meter-value">30 ms #{words}low</span></p>)

    # On a threshold is in the middle, as <meter> reads it.
    for settings <- [%{"low" => 30}, %{"high" => 30}, %{"low" => 10, "high" => 50}, %{}] do
      refute html(Meter, Map.put(settings, "max", 100)) =~ words
    end

    # Optimum names no band.
    refute html(Meter, %{"max" => 100, "optimum" => 90}) =~ words

    gaps = [%{"at" => ~U[2026-11-04 11:00:00Z], "p50" => nil}]
    refute html(Meter, %{"max" => 100, "high" => 20}, :live, gaps) =~ words
  end

  @tag verifies: "stat-reduce"
  test "on a surface, a capped series' latest is its newest, from a source that orders or not" do
    rows = Enum.reverse(@rows)

    for supports <- [[:budget, :order], []] do
      sources = %{
        "lat" => {%Macaw.Test.Rows{schema: @schema, rows: rows, supports: supports}, nil}
      }

      surface =
        Surface.build!("s", cells: [{"macaw.stat", source: "lat", fields: %{"value" => "p50"}}])

      {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)

      html =
        v
        |> Surface.render(sources: sources, now: @now, ceiling: 1_000)
        |> Phoenix.HTML.safe_to_string()

      assert html =~ ~s(<data value="30">), "#{inspect(supports)}: #{html}"
    end
  end

  @tag verifies: ["stat-markup", "meter-markup"]
  test "a latest that is the whole answer has no notice; a sample, capped, or another statistic does" do
    rows = Enum.reverse(@rows)
    words = Macaw.Component.Drawn.words(:capped)

    page = fn cell, supports, ceiling ->
      sources = %{
        "lat" => {%Macaw.Test.Rows{schema: @schema, rows: rows, supports: supports}, nil}
      }

      surface = Surface.build!("s", cells: [cell])
      {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)

      v
      |> Surface.render(sources: sources, now: @now, ceiling: ceiling)
      |> Phoenix.HTML.safe_to_string()
    end

    stat = fn settings ->
      {"macaw.stat", source: "lat", settings: settings, fields: %{"value" => "p50"}}
    end

    meter = {"macaw.meter", source: "lat", settings: %{"max" => 100}, fields: %{"value" => "p50"}}

    for supports <- [[:budget, :order], []] do
      for cell <- [stat.(%{}), meter] do
        html = page.(cell, supports, 1_000)
        refute html =~ words, "#{inspect(supports)}: #{html}"
        assert html =~ ~s(value="30")
      end

      # Another statistic under a low ceiling read only part of the data.
      assert page.(stat.(%{"reduce" => "sum"}), supports, 2) =~ words
    end

    sample = fn facts ->
      delivery = Delivery.new!([%{"at" => @now, "p50" => 1}], served: facts)
      {:ok, context} = Context.new(mode: :socketless, instance: "c1", size: {1, 1}, now: @now)
      Reading.notice(:capped, delivery, context, "latest")
    end

    assert sample.(reduced_by: :source, ordered: :source) == nil
    assert sample.(reduced_by: :runtime, ordered: :runtime) == nil
    refute sample.(reduced_by: :source, ordered: :sample) == nil
    refute sample.(capped: true, ordered: :source) == nil
    assert html(Stat, %{}, :stale) =~ Macaw.Component.Drawn.words(:stale)
  end

  @tag verifies: "stat-declares"
  test "a surface checks the value role against the source's schema" do
    sources = %{"lat" => {%Macaw.Test.Rows{schema: @schema, rows: @rows}, nil}}
    registry = Registry.new!([Macaw.Builtin])

    cell = fn fields ->
      Surface.build!("s", cells: [{"macaw.stat", source: "lat", fields: fields}])
    end

    assert {:error, faults} = Surface.validate(cell.(%{"value" => "at"}), registry, sources)
    assert Enum.any?(faults, &match?({[:cells, _, :fields, "value" | _], _}, &1))
    assert {:error, faults} = Surface.validate(cell.(%{"value" => "nope"}), registry, sources)
    assert Enum.any?(faults, &match?({[:cells, _, :fields, "value" | _], _}, &1))
  end

  @tag verifies: "stat-reduce"
  test "a number is written as given or at its digits" do
    assert Reading.format(3, nil) == "3"
    assert Reading.format(1.5, nil) == "1.5"
    assert Reading.format(1.005, 2) =~ ~r/^1\.0[01]$/
    assert Reading.format(2, 1) == "2.0"
    assert Reading.format(2.6, 0) == "3"
  end

  @tag verifies: ["stat-stylesheet", "components-meter"]
  test "the stylesheets style what they emit, in the theme's colors only, at their addresses" do
    for {module, selectors} <- [
          {Stat, [".mw-stat{", ".mw-stat-label{", ".mw-stat-value{", ".mw-stat-unit{"]},
          {Meter,
           [
             ".mw-meter{",
             ".mw-meter-label{",
             ".mw-meter meter{",
             ".mw-meter-value{",
             ".mw-meter-band{"
           ]}
        ] do
      css = module.stylesheet()
      assert module.stylesheet_path() == Macaw.Component.Stylesheet.path(css)
      for selector <- selectors, do: assert(css =~ selector, "no rule for #{selector}")
      refute css =~ "url("
      refute css =~ "@import"

      for [_, value] <- Regex.scan(~r/(?:color|background[a-z-]*):([^;}]+)[;}]/, css),
          do: assert(value =~ ~r/var\(--mw-[a-z-]+,#[0-9a-f]+\)/, value)
    end
  end
end
