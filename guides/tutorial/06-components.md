# 6. Writing components

A component is a module that implements `Macaw.Component`. The built-in table is one;
yours use the same contract, register the same way, and are held to the same rules.
This chapter builds three components and covers the whole contract.

**What you'll learn:**

- `use Macaw.Component` and its compile-time checks;
- parameters and settings;
- configured declarations (`Macaw.Component.Declarations`): slots, state, events and the
  rest;
- slots with roles, and how bindings are checked (`Macaw.Component.Slot`);
- row budgets;
- rendering: assigns, the context, kinds, drawn states and modes;
- contained components, which hold a value;
- packages, the registry and client hooks;
- the supporting modules: state, events, announcements, stylesheets and proxy routes.

Testing components with the conformance kit is [chapter 7](07-testing.md).

## A first component

A "stat" tile shows one number computed from a slot's rows: a sum, a maximum or a count
of the field the document binds to its `value` role.

```elixir
defmodule MyApp.Components.Stat do
  @moduledoc "One number from a slot's rows: the sum, maximum or count of the bound field."
  use Macaw.Component, name: "my_app.stat", kinds: [:content]

  import Phoenix.Component, only: [sigil_H: 2, dynamic_tag: 1]

  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.{Delivery, Table}

  @impl true
  def parameters do
    %{
      "label" => %{type: :text, doc: "what the number is"},
      "reduce" => %{type: :category, values: ["sum", "max", "count"], default: "sum", bindable: true}
    }
  end

  @impl true
  def declarations(_settings) do
    {:ok,
     slots: %{
       "rows" => %{
         requires: %{"value" => %{type: :number, doc: "the field to summarize"}},
         doc: "the rows to summarize"
       }
     },
     reading: :glance}
  end

  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"rows" => delivery}} = assigns)
      when drawn in [:live, :capped] do
    case Delivery.named_rows(delivery) do
      {:ok, rows} -> stat(rows, drawn, assigns)
      # Rows that can't be read by name draw as the built-in table draws rows that don't pack.
      {:error, _faults} -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, assigns), do: Drawn.render(assigns.drawn, assigns.context)

  defp stat(rows, drawn, assigns) do
    field = Context.field(assigns.context, "rows", "value")
    values = rows |> Enum.map(&Table.get(&1, field)) |> Enum.reject(&is_nil/1)

    assigns =
      Map.merge(assigns, %{
        number: reduce(assigns.settings["reduce"], values),
        notice: Drawn.render(drawn, assigns.context),
        heading: Context.heading(assigns.context, 0)
      })

    ~H"""
    <div class="my-stat">
      {@notice}
      <.dynamic_tag tag_name={@heading}>{@settings["label"]}</.dynamic_tag>
      <p class="my-stat-number">{@number}</p>
    </div>
    """
  end

  defp reduce("count", values), do: length(values)
  defp reduce(_sum_or_max, []), do: "–"
  defp reduce("sum", values), do: Enum.sum(values)
  defp reduce("max", values), do: Enum.max(values)
end
```

The rows arrive with the source's field names, and the context says which of them the
document bound to the `value` role: `Context.field/3`, below. `Delivery.named_rows/1`
answers `{:ok, rows}`, or `{:error, faults}` for tuple rows it can't read by name, and the
render draws that as `:no_data` rather than raising. This one uses HEEx, which needs
`phoenix_live_view` in your dependencies; a render may equally answer `{:safe, iodata}`
or a string, which is escaped. Any value of the `Phoenix.HTML.Safe` protocol will do.

The assigns are a plain map, not a LiveView's: add to them with `Map.merge/2`.
`Phoenix.Component.assign/2` raises on them, because they carry no change tracking.

### `use Macaw.Component`

`use` takes the **static declarations**, the ones that never depend on settings:

| Option | Value |
|---|---|
| `name:` | required: dotted lower-case words, prefixed by your package (`"my_app.stat"`) |
| `kinds:` | required: the kinds it renders as, from `:navigation`, `:content`, `:control`, `:container` |
| `hooks:` | client hooks, `%{"HookName" => "priv/static/file.js"}` |
| `assets:` | static files it needs: `.css`, `.svg`, `.png`, `.webp`, `.woff2` or `.json` paths |

These are checked **when the module compiles**: a bad name, an unknown or missing kind,
a kind without a `render/2` clause, a clause for a kind you didn't declare, an absolute
or `..` path all fail the build, naming the problem. So a component that compiles has a
render for every kind it claims.

`Macaw.Component.info/1` reads the static declarations back, and `component?/1` says
whether a module is a component at all:

```elixir
alias MyApp.Components.Stat

{:ok, info} = Macaw.Component.info(Stat)
{info.name, info.kinds, Macaw.Component.component?(Stat), Macaw.Component.component?(String)}
#=> {"my_app.stat", [:content], true, false}

Macaw.Component.kinds()
#=> [:navigation, :content, :control, :container]
```

## Parameters and settings

`parameters/0` declares the component's settings, in the shape sources use for their
parameters (`Macaw.Data.Parameter`, chapter 2). It takes no settings: parameters are
static, so a host can validate settings before calling anything else.

- A parameter **without a default is required**: `"label"` above.
- **`bindable: true`** lets a page bind the setting to state (the page runtime's job,
  coming with `macaw_live`); a bindable parameter needs a default, which is its value
  until the state has one.

`Macaw.Component.parameters/1` checks the declarations, and `settings/2` validates given
settings, filling in defaults:

```elixir
{:ok, _parameters} = Macaw.Component.parameters(Stat)

Macaw.Component.settings(Stat, %{"label" => "Errors"})
#=> {:ok, %{"label" => "Errors", "reduce" => "sum"}}

Macaw.Component.settings(Stat, %{"label" => :errors, "reduce" => "median", "tint" => "red"})
#=> {:error, [{["label"], {:type, :text}}, {["reduce"], {:enum, ["sum", "max", "count"]}}, {["tint"], :unknown_param}]}

Macaw.Component.settings(Stat, %{})
#=> {:error, [{["label"], :required}]}

Macaw.Component.format_fault({["reduce"], {:enum, ["sum", "max", "count"]}})
#=> "reduce: {:enum, [\"sum\", \"max\", \"count\"]}"
```

A setting is the term it is: `:errors` is an atom, not text, and a `:color` parameter
takes a color term such as `~RGB"#3b6fa8"`, never a string (chapter 9). On a surface these
faults appear at `[:cells, cell, :settings, name]`.

## Declarations

`declarations/1` answers the **configured declarations**, everything that may depend on
settings, as a keyword list or map. It runs at validation, so it must be pure: no I/O, no
clock, the same answer for the same settings. It's called with every bindable parameter
at its default, so a binding can never change what a component declares.
`Macaw.Component.Declarations` builds and checks the answer:

| Key | Value | Default |
|---|---|---|
| `slots` | data inputs by name, each `%{requires: roles, doc: text}` | `%{}` |
| `writes` | standard state it writes, by name, with the value type | `%{}` |
| `local` | client-side state keys it shares, with domain types | `%{}` |
| `events` | the names of the events it emits | `[]` |
| `announces` | the names of announcements it may request | `[]` |
| `observes` | what it can observe, from `Macaw.Component.observations/0` | `[]` |
| `shortcuts` | page shortcuts, each `%{key, action, description}` | `[]` |
| `reading` | `:glance`, `:scan` or `:read` | `:glance` |
| `words` | a word count, only with `reading: :read` | `nil` |
| `stylesheets` | generated CSS strings, served by content address | `[]` |
| `proxy_routes` | media from another origin, via the host's proxy | `[]` |
| `isolation` | `:pure` or `:contained` | `:pure` |
| `access` | a capability a viewer needs to see it | `nil` |

Each key buys an effect when components are composed. `reading` tells attention analysis
a chart from an article; `events` and `writes` let a page wire interaction without the
components knowing each other; `observes` keeps a host's privacy notice exact. Every
fault is reported at once:

```elixir
alias Macaw.Component.Declarations

Declarations.keys()
#=> [:slots, :writes, :local, :events, :announces, :observes, :shortcuts, :reading,
#    :words, :stylesheets, :proxy_routes, :isolation, :access]

Declarations.new(
  [
    slots: %{"rows" => %{requires: %{"y" => %{type: :money}}}},
    events: ["open", "open"],
    writes: %{"selection" => :window, "zoom" => :number},
    observes: [:hover_item, :stare],
    words: 300,
    isolation: :contained
  ],
  Stat
)
#=> {:error,
#    [
#      {[:events], {:duplicate, "open"}},
#      {[:isolation], {:missing, ["init/2", "delivery/3", "size/2", "bound/3"]}},
#      {[:observes, 1], {:unknown_observation, :stare}},
#      {[:slots, "rows", :requires, "y", :type], {:unknown_type, :money}},
#      {[:words], :words_without_read},
#      {[:writes, "selection"], {:type, "selection", :window}},
#      {[:writes, "zoom"], {:not_standard, "zoom"}}
#    ]}
```

`Macaw.Component.declarations/2` validates settings first, then calls `declarations/1`
and builds the answer. `Declarations.emits?/2` says whether an event name is declared:

```elixir
{:ok, declarations} = Macaw.Component.declarations(Macaw.Builtin.Table, %{})
{Declarations.emits?(declarations, "sort"), Declarations.emits?(declarations, "drag")}
#=> {true, false}
```

### State a component writes

`writes` names **standard** state sources, whose meaning every host shares, and the
value type the component writes to each. `Macaw.Component.State` holds the vocabulary:

```elixir
alias Macaw.Component.State

State.standard()
#=> %{"breakpoints" => [:breakpoints], "camera" => [:camera], "selection" => [:identity], "window" => [:window]}

{State.conforms?(:window, %{last: 3600}), State.conforms?(:identity, %{"host" => "web-1"}), State.conforms?(:window, %{from: 2, to: 1})}
#=> {true, true, false}
```

`State.types/0` lists every value type and `State.local_types/0` those a `local` key may
carry. A component writes state only by emitting events; applying them is the page
runtime's.

### Events

An event a component emits is a `Macaw.Data.Event`, one shape for every component:

```elixir
alias Macaw.Data.Event

{:ok, event} =
  Event.new(
    name: "select",
    instance: "status-services",
    initiator: :visitor,
    time: ~U[2026-10-29 12:00:00Z],
    identity: %{"service" => "api"},
    row: %{"service" => "api", "p50" => 42}
  )

recorded = Event.recordable(event)
{Map.has_key?(recorded, :row), recorded.identity}
#=> {false, %{"service" => "api"}}
```

`recordable/1` is the form records and analytics see: it drops the data `row` and the
pointer position, so row values never reach a record. `Event.fields/0` lists the fields.

## Slots with roles

A slot with no `requires` reads whole rows. A slot can instead declare **roles**: the
fields it reads, with what each must be. (The table's slot declares one optional role,
`columns`, so it reads whole rows unless a document chooses its columns, chapter 5.) Here's a component that counts
the readings of a latency series:

```elixir
defmodule MyApp.Components.Readings do
  @moduledoc "How many readings of a duration series are on show, gaps not counted."
  use Macaw.Component,
    name: "my_app.readings",
    kinds: [:content],
    hooks: %{"Readings" => "priv/static/readings.js"}

  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.{Delivery, Table}

  @impl true
  def declarations(_settings) do
    {:ok,
     slots: %{
       "series" => %{
         requires: %{
           "t" => %{type: :time, window: true, doc: "when"},
           "y" => %{type: :number, quantity: :duration, doc: "how long"}
         }
       }
     }}
  end

  @impl true
  def budget("series", _settings, {width, _height}), do: max(1, trunc(width / 4))

  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"series" => delivery}} = assigns)
      when drawn in [:live, :capped] do
    y = Context.field(assigns.context, "series", "y")

    case Delivery.named_rows(delivery) do
      {:ok, rows} ->
        count = Enum.count(rows, &(Table.get(&1, y) != nil))

        {:safe,
         [Phoenix.HTML.Safe.to_iodata(Drawn.render(drawn, assigns.context)), "<p>#{count} readings</p>"]}

      {:error, _faults} ->
        Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, assigns), do: Drawn.render(assigns.drawn, assigns.context)
end
```

A requirement takes the keys `Slot.requirement_keys/0` lists: `type` (one type or a
list), `window` (must be the source's window field), `identity` (must be declared
identity), `quantity`, `many` (one or more fields, a chart's series), `optional` and
`doc`. `Macaw.Component.Slot.check/3` checks a binding, a map from role to field, against
a schema. It's what surface validation calls:

```elixir
alias Macaw.Component.Slot

{:ok, slot} =
  Slot.new(%{requires: %{"t" => %{type: :time, window: true}, "y" => %{type: :number, quantity: :duration}}})

schema =
  Macaw.Data.Schema.new!(%{
    "t" => %{type: :time},
    "host" => %{type: :category},
    "ms" => %{type: :number, unit: "ms", quantity: :duration},
    "errors" => %{type: :number}
  })

Slot.check(slot, schema, %{"y" => "ms"})
#=> :ok

Slot.check(slot, schema, %{"y" => "errors", "t" => "host", "z" => "ms"})
#=> {:error, [{["t"], {:type, [:time], :category}}, {["t"], :not_window}, {["y"], {:quantity, :duration, nil}}, {["z"], :unknown_role}]}

Slot.requirement_keys()
#=> [:type, :window, :identity, :quantity, :many, :optional, :doc]
```

A `many` role takes a list of fields, each once: a field listed twice is
`{:duplicate, field}` at the role, since a chart would draw that series twice:

```elixir
{:ok, series} = Slot.new(%{requires: %{"t" => %{type: :time, window: true}, "ys" => %{type: :number, many: true}}})

Slot.check(series, schema, %{"ys" => ["ms", "errors", "ms"]})
#=> {:error, [{["ys"], {:duplicate, "ms"}}]}
```

A `window` role left unbound reads the schema's window field, so `%{"y" => "ms"}` is
enough. `Slot.resolve/3` gives the binding it passes **resolved**: every role mapped to
its field, the window role filled in:

```elixir
Slot.resolve(slot, schema, %{"y" => "ms"})
#=> %{"t" => "t", "y" => "ms"}
```

On a surface, a cell binds roles under `fields:`. (`MyApp.Components` is this
chapter's package of components, defined under "Packages and the registry" below.)

```elixir
registry = Macaw.Registry.new!([Macaw.Builtin, MyApp.Components])
sources = %{"latency" => {%MyApp.Latency{}, nil}, "services" => {%MyApp.Services{}, nil}}

readings = fn fields ->
  {:ok, surface} =
    Macaw.Surface.new(
      name: "latency",
      cells: %{
        "count" => %{
          component: "my_app.readings",
          place: %{x: 0, y: 0, w: 4, h: 2},
          slots: %{"series" => %{source: "latency", fields: fields}}
        }
      }
    )

  Macaw.Surface.validate(surface, registry, sources)
end

{:ok, validated} = readings.(%{"y" => "ms"})
validated.cells["count"].slots["series"].fields
#=> %{"t" => "t", "y" => "ms"}

readings.(%{"y" => "host"})
#=> {:error,
#    [
#      {[:cells, "count", :slots, "series", :fields, "y"], {:type, [:number], :category}},
#      {[:cells, "count", :slots, "series", :fields, "y"], {:quantity, :duration, nil}}
#    ]}
```

So a document can't bind a duration chart to a category field, and the fault says so
before anything is fetched.

**What reaches the component.** A component receives each delivery with the
**source's** field names, and the resolved binding in its context: `Context.field(context,
slot, role)` answers the field bound to a role, a `many` role's list of fields, or `nil`
for an optional role left unbound. That's how `my_app.stat` finds its field, and why
one component reads any source whose fields meet its roles. A slot with no roles reads
every field, as the table does with its `columns` role left unbound. The context also
carries each slot's schema, so `Context.label(context, slot, field)` gives the words
that head a field (its `label`, else its name) and `Context.unit/3` its unit, which is
how the table writes its headers.

## Budgets

`budget(slot, settings, {width, height})` answers how many rows a slot wants at the cell's
declared size, or `nil` for every row (up to the host's ceiling). `my_app.readings` wants
one reading per 4 px of width. Without `budget/3`, a slot reads at the ceiling.
`Macaw.Component.budget/4` calls it and checks the answer:

```elixir
alias MyApp.Components.Readings

{Macaw.Component.budget(Readings, "series", %{}, {600, 128}), Macaw.Component.budget(Stat, "rows", %{}, {600, 128})}
#=> {{:ok, 150}, {:ok, nil}}
```

An answer that isn't a positive integer or `nil` is `{:error, {:bad_budget, answer}}`,
and the surface draws that cell `invalid` without fetching.

### Row order

A budget alone gets a sample of the rows. A slot that shows rows in an order (a table
sorted by a column) wants the **first** rows in it instead, and asks with the optional
`order(slot, settings)` callback: `[{field, :asc | :desc}, …]`, each field once, the
first key deciding first, read from its settings. It becomes the request's `order`
(chapter 2). `Macaw.Component.order/3` calls it and checks the answer:

```elixir
Macaw.Component.order(Readings, "series", %{})
#=> {:ok, []}
```

- **No callback, no order:** `{:ok, []}`, as for `my_app.readings`. The built-in table
  answers its `sort` column in its `order` direction (chapter 5).
- **A malformed answer** (a field twice, a bad direction, not a list) is
  `{:error, {:bad_order, answer}}`, and the component kit's `:order` check reports it
  (chapter 7).
- **A surface asks it for every bound slot,** puts the order in the slot's request, and
  pools slots of one source only when they ask the same order. An order the slot's schema
  can't answer, a field it lacks, draws the cell `invalid` and fetches nothing.

## Rendering

`render(kind, assigns)` gets six assigns (`Macaw.Component.Assigns.keys/0`), and nothing
else: not the viewer, not other components, not the page.

| Assign | Value |
|---|---|
| `context` | the `%Macaw.Component.Context{}` it renders in |
| `settings` | validated settings, defaults filled in |
| `declarations` | its `%Declarations{}` for those settings |
| `drawn` | its drawn state (chapter 4) |
| `deliveries` | a pure component's latest delivery per slot; a slot not delivered yet is absent |
| `value` | a contained component's value; `nil` for a pure one |

The **context** carries the mode, the instance id, the declared size, the root font
size, the heading level, the theme, the viewer's display preferences, `now` and the
cell's resolved bindings. The surface builds it for each cell; you build one yourself
in tests and standalone use:

```elixir
alias Macaw.Component.Context

{:ok, context} =
  Context.new(
    mode: :live,
    instance: "status-cpu",
    size: {600, 256},
    now: ~U[2026-10-29 12:00:00Z],
    heading_level: 3,
    bindings: %{"rows" => %{"value" => "cpu"}}
  )

{Context.heading(context, 0), Context.heading(context, 5), Context.id(context, "value")}
#=> {"h3", "h6", "status-cpu-value"}

{Context.field(context, "rows", "value"), Context.field(context, "rows", "label")}
#=> {"cpu", nil}

Context.new(mode: :web, instance: "a b", size: {0, 1})
#=> {:error, [{[:instance], :bad_id}, {[:mode], {:unknown_mode, :web}}, {[:now], :required}, {[:size], :not_a_size}]}
```

- **`Context.heading/2`** gives the heading element `depth` levels below the component's
  top, never past `h6`. Never hard-code a heading level: the surface decides the outline.
- **`Context.id/2`** gives an element id unique to the instance and stable across renders.
  Derive ids from content (a row's identity, a section's position), never a counter.
- **`now`** is the surface's. A component never reads the clock either.
- **`Context.field/3`** gives the field a role is bound to. Never assume a field's name:
  the document decides it.

### Rules every render follows

The conformance kit (chapter 7) checks these, because a component that keeps them works
on any page under a strict Content Security Policy and accessibly:

- complete HTML without a socket; native elements for behavior (`<details>`, `<dialog>`,
  real `<button>`s);
- no `style` attributes, `<style>` elements, inline scripts, `on…` attributes or
  `javascript:` URLs, and nothing loaded from another origin;
- colors from the theme's roles (`var(--mw-…)` properties or classes), never literals
  without a non-color cue;
- headings at the context's level; every control, image and link named;
- no positive `tabindex`; one tab stop per composite widget;
- **always a drawn state:** render `Macaw.Component.Drawn.render/2` (or your own notice)
  for every state you don't draw data for, so a cell is never blank.

**Kinds** add rules of their own: a `:navigation` render is a `<nav>` named by
`aria-label`, of `<a href>` links; a `:control` render uses real, named form controls; a
`:container` render is a tab list, a disclosure or a dialog; `:content` has no extra
rule. A cell picks its kind (`kind:` in the document, `:content` by default), and
validation checks the component offers it.

**Modes** are in the context. Most components render the same markup in every mode;
`Macaw.Component.Mode.allows?/2` says when not (no `<canvas>` outside `:live`, no hooks,
scripts or live regions in `:neutral` and `:print`), over the features
`Mode.features/0` lists:

```elixir
Macaw.Component.Mode.features()
#=> [:canvas, :hooks, :scripts, :tokens, :live_regions, :per_viewer]
```

### Rendered on a surface

```elixir
{:ok, surface} =
  Macaw.Surface.new(
    name: "overview",
    title: "Overview",
    cells: %{
      "errors" => %{
        component: "my_app.stat",
        settings: %{"label" => "Errors"},
        place: %{x: 0, y: 0, w: 3, h: 2},
        slots: %{"rows" => %{source: "services", fields: %{"value" => "errors"}}}
      },
      "slowest" => %{
        component: "my_app.stat",
        settings: %{"label" => "Slowest p50 (ms)", "reduce" => "max"},
        place: %{x: 3, y: 0, w: 3, h: 2},
        slots: %{"rows" => %{source: "services", fields: %{"value" => "p50"}}}
      },
      "count" => %{
        component: "my_app.readings",
        place: %{x: 6, y: 0, w: 6, h: 2},
        slots: %{"series" => %{source: "latency", fields: %{"y" => "ms"}}}
      }
    }
  )

{:ok, validated} = Macaw.Surface.validate(surface, registry, sources)

validated
|> Macaw.Surface.render(sources: sources, now: ~U[2026-10-29 12:00:30Z], ceiling: 1_000)
|> Phoenix.HTML.safe_to_string()
|> IO.puts()
```

```html
<div class="mw-cell mw-col-1 mw-span-3 mw-row-1 mw-rows-2" id="overview-errors">
  <div class="my-stat">
    <h3>Errors</h3>
    <p class="my-stat-number">10</p>
  </div>
</div>
<div class="mw-cell mw-col-4 mw-span-3 mw-row-1 mw-rows-2" id="overview-slowest">
  <div class="my-stat">
    <h3>Slowest p50 (ms)</h3>
    <p class="my-stat-number">130</p>
  </div>
</div>
<div class="mw-cell mw-col-7 mw-span-6 mw-row-1 mw-rows-2" id="overview-count"><p>120 readings</p></div>
```

The stats' headings are `h3`, one below the surface's `h2` title. One component draws
two numbers from two fields, each the field its cell bound. Both stat cells read
`"services"` with equal params and cost one fetch. The readings cell asked for 150 rows
(600 px wide) and both hosts' 120 readings fit, so it's `live`.

## Contained components

A **pure** component renders from its settings and deliveries alone. A **contained**
one holds a **value** that evolves: a simulation, a layout that takes time to compute.
It declares `isolation: :contained` and implements four transitions:

| Transition | When |
|---|---|
| `init(settings, context)` | the value is created |
| `delivery(value, slot, delivery)` | a slot's data arrives |
| `size(value, {width, height})` | the cell is sized or resized |
| `bound(value, name, new)` | a bound parameter or state changed |

The transitions are pure: no I/O, no clock, no processes. The process around the value is
the host's (the live runtime will run each in a supervised, heap-limited process). The
render reads `assigns.value`, and `deliveries` is `%{}`:

```elixir
defmodule MyApp.Components.Tally do
  @moduledoc "A running count of the rows delivered, held as a value."
  use Macaw.Component, name: "my_app.tally", kinds: [:content]

  alias Macaw.Component.Drawn
  alias Macaw.Data.Delivery

  @impl true
  def declarations(_settings), do: {:ok, slots: %{"rows" => %{}}, isolation: :contained}

  @impl true
  def init(_settings, context), do: %{rows: 0, size: context.size}

  @impl true
  def delivery(value, "rows", delivery), do: %{value | rows: value.rows + length(Delivery.rows(delivery))}

  @impl true
  def size(value, size), do: %{value | size: size}

  @impl true
  def bound(value, _name, _new), do: value

  @impl true
  def render(:content, %{drawn: :live, value: value}), do: {:safe, "<p>#{value.rows} rows</p>"}
  def render(:content, assigns), do: Drawn.render(assigns.drawn, assigns.context)
end
```

The dispatch functions call the transitions, and refuse a pure component with
`ArgumentError`:

```elixir
alias MyApp.Components.Tally

value = Macaw.Component.init(Tally, %{}, context)
value = Macaw.Component.delivery(Tally, value, "rows", Macaw.Data.Delivery.new!([%{"a" => 1}, %{"a" => 2}]))
value = Macaw.Component.size(Tally, value, {300, 128})
{value, Macaw.Component.contained?(Tally), Macaw.Component.contained?(Stat)}
#=> {%{rows: 2, size: {300, 128}}, true, false}

Macaw.Component.transitions()
#=> [init: 2, delivery: 3, size: 2, bound: 3]
```

A surface rendered by `macaw` 0.3.0 runs `init`, `delivery` for each delivered slot in
name order, and `size`, then renders with the value.

## Packages and the registry

A **package** is a module with `__members__/0`, the list of its member modules. Members
that use `Macaw.Component` are its components; one package can also hold sources,
transforms and aggregates, each read by its own registry:

```elixir
defmodule MyApp.Components do
  @moduledoc "MyApp's components, enabled in the host's registry."
  def __members__,
    do: [MyApp.Components.Stat, MyApp.Components.Readings, MyApp.Components.Tally]
end
```

`Macaw.Component.Package` reads a package the way every host does:

```elixir
alias Macaw.Component.Package

{:ok, components} = Package.components(MyApp.Components)
Enum.map(components, & &1.name)
#=> ["my_app.stat", "my_app.readings", "my_app.tally"]

{Package.check(MyApp.Components), Package.check(String)}
#=> {:ok, {:error, [{[], :not_a_package}]}}
```

Enable it in the registry next to `Macaw.Builtin`. Two components with one name across
packages fail at boot, naming both.

**Client hooks.** `my_app.readings` declared a hook, `"Readings"`, a static JS file in its
package. Macaw adds no build step; the host imports enabled packages' hooks into its own
`LiveSocket`. `Macaw.Registry.hooks/1` (or `Package.hooks/1` for a list of packages) collects
them, by name, refusing two hooks of one name:

```elixir
Macaw.Registry.hooks(registry)
#=> {:ok, %{"Readings" => {MyApp.Components, "priv/static/readings.js"}}}
```

## Assets, stylesheets and proxy routes

Everything a component loads comes from your own origin.

- **Static assets** (`assets:` on `use`) are files in your package that the host serves.
- **Generated stylesheets** (`stylesheets:` in declarations) are CSS strings a component
  computes from its settings. Each is served at its content address,
  `Macaw.Component.Stylesheet.path/1`, and refused (`:origin`) if it imports or loads
  from another origin:

  ```elixir
  alias Macaw.Component.Stylesheet

  String.starts_with?(Stylesheet.path(".my-stat{font-size:2rem}"), "/assets/")
  #=> true

  {Stylesheet.fault("@import url(https://cdn.example/x.css);"), Stylesheet.fault(".a{background:url(/img/a.png)}")}
  #=> {:origin, nil}
  ```

- **Proxy routes** (`proxy_routes:`) name media a component needs from elsewhere (map
  tiles, avatars). The component renders a same-origin path through the host's proxy,
  `Macaw.Component.Proxy.path/3`:

  ```elixir
  alias Macaw.Component.Proxy

  route = %{name: "tiles", url: "https://tiles.example/{z}/{x}/{y}.png", types: ["image/png"]}

  Proxy.path("my_app.map", route, %{"z" => "1", "x" => "0", "y" => "0"})
  #=> {:ok, "/macaw/proxy/my_app.map/tiles?x=0&y=0&z=1"}

  Proxy.path("my_app.map", route, %{"z" => "1"})
  #=> {:error, {:placeholders, ["x", "y"]}}

  Proxy.placeholders(route)
  #=> ["z", "x", "y"]
  ```

  Mounting the proxy itself is the host's, and comes with the host libraries.

## Announcements and the client

A component never renders a live region. It **requests** announcements by declared name,
and the page's one announcer speaks them. `Macaw.Component.Announcement.new/2` builds a
request, checked against the declarations:

```elixir
{:ok, saving} = Declarations.new([announces: ["saved"]], Stat)

Macaw.Component.Announcement.new(saving, name: "saved", text: "Saved", politeness: :polite)
#=> {:ok, %{name: "saved", politeness: :polite, text: "Saved"}}

Macaw.Component.Announcement.new(saving, name: "boom", text: "", politeness: :loud)
#=> {:error, [{[:name], {:undeclared, "boom"}}, {[:politeness], {:politeness, :loud}}, {[:text], :empty}]}
```

On the client, hooks find the announcer and the client bus by fixed names,
`Macaw.Component.Client`, so components share them on any page:

```elixir
alias Macaw.Component.Client

{Client.announcer_ids(), Client.announce_event(), Client.bus_name()}
#=> {%{assertive: "mw-announcer-assertive", polite: "mw-announcer-polite"}, "macaw:announce", "MacawBus"}
```

`macaw_component` ships one ES module implementing both, with no build step: the host
serves its `priv/static` (`Plug.Static, at: "/", from: {:macaw_component, "priv/static"}`)
and a hook imports it from `Client.module_url/0`. The client accepts only the names a
component declares, which reach it as the data attributes `Client.attributes/1` renders,
put on the element the hook is attached to:

```elixir
{Client.module_url(), Client.attributes(saving)}
#=> {"/macaw_component/client.js", [{"data-mw-announces", ~s(["saved"])}, {"data-mw-local", "[]"}]}
```

## Pitfalls

- **Reading the viewer or the clock in a component.** Neither reaches it, by design:
  the viewer shapes data in sources; `now` is in the context.
- **Blank renders.** Handle every drawn state. A catch-all clause that renders
  `Drawn.render(assigns.drawn, assigns.context)` is the simplest way.
- **Hard-coded heading levels or ids.** Use `Context.heading/2` and `Context.id/2`.
- **Side effects in `declarations/1` or transitions.** They run at validation and in the
  host's process; they must be pure.
- **`assign/2` on the assigns.** They're a plain map; use `Map.merge/2` or `Map.put/3`.
- **Reading a field by a fixed name.** Rows arrive with the source's field names; read
  the one bound to a role with `Context.field/3`.
- **Forgetting to enable the package.** A component not in the registry is
  `:unknown_component`, even when its module is loaded.

## Recap

- `use Macaw.Component, name:, kinds:` declares the static facts, checked at compile time.
- `parameters/0` declares settings; `declarations/1` declares slots, state, events and
  the rest, purely, every fault at once.
- Roles make slot bindings checkable before data flows, and `Context.field/3` reads the
  field each role is bound to.
- `render/2` gets six assigns; use the context for headings and ids, and always draw a
  state.
- Contained components hold a value through four pure transitions.
- Packages list members; the registry enables them and collects their hooks.

**Further reading:** [the behavior](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-behavior), [declarations](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-declares), [slots](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-slots) and [budgets](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-budget) in `macaw_component`'s spec/01; [assigns](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-assigns), [the context](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-context), [rendering rules](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-rendering) and [contained values](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-contained) and [the client protocols](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-client) in its spec/02; [packages](https://github.com/dcoai/macaw_component/blob/main/spec/03-packages.md#components-packages) in its spec/03.

Next: [chapter 7, Testing with the conformance kits](07-testing.md).
