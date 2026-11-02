# 3. Schemas, tables and deliveries

A source answers with data and says what the data means. This chapter covers the three
values involved: the **schema** (what each field means), the **table** (columnar typed
data) and the **delivery** (one answer of a source, with the facts of what it served).
It also covers the units and quantities a schema's numbers are measured in.

**What you'll learn:**

- `Macaw.Data.Schema`: field types and attributes, identity, the window field, declared
  values, faults, versions, compatibility and the JSON form;
- `Macaw.Data.Unit` and `Macaw.Data.Quantity`: units by their UCUM codes;
- `Macaw.Data.Schema.Cache`: schemas by version;
- `Macaw.Data.Table`: building, reading and slicing columnar data;
- `Macaw.Data.Delivery`: rows as the source gave them, `served` facts and `origin`.

## Schemas

A schema maps each field, named as the rows name it, to a **description** of what it
means. `Macaw.Data.Schema.new/1` is the only constructor:

```elixir
alias Macaw.Data.Schema
import Macaw.Layers.Color, only: [sigil_RGB: 2]

{:ok, schema} =
  Schema.new(%{
    "t" => %{type: :time},
    "host" => %{type: :category, identity: true, label: "Host"},
    "state" => %{
      type: :category,
      values: [
        %{value: "ok", name: "OK"},
        %{value: "warn", name: "Warning"},
        %{value: "fail", name: "Failing", color: ~RGB"#c23238"}
      ],
      order: ["ok", "warn", "fail"],
      status: %{"ok" => :good, "warn" => :warning, "fail" => :bad}
    },
    "cpu" => %{
      type: :number,
      unit: "%",
      quantity: :ratio,
      bounds: [0, 100],
      polarity: :lower_is_better,
      target: 70,
      metric_kind: :gauge
    },
    "where" => %{type: :point, label: "Location"}
  })
```

### Types and attributes

Every field has a `type`, one of six:

| Type | Holds |
|---|---|
| `:time` | instants: `DateTime`, `NaiveDateTime` or `Date`; never a counter |
| `:number` | integers and floats |
| `:category` | one of a set of values: strings, atoms or numbers |
| `:text` | free text |
| `:color` | data colors as color terms, one per row (a team's color), never drawing colors |
| `:point` | a geographic position, `{longitude, latitude}` |

The other attributes say as much as the source knows. `Schema.attributes/0` lists all
fourteen:

```elixir
Schema.attributes()
#=> [:type, :unit, :quantity, :label, :order, :status, :polarity, :target,
#    :continuity, :window, :metric_kind, :bounds, :identity, :values]
```

- `unit` (a UCUM code) and `quantity` (what the unit measures), for numbers;
- `label`, the field's name for a person;
- `order` and `status` for categories: the states in order, and what each means as a
  theme role (`:good`, `:warning`, `:bad`, `:info`, `:neutral`);
- `polarity` (`:higher_is_better`, `:lower_is_better`, `:neutral`) and `target`;
- `bounds`, where values physically lie, a display hint, never validation;
- `metric_kind` (`:gauge`, `:counter`, `:rate`), how a number was measured;
- `continuity`, the longest gap between readings that is still one run;
- `window`, to choose the window field (below);
- `identity`, to say a field names the thing a row is about;
- `values`, the complete set a category takes.

`fetch/2` reads a field's description, and `fetch/3` one attribute, by either spelling of
the name:

```elixir
Schema.fetch(schema, :cpu, :unit)
#=> {:ok, "%"}

Schema.fetch(schema, "nope")
#=> :error
```

### Values, names and colors

A category's `values` may be bare values or entries with a display `name` and a data
`color`. Read them back with `values/2`, `value_names/2` and `value_colors/2`:

```elixir
{Schema.values(schema, "state"), Schema.value_names(schema, "state"), Schema.value_colors(schema, "state")}
#=> {["ok", "warn", "fail"],
#    %{"fail" => "Failing", "ok" => "OK", "warn" => "Warning"},
#    %{"fail" => ~RGB"#c23238"}}

Schema.entry_keys()
#=> [:value, :name, :color]
```

A data color is a **color term** (`color?/1`): a literal `%Macaw.Layers.Color{}`, which
`~RGB"#c23238"` writes in code and `Macaw.Layers.Color.parse!/1` reads from text at your
input's edge, or a theme color such as `{:color, "bad"}`. A string is never a color, so
`color: "#c23238"` is refused as `{:type, :color}`. **A schema never holds a drawing
color.** A `color` key on a field is refused, with a fault that points you to `status`,
`order`, `polarity` or `quantity`, which carry the meaning a theme turns into color.

```elixir
{Schema.color?(~RGB"#663399"), Schema.color?({:color, "bad"}), Schema.color?("rebeccapurple")}
#=> {true, true, false}
```

(In a `#=>` line, `~RGB"#c23238"` stands for the struct the sigil builds, which `iex`
shows as `%Macaw.Layers.Color{r: 194.0, g: 50.0, b: 56.0, opacity: 1.0}`.)

A schema holds every field name, and every state and role, as a string, whatever
spelling you built it with; every function that takes a name takes either spelling.

### Identity and the window field

**Identity is declared, never guessed.** A field with `identity: true` names the entity a
row is about; several fields together form a composite identity. Selection, "latest per
host" and per-identity derivations all read it:

```elixir
{Schema.identity(schema), Schema.identity(schema, %{"host" => "web-1", "cpu" => 12})}
#=> {["host"], "web-1"}
```

**The window field** is what a request's window applies to: the field marked
`window: true`, else the schema's only `:time` field. With two time fields and neither
marked there is none, because "the first" would be a guess:

```elixir
{Schema.window_field(schema), Schema.window_kind(schema)}
#=> {"t", :range}

Schema.window_field(Schema.new!(%{"start" => %{type: :time}, "end" => %{type: :time}}))
#=> nil
```

`window_kind/1` is `:range` over a `:time` or `:number` field and `:box` over a `:point`.

### Faults

A bad schema answers every fault at once, ordered by path, and `format_error/1` words
each one:

```elixir
Schema.new(%{
  "cpu" => %{type: :number, unit: "pct", fill: "red"},
  "t" => %{type: :time, identity: true},
  "x" => %{}
})
#=> {:error,
#    [
#      {["cpu", :fill], {:color_key, :fill}},
#      {["cpu", :unit], {:unit, "pct", {:unknown_atom, "pct"}}},
#      {["t", :identity], {:invalid_for, :time}},
#      {["x", :type], :required}
#    ]}

{:error, [fault]} = Schema.new(%{"cpu" => %{type: :number, unit: "%", quantity: :duration}})
Schema.format_error(fault)
#=> "cpu.quantity: unit \"%\" does not measure :duration (spec/03 §13)"
```

`Schema.new!/1` raises `ArgumentError` with every fault formatted; use it for schemas
built from constants, as the sources in this tutorial do.

### Versions, compatibility and JSON

A schema's **version** is the SHA-256 of the schema term's canonical encoding, not of
any JSON: the same on every node, and new with any change. A delivery names the version
its rows were made under:

```elixir
String.length(Schema.version(schema))
#=> 64
```

`compatibility/2` says whether another schema's rows read as this one's: every field
present, of the same type, in units that convert, with the same identity. Labels and
other facts aren't compared:

```elixir
history = Schema.new!(%{"t" => %{type: :time}, "host" => %{type: :category, identity: true}, "cpu" => %{type: :number, unit: "1"}})
Schema.compatibility(schema, history)
#=> {:error, [{"state", :missing}, {"where", :missing}]}
```

(`"%"` and `"1"` are both dimensionless, so `cpu` converts and passes.)

The JSON form is an adapter at the edge, for storing or sending a schema: the schema
itself is the term. The document is an object, its form's version stamped beside the
fields, so a later form can tell an old document from a new one. A value entry's color
is written in the colors' tagged form, and reading it back makes no atoms and gives the
same schema:

```elixir
json = Schema.to_json(schema)
{String.starts_with?(json, ~s({"$version":1,"fields":[)), json =~ ~s({"$rgb":"#c23238"})}
#=> {true, true}

{:ok, back} = Schema.from_json(json)
back == schema
#=> true
```

`from_json/2` reads through the document kernel's gates (chapter 8): it takes `limits:`
to tighten the document limits, refuses a newer stamp by name before reading anything
(`{[], {:newer_schema, needs, 1}}`), and still reads a document written before the
stamp, whose root was the bare list of fields. `to_map/1` and `from_map/1` are the bare
pairs, unstamped, for a document that embeds a schema (a derived source's, chapter 11).

## Units and quantities

Units are named by their [UCUM](https://ucum.org/ucum) codes, the case-sensitive codes
OpenTelemetry uses: `s`, `ms`, `By`, `kBy`, `%`, `Cel`, `kW.h`, `{request}/s`. One code
per unit means two sources can't label the same thing two ways. `Macaw.Data.Unit` reads
and converts them:

```elixir
alias Macaw.Data.{Quantity, Unit}

{Unit.valid?("kW.h"), Unit.parse("sec")}
#=> {true, {:error, {:unknown_atom, "sec"}}}

{Unit.convert(1500, "ms", "s"), Unit.convert(100, "Cel", "[degF]")}
#=> {1.5, 212.0}

Unit.symbol("kBy/s")
#=> "kB/s"
```

People type symbols, not codes. `parse_alias/1` reads a symbol, and refuses an
ambiguous one by naming what it could mean:

```elixir
Unit.parse_alias("°C")
#=> {:ok, "Cel"}

Unit.parse_alias("KB")
#=> {:error, {:ambiguous, "KB", [{"kBy", "1,000 bytes"}, {"KiBy", "1,024 bytes"}]}}
```

`Unit.conversion/2` gives the exact scale and offset between two codes, and
`Unit.dimension/1` a code's dimension. A **quantity** says what a unit measures, from a
fixed list (`Quantity.all/0`). A schema checks that a field's unit measures its quantity,
as the fault above showed:

```elixir
{Quantity.of_unit("ms"), Quantity.of_unit("kW.h"), Quantity.base_unit(:information)}
#=> {:duration, :energy, "By"}

Quantity.label(%{unit: "ms"})
#=> "ms"

Quantity.bounds(:ratio, "%")
#=> {0.0, 100.0}
```

Two edges come up often. `:telemetry` measurements name their time units as atoms, which
`Unit.from_telemetry/1` turns into codes (`:native` has no fixed unit, so convert it
first). Money is a currency code, which never converts, since an exchange rate is data:

```elixir
{Unit.from_telemetry(:millisecond), Unit.from_telemetry({:native, :microsecond}), Unit.from_telemetry(:native)}
#=> {{:ok, "ms"}, {:ok, "us"}, {:error, :native}}

{Unit.currency("{iso4217:EUR}"), Quantity.of_unit("{iso4217:EUR}")}
#=> {"EUR", :currency}
```

`Quantity.additivity/2` says whether values of a quantity may be summed across series or
over time, and `Quantity.family/2` lists the display family a unit belongs to (bytes,
kibibytes, …), which components use to pick a readable unit.

## The schema cache

Deliveries name a schema version, not a schema, so whoever reads many deliveries keeps
schemas by version. `Macaw.Data.Schema.Cache` is that cache as a value: `resolve/4` answers
from the cache, or calls a describe function once and caches the answer:

```elixir
alias Macaw.Data.Schema.Cache

describe = fn "cpu_feed" -> {:ok, schema} end
version = Schema.version(schema)

{:ok, ^schema, cache} = Cache.resolve(Cache.new(), "cpu_feed", version, describe)
{:ok, ^schema} = Cache.fetch(cache, "cpu_feed", version)

{:error, reason, _cache} = Cache.resolve(cache, "cpu_feed", "another-version", nil)
reason
#=> {:unknown_schema, "cpu_feed", "another-version"}
```

`Cache.put/3` adds a schema under its own version. The push subscriptions of chapter 2
hold one of these.

## Tables

`Macaw.Data.Table` is columnar typed data: named columns of declared types, all one
length. A table is a list of immutable **chunks** of up to `Table.chunk_rows/0` (8,192)
rows, each column packed per chunk. Number and time columns are packed into
reference-counted binaries off the process heap, so a big table costs its process little
and garbage collection doesn't copy it. `new/1` builds one from `{name, type, values}`
columns:

```elixir
alias Macaw.Data.Table

{:ok, table} =
  Table.new([
    {"t", :time, [~U[2026-10-29 12:00:00Z], ~U[2026-10-29 12:01:00Z], nil]},
    {"ms", :number, [12, nil, 30]},
    {"host", :category, ["a", :b, "a"]}
  ])

{Table.names(table), Table.size(table), Table.column(table, "ms"), Table.column_type(table, "t")}
#=> {["t", "ms", "host"], 3, [12, nil, 30], :time}

Table.row(table, 1)
#=> %{"host" => "b", "ms" => nil, "t" => ~U[2026-10-29 12:01:00Z]}
```

**A gap is `nil`, never zero,** in every type: absence is information. **Packing never
changes a value,** with one exception: a category's atom reads back as the string that
spells it (`:b` above reads `"b"`), so compare category values as strings, or with
`Macaw.Data.Operations.same?/2`. A time keeps its zone and precision, and a number its
integer or float. `rows/1` is every row as a map, `row/2` one row (`nil` past
the end), and `slice/3` a run of rows that keeps the parent's chunks, copying nothing:

```elixir
table |> Table.slice(1, 2) |> Table.rows() |> length()
#=> 2

Table.types()
#=> [:number, :time, :category, :text, :color, :point, :term]
```

**A table is opaque, and equal by its contents.** `Table.t()` is an opaque type: read a
table through its functions (`names/1`, `size/1`, `column/2`, `row/2`, `rows/1`,
`chunks/1`), never its struct's fields. The same rows chunked two ways are one value but
two terms, so compare tables with `Table.equal?/2`, never `==`. `digest/1` is the content
digest, and `compact/1` rewrites a table into canonical chunks:

```elixir
{:ok, first} = Table.new([{"ms", :number, [1, 2]}])
{:ok, second} = Table.new([{"ms", :number, [3, 4]}])
{:ok, joined} = Table.append(first, second)
{:ok, whole} = Table.new([{"ms", :number, [1, 2, 3, 4]}])

{Table.equal?(joined, whole), joined == whole, length(Table.chunks(joined)), Table.digest(joined) == Table.digest(whole)}
#=> {true, false, 2, true}
```

`new/1` reports every fault at once:

```elixir
Table.new([{"a", :number, [1, "x"]}, {"a", :text, ["q", "r"]}])
#=> {:error, [{["a"], :duplicate}, {["a", 1], {:type, :number}}]}
```

A table holds data only. A function, a PID, a reference or a port has no digest, so even a
`:term` column refuses one, as `{[name, i], :not_data}`:

```elixir
Table.new([{"owner", :term, [self()]}])
#=> {:error, [{["owner", 0], :not_data}]}
```

`from/2` reads the shapes data arrives in (a list of row maps, a map or keyword list of
columns, an `Nx` tensor or anything implementing `Table.Reader`, the last two with their
optional packages) and normalizes at the edge: a time column's ISO strings and dates
become `DateTime`s. Numbers stay as given, an integer an integer beside a float:

```elixir
{:ok, edge} =
  Table.from(
    [%{"t" => "2026-10-29T12:00:00Z", "v" => 1}, %{"t" => ~D[2026-10-29], "v" => 2.5}],
    types: %{"t" => :time}
  )

Table.rows(edge)
#=> [%{"t" => ~U[2026-10-29 12:00:00Z], "v" => 1},
#    %{"t" => ~U[2026-10-29 00:00:00Z], "v" => 2.5}]

Table.column_types([%{"a" => 1, "b" => "x", "c" => ~U[2026-10-29 12:00:00Z], "d" => :ok, "e" => ~RGB"#3b6fa8"}])
#=> %{"a" => :number, "b" => :text, "c" => :time, "d" => :category, "e" => :color}
```

`column_types/1` only suggests types; a table's declared types are what `column_type/2`
says. `Table.get/2` reads a row's field by either spelling of its name, which helps when
rows have atom keys and documents use strings:

```elixir
Table.get(%{ms: 3}, "ms")
#=> 3
```

## Deliveries

A `Macaw.Data.Delivery` is one answer of a source: its rows **as the source gave them**,
plus a handful of facts. Nothing is copied or packed when a delivery is made, which
matters on a busy page; a reader that wants columns packs them on demand. `new/2` takes
the rows and these options:

| Option | Meaning |
|---|---|
| `schema:` | the version of the schema the rows were made under |
| `served:` | what this answer actually served (below) |
| `names:` | column names for tuple rows or a tensor, in order |
| `types:` | column types for packing; inferred when absent |
| `origin:` | `%{source:, request:, as_of:}`: where it came from |

The `served` facts are what a reader needs to draw honestly:

| Fact | Meaning | Default |
|---|---|---|
| `window` | the window actually served, `[from, to]` or a box | `nil` |
| `resolution` | the spacing of the rows (seconds, or a name like `:minute`) | `nil` |
| `capped` | the source stopped short of the window asked | `false` |
| `reduced_by` | who brought the rows within budget: `:source`, `:runtime` or `nil` | `nil` |
| `ordered` | who put the rows in the request's order: `:source`, `:runtime` or `:sample` (chapter 2) | `nil` |
| `params` | the parameters it answered for | `%{}` |
| `note` | a line for a person (`"coarsened from raw"`) | `nil` |
| `position` | for a push snapshot, the number of the last increment it reflects (chapter 2) | `nil` |
| `complete_until` | the source's watermark: a window value below which it expects no further change | `nil` |

A source sets `reduced_by: :source` when it honored a budget itself; `:runtime` is
Macaw's own mark. A delivery of tuple rows needs `names:` so it can be read by name:

```elixir
alias Macaw.Data.Delivery

delivery =
  Delivery.new([{"web-1", 42}, {"web-2", nil}],
    names: ["host", "ms"],
    served: [capped: true, note: "first two only", resolution: :minute]
  )

Delivery.rows(delivery)
#=> [{"web-1", 42}, {"web-2", nil}]

Delivery.named_rows(delivery)
#=> [%{"host" => "web-1", "ms" => 42}, %{"host" => "web-2", "ms" => nil}]

{delivery.served.capped, delivery.served.note, Delivery.empty?(delivery)}
#=> {true, "first two only", false}
```

- `rows/1` reads the rows as given, a list uncopied;
- `named_rows/1` reads them as maps, by `names` for tuples (tuple rows without names
  raise: they can't be read by name);
- `table/2` packs them into a `Macaw.Data.Table`, `{:ok, table}` or `{:error, faults}`,
  and `table!/2` raises;
- `empty?/1` says whether there are no rows.

Packing is where values are checked against their types, so a value of the wrong type is
`table/2`'s fault, not `new/2`'s:

```elixir
Delivery.table(Delivery.new([%{"a" => 1}, %{"a" => "x"}], types: %{"a" => :number}))
#=> {:error, [{["a", 1], {:type, :number}}]}
```

The built-in table component packs each delivery this way, and draws "No data" for
rows that don't pack.

## Pitfalls

- **A counter or sequence number is not `:time`.** Time fields hold instants; a tick
  count is a `:number`.
- **Units are codes, not symbols.** `"ms"`, `"By"`, `"Cel"`: read what a person typed
  with `Unit.parse_alias/1` first.
- **Undeclared identity.** Without `identity: true`, nothing can select a row, group a
  series or find "latest per host". Declare it whenever rows are about things.
- **Two time fields.** A schema with two `:time` fields needs `window: true` on one,
  or requests to it can carry no window.
- **Filling gaps with zero.** A missing reading is `nil`. A zero draws a false dip.
- **Tuple rows without `names:`.** Reading them by name raises; give the names.
- **A color written as text.** `"#c23238"` is a string, and a string is never a color:
  write `~RGB"#c23238"` in code, and read text with `Macaw.Layers.Color.parse!/1` where
  it comes in.
- **Matching a packed category on an atom.** A table reads `:ok` back as `"ok"`;
  compare with the string.
- **Comparing tables with `==`.** Two tables of the same rows may be chunked
  differently; `Table.equal?/2` compares what they hold.

## Recap

- A schema says what fields mean: types, units, identity, the window field and declared
  values, checked when it's built, with every fault at once. Its names are strings, its
  data colors color terms, and its version a digest of the term; JSON is its adapter.
- Units are UCUM codes; quantities say what they measure.
- A table is columnar typed data in chunks, with gaps kept as `nil`, reading back what
  it was given (a category's atom as its string). It is opaque: read it through its
  functions and compare with `Table.equal?/2`.
- A delivery carries rows as given, plus the `served` facts and `origin`.

**Further reading:** [the schema](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-schema), [the table](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-table) and [deliveries](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-delivery) in `macaw_data`'s spec/01, and [units](https://github.com/dcoai/macaw_data/blob/main/spec/03-units.md#units-codes) in its spec/03.

Next: [chapter 4, Surfaces in depth](04-surfaces.md).
