# 7. Testing with the conformance kits

Macaw's contracts come with **conformance kits**: the rules of each contract as checks you
run in your own test suite. A component author proves a component conforms by running
the component kit; a source author runs the source kit. This chapter shows both, and how
to test surfaces themselves.

**What you'll learn:**

- the component kit, `Macaw.Component.Conformance`: its checks, fixtures and options;
- reading findings, and running checks one at a time;
- the source kit, `Macaw.Data.Source.Conformance`: requests, budgets, push and the rest;
- testing a surface's validation and markup.

## Setting up

The component kit reads renders as HTML with `lazy_html`, an optional dependency. Add it
for tests:

```elixir
{:lazy_html, "~> 0.1", only: :test}
```

The source kit has no extra dependency. Both are in `lib/` of their packages and load in
production; only the code `use` writes into your test module calls ExUnit.

## The component kit

`use Macaw.Component.Conformance` inside an ExUnit case writes one test per check. The
fixtures say which settings, deliveries and bindings to render with; give one fixture
per distinct shape of your component's declarations:

```elixir
defmodule MyApp.Components.StatTest do
  use ExUnit.Case, async: true

  alias Macaw.Data.Delivery

  use Macaw.Component.Conformance,
    component: MyApp.Components.Stat,
    now: ~U[2026-10-29 12:00:00Z],
    fixtures: [
      %{
        name: "sum",
        settings: %{"label" => "Errors"},
        bindings: %{"rows" => %{"value" => "errors"}},
        deliveries: %{"rows" => Delivery.new!([%{"errors" => 3}, %{"errors" => 4}])}
      },
      %{
        name: "count of nothing",
        settings: %{"label" => "Errors", "reduce" => "count"},
        bindings: %{"rows" => %{"value" => "errors"}},
        deliveries: %{"rows" => Delivery.new!([])}
      }
    ]
end
```

`mix test` then runs fourteen tests for the component, `Macaw.Component.Conformance.checks/0`:

| Check | Holds |
|---|---|
| `:declarations` | parameters are valid; each fixture's settings pass; `declarations/1` is pure and ignores bindable parameters; fixture events are declared |
| `:kinds` | every declared kind renders, to its kind's rules |
| `:modes` | every mode renders; no `<canvas>` outside live; no hooks, scripts, live regions or tokens in neutral and print |
| `:delivery` | no inline style or script, no `on…` attributes or `javascript:` URLs, nothing from another origin |
| `:headings` | top headings at the context's level, and moving with it |
| `:names` | images, buttons, links and controls are named; ARIA states take legal values; ARIA references resolve |
| `:keyboard` | no positive `tabindex`; one tab stop per composite widget; no `role="menu"` |
| `:colors` | literal colors only with a non-color cue (`data-mw-cue`) |
| `:ids` | ids unique, stable across renders, prefixed by the instance |
| `:drawn` | every drawn state renders readable text in every mode |
| `:budget` | `budget/3` answers well for every slot at three sizes |
| `:order` | `order/2`, where declared, answers a row order of the right shape for every slot |
| `:contained` | a contained component's transitions answer values that render, purely |
| `:bindings` | the render follows the fields bound in the context: renamed to fresh names, they draw the same |

A **fixture** is a map of `name` (how findings name it), `settings`, `deliveries` (one per
slot), `bindings` (each slot's resolved binding, `%{slot => %{role => field}}`, carried by
every context the kit builds) and `events` (event names its interaction produces, checked
as declared). The `:bindings` check probes each fixture that has bindings: it renames the
bound fields, in the delivery and the binding alike, and finds `{:ignores_binding, slot}`
when the render doesn't follow them, as a component reading a fixed field name wouldn't.
It rebuilds the renamed delivery through `Delivery.new/2`'s value, so a delivery it can't
rebuild is the finding `{:unrenamable, slot, faults}`, the delivery's own faults, never
a raise.

The options are `fixtures:` (one bare fixture by default), `check_sets:`, `theme:`
(a `%Macaw.Layers.Theme{}`, its colors terms), `size:` (`{640, 400}`) and `now:`.

Each component in this tutorial passes:

```elixir
defmodule MyApp.Components.ReadingsTest do
  use ExUnit.Case, async: true

  use Macaw.Component.Conformance,
    component: MyApp.Components.Readings,
    fixtures: [
      %{
        bindings: %{"series" => %{"t" => "t", "y" => "ms"}},
        deliveries: %{"series" => Macaw.Data.Delivery.new!([%{"t" => ~U[2026-10-29 12:00:00Z], "ms" => 3}])}
      }
    ]
end

defmodule MyApp.Components.TallyTest do
  use ExUnit.Case, async: true

  use Macaw.Component.Conformance,
    component: MyApp.Components.Tally,
    fixtures: [%{deliveries: %{"rows" => Macaw.Data.Delivery.new!([%{"n" => 1}])}}]
end
```

### Findings

Under the tests, `check/2` runs every check and answers **findings**, `[]` for a component
that passes; `check/3` runs one; `format/1` words a finding. A finding names the check,
where it failed (fixture, kind, mode) and what. Forgetting a required setting, for
instance, or reading a fixed field name instead of the bound one, as this component does:

```elixir
defmodule MyApp.Components.FixedField do
  @moduledoc "A total of the field named `n`, whatever the document bound: a mistake the kit finds."
  use Macaw.Component, name: "my_app.fixed_field", kinds: [:content]

  alias Macaw.Component.Drawn
  alias Macaw.Data.{Delivery, Table}

  @impl true
  def parameters, do: %{"label" => %{type: :text}}

  @impl true
  def declarations(_settings),
    do: {:ok, slots: %{"rows" => %{requires: %{"value" => %{type: :number}}}}}

  @impl true
  def render(:content, %{drawn: :live, deliveries: %{"rows" => delivery}} = assigns) do
    case Delivery.named_rows(delivery) do
      {:ok, rows} ->
        values = rows |> Enum.map(&Table.get(&1, "n")) |> Enum.reject(&is_nil/1)
        {:safe, "<p>#{Enum.sum(values)}</p>"}

      {:error, _faults} ->
        Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, assigns), do: Drawn.render(assigns.drawn, assigns.context)
end
```

```elixir
defmodule MyApp.Components.FindingsTest do
  use ExUnit.Case, async: true

  alias Macaw.Component.Conformance

  @rows %{"rows" => Macaw.Data.Delivery.new!([%{"n" => 1}])}

  test "a fixture without the required label is a declarations finding" do
    findings = Conformance.check(MyApp.Components.Stat, [])

    assert findings == [declarations: {{"fixture 1", nil, nil}, {:settings, [{["label"], :required}]}}]
    assert [line] = Enum.map(findings, &Conformance.format/1)
    assert line =~ "declarations"
  end

  test "a component reading a fixed field name ignores its binding" do
    fixture = %{settings: %{"label" => "N"}, bindings: %{"rows" => %{"value" => "n"}}, deliveries: @rows}

    assert Conformance.check(:bindings, MyApp.Components.Stat, fixtures: [fixture]) == []

    assert Conformance.check(:bindings, MyApp.Components.FixedField, fixtures: [fixture]) ==
             [bindings: {{"fixture 1", :content, :live}, {:ignores_binding, "rows"}}]
  end

  test "one check at a time" do
    assert Conformance.check(:headings, MyApp.Components.Stat, fixtures: [%{settings: %{"label" => "N"}}]) == []
  end

  test "the checks and the check sets" do
    assert length(Conformance.checks()) == 14
    assert Conformance.check_sets() == [:visual]
  end
end
```

**Check sets** add checks for a family of components. The one shipped, `:visual`, is for
components that draw data (charts, maps): the drawing is a named, described image beside
an accessible table, one tab stop, a drawn token that follows the data, SVG outside
live mode. Add it with `check_sets: [:visual]`.

## The source kit

`use Macaw.Data.Source.Conformance` does the same for a source, eight checks
(`Macaw.Data.Source.Conformance.checks/0`):

| Check | Holds |
|---|---|
| `:describe` | the description and schema are valid, measures known, capabilities backed by the schema, describe stable |
| `:deliveries` | every delivery is well formed: fields described, identity present, rows within the served window, honest `capped` and `reduced_by` |
| `:supports` | each declared capability is really honored |
| `:push` | a pushing source sends its schema first, and increments numbered from 1 and well formed |
| `:errors` | unreadable requests answer values, never crash; undeclared params never reach the source |
| `:unsubscribe` | after unsubscribing, nothing more arrives |
| `:determinism` | one request at one `now` gives one answer |
| `:viewers` | a source declaring `viewer_independent` answers two viewers alike |

```elixir
defmodule MyApp.LatencyTest do
  use ExUnit.Case, async: true

  use Macaw.Data.Source.Conformance,
    source: %MyApp.Latency{},
    now: ~U[2026-10-29 12:00:30Z],
    requests: [
      [],
      [window: [~U[2026-10-29 11:00:00Z], nil]],
      [params: %{"host" => "web-2"}]
    ]
end
```

Its options:

- `source:` the source, an expression evaluated in each test;
- `context:` what `describe/2` is given (`nil`);
- `requests:` what to ask, each a keyword list of request fields among `params`,
  `window`, `box`, `region`, `latest` and `as_of`. **A capability you declare needs a
  request that probes it:** `MyApp.Latency` supports `:window`, so one request has a
  window; without it the kit reports `{:no_probe, :window}`;
- `budgets:` the budgets each request is fetched with (`[nil, 5]`);
- `now:`, `viewers:` (two opaque viewers), `as_of:`;
- `push:` a function of the source that makes it push, required for `:push`;
- `down:` a source of the same kind that can't answer, held to answering errors;
- `timeout:`, `reductions:`, `processes:`, `quiet:` for the liveness and cost bounds.

The pushing source from chapter 2 needs `push:`:

```elixir
defmodule MyApp.TickerTest do
  use ExUnit.Case, async: true

  use Macaw.Data.Source.Conformance,
    source: MyApp.Ticker.new(),
    push: &MyApp.Ticker.tick(&1, [%{"t" => ~U[2026-10-29 12:00:00Z], "value" => 1}])
end
```

### What it catches

Here's a source with two common mistakes: it reads the clock, and it declares `:budget`
but ignores it:

```elixir
defmodule MyApp.Sloppy do
  @moduledoc "A source with two mistakes the kit finds."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct []

  @schema Schema.new!(%{"t" => %{type: :time}, "v" => %{type: :number}})

  @impl true
  def describe(%__MODULE__{}, _context), do: Description.new(schema: @schema, supports: [:budget])

  @impl true
  def fetch(%__MODULE__{}, request) do
    # The request's now, never the clock: two fetches of one request agree.
    rows = for i <- 1..20, do: %{"t" => DateTime.add(request.now, -i), "v" => i}
    Delivery.new(rows, schema: Schema.version(@schema))
  end
end
```

`check/2` answers the findings, and `format/1` words them:

```elixir
alias Macaw.Data.Source.Conformance

findings = Conformance.check(%MyApp.Sloppy{}, [])

Keyword.get(findings, :supports)
#=> {:over_budget, {[], 5}, 20}

findings |> Keyword.take([:supports]) |> Enum.map(&Conformance.format/1)
#=> ["supports: asked for at most 5 rows (fetch [] with budget 5), the source names :budget and served 20"]

Conformance.check(%MyApp.Latency{}, requests: [[], [window: [~U[2026-10-29 11:00:00Z], nil]]], now: ~U[2026-10-29 12:00:30Z])
#=> []
```

The `:determinism` check catches the clock too: "asked twice with one now, the source
answered twice differently; an answer depends on the request, never on a clock the
source reads". The kit runs every callback in a process of its own, so a source that
raises is a finding, not a crashed test run, and it judges cost by reductions, not wall
time, so a busy CI machine doesn't change a verdict.

Run the kit early: the `:errors` check is why chapter 2's `MyApp.Latency` checks its
request with `Macaw.Data.Window.check/2` before reading the window. A window of numbers
is a caller's mistake, and the source answers it as a value instead of crashing.

## Testing surfaces

Surfaces are values, so testing them needs nothing special. Assert on validation faults,
on fetched drawn states, and on markup, parsed with `LazyHTML`:

```elixir
defmodule MyApp.StatusSurfaceTest do
  use ExUnit.Case, async: true

  @now ~U[2026-10-29 12:00:00Z]

  setup do
    registry = Macaw.Registry.new!([Macaw.Builtin, MyApp.Components])
    sources = %{"services" => {%MyApp.Services{}, nil}}

    {:ok, surface} =
      Macaw.Surface.new(
        name: "status",
        title: "Service status",
        cells: %{
          "errors" => %{
            component: "my_app.stat",
            settings: %{"label" => "Errors"},
            place: %{x: 0, y: 0, w: 4, h: 2},
            slots: %{"rows" => %{source: "services", fields: %{"value" => "errors"}}}
          },
          "services" => %{
            component: "macaw.table",
            settings: %{"caption" => "Services", "sort" => "p50", "order" => "desc"},
            place: %{x: 4, y: 0, w: 8, h: 4},
            slots: %{"rows" => %{source: "services"}}
          }
        }
      )

    {:ok, validated} = Macaw.Surface.validate(surface, registry, sources)
    %{validated: validated, env: [sources: sources, now: @now, ceiling: 100]}
  end

  test "every cell is live", %{validated: validated, env: env} do
    for {_cell, %{drawn: drawn}} <- Macaw.Surface.fetch(validated, env), do: assert(drawn == :live)
  end

  test "the slowest service comes first", %{validated: validated, env: env} do
    html = validated |> Macaw.Surface.render(env) |> Phoenix.HTML.safe_to_string()
    doc = LazyHTML.from_fragment(html)

    assert doc |> LazyHTML.query("#status-services caption") |> LazyHTML.text() == "Services"
    assert doc |> LazyHTML.query("#status-services tbody tr td:nth-child(4)") |> Enum.map(&LazyHTML.text/1) |> hd() == "mail"
    assert doc |> LazyHTML.query("#status-errors .my-stat-number") |> LazyHTML.text() == "10"
  end
end
```

Pass a fixed `now:` in tests. Since no source or component reads the clock, a surface
renders the same markup every time.

## Pitfalls

- **No fixture for a declaration shape.** If settings change a component's slots or
  events, give a fixture for each shape, or the kit never sees them.
- **Declaring capabilities you don't probe.** The source kit refuses to guess: give a
  request for each capability you declare.
- **Forgetting `lazy_html` in the test dependencies.** `Macaw.Component.Conformance` only
  compiles when `LazyHTML` is loaded.
- **Testing with `DateTime.utc_now/0`.** Fix `now`, and tests stay reproducible.

## Recap

- `use Macaw.Component.Conformance, component:, fixtures:` writes fourteen tests: the
  contract's rules, checked on real renders.
- `use Macaw.Data.Source.Conformance, source:, requests:` writes eight: well-formed,
  honest, deterministic answers.
- `check/2`, `check/3` and `format/1` give findings directly.
- Surfaces are values: assert on faults, drawn states and parsed markup.

**Further reading:** [the component kit](https://github.com/dcoai/macaw_component/blob/main/spec/04-conformance.md#components-kit) in `macaw_component`'s spec/04, and [the source kit](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-conformance) in `macaw_data`'s spec/01.

Next: [chapter 8, Documents](08-documents.md).
