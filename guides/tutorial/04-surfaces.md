# 4. Surfaces in depth

Chapter 1 rendered a one-cell surface. This chapter covers everything a surface does in
`macaw` 0.3.0: the document and its cells, layouts, the registry, validation and its
faults, fetching with budgets and pooling, drawn states, and rendering options.

**What you'll learn:**

- `Macaw.Surface` and `Macaw.Surface.Cell`: every key, its rules and its faults;
- `Macaw.Layout` and the built-in layouts: the grid, the stack, the flow and named
  areas, their placement, reading order and stylesheets;
- cells as a list, derived names and the one-slot `source:` shorthand;
- `Macaw.Registry`: enabling packages and layouts, and looking them up;
- `Macaw.Surface.validate/3` and `%Macaw.Surface.Validated{}`;
- `Macaw.Surface.fetch/2`: budgets, the ceiling, pooling, viewers and timeouts;
- drawn states: what a cell shows when its data isn't there;
- `Macaw.Surface.render/3`: modes, heading levels, themes and sizes.

The examples use `MyApp.Services` from chapter 1 and `MyApp.Latency` from chapter 2.

## The surface document

`Macaw.Surface.new/1` takes a keyword list or a map with atom keys:

| Key | Value | Default |
|---|---|---|
| `name` | lower-case words joined by `_`; it prefixes every cell's element id | required |
| `title` | a non-empty string, the surface's heading, or `nil` for none | `nil` |
| `layout` | how the cells are laid out: a layout's name or `{name, options}`, a built-in one (`:grid`, `{:grid, columns: 24}`, `{:stack, order: [...]}`, `{:flow, order: [...]}`, `{:areas, template: [...]}`) or one your registry adds | `:grid`; a stack for listed cells with no place |
| `cells` | the cells by name, at least one; or a list of cells, in order | required |

It checks the document's own shape and reports every fault at once, ordered by path. A
built-in layout's options are checked here too:

```elixir
alias Macaw.Surface

Surface.new(name: "Status Board", title: "", layout: {:grid, columns: 10}, cells: %{"a" => %{component: "macaw.table", place: %{x: 0, y: 0, w: 12, h: 4}}})
#=> {:error,
#    [
#      {[:layout, :options, :columns], {:enum, [6, 12, 24]}},
#      {[:name], {:type, :name}},
#      {[:title], {:type, :string}}
#    ]}
```

A layout whose options fail still judges its cells' places, since a place's shape needs no
options, so a missing place is reported beside the options' fault:

```elixir
Surface.new(name: "ops", layout: {:grid, columns: 10}, cells: %{"a" => %{component: "macaw.table"}})
#=> {:error,
#    [
#      {[:cells, "a", :place], :required},
#      {[:layout, :options, :columns], {:enum, [6, 12, 24]}}
#    ]}
```

Cell names follow the same rule as the surface's name: lower-case words joined by `_`.
A layout name `new/1` doesn't know, such as `"wall"`, is held as given, with its cells'
places: which layouts exist is your registry's to say, at validation.

### Cells

A cell is a `%Macaw.Surface.Cell{}` with eight keys (`Macaw.Surface.Cell.keys/0`):

| Key | Value | Default |
|---|---|---|
| `component` | the component's registered name, a string | required |
| `kind` | the kind it renders as: `:content`, `:navigation`, `:control` or `:container` | `:content` |
| `settings` | its settings by parameter name, each the term it is | `%{}` |
| `slots` | each slot bound to a source: `%{source:, fields:, params:}` | `%{}` |
| `source`, `fields`, `params` | the shorthand for a one-slot component's slot (below) | `nil`, `%{}`, `%{}` |
| `place` | where it sits, as its layout reads it: `%{x, y, w, h}` on a grid, `%{area: name}` under areas, none under a stack or a flow | required on a grid or areas |

`Macaw.Surface.Cell.new/1` builds one alone, which is handy for checking a cell a person
is editing. **Settings and params are the terms they are:** a string, a number, a
`DateTime`, a color term, a point `{lon, lat}`, an atom or a map of them, kept as given.
A cell checks only its own shape: settings and params must be maps, and their keys
names. Whether each value is of its parameter's type is a question for validation,
which knows the component's parameters and the sources' descriptions:

```elixir
alias Macaw.Surface.Cell

Cell.keys()
#=> [:component, :kind, :settings, :slots, :source, :fields, :params, :place]

{:ok, cell} = Cell.new(component: "macaw.table", settings: %{"since" => ~D[2026-01-01]})
cell.settings
#=> %{"since" => ~D[2026-01-01]}

Cell.new(component: "macaw.table", settings: %{1 => "one"}, slots: %{"rows" => %{source: "services", params: []}})
#=> {:error, [{[:settings, 1], {:type, :name}}, {[:slots, "rows", :params], {:type, :map}}]}
```

JSON can't hold every term, so the JSON form (chapter 8) writes the ones it can by tags
and refuses the rest; the surface itself is the term.

A slot binding has three keys: `source`, the source's name in your `sources` map
(required); `params`, the source's parameters (chapter 2); and `fields`, which maps the
component's **roles** to the source's fields, for components that declare roles
(chapter 6). The built-in table has one role, `columns`, which is optional: left
unbound, it shows every field (chapter 5).

## Layouts

**A layout is a behavior, the way a component is one:** `Macaw.Layout`. A surface names
its layout by `layout`, and every rule of placing its cells is the layout's: it checks
its options and each cell's place, finds the placement faults, gives the reading order,
the classes of the cells' container and of each cell, each cell's declared size, and its
one static stylesheet. The core ships four, `Macaw.Layout.builtins/0`: the grid
(`Macaw.Grid`), the stack, the flow and named areas. Validation, fetching and rendering
reach a layout only through the behavior, so a layout your app adds (registered as
below) is placed, ordered and sized by the same rules.

Every layout keeps two rules of the web: **placement is by classes from a static
stylesheet, never inline style,** so a page runs under a strict Content Security Policy;
and **reading order is the visual order,** which is the order cells appear in the HTML, so
a screen reader or keyboard user meets them in the order you see them.

### The grid

The grid is the default. It has 12 columns, or 6 or 24 with `{:grid, columns: n}`
(`Grid.widths/0`), and up to 64 rows. A place is four integers: `x` from 0 to one less
than the columns, `w` from 1 with `x + w` at most the columns, `y` from 0, `h` from 1,
and `y + h` at most 64. `Macaw.Grid` holds the rules:

```elixir
alias Macaw.Grid

{Grid.columns(), Grid.rows()}
#=> {12, 64}

Grid.faults(%{
  "a" => %{place: %{x: 0, y: 0, w: 8, h: 2}},
  "b" => %{place: %{x: 6, y: 1, w: 6, h: 2}},
  "c" => %{place: %{x: 10, y: 4, w: 4, h: 1}}
})
#=> [
#      {[:cells, "b", :place], {:overlap, "a"}},
#      {[:cells, "c", :place], {:out_of_bounds, :x_plus_w, 14}}
#    ]

Grid.faults(%{"c" => %{place: %{x: 10, y: 4, w: 4, h: 1}}}, %{columns: 24})
#=> []
```

`faults/1` judges the 12 columns, and `faults/2` the columns its options give. A surface
asks for another width by its layout, and a width outside the set is a fault at
`[:layout, :options, :columns]` (above).

An overlap is reported at the cell that comes later in **reading order**: by `y`, then
`x`, then name:

```elixir
Grid.order(%{
  "z" => %{place: %{x: 0, y: 0, w: 1, h: 1}},
  "a" => %{place: %{x: 6, y: 0, w: 1, h: 1}},
  "m" => %{place: %{x: 0, y: 1, w: 1, h: 1}}
})
#=> ["z", "a", "m"]
```

A place's classes are the same on every width; the cells' container says the width:

```elixir
Grid.classes(%{x: 0, y: 2, w: 6, h: 3})
#=> "mw-cell mw-col-1 mw-span-6 mw-row-3 mw-rows-3"

{Grid.container(%{columns: 12}), Grid.container(%{columns: 24})}
#=> {"mw-grid", "mw-grid mw-grid-24"}
```

Every class is one rule of a single static stylesheet for every width,
`Grid.stylesheet/0`. It also holds
a container query that stacks the cells in reading order, full width, when the surface is
narrower than 40rem, so a surface works on a phone without a second layout. Its CSS
custom properties `--mw-grid-row` (default `4rem`) and `--mw-grid-gap` (`1rem`) set the
row height and gap. Serve it at `Grid.stylesheet_path/0`, which is its content address:
the path changes only when the stylesheet does, so browsers may cache it forever.

```elixir
String.starts_with?(Grid.stylesheet_path(), "/assets/")
#=> true
```

A cell's **declared size** is its share of the surface's width and its rows' height,
`Grid.size(place, width, row_height)` on 12 columns (`size/4` takes the options). A
component lays out at this size until anything measures it, and its row budget is
computed from it (below):

```elixir
{Grid.size(%{x: 0, y: 0, w: 6, h: 4}, 1200, 64), Grid.size(%{x: 0, y: 0, w: 6, h: 4}, %{columns: 24}, 1200, 64)}
#=> {{600.0, 256}, {300.0, 256}}
```

### The stack and the flow

Two layouts order their cells by a list. **The stack**, `:stack`, is one column: what
the grid collapses to on a narrow screen, chosen on purpose. **The flow**, `:flow`, is
sections for prose, each as tall as its content. Their one option, `order`, is every
cell's name once, in reading order. A cell under them has no place, and its declared
size is the surface's width and four rows:

```elixir
registry = Macaw.Registry.new!([Macaw.Builtin])
sources = %{"services" => {%MyApp.Services{}, nil}, "latency" => {%MyApp.Latency{}, nil}}
now = ~U[2026-10-29 12:00:30Z]

{:ok, column} =
  Surface.new(
    name: "column",
    layout: {:stack, order: ["services", "latency"]},
    cells: %{
      "latency" => %{component: "macaw.table", slots: %{"rows" => %{source: "latency", params: %{"host" => "web-1"}}}},
      "services" => %{component: "macaw.table", slots: %{"rows" => %{source: "services"}}}
    }
  )

{:ok, validated} = Surface.validate(column, registry, sources)
html = validated |> Surface.render(sources: sources, now: now, ceiling: 100) |> Phoenix.HTML.safe_to_string()

{validated.order, html =~ ~s(<div class="mw-stack"><div class="mw-cell" id="column-services">)}
#=> {["services", "latency"], true}
```

The stack's container is `mw-stack` and each cell `mw-cell`; the flow's container is
`mw-flow` and each cell `mw-cell mw-section`. A cells map keeps no order, so the order is
the layout's to state, and it must name every cell exactly once. A place given to a cell
is refused when the surface is built; the order is checked against the cells at
validation, every fault at once:

```elixir
Surface.new(
  name: "column",
  layout: {:flow, order: ["services"]},
  cells: %{"services" => %{component: "macaw.table", place: %{x: 0, y: 0, w: 12, h: 4}}}
)
#=> {:error, [{[:cells, "services", :place], {:not_taken, "flow"}}]}

{:ok, muddled} =
  Surface.new(
    name: "column",
    layout: {:stack, order: ["services", "services", "errors"]},
    cells: %{
      "services" => %{component: "macaw.table", slots: %{"rows" => %{source: "services"}}},
      "latency" => %{component: "macaw.table", slots: %{"rows" => %{source: "latency", params: %{"host" => "web-1"}}}}
    }
  )

Surface.validate(muddled, registry, sources)
#=> {:error,
#    [
#      {[:layout, :options, :order], {:missing, "latency"}},
#      {[:layout, :options, :order, 1], {:duplicate, "services"}},
#      {[:layout, :options, :order, 2], {:unknown_cell, "errors"}}
#    ]}
```

### Named areas

`:areas` lays out named regions from a template, as CSS's `grid-template-areas` does. Its
one option, `template`, is rows of area names, each row naming the area of each of its
columns (`nil` for a column no area holds), every row as wide as the first. An area is
the rectangle of the columns that name it, and a cell's place names one,
`%{area: "main"}`, one cell to an area. Reading order is the order each area first
appears in the template, row by row:

```elixir
{:ok, board} =
  Surface.new(
    name: "board",
    layout: {:areas, template: [["head", "head"], ["side", "main"]]},
    cells: %{
      "services" => %{component: "macaw.table", place: %{area: "main"}, slots: %{"rows" => %{source: "services"}}},
      "latency" => %{
        component: "macaw.table",
        place: %{area: "head"},
        slots: %{"rows" => %{source: "latency", params: %{"host" => "web-1"}}}
      }
    }
  )

{:ok, validated} = Surface.validate(board, registry, sources)
validated.order
#=> ["latency", "services"]
```

An area no cell takes, `side` here, stays empty. The template's own faults are found when
the surface is built, at `[:layout, :options, :template]`: a row of another width
(`{:width, first, given}` at its index), an area that isn't a rectangle
(`{:not_rectangle, name}`), more than 64 rows or 24 columns. A place naming an area the
template lacks, and a second cell in one area, are found at validation:

```elixir
Surface.new(name: "board", layout: {:areas, template: [["head", "head"], ["side", "main", "main"]]}, cells: %{"a" => %{component: "macaw.table", place: %{area: "main"}}})
#=> {:error, [{[:layout, :options, :template, 1], {:width, 2, 3}}]}

{:ok, crowded} =
  Surface.new(
    name: "board",
    layout: {:areas, template: [["head", "head"], ["side", "main"]]},
    cells: %{
      "a" => %{component: "macaw.table", place: %{area: "main"}, slots: %{"rows" => %{source: "services"}}},
      "b" => %{component: "macaw.table", place: %{area: "main"}, slots: %{"rows" => %{source: "services"}}},
      "c" => %{component: "macaw.table", place: %{area: "foot"}, slots: %{"rows" => %{source: "services"}}}
    }
  )

Surface.validate(crowded, registry, sources)
#=> {:error,
#    [
#      {[:cells, "b", :place, :area], {:taken, "a"}},
#      {[:cells, "c", :place, :area], {:unknown_area, "foot"}}
#    ]}
```

The container's classes are `mw-areas` and a class carrying the digest of the template,
and each cell's `mw-cell mw-area-<area>`. Its stylesheet is generated per template: one
template is always one sheet at one address, and two templates never share a rule. Like
the grid's, it stacks the areas in reading order when the surface is narrower than 40rem.

### Serving a layout's stylesheet

Whatever the layout, `Macaw.Surface.stylesheet/1` of a validated surface is its layout's
sheet and its path, `{path, css}`: the content address to serve it at from your own
origin. The grid's, the stack's and the flow's are each one sheet whatever the surface;
an areas layout's is its template's:

```elixir
{path, css} = Surface.stylesheet(validated)
{String.starts_with?(path, "/assets/"), css =~ ~s(grid-template-areas:"head head" "side main")}
#=> {true, true}

{:ok, stacked} = Surface.validate(column, registry, sources)
Surface.stylesheet(stacked) == {Macaw.Layout.Stack.stylesheet_path(), Macaw.Layout.Stack.stylesheet()}
#=> true
```

Chapter 10 serves them from Phoenix.

## Cells as a list

A surface's cells are a map by name, and that is what a surface holds. You may also give
them as a **list**, an input form that keeps their order and can name them for you:

- **A listed cell's name** is its `name` key, else one derived from its component's last
  word and its source: `"macaw.table"` reading `"services"` is `table_services`, the
  word alone with no single source. A derived name is numbered `_2`, `_3`, … past every
  name taken, the list's explicit names first, so names are deterministic and element
  ids stable across renders.
- **With no layout and no place,** listed cells are stacked in the list's order,
  `{:stack, order: names}`; a `:stack` or `:flow` named with no `order` takes the list's.
  Listed cells that all have a place go on the grid, as mapped ones do.
- **A list placing some cells and not others** is `:place_mixed` at `[:cells]`, never a
  guess.

```elixir
{:ok, listed} =
  Surface.new(
    name: "listed",
    cells: [
      %{component: "macaw.table", slots: %{"rows" => %{source: "services"}}},
      %{component: "macaw.table", slots: %{"rows" => %{source: "services"}}},
      %{name: "table_services_2", component: "macaw.table", slots: %{"rows" => %{source: "latency"}}}
    ]
  )

listed.layout
#=> {"stack", %{order: ["table_services", "table_services_3", "table_services_2"]}}

Surface.new(
  name: "listed",
  cells: [
    %{component: "macaw.table", place: %{x: 0, y: 0, w: 6, h: 4}},
    %{component: "macaw.table"}
  ]
)
#=> {:error, [{[:cells], :place_mixed}]}
```

The second cell would have been `table_services_2`, but the third claims that name
explicitly, so the second is numbered past it. A built-in layout holds its options
checked, every name a string, so the stack reads back as `{"stack", %{order: [...]}}`.
Until a listed cell has a name, its faults are at its index, `[:cells, i | path]`; then at
its name, as a mapped cell's. The forms (chapter 8) write the expanded document, the map
and the layout with its order, so a stored surface never depends on a default.

### The source shorthand

A component with one slot is bound by `source:` on the cell, with `fields:` and `params:`
beside it as a slot binding has them: validation gives the binding to that one slot, and
`Validated` holds it under the slot's name. It's what chapter 1's `{"macaw.table", source:
"services"}` wrote:

```elixir
{:ok, short} = Surface.new(name: "short", cells: [%{component: "macaw.table", source: "latency", params: %{"host" => "web-1"}}])
{:ok, validated} = Surface.validate(short, registry, sources)

validated.cells["table_latency"].slots["rows"].params
#=> %{"host" => "web-1"}

Surface.new(name: "short", cells: %{"a" => %{component: "macaw.table", place: %{x: 0, y: 0, w: 12, h: 4}, source: "services", slots: %{"rows" => %{source: "services"}}}})
#=> {:error, [{[:cells, "a", :source], :source_and_slots}]}
```

Its faults are at the cell's own keys (`[:cells, c, :source]`, `[…, :params | path]`,
`[…, :fields | path]`). A component with no slot or several can't take it:
`{:ambiguous_slot, slots}` at `[:cells, c, :source]`, so a component that later gains a
second slot faults loudly and is never silently rebound.

### The short form

`Macaw.Surface.build(name, keys)` is `new/1` of the same keys, its cells a list of
`{component, opts}`, `opts` the cell's other keys. The surface it answers is equal to the
one written out; `build!/2` raises naming every fault:

```elixir
Surface.build!("short", cells: [{"macaw.table", source: "latency", params: %{"host" => "web-1"}}]) == short
#=> true
```

## The registry

`Macaw.Registry` is the closed list of components and layouts your documents may name.
Its components come from **packages**: modules with `__members__/0`, the list of their
components (chapter 6). Nothing is enabled implicitly, not even the built-in table:

```elixir
alias Macaw.Registry

registry = Registry.new!([Macaw.Builtin])

{Registry.component(registry, "macaw.table"), Registry.component(registry, "my_app.chart")}
#=> {{:ok, Macaw.Builtin.Table}, :error}

Registry.packages(registry)
#=> [Macaw.Builtin]

Registry.new([String])
#=> {:error, [{[String], :not_a_package}]}
```

`new/2` reports every fault at once, including two packages that register the same
component name (`{:duplicate, name, [{module, package}, …]}`). `new!/2` raises with all
of them, which is how a host should fail at boot. `components/1` lists `{name, module}`
pairs, and `hooks/1` the client hooks of every enabled component (chapter 6). Names are
looked up by spelling; an atom is read as its string, and no atom is ever made from a
document.

**Layouts are closed the same way.** A registry holds the built-in layouts and the ones
its `layouts:` option adds, each a module implementing `Macaw.Layout`, and nothing else.
A module that isn't a layout is `:not_a_layout`, and a name two layouts share
`{:duplicate_layout, name, modules}`:

```elixir
Registry.layouts(registry)
#=> [{"areas", Macaw.Layout.Areas}, {"flow", Macaw.Layout.Flow}, {"grid", Macaw.Grid}, {"stack", Macaw.Layout.Stack}]

Registry.new([Macaw.Builtin], layouts: [String])
#=> {:error, [{[:layouts, String], :not_a_layout}]}
```

A surface naming a layout its registry doesn't hold is a fault at validation:

```elixir
{:ok, wall} =
  Surface.new(name: "wall", layout: "wall", cells: %{"a" => %{component: "macaw.table", place: %{x: 0, y: 0, w: 4, h: 2}, source: "services"}})

Surface.validate(wall, registry, sources)
#=> {:error, [{[:layout], {:unknown, :layout}}]}
```

**The host's registry** usually comes from its configuration:
`config :macaw, packages: [...], layouts: [...]`. `Registry.default/0` builds it on its
first call, `Macaw.Builtin` always among the packages, and keeps it, rebuilding it only
when the configuration changes; `Registry.from_config/1` builds one from a keyword list
of the same keys. `Macaw.Surface.show/2` uses the default unless it's given `registry:`.

```elixir
Registry.from_config(packages: []) == registry
#=> true
```

## Validation

`Macaw.Surface.validate(surface, registry, sources)` is the static pass. It calls each
bound source's `describe/2` once, does no other I/O, and answers every fault at once,
ordered by path. **Each check runs on what it needs,** so one failure doesn't hide
another: a binding's source and params need only the cell; the kind and settings need
the component; which slots exist, and each binding's fields, need the component's
declarations for those settings. A check a failed prerequisite rules out is reported
as `{:unchecked, prerequisite}`, never skipped silently:

| Fault | At | Meaning |
|---|---|---|
| `{:unknown_component, name}` | `[:cells, c, :component]` | the registry doesn't hold it |
| `{:kind_not_offered, kind, kinds}` | `[:cells, c, :kind]` | the component doesn't render that kind |
| the component's settings faults | `[:cells, c, :settings, …]` | a setting is unknown, missing or of the wrong type |
| `:unbound` | `[:cells, c, :slots, s]` | a slot the component declares isn't bound |
| `:unknown_slot` | `[:cells, c, :slots, s]` | a binding of a slot it doesn't declare |
| `{:unknown_source, name}` | `[…, s, :source]` | the source isn't in your `sources` map |
| `{:describe, reason}` | `[…, s, :source]` | the source's `describe/2` failed |
| field faults | `[…, s, :fields, role]` | a role's field is missing or doesn't meet its requirement |
| params faults | `[…, s, :params, name]` | a parameter is unknown, missing, illegal or of the wrong type |
| `{:unchecked, :component}` | `[:cells, c, :slots]` | the cell's slots and fields weren't checked: its component is unknown |
| `{:unchecked, :settings}` | `[:cells, c, :slots]` | the cell's slots and fields weren't checked: its settings failed |
| `{:unknown, :layout}` | `[:layout]` | the registry holds no layout of that name |
| placement faults | `[:cells, c, :place, …]`, `[:layout, :options, …]` | the layout's: out of bounds or overlapping on a grid, an unknown or taken area, an order that misses, repeats or invents a cell |
| `{:ambiguous_slot, slots}` | `[:cells, c, :source]` | the `source:` shorthand on a component without exactly one slot |

Here is a surface with several things wrong. A source can refuse to describe itself; this
one does when its context, your configuration for it, names a table that doesn't exist:

```elixir
defmodule MyApp.Unreachable do
  @moduledoc "A source whose store is down: it describes itself, but every fetch fails."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.Schema
  alias Macaw.Data.Source.Description

  defstruct []

  @impl true
  def describe(%__MODULE__{}, :missing_table), do: {:error, :missing_table}

  def describe(%__MODULE__{}, _context),
    do: Description.new(schema: Schema.new!(%{"service" => %{type: :category}}))

  @impl true
  def fetch(%__MODULE__{}, _request), do: {:error, :unreachable}
end
```

```elixir
sources = %{
  "services" => {%MyApp.Services{}, nil},
  "archive" => {%MyApp.Unreachable{}, :missing_table}
}

{:ok, broken} =
  Surface.new(
    name: "broken",
    cells: %{
      "menu" => %{component: "macaw.table", kind: :navigation, place: %{x: 0, y: 0, w: 4, h: 2}},
      "chart" => %{
        component: "my_app.chart",
        place: %{x: 4, y: 0, w: 4, h: 2},
        slots: %{"series" => %{source: "services", params: %{"region" => "eu"}}}
      },
      "unbound" => %{component: "macaw.table", place: %{x: 8, y: 0, w: 4, h: 2}},
      "typo" => %{
        component: "macaw.table",
        place: %{x: 0, y: 2, w: 6, h: 2},
        slots: %{"rows" => %{source: "service"}, "extra" => %{source: "services"}}
      },
      "old" => %{
        component: "macaw.table",
        place: %{x: 6, y: 2, w: 6, h: 2},
        slots: %{"rows" => %{source: "archive"}}
      }
    }
  )

{:error, faults} = Surface.validate(broken, registry, sources)
faults
#=> [
#      {[:cells, "chart", :component], {:unknown_component, "my_app.chart"}},
#      {[:cells, "chart", :slots], {:unchecked, :component}},
#      {[:cells, "chart", :slots, "series", :params, "region"], :unknown_param},
#      {[:cells, "menu", :kind], {:kind_not_offered, :navigation, [:content]}},
#      {[:cells, "menu", :slots, "rows"], :unbound},
#      {[:cells, "old", :slots, "rows", :source], {:describe, :missing_table}},
#      {[:cells, "typo", :slots, "extra"], :unknown_slot},
#      {[:cells, "typo", :slots, "rows", :source], {:unknown_source, "service"}},
#      {[:cells, "unbound", :slots, "rows"], :unbound}
#    ]
```

The `chart` cell shows the rule at work. Its component is unknown, so nothing can say
which slots it has: that is `{:unchecked, :component}`. But its binding's source and
params need no component, and they're checked anyway: `MyApp.Services` takes no
`region` parameter. The `menu` cell's kind is refused, and its unbound slot is still
reported.

To show faults to a person, `Macaw.Layers.Fault.format/2` words each one with its path.
The kernel words its own reasons; the others are shown as terms:

```elixir
Enum.map(faults, &Macaw.Layers.Fault.format(&1, root: "surface"))
#=> [
#      "cells.chart.component: {:unknown_component, \"my_app.chart\"}",
#      "cells.chart.slots: {:unchecked, :component}",
#      "cells.chart.slots.series.params.region: :unknown_param",
#      "cells.menu.kind: {:kind_not_offered, :navigation, [:content]}",
#      "cells.menu.slots.rows: :unbound",
#      "cells.old.slots.rows.source: {:describe, :missing_table}",
#      "cells.typo.slots.extra: :unknown_slot",
#      "cells.typo.slots.rows.source: {:unknown_source, \"service\"}",
#      "cells.unbound.slots.rows: :unbound"
#    ]
```

Settings faults read better. A setting is checked against its parameter's type as the
term it is, so an atom where the table's `caption` takes text is refused:

```elixir
{:ok, sorted} =
  Surface.new(
    name: "sorted",
    cells: %{
      "services" => %{
        component: "macaw.table",
        settings: %{"order" => "up", "caption" => :services},
        place: %{x: 0, y: 0, w: 12, h: 4},
        slots: %{"rows" => %{source: "services"}}
      }
    }
  )

{:error, faults} = Surface.validate(sorted, registry, sources)
Enum.map(faults, &Macaw.Layers.Fault.format/1)
#=> [
#      "cells.services.settings.caption: {:type, :text}",
#      "cells.services.settings.order: must be one of \"asc\", \"desc\"",
#      "cells.services.slots: {:unchecked, :settings}"
#    ]
```

The cell's settings failed, so its slots weren't checked against the component's
declarations: fix the settings and validate again to see them checked.

### The validated surface

A `%Macaw.Surface.Validated{}` holds what rendering needs: the surface, each cell's
component module, its validated settings (defaults filled in) and declarations, each
slot's source, description, resolved binding and checked params, and the cells in
reading order. A **resolved binding** is the field each of the component's roles reads,
with an unbound window role filled in (chapter 6); it's how the binding reaches the
component:

```elixir
{:ok, surface} =
  Surface.new(
    name: "status",
    title: "Service status",
    cells: %{
      "services" => %{
        component: "macaw.table",
        settings: %{"caption" => "Services"},
        place: %{x: 0, y: 0, w: 8, h: 4},
        slots: %{"rows" => %{source: "services"}}
      },
      "latency" => %{
        component: "macaw.table",
        settings: %{"caption" => "Latency", "sort" => "t", "order" => "desc"},
        place: %{x: 8, y: 0, w: 4, h: 4},
        slots: %{"rows" => %{source: "latency", params: %{"host" => "web-1"}}}
      }
    }
  )

sources = %{"services" => {%MyApp.Services{}, nil}, "latency" => {%MyApp.Latency{}, nil}}
{:ok, validated} = Surface.validate(surface, registry, sources)

cell = validated.cells["services"]
{cell.module, cell.settings}
#=> {Macaw.Builtin.Table, %{"caption" => "Services", "identity" => "", "order" => "asc", "sort" => ""}}

{validated.order, validated.cells["latency"].slots["rows"].params}
#=> {["services", "latency"], %{"host" => "web-1"}}
```

Validate when a document is saved as well as when it's shown: the static pass is cheap,
and faults found at save time can be shown to the person who made them.

## Fetching

`Macaw.Surface.fetch(validated, env)` fetches every slot and answers each cell's
deliveries and **drawn state**: `%{cell => %{deliveries: %{slot => delivery}, drawn: state}}`.
`env` is a keyword list:

| Option | Meaning | Default |
|---|---|---|
| `sources:` | the same map you validated with | required |
| `now:` | the surface's instant; no source reads a clock | required |
| `ceiling:` | the most rows any slot may receive | required |
| `viewer:` | your viewer, passed to every source's request | `nil` (anonymous) |
| `width:` | the surface's width in CSS pixels, for declared sizes | `1200` |
| `row_height:` | a layout row's height in CSS pixels | `64` |
| `timeout:` | milliseconds a fetch may take before its cells show "Loading" | `5_000` |

```elixir
now = ~U[2026-10-29 12:00:30Z]
env = [sources: sources, now: now, ceiling: 1_000]
fetched = Surface.fetch(validated, env)

Map.new(fetched, fn {cell, %{drawn: drawn}} -> {cell, drawn} end)
#=> %{"latency" => :capped, "services" => :live}
```

Why is the latency cell `:capped`? Each slot's **budget**, the rows its component asks
for, is computed from the cell's declared size. The table asks for the rows its height
shows at 32 px a row, times four, at least 10. Four grid rows of 64 px is 256 px, so 8
rows shown and a budget of 32. The source has 60 readings for `web-1`, so the delivery
was reduced to 32 and the cell says it shows part of the data:

```elixir
delivery = fetched["latency"].deliveries["rows"]
{length(Macaw.Data.Delivery.rows(delivery)), delivery.served.reduced_by}
#=> {32, :runtime}
```

A taller cell gets more rows; a lower `ceiling:` gets fewer, for every cell:

```elixir
fetched = Surface.fetch(validated, Keyword.put(env, :ceiling, 3))
Map.new(fetched, fn {cell, %{drawn: drawn}} -> {cell, drawn} end)
#=> %{"latency" => :capped, "services" => :capped}
```

**Pooling.** Cells that read one source with equal params cost one fetch, made at the
largest of their budgets; each cell then gets its own reduction. Two tables of
`"services"` on a surface fetch it once. Cells with different params (one per host, say)
fetch separately.

**Fetching never blocks or crashes the caller.** Every fetch runs in a process of its own,
concurrently, bounded by `timeout:` (chapter 2's `Macaw.Data.Bounded`). A slow source
makes its cells draw "Loading"; a failing or crashing one, "Source unavailable".

### Viewers

Whatever you pass as `viewer:` reaches every source's request untouched. A source can
filter, refuse or tailor by it. This one shows each team its own services:

```elixir
defmodule MyApp.TeamServices do
  @moduledoc "Services visible to the viewer's team only."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct []

  @schema Schema.new!(%{
            "service" => %{type: :category, identity: true},
            "team" => %{type: :category}
          })

  @rows [
    %{"service" => "api", "team" => "core"},
    %{"service" => "billing", "team" => "payments"},
    %{"service" => "auth", "team" => "core"}
  ]

  @impl true
  def describe(%__MODULE__{}, _context), do: Description.new(schema: @schema)

  @impl true
  def fetch(%__MODULE__{}, %{viewer: %{team: team}}),
    do: Delivery.new(Enum.filter(@rows, &(&1["team"] == team)), schema: Schema.version(@schema))

  def fetch(%__MODULE__{}, %{viewer: nil}), do: {:error, :sign_in_required}
end
```

```elixir
team_sources = %{"mine" => {%MyApp.TeamServices{}, nil}}

{:ok, mine} =
  Surface.new(
    name: "mine",
    cells: %{
      "services" => %{
        component: "macaw.table",
        place: %{x: 0, y: 0, w: 12, h: 2},
        slots: %{"rows" => %{source: "mine"}}
      }
    }
  )

{:ok, mine} = Surface.validate(mine, registry, team_sources)
team_env = [sources: team_sources, now: now, ceiling: 100]

mine |> Surface.fetch([viewer: %{team: "core"}] ++ team_env) |> get_in(["services", :deliveries, "rows"]) |> Macaw.Data.Delivery.rows() |> length()
#=> 2

mine |> Surface.fetch(team_env) |> get_in(["services", :drawn])
#=> :down
```

Validation never sees a viewer: it only calls `describe/2`, which is why a description
can't depend on who's looking.

## Drawn states

Every cell is always in exactly one **drawn state**, and never blank.
`Macaw.Component.Drawn` defines them, in precedence order:

| State | When a surface draws it | Words |
|---|---|---|
| `crashed` | (the live runtime: a component's process crashed) | Couldn't be drawn |
| `down` | a fetch answered an error, or its process exited | Source unavailable |
| `invalid` | a component's budget answer was bad | Invalid settings |
| `loading` | a fetch didn't answer within `timeout:` | Loading |
| `no_data` | a delivery has no rows | No data |
| `stale` | (the live runtime: data out of date) | Out of date |
| `capped` | a delivery was capped by its source or reduced by anyone | Showing part of the data |
| `live` | everything else, and any cell without slots | |

A cell with several slots takes the highest-precedence state among them. Here is a slow
source, with a short timeout:

```elixir
defmodule MyApp.Slow do
  @moduledoc "A source that takes longer than a surface waits."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct delay: 1_000

  @schema Schema.new!(%{"n" => %{type: :number}})

  @impl true
  def describe(%__MODULE__{}, _context), do: Description.new(schema: @schema)

  @impl true
  def fetch(%__MODULE__{delay: delay}, _request) do
    Process.sleep(delay)
    Delivery.new([%{"n" => 1}], schema: Schema.version(@schema))
  end
end
```

```elixir
state_sources = %{
  "slow" => {%MyApp.Slow{}, nil},
  "down" => {%MyApp.Unreachable{}, nil},
  "services" => {%MyApp.Services{}, nil}
}

table = fn source, x ->
  %{component: "macaw.table", place: %{x: x, y: 0, w: 4, h: 2}, slots: %{"rows" => %{source: source}}}
end

{:ok, states} =
  Surface.new(
    name: "states",
    cells: %{"slow" => table.("slow", 0), "down" => table.("down", 4), "fine" => table.("services", 8)}
  )

{:ok, states} = Surface.validate(states, registry, state_sources)
state_env = [sources: state_sources, now: now, ceiling: 100, timeout: 50]
fetched = Surface.fetch(states, state_env)

Map.new(fetched, fn {cell, %{drawn: drawn}} -> {cell, drawn} end)
#=> %{"down" => :down, "fine" => :live, "slow" => :loading}

IO.puts(states |> Surface.render(fetched, state_env) |> Phoenix.HTML.safe_to_string())
```

Each state other than `live` renders a static notice, the same in every mode:

```html
<div class="mw-cell mw-col-1 mw-span-4 mw-row-1 mw-rows-2" id="states-slow">
  <p class="mw-drawn mw-drawn-loading" data-mw-drawn="loading">
    <span class="mw-glyph mw-glyph-square mw-role-info" aria-hidden="true"></span> Loading</p>
</div>
<div class="mw-cell mw-col-5 mw-span-4 mw-row-1 mw-rows-2" id="states-down">
  <p class="mw-drawn mw-drawn-down" data-mw-drawn="down">
    <span class="mw-glyph mw-glyph-cross mw-role-bad" aria-hidden="true"></span> Source unavailable</p>
</div>
```

The notice is text, so it reads without color or images; the glyph element carries the
state's theme role as a class for your stylesheet (chapter 9). A capped table draws the
"Showing part of the data" notice above its rows. You can use the module directly:

```elixir
alias Macaw.Component.Drawn

{Drawn.pick([:capped, :loading, :no_data]), Drawn.words(:no_data), Drawn.role(:down)}
#=> {:loading, "No data", :bad}

Drawn.all()
#=> [:crashed, :down, :invalid, :loading, :no_data, :stale, :capped, :live]
```

## Rendering

`Macaw.Surface.render(validated, fetched, env)` renders what `fetch/2` answered;
`render(validated, env)` fetches and renders in one call. Rendering takes these options
on top of fetching's:

| Option | Meaning | Default |
|---|---|---|
| `mode:` | `:live`, `:socketless`, `:neutral` or `:print` | `:socketless` |
| `heading_level:` | the level of the surface's title | `2` |
| `theme:` | a `Macaw.Layers.Theme` every component renders with | `Macaw.Layers.Theme.default()` |
| `width:`, `row_height:` | as for fetching: the declared sizes components lay out at | `1200`, `64` |
| `now:` | the instant components see | required |

`Macaw.Surface.show(surface, env)` validates, fetches and renders in one call, answering
`{:ok, html}` or validation's faults. It takes the same options, with defaults a host
would otherwise restate: `registry:` (`Macaw.Registry.default/0`), `now:` (one clock read,
in that call), `ceiling:` (`config :macaw, :ceiling`, raising with neither) and `mode:`
(`:socketless`, or from a LiveView's `socket:`, chapter 10). Only `sources:` is
required. It renders exactly what `validate/3` then `render/2` render, given the same
`now`.

Splitting fetch from render lets you fetch once and render twice: say, a page and its
printout.

**Headings follow the page's outline.** The title is an `h2` by default; give
`heading_level: 3` when the surface sits under an `h2` of your page. Components' own
headings go one level below the title, or at the title's level when the surface has no
title, so the page keeps one outline:

```elixir
html = validated |> Surface.render(env ++ [heading_level: 3]) |> Phoenix.HTML.safe_to_string()
String.starts_with?(html, ~s(<div class="mw-surface" id="status"><h3 class="mw-surface-title">Service status</h3>))
#=> true
```

**Modes** say where the markup goes. `:socketless` is complete HTML for a first render, a
bot or a browser without JavaScript; `:live` is for a connected LiveView; `:neutral` is
a base render with nothing per viewer, for records; `:print` is for print and PDF.
`Macaw.Component.Mode.allows?/2` says what each allows; the built-in table renders the
same markup in every mode:

```elixir
alias Macaw.Component.Mode

{Mode.all(), Mode.allows?(:neutral, :hooks), Mode.allows?(:live, :canvas)}
#=> {[:live, :socketless, :neutral, :print], false, true}
```

**Element ids** are `"<surface>-<cell>"` for each cell, and components derive theirs from
it, so ids are stable across renders and unique on the page as long as surface names are.

## Pitfalls

- **Reading `{:unchecked, _}` as the whole story.** It says a cell's slots and fields
  weren't checked, because its component is unknown or its settings failed. Fix those
  and validate again: the slots may have faults of their own.
- **Overlapping cells.** The grid refuses them; move one down. Remember `y + h <= 64`.
- **A stack's or flow's order out of step with its cells.** It must name every cell
  once: adding a cell to a map means adding it to the order. List the cells instead, and
  the order is the list's.
- **Mixing placed and unplaced listed cells.** That is `:place_mixed`, never a guess:
  place them all (a grid) or none (a stack).
- **Huge budgets.** A tall cell asks for many rows; `ceiling:` is your cap. Set it to
  what your sources can serve quickly.
- **Expecting a viewer in validation.** `describe/2` never sees one. Check access in
  `fetch/2`.
- **Two surfaces with one name on a page.** Element ids would collide; give each its own
  name.
- **A component that raises.** Rendering doesn't catch it: the error is yours to see,
  which is what you want in development. The live runtime will isolate components by
  process.

## Recap

- A surface is a named document of cells under a layout; a cell names a component, its
  kind, settings, slot bindings (or the one-slot `source:` shorthand) and place.
- A layout is a `Macaw.Layout`: the grid (6, 12 or 24 columns), the stack and the flow
  (by `order`) and named areas (by `template`) are built in. Each places cells by classes
  from a static stylesheet, `Surface.stylesheet/1`, in reading order.
- Cells may be a list: their order is kept, names derived, and unplaced cells stacked.
- The registry is closed: list the packages and layouts your documents may use.
- Validation answers every fault by path; fetching budgets each slot by its cell's size,
  clamps to the ceiling, pools equal requests and never blocks; every cell has a drawn
  state; rendering takes a mode, heading level and theme.

**Further reading:** [the surface document](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-document), [cells](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-cells), [layouts](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-layouts), [the grid](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-grid), [validation](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-validate), [fetching](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-fetch) and [rendering](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-render) in spec/06; [the registry](https://github.com/dcoai/macaw/blob/main/spec/12-registry.md#registry-host) in spec/12; [drawn states](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-states) in `macaw_component`'s spec/02.

Next: [chapter 5, The built-in table](05-the-table.md).
