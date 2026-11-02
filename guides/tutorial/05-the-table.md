# 5. The built-in table

`macaw` ships one built-in component, the table, registered as `"macaw.table"` in the
package `Macaw.Builtin`. This chapter covers its settings, its markup, how it sorts and
selects, its row budget, and what it draws when data is missing. It's also a worked
example of the component contract you'll implement in chapter 6.

**What you'll learn:**

- the table's parameters and declarations, read through `Macaw.Component`;
- captions, sorting, order and row identity;
- choosing columns with the `columns` role, and headers from the schema;
- how cell values are written as text;
- the table's row budget;
- notices for capped, empty and failing data;
- the table's stylesheet, and what it leaves to you.

## Reading a component's contract

Every component describes itself, and the dispatch functions in `Macaw.Component` read
those descriptions without rendering anything. That's how you find out what a component
takes:

```elixir
alias Macaw.Builtin.Table

{:ok, info} = Macaw.Component.info(Table)
{info.name, info.kinds}
#=> {"macaw.table", [:content]}

{:ok, parameters} = Macaw.Component.parameters(Table)
Map.new(parameters, fn {name, parameter} -> {name, Map.get(parameter, :default)} end)
#=> %{"caption" => "Table", "identity" => "", "order" => "asc", "sort" => ""}

{:ok, declarations} = Macaw.Component.declarations(Table, %{})
{Map.keys(declarations.slots), declarations.events, declarations.writes, declarations.reading}
#=> {["rows"], ["sort", "select"], %{"selection" => :identity}, :scan}

columns = declarations.slots["rows"].requires["columns"]
{columns.many, columns.optional}
#=> {true, true}
```

| Parameter | Type | Default | Meaning |
|---|---|---|---|
| `caption` | text | `"Table"` | the table's accessible name, its `<caption>` |
| `identity` | text | `""` | the field naming each row; `""` for rows that can't be selected |
| `sort` | text, bindable | `""` | the field rows are sorted by; `""` keeps the delivered order |
| `order` | `"asc"` or `"desc"`, bindable | `"asc"` | the sort direction |

Its declarations say it has one slot, `rows`, of whole rows, with one role, `columns`:
the fields shown, in order, of any type, many of them, and optional, so any source binds
and, left unbound, every field shows. It emits `sort` and `select` events; it writes the
standard `selection` state as an identity; it observes `:activate` and `:select`; and
its reading load is `:scan`. The live runtime will use the events and state; in 0.3.0
they're declarations, and the buttons are rendered ready for it.

## A source with some texture

To see sorting, gaps and formatting, here's a source of incidents with times, a missing
value and a position:

```elixir
defmodule MyApp.Incidents do
  @moduledoc "Recent incidents, with gaps and positions."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct []

  @schema Schema.new!(%{
            "id" => %{type: :text, identity: true},
            "opened" => %{type: :time},
            "minutes" => %{type: :number, unit: "min", quantity: :duration},
            "site" => %{type: :point}
          })

  @rows [
    %{"id" => "INC-7", "opened" => ~U[2026-10-29 09:15:00Z], "minutes" => 42, "site" => {2.35, 48.86}},
    %{"id" => "INC-8", "opened" => ~U[2026-10-29 10:02:00Z], "minutes" => nil, "site" => {-0.13, 51.51}},
    %{"id" => "INC-9 & co", "opened" => ~U[2026-10-29 11:40:00Z], "minutes" => 7, "site" => nil}
  ]

  @impl true
  def describe(%__MODULE__{}, _context), do: Description.new(schema: @schema)

  @impl true
  def fetch(%__MODULE__{}, _request),
    do: {:ok, Delivery.new(@rows, schema: Schema.version(@schema))}
end
```

A helper renders one table cell with given settings, so each example below is one line:

```elixir
registry = Macaw.Registry.new!([Macaw.Builtin])
sources = %{"incidents" => {%MyApp.Incidents{}, nil}}
now = ~U[2026-10-29 12:00:00Z]

render = fn settings, h ->
  {:ok, surface} =
    Macaw.Surface.new(
      name: "ops",
      cells: %{
        "incidents" => %{
          component: "macaw.table",
          settings: settings,
          place: %{x: 0, y: 0, w: 12, h: h},
          slots: %{"rows" => %{source: "incidents"}}
        }
      }
    )

  {:ok, validated} = Macaw.Surface.validate(surface, registry, sources)

  validated
  |> Macaw.Surface.render(sources: sources, now: now, ceiling: 1_000)
  |> Phoenix.HTML.safe_to_string()
end

IO.puts(render.(%{"caption" => "Incidents", "sort" => "minutes", "order" => "desc", "identity" => "id"}, 3))
```

## Markup, sorting and selection

That renders (indented for reading):

```html
<table class="mw-table">
  <caption>Incidents</caption>
  <thead><tr>
    <th scope="col"><button type="button" data-mw-event="sort" value="id">id</button></th>
    <th scope="col" aria-sort="descending"><button type="button" data-mw-event="sort" value="minutes">minutes (min)</button></th>
    <th scope="col"><button type="button" data-mw-event="sort" value="opened">opened</button></th>
    <th scope="col"><button type="button" data-mw-event="sort" value="site">site</button></th>
  </tr></thead>
  <tbody>
    <tr id="ops-incidents-r-SU5DLTc">
      <td><button type="button" data-mw-event="select" value="INC-7">Select INC-7</button> INC-7</td>
      <td>42</td><td>2026-10-29T09:15:00Z</td><td>2.35, 48.86</td>
    </tr>
    <tr id="ops-incidents-r-SU5DLTkgJiBjbw">
      <td><button type="button" data-mw-event="select" value="INC-9 &amp; co">Select INC-9 &amp; co</button> INC-9 &amp; co</td>
      <td>7</td><td>2026-10-29T11:40:00Z</td><td></td>
    </tr>
    <tr id="ops-incidents-r-SU5DLTg">
      <td><button type="button" data-mw-event="select" value="INC-8">Select INC-8</button> INC-8</td>
      <td></td><td>2026-10-29T10:02:00Z</td><td>-0.13, 51.51</td>
    </tr>
  </tbody>
</table>
```

What to notice:

- **A real caption and scoped headers.** Every column header is a `<th scope="col">`
  holding a real `<button>`, so sorting is reachable by keyboard and screen reader. The
  sorted column carries `aria-sort`. The header's words come from the schema (below).
- **Sorting puts `nil` last** in either direction, and keeps ties in delivered order.
  Times, dates and numbers sort by value. A `sort` naming no column is ignored.
- **With `identity`,** each row's first cell starts with a "Select" button whose value is
  the row's identity, and the row's id is derived from the identity (base64url-encoded,
  so any value makes a valid id). Ids are stable across renders and unique per instance.
- **Values are written as text:** a `DateTime` in ISO 8601, a point as
  `longitude, latitude`, `nil` as an empty cell, and everything escaped (`&amp;`).

## Columns and headers

**Headers come from the schema.** Each column is headed by its field's `label`, with its
`unit` after it in parentheses, or by the field's name when the schema gives no label:
`minutes` above has a unit and no label, so it reads `minutes (min)`, and chapter 1's
`p50` reads `Median latency (ms)`. The sort button's `value` stays the field's name,
which is what a `sort` setting names. A schema describes meaning, so the words a person
reads belong there, once, for every component that shows the field.

**Choosing columns** is binding the `rows` slot's `columns` role: the fields to show, in
the order given. Unbound, the table shows every field of the delivered rows (in name
order, for rows that are maps):

```elixir
{:ok, chosen} =
  Macaw.Surface.new(
    name: "ops",
    cells: %{
      "incidents" => %{
        component: "macaw.table",
        place: %{x: 0, y: 0, w: 12, h: 3},
        slots: %{"rows" => %{source: "incidents", fields: %{"columns" => ["minutes", "id"]}}}
      }
    }
  )

{:ok, chosen} = Macaw.Surface.validate(chosen, registry, sources)
IO.puts(chosen |> Macaw.Surface.render(sources: sources, now: now, ceiling: 1_000) |> Phoenix.HTML.safe_to_string())
```

```html
<table class="mw-table">
  <caption>Table</caption>
  <thead><tr>
    <th scope="col"><button type="button" data-mw-event="sort" value="minutes">minutes (min)</button></th>
    <th scope="col"><button type="button" data-mw-event="sort" value="id">id</button></th>
  </tr></thead>
  <tbody>
    <tr><td>42</td><td>INC-7</td></tr>
    <tr><td></td><td>INC-8</td></tr>
    <tr><td>7</td><td>INC-9 &amp; co</td></tr>
  </tbody>
</table>
```

The binding is checked against the source's schema at validation, like any role's
(chapter 6): a field the schema doesn't have is a fault at the binding's `fields`, and
so is a single name where the role takes a list, and a field listed twice:

```elixir
{:ok, typo} =
  Macaw.Surface.build("ops", cells: [{"macaw.table", name: "incidents", source: "incidents", fields: %{"columns" => ["minutes", "owner"]}}])

Macaw.Surface.validate(typo, registry, sources)
#=> {:error, [{[:cells, "incidents", :fields, "columns"], {:missing, "owner"}}]}

{:ok, twice} =
  Macaw.Surface.build("ops", cells: [{"macaw.table", name: "incidents", source: "incidents", fields: %{"columns" => ["minutes", "minutes"]}}])

Macaw.Surface.validate(twice, registry, sources)
#=> {:error, [{[:cells, "incidents", :fields, "columns"], {:duplicate, "minutes"}}]}
```

(That cell uses the `source:` shorthand, chapter 4, so its faults are at the cell's own
`fields`.) The columns shown don't limit sorting or identity: `sort` and `identity` may
name any delivered field, shown or not.

## Budget and notices

The table's row budget is the rows its declared height shows at 32 px a row, times four
for scrolling, at least 10:

```elixir
for h <- [1, 2, 4, 8], do: Macaw.Component.budget(Table, "rows", %{}, Macaw.Grid.size(%{x: 0, y: 0, w: 12, h: h}, 1200, 64))
#=> [{:ok, 10}, {:ok, 16}, {:ok, 32}, {:ok, 64}]
```

When the delivery was capped by its source, or reduced by anyone, the table draws the
"Showing part of the data" notice **above** its rows; the rows it has are still shown.
With a ceiling of 2, two of the three incidents remain:

```elixir
{:ok, capped} =
  Macaw.Surface.new(
    name: "ops",
    cells: %{
      "incidents" => %{
        component: "macaw.table",
        place: %{x: 0, y: 0, w: 12, h: 2},
        slots: %{"rows" => %{source: "incidents"}}
      }
    }
  )

{:ok, capped} = Macaw.Surface.validate(capped, registry, sources)
html = capped |> Macaw.Surface.render(sources: sources, now: now, ceiling: 2) |> Phoenix.HTML.safe_to_string()

{html =~ "Showing part of the data", length(String.split(html, "<tr")) - 2}
#=> {true, 2}
```

A delivery with no rows draws "No data", and a failing source "Source unavailable"
(chapter 4). Rows that can't be packed into columns, such as a text value in a column
the delivery's `types:` declares `:number` (chapter 3), also draw "No data".

## The table's stylesheet

The table has one static stylesheet, `Table.stylesheet/0`, served at its content
address, `Table.stylesheet_path/0`, as the layouts' sheets are. It styles the table, its
caption, cells, header and select buttons, striped rows, a visible focus ring, and the
sorted column's mark (an arrow after the header's button, from its `aria-sort`). Every
color is a theme custom property with the default theme's value as its fallback, so the
table follows the theme on the page (chapter 9). It loads and imports nothing:

```elixir
css = Table.stylesheet()
{css =~ "var(--mw-text,", String.starts_with?(Table.stylesheet_path(), "/assets/")}
#=> {true, true}
```

Serve it beside your layout's stylesheet (chapter 1 writes both to files; chapter 10
serves them from Phoenix).

## What the table leaves to you

- **The notices' look.** Its stylesheet covers the table itself. The drawn-state notices
  render classes (`mw-drawn`, `mw-glyph`, `mw-role-…`) and no styles; style them in your
  stylesheet with the theme's custom properties (chapter 9). Override the table's own
  rules there too, if you want another look.
- **Interaction.** The sort and select buttons emit events for the live runtime, which
  isn't released. On a server-rendered page they do nothing; set `sort` and `order` in
  the document instead.
- **Renaming a column.** A header reads the schema's label; change the words in the
  schema, where every component reads them.

## Pitfalls

- **Sorting by a column that isn't delivered** silently keeps the delivered order.
  Check the field's spelling against the rows.
- **Identity must be a delivered field** too. `"identity" => "id"` with no `id` column
  renders rows without select buttons.
- **Headers that read like field names.** A header is the field's name only when its
  schema has no `label`; give the field one.
- **A low ceiling with a sorted table:** reduction happens before sorting, so a
  "slowest first" table under a tight budget shows a sample of rows sorted, not the top
  rows. A request's `order` (chapter 2) is how a reader asks for the first rows in an
  order, but the table declares no `order/2`, and a surface fetched by `macaw` 0.3.0
  sends none. If you need the top rows today, have the source sort and limit, and
  declare `:budget` in its `supports`.

## Recap

- `"macaw.table"` takes `caption`, `identity`, `sort` and `order`, and reads whole rows;
  its optional `columns` role chooses and orders the fields shown, checked at validation.
- Its markup is a captioned table with scoped header buttons headed by the schema's
  labels and units, stable row ids and escaped text values.
- Its budget follows its height; capped data shows a notice above the rows.
- Its stylesheet is static, themed by custom properties, and served at its content
  address; the notices' look and interaction are yours or the live runtime's.

**Further reading:** [the table](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-table) in spec/05.

Next: [chapter 6, Writing components](06-components.md).
