# 1. Your first surface

In this chapter you install Macaw, write a small data source, and render a **surface**,
Macaw's unit of composition, to HTML: first in five lines, then spelled out step by step,
so you see what each piece is and what the short form fills in for you.

**What you'll learn:**

- how to add Macaw to a Mix project and configure it;
- what a source, a registry, a surface and a cell are, and how they fit together;
- the short code form, `Macaw.Surface.build!/2` and `Macaw.Surface.show/2`;
- the steps every surface goes through: building, validation, then rendering;
- how to look at the result in a browser.

## Installing

Macaw's core is the `macaw` package. Add it to your dependencies in `mix.exs`:

```elixir
{:macaw, "~> 0.3.0"}
```

It brings `macaw_layers`, `macaw_data`, `macaw_component` and `phoenix_html` with it, so
you don't list them yourself. Run `mix deps.get`, and you're ready. Macaw needs Elixir 1.18
or later.

Macaw is a very early release: every 0.x version may change its API. This tutorial
describes `macaw` 0.3.0 on `macaw_layers` 0.3, `macaw_data` 0.7 and `macaw_component` 0.2.

## The plan

You'll build a small "service status" surface: a table of services with their latency
and error counts. Four things take part:

```text
  MyApp.Services            the source: describes its data, answers fetches
        │
        ▼
  Macaw.Registry            the components and layouts the host allows ("macaw.table")
        │
        ▼
  Macaw.Surface             the document: cells laid out by a layout, bound to sources
        │  validate/3 ─────► Macaw.Surface.Validated
        ▼
  Macaw.Surface.render/2    fetches every slot, renders every cell: one HTML value
```

The surface is a value, an Elixir term. It names a component (`"macaw.table"`) and a
source (`"services"`) by string, and your code maps those names to real modules when it
validates and renders. That separation is what lets surfaces be stored, shared and
edited as documents, while your application decides which components and data they can
reach.

## Step 1: a source

A **source** is anything a cell can read data from. It is a struct whose module
implements the `Macaw.Data.Source` behavior with two callbacks:

- `describe/2` says what the data *is*: its schema, its parameters, what it supports;
- `fetch/2` answers one request with a `Macaw.Data.Delivery`, the rows.

Create `lib/my_app/services.ex`:

```elixir
defmodule MyApp.Services do
  @moduledoc "Service health, one row per service. A real source would query a store."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct []

  @schema Schema.new!(%{
            "service" => %{type: :category, identity: true},
            "region" => %{type: :category, values: ["eu", "us"]},
            "p50" => %{type: :number, unit: "ms", quantity: :duration, label: "Median latency"},
            "errors" => %{type: :number, label: "Errors in the last hour"}
          })

  @rows [
    %{"service" => "api", "region" => "eu", "p50" => 42, "errors" => 0},
    %{"service" => "auth", "region" => "eu", "p50" => 18, "errors" => 2},
    %{"service" => "billing", "region" => "us", "p50" => 95, "errors" => 7},
    %{"service" => "search", "region" => "us", "p50" => 61, "errors" => 0},
    %{"service" => "mail", "region" => "eu", "p50" => 130, "errors" => 1}
  ]

  @impl true
  def describe(%__MODULE__{}, _context), do: Description.new(schema: @schema)

  @impl true
  def fetch(%__MODULE__{}, _request),
    do: {:ok, Delivery.new(@rows, schema: Schema.version(@schema))}
end
```

A few things to notice:

- **The schema describes meaning, not presentation.** `"p50"` is a number in
  milliseconds that measures a duration; `"service"` names the thing each row is about
  (`identity: true`). Components read these facts to decide how to show the data. There
  is no color or format in a schema. Chapter 3 covers schemas in full.
- **`describe/2` takes a context, never a viewer.** The context is your configuration for
  the source (a connection name, a tenant); it's `nil` here. What a source *is* never
  depends on who is looking.
- **Errors are values.** Both callbacks answer `{:ok, …}` or `{:error, reason}`; a source
  never raises.
- **The delivery names the schema's version,** a hash of the schema's content, so a
  reader always knows which schema its rows were produced under.

## Step 2: a surface in five lines

With a source in hand, a surface that shows it in the built-in table is five lines:

```elixir
now = ~U[2026-11-01 12:00:00Z]

{:ok, html} =
  "status"
  |> Macaw.Surface.build!(title: "Service status", cells: [{"macaw.table", source: "services"}])
  |> Macaw.Surface.show(sources: %{"services" => {%MyApp.Services{}, nil}}, ceiling: 1_000, now: now)

IO.puts(Phoenix.HTML.safe_to_string(html))
```

- **`build!/2`** builds the surface named `"status"` from its keys. Its `cells` is a list,
  each cell `{component, opts}`: here one cell, the table, reading the source the
  document calls `"services"`. It raises naming every fault, because a surface written
  in code with a mistake in it is a bug in that code.
- **`show/2`** validates the surface, fetches its data and renders it, answering
  `{:ok, html}` or `{:error, faults}`. `sources:` maps the names a document uses to
  `{source, context}` pairs: your code deciding which data a name reaches.
- **`ceiling:`** is the most rows any one slot may receive, your guard against a
  component asking for a million rows. A host sets it once in its configuration instead
  (below).
- **`now:`** is the surface's "now". Every source and component sees this one instant,
  which keeps a surface consistent. Left out, `show/2` reads the clock once itself, as a
  host does when it serves a page; an example or a test gives its own, so its output is
  the same on every run.

The result is a `Phoenix.HTML` safe value. Printed, it looks like this (indented here for
reading):

```html
<div class="mw-surface" id="status">
  <h2 class="mw-surface-title">Service status</h2>
  <div class="mw-stack">
    <div class="mw-cell" id="status-table_services">
      <table class="mw-table">
        <caption>Table</caption>
        <thead><tr>
          <th scope="col"><button type="button" data-mw-event="sort" value="errors">Errors in the last hour</button></th>
          <th scope="col"><button type="button" data-mw-event="sort" value="p50">Median latency (ms)</button></th>
          <th scope="col"><button type="button" data-mw-event="sort" value="region">region</button></th>
          …
        </tr></thead>
        <tbody>
          <tr><td>0</td><td>42</td><td>eu</td><td>api</td></tr>
          …
        </tbody>
      </table>
    </div>
  </div>
</div>
```

The surface is complete HTML: no JavaScript, no inline style, nothing loaded from
elsewhere. The headers come from the schema: a field's `label` with its unit after it
(`Median latency (ms)`), or its name when it has no label. Layout is done with classes
(`mw-stack`, `mw-cell`) from static stylesheets you serve (step 4).

### Configuring the host

An application sets what every surface shares once, in `config/config.exs`:

```
import Config

config :macaw, ceiling: 1_000
```

With that, `show/2` takes the ceiling from the configuration, and a call needs only
`sources:`. Without either, `show/2` raises `ArgumentError`: a host that never chose a
ceiling is misconfigured. The same configuration lists the component packages your
documents may use, `packages: [...]`, which chapter 6 adds to.

## Step 3: what the five lines expand to

The short form fills in defaults. Here is the same surface spelled out, one step at a
time, with each default made explicit.

### The registry

A **registry** lists the components and layouts a host allows its documents to use. It's
closed by default: a component is only available when its package is listed. The core's
built-in components (today, one: the table) are the package `Macaw.Builtin`, which the
host's default registry always holds, whatever the configuration lists:

```elixir
registry = Macaw.Registry.default()

Macaw.Registry.components(registry)
#=> [{"macaw.table", Macaw.Builtin.Table}]

Macaw.Registry.layouts(registry) |> Enum.map(fn {name, _module} -> name end)
#=> ["areas", "flow", "grid", "stack"]
```

`Macaw.Registry.default/0` builds the registry from `config :macaw, packages: [...]` on
its first call and keeps it, so a host calls it as it boots: a misconfigured package
fails the boot. `show/2` uses it unless you pass `registry:`. To build one yourself,
`Macaw.Registry.new!([Macaw.Builtin])` lists the packages explicitly (chapter 4).

### The surface

A **surface** is a set of **cells**, each naming a component, its settings, and, for
each of the component's **slots** (its data inputs), the source the slot reads. Its
**layout** says how the cells are arranged. This is the surface `build!/2` made:

```elixir
{:ok, surface} =
  Macaw.Surface.new(
    name: "status",
    title: "Service status",
    layout: {:stack, order: ["table_services"]},
    cells: %{
      "table_services" => %{component: "macaw.table", source: "services"}
    }
  )

surface == Macaw.Surface.build!("status", title: "Service status", cells: [{"macaw.table", source: "services"}])
#=> true
```

Three defaults filled it in:

- **The cell's name.** Cells are a map by name. A listed cell with no `name` gets one
  derived from its component's last word and its source, `table_services`; the name
  prefixes the cell's element id (`status-table_services`).
- **The layout.** Listed cells with no place are stacked, one column, in the list's
  order: `{:stack, order: [...]}`. Give each cell a `place` and they go on a 12-column
  grid instead (chapter 4).
- **The slot.** `source: "services"` is the shorthand for the component's one slot. The
  table has one, `"rows"`, so it means `slots: %{"rows" => %{source: "services"}}`,
  which you can write instead.

`Macaw.Surface.new/1` (and `build/2`) only check the document's own shape: required keys,
names, types, and the layout's rules for placing cells. It doesn't know yet whether
`"macaw.table"` exists or what `"services"` is.

### Validation

Validation checks the surface against the real world: your registry and your sources,
given as the same map `show/2` took:

```elixir
sources = %{"services" => {%MyApp.Services{}, nil}}

{:ok, validated} = Macaw.Surface.validate(surface, registry, sources)

{validated.order, validated.cells["table_services"].slots["rows"].source}
#=> {["table_services"], "services"}
```

This is the **static pass**: it finds the component and the layout, checks the cell's
settings against the component's parameters, binds the shorthand to the `rows` slot,
checks every slot is bound, and calls each source's `describe/2` to check the binding
against its schema. It does no other I/O and knows nothing of any viewer, so you can run
it when a document is saved, not only when it's shown. The answer, a
`%Macaw.Surface.Validated{}`, is the only thing that renders: a surface that hasn't
passed validation can't be drawn by mistake.

### Rendering

`Macaw.Surface.render/2` fetches every slot and renders every cell:

```elixir
rendered = Macaw.Surface.render(validated, sources: sources, now: now, ceiling: 1_000)

Phoenix.HTML.safe_to_string(rendered) == Phoenix.HTML.safe_to_string(html)
#=> true
```

Its three options are required: `sources:`, `now:` and `ceiling:`, which `show/2`
defaulted where it could. It renders in the `:socketless` mode, complete HTML for a page
with no live connection, which is `show/2`'s default too (chapter 10 renders for a
LiveView). The output is byte for byte what the five lines rendered.

## Step 4: seeing it

The page needs two stylesheets: the layout's, which arranges the cells, and the table's.
`Macaw.Surface.stylesheet/1` gives a validated surface's layout sheet as `{path, css}`;
the table's is `Macaw.Builtin.Table.stylesheet/0`. Write them and the page to files:

```elixir
{_path, layout_css} = Macaw.Surface.stylesheet(validated)

File.mkdir_p!("tmp/preview")
File.write!("tmp/preview/layout.css", layout_css)
File.write!("tmp/preview/table.css", Macaw.Builtin.Table.stylesheet())

File.write!("tmp/preview/index.html", """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><title>Status</title>
<link rel="stylesheet" href="layout.css"><link rel="stylesheet" href="table.css">
</head>
<body>#{Phoenix.HTML.safe_to_string(html)}</body>
</html>
""")
```

Open `tmp/preview/index.html`. You'll see the table across the page, with a ruled
header and striped rows. Its colors are the default theme's; chapter 9 themes them. In
a Phoenix app you serve each stylesheet from your endpoint at its `path`, a content
address that changes only when the stylesheet does (chapter 10).

The sort buttons in the header don't do anything yet. They emit events
(`data-mw-event="sort"`) for the live runtime, `macaw_live`, which isn't released; for
now a surface is rendered complete on the server, and that's what this tutorial covers.

## Pitfalls

- **Names are strings in documents.** You may write `name: :status` in Elixir, and Macaw
  reads the atom as its spelling, but it never turns a document's string into an atom.
  Component, source, cell and slot names are strings.
- **Validate with the same sources you render with.** The `sources` map is how names in
  the document reach your code; a name missing from it is a validation fault.
  `show/2` takes it once, for both.
- **Don't call `DateTime.utc_now/0` inside a source.** A source gets `now` in its request.
  Reading the clock makes two fetches of one request disagree. The one clock read is the
  host's, in `show/2`.
- **`render/2` takes a validated surface,** not a `%Macaw.Surface{}`. A function clause
  error there means you skipped `validate/3`; `show/2` does both.

## Recap

- A **source** describes its data (a schema) and fetches rows (a delivery).
- A **registry** is the closed list of components and layouts your host allows;
  `Macaw.Registry.default/0` builds it from your configuration, with the built-in table.
- A **surface** is a document of **cells** under a **layout**; each cell names a
  component and binds its slots to sources by name.
- `build!/2 |> show/2` is the short form; it expands to `new/1` with derived names, a
  stack and the slot shorthand, then `validate/3` and `render/2` with `sources:`, `now:`
  and `ceiling:`.

**Further reading:** the core's goals in [spec/00 §2](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-goals), and surfaces in [spec/06 §3](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-regions), the one call and the short form in [§3.7](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-show) and [§3.8](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-build).

Next: [chapter 2, Sources](02-sources.md), goes deep on the source contract.
