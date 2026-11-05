# 11. Operations and derived sources

Sources answer raw rows; pages often need them shaped: filtered, grouped, binned, reduced,
or combined from several sources. `macaw_data` holds the operations for that, the same
code a chart and a derived source run, and **derived sources**: sources computed from
other sources, which a surface reads like any other.

**What you'll learn:**

- table operations and statistics (`Macaw.Data.Operations`): running pipelines,
  validation and faults;
- derived sources (`Macaw.Data.Derived`), with a host function (`defsource`) or a stored
  function checked by the sandbox;
- the engine (`Macaw.Data.Derived.Engine`) that runs them, and binding a derived source
  on a surface;
- the bounded runner and the sandbox's faults.

## Table operations

`Macaw.Data.Operations` runs a pipeline of **nodes** over a table: each node a map naming
its `op` and options, each step's output the next one's input. The registry of
operations is explicit and closed; `macaw_data`'s own package is always in it.
`registry/1` answers `{:ok, registry}` or every fault in the packages it's given, and
`registry!/1` the registry alone:

```elixir
alias Macaw.Data.{Operations, Table}

Operations.registry([Enum])
#=> {:error, [{[Enum], :not_a_package}]}

registry = Operations.registry!([])

{Operations.transforms(registry), Operations.aggregates(registry)}
#=> {["aggregate", "bin", "filter", "fold", "lttb", "m4", "sort", "spectrum", "stack", "sum", "take", "window"],
#    ["count", "delta", "deviation", "distinct", "extent", "max", "mean", "median", "min", "quantile", "slope", "sum", "variance"]}
```

The mean latency per host, slowest first, skipping missing readings:

```elixir
rows = [
  %{"host" => "a", "ms" => 40},
  %{"host" => "b", "ms" => 90},
  %{"host" => "a", "ms" => 60},
  %{"host" => "b", "ms" => nil}
]

{:ok, table} =
  Operations.apply(
    registry,
    [
      %{op: "filter", field: "ms", test: :present},
      %{op: "aggregate", field: "ms", fn: "mean", by: "host", as: "avg"},
      %{op: "sort", field: "avg", order: :descending}
    ],
    rows
  )

Table.rows!(table)
#=> [%{"avg" => 90.0, "host" => "b"}, %{"avg" => 50.0, "host" => "a"}]
```

`apply/4` takes rows in any shape `Table.from/2` reads, and answers a table. Its fourth
argument is a context: `now:` for relative `window`s, `schema:` for `window`'s `latest`.

| Op | Does | Main options |
|---|---|---|
| `filter` | keeps rows passing a test | `field`, `test` (`:eq`, `:ne`, `:lt`, `:lte`, `:gt`, `:gte`, `:present`, `:absent`), `value` |
| `take` | the last (or first) `n` rows | `n`, `side` |
| `window` | rows in a relative time window | `field`, `from`, `to` (`[n, :hour]`), `latest` |
| `sort` | a stable sort, `nil` last in either direction | `field`, `order` |
| `aggregate`, `sum` | one row per group | `field`, `fn`, `by`, `as` |
| `bin` | a histogram | `field`, `thresholds`, `fn`, `as` |
| `fold` | wide columns to long rows | `fields`, `as` |
| `stack` | stacked series, d3's offsets and orders | `fields`, `order`, `offset` |
| `lttb`, `m4` | downsampling that keeps a line's shape or its extremes | `fields`, `n` / `width` |

`sort` orders a column by its type: a time by its instant, a number by value, text and
categories by spelling. A missing reading sorts last whichever way you sort:

```elixir
{:ok, sorted} = Operations.apply(registry, [%{op: "sort", field: "ms", order: :descending}], rows)
Table.column(sorted, "ms")
#=> [90, 60, 40, nil]
```

The two reducers keep a line's look at a fraction of its rows, the same whatever the
table's chunking:

- **`lttb`** keeps at most `n` rows, the first and last among them, by MinMaxLTTB: each
  chunk's buckets contribute their least and greatest points, and
  Largest-Triangle-Three-Buckets picks `n` of those. Its error stays within a stated
  tolerance of the exact algorithm, which `Macaw.Data.Reduce.lttb/3` still runs.
- **`m4`** keeps each pixel column's first, last, least and greatest rows, at most four
  a column, over columns whose edges move to a bucket edge at most a quarter of a pixel
  away.
- A time `x` reduces on a `:time` scale, in microseconds; give the context `scale:
  :linear` for seconds.

```elixir
line = for i <- 0..999, do: %{"x" => i, "y" => :math.sin(i / 20)}

{:ok, kept} = Operations.apply(registry, [%{op: "lttb", fields: ["x", "y"], n: 20}], line)
{:ok, columns} = Operations.apply(registry, [%{op: "m4", fields: ["x", "y"], width: 10}], line)

{Table.size(kept), List.first(Table.column(kept, "x")), List.last(Table.column(kept, "x")), Table.size(columns) <= 40}
#=> {20, 0, 999, true}
```
| `spectrum` | an FFT amplitude spectrum | `field`, `time`, `every`, `samples`, `window` |

**Every node is checked before any runs,** and every fault answered at once, at
`[index, option]`; `format_error/1` words one:

```elixir
Operations.apply(
  registry,
  [%{op: "sort", field: "ms", order: :sideways}, %{op: "teleport"}, %{field: "x"}, %{op: "take", n: 1, extra: 1}],
  rows
)
#=> {:error,
#    [
#      {[0, "order"], {:type, {:enum, [:ascending, :descending]}}},
#      {[1, "op"], {:unknown, :transform, "teleport"}},
#      {[2, "op"], :required},
#      {[3, "extra"], {:invalid_for, "take"}}
#    ]}

Operations.format_error({[0, "order"], {:type, {:enum, [:ascending, :descending]}}})
#=> "step 1, order: is one of ascending or descending"
```

`apply!/4` raises with the worded faults; `validate/3` checks without running;
`outputs/4` says which columns a pipeline produces, without data:

```elixir
Operations.outputs(registry, [%{op: "aggregate", field: "ms", fn: "mean", by: "host"}], [{"host", :category}, {"ms", :number}])
#=> {:ok, [{"host", :category}, {"mean", :number}]}
```

### Statistics

The thirteen statistics are aggregates, usable in `aggregate` and `bin` nodes or alone
with `Operations.aggregate/4`. `nil` readings are dropped first: a gap is absence, never
zero.

```elixir
{Operations.aggregate(registry, "quantile", [1, 2, 3, 4, nil], %{p: 0.5}), Operations.aggregate(registry, "median", [1, 2, 3, 10], %{})}
#=> {{:ok, 2.5}, {:ok, 2.5}}
```

**`sum` and `mean` are exact.** Integers sum to an integer. With a float among the
readings, the exact sum is rounded once, so any order of the readings gives the same
bits, where a sequential float sum can lose a reading:

```elixir
{Operations.aggregate(registry, "sum", [1, 2, nil], %{}), Operations.aggregate(registry, "sum", [1.0e16, 1.0, -1.0e16], %{}), Enum.sum([1.0e16, 1.0, -1.0e16])}
#=> {{:ok, 3}, {:ok, 1.0}, 0.0}
```

A sum beyond a float's range is the fault `:overflow`, never an `ArithmeticError`: alone
under `"values"`, in a node at the node's index:

```elixir
{Operations.aggregate(registry, "sum", [1.0e308, 1.0e308], %{}), Operations.apply(registry, [%{op: "aggregate", field: "ms", fn: "sum"}], [%{"ms" => 1.0e308}, %{"ms" => 1.0e308}])}
#=> {{:error, [{["values"], :overflow}]}, {:error, [{[0, "field"], :overflow}]}}
```

So an aggregate of your own may answer `{:error, :overflow}` from `reduce/2` and
`finish/2`, as `sum` and `mean` do.

### Your own operations

An operation is a module implementing `Macaw.Data.Transform` (or `Macaw.Data.Aggregate`
for a statistic). It declares its options once, with `Macaw.Data.Operations.Option`, and
that one declaration drives validation, defaults and the faults above. It's pure: the
same node and table give the same table. Here's one that adds a ratio column:

```elixir
defmodule MyApp.Ops.Ratio do
  @moduledoc "Adds a column: one field divided by another."
  @behaviour Macaw.Data.Transform

  alias Macaw.Data.Table
  alias Macaw.Data.Operations.Option

  @impl true
  def name, do: "ratio"

  @impl true
  def options do
    [
      {"of", %Option{type: :field, required: true, doc: "the numerator"}},
      {"per", %Option{type: :field, required: true, doc: "the denominator"}},
      {"as", %Option{type: :name, default: "ratio", doc: "the new column"}}
    ]
  end

  @impl true
  def needs, do: []

  @impl true
  def outputs(%{"as" => as}, columns), do: columns ++ [{to_string(as), :number}]

  @impl true
  def run(%{"of" => of, "per" => per, "as" => as}, table, _context) do
    ratios = Enum.zip_with(Table.column(table, of), Table.column(table, per), &ratio/2)
    kept = for name <- Table.names(table), do: {name, Table.column_type(table, name), Table.column(table, name)}
    Table.new!(kept ++ [{to_string(as), :number, ratios}])
  end

  defp ratio(a, b) when is_number(a) and is_number(b) and b != 0, do: a / b
  defp ratio(_a, _b), do: nil
end

defmodule MyApp.Ops do
  @moduledoc "MyApp's operations package."
  def __members__, do: [MyApp.Ops.Ratio]
end
```

`run/3` gets the node checked, with string keys and defaults filled in, and answers a
table, or `{:error, {key, reason}}` for input it refuses at run time, which `apply/4`
answers as a fault at the node's index. It reads its input by column (`Table.column/2`),
never row by row, and builds its answer with `Table.new!/1`. `outputs/2` names the
columns it answers, so a pipeline's columns are known without data. An operation
that should run a chunk at a time, and let a caller cache its work per chunk, declares
itself a column-native step instead (`class/1`, `chunk/3` and the rest of
`Macaw.Data.Transform`'s optional callbacks), as every built-in operation does. Enable the
package explicitly:

```elixir
with_ratio = Operations.registry!([MyApp.Ops])

{:ok, ratios} = Operations.apply(with_ratio, [%{op: "ratio", of: "errors", per: "requests"}], [%{"errors" => 3, "requests" => 300}, %{"errors" => 1, "requests" => 0}])
Table.column(ratios, "ratio")
#=> [0.01, nil]

Operations.apply(registry, [%{op: "ratio", of: "errors", per: "requests"}], [])
#=> {:error, [{[0, "op"], {:unknown, :transform, "ratio"}}]}
```

Two members with one name are a fault when the registry is built,
`{[kind, name], {:named_twice, module, other}}`, naming both.

## Derived sources

A **derived source** is computed from other sources by a function: rows in, rows out.
It's data: an id, its inputs, its output schema and its function, so a document can hold
one. The function is either a **host function** (your own trusted Elixir, `defsource`)
or **stored source text**, untrusted, which the sandbox checks before compiling it.

### Host functions

```elixir
defmodule MyApp.Derivations do
  @moduledoc "Derived-source functions this app trusts."
  use Macaw.Data.Derived.Functions

  defsource slowest(inputs) do
    inputs["latency"]
    |> Enum.group_by(& &1["host"])
    |> Enum.map(fn {host, rows} ->
      %{"host" => host, "worst" => rows |> Enum.map(& &1["ms"]) |> Enum.max()}
    end)
  end
end
```

A host function gets its inputs keyed by name, each a list of rows (as the source gave
them, or a table input's rows), and answers a list of rows. `defsource name(inputs,
context)` takes a context too: each input's schema and served facts. Register the
modules explicitly. `Functions.registry/1` answers `{:ok, functions}` or every fault, and
`registry!/1` the map alone:

```elixir
alias Macaw.Data.Derived
alias Macaw.Data.Derived.{Engine, Functions, Sandbox}

Functions.registry([Enum])
#=> {:error, [{[Enum], :not_a_function_module}]}

functions = Functions.registry!([MyApp.Derivations])
#=> %{"slowest" => {MyApp.Derivations, 1}}

{:ok, worst} =
  Derived.new(
    id: "worst",
    from: [{"latency", nil}],
    schema: %{"host" => %{type: :category, identity: true}, "worst" => %{type: :number, unit: "ms"}},
    function: "slowest"
  )
```

`Derived.conform/2` holds an answer to the source's schema, which makes a host function
easy to test: it answers the rows keyed by strings, or the first row that doesn't fit,
by index, field and reason, never the value:

```elixir
{Derived.conform(worst, [%{host: "web-1", worst: 48}]), Derived.conform(worst, [%{"host" => "web-1", "worst" => "slow"}])}
#=> {{:ok, [%{"host" => "web-1", "worst" => 48}]}, {:error, {0, "worst", {:type, :number}}}}
```

An input is `{name, window}`. The window says how much history the function needs:
`nil` for all of it, `%{last: n}` for each identity's newest `n` rows, or a request map
(`%{window: [from, to]}`, `%{latest: true}`).

`Derived.new/1` takes the value only: a keyword list or a map of terms. A stored derived
source's forms are the adapter, written and read by `Macaw.Layers.Form`, the JSON adapter
surfaces use (chapter 8). `to_map/1` and `to_json/1` answer `{:ok, form}`, stamped
version 2, or faults for a value with no form; `from_map/2` and `from_json/2` read
through the gates and then judge the value with `new/1`. A map form goes to
`from_map/2`, never to `new/1`:

```elixir
{:ok, worst_json} = Derived.to_json(worst)
Derived.from_json(worst_json) == {:ok, worst}
#=> true

{:ok, form} = Derived.to_map(worst)
{Derived.from_map(form) == {:ok, worst}, match?({:error, _}, Derived.new(form))}
#=> {true, true}
```

### Stored functions

A stored function is source text, one `fn`. Before it's compiled, the **sandbox**
checks it against an allowlist: pure functions of `Enum`, `Map`, `String` and friends,
no processes, no I/O, no atoms made, no structs. With `per: :identity`, it's called once
per entity of its input:

```elixir
{:ok, average} =
  Derived.new(
    id: "average",
    from: [{"latency", %{last: 5}}],
    schema: %{"host" => %{type: :category, identity: true}, "mean" => %{type: :number}},
    per: :identity,
    elixir: "fn rows -> %{\"mean\" => Enum.sum(Enum.map(rows, & &1.ms)) / Enum.count(rows)} end"
  )
```

Inside a stored function a row's fields read as `row.field`. What the checker refuses,
`Derived.new/1` reports at `[:elixir]`, with the line:

```elixir
Derived.new(id: "peek", from: [{"latency", nil}], schema: %{"v" => %{type: :number}}, elixir: ~S|fn _rows -> File.read!("/etc/passwd") end|)
#=> {:error, [{[:elixir], {:check, 1, {:restricted, {"File", "read!", 1}}}}]}

{:error, faults} = Sandbox.check("fn rows -> send(self(), rows) end")
Enum.map(faults, &Sandbox.format_error/1)
#=> ["line 1: send/2 is not allowed in a derived source"]
```

A stored function reaches the operations through one module, `Macaw.Data.Ops`, by
literal name: `Macaw.Data.Ops.aggregate(values, "median")` or
`Macaw.Data.Ops.transform(rows, "sort", %{field: :ms})`. The checker holds each name to the
registry before the function runs. Each answers `{:ok, value}` or `{:error, faults}`, and
`Macaw.Data.Ops.aggregate!/2` and `transform!/3` the bare value; the sandbox allows all of
them. The same calls work in your own code:

```elixir
{Macaw.Data.Ops.aggregate([3, nil, 1, 2], "median"), Macaw.Data.Ops.aggregate([3, nil, 1, 2], "mode")}
#=> {{:ok, 2}, {:error, [{[], {:unknown, :aggregate, "mode"}}]}}
```

Even `length/1` and `inspect/1` are refused: the allowlist is small on purpose. Every
function, stored or host, runs bounded by reductions, heap and a liveness timeout, in a
process of its own; a runaway ends as a fault, never a crash. A stored function reaches
the operations above through `Macaw.Data.Ops`.

## The engine

`Macaw.Data.Derived.Engine` runs a set of derived sources: it resolves their inputs,
refuses cycles, and recomputes in **pulses**. It's a value you hold, as a `Push` is:
show it deliveries with `push/4`, run what's due with `run/2`:

```elixir
{:ok, engine} =
  Engine.new(%{["worst"] => worst, ["average"] => average},
    sources: ["latency"],
    functions: functions,
    debounce: 0
  )

latency = %MyApp.Latency{minutes: 10}
{:ok, description} = Macaw.Data.Source.describe(latency, nil)
request = Macaw.Data.Source.Request.new!(now: ~U[2026-10-29 12:00:30Z])
{:ok, delivery} = Macaw.Data.Source.fetch(latency, description, request)

engine = Engine.push(engine, %{"latency" => delivery}, %{"latency" => description.schema}, 0)
engine = Engine.run(engine, 0)

Engine.status(engine)
#=> %{["average"] => :live, ["worst"] => :live}

engine |> Engine.outputs() |> Map.new(fn {path, d} -> {path, Macaw.Data.Delivery.rows!(d)} end)
#=> %{
#      ["average"] => [%{"host" => "web-1", "mean" => 34.0}, %{"host" => "web-2", "mean" => 35.0}],
#      ["worst"] => [%{"host" => "web-1", "worst" => 48}, %{"host" => "web-2", "worst" => 47}]
#    }
```

- An output is a `Macaw.Data.Table`, packed once under the output schema, so
  `Delivery.rows!/1` reads it as any table's rows: every field present, keys as strings,
  `nil` where the function left a field out, and a category's atom as its string.
- `push/4` takes the latest deliveries and schemas by source name and the owner's
  monotonic milliseconds; a changed input marks the sources that read it, and the next
  pulse is due `debounce:` milliseconds later (`due/1`).
- `run/2` runs a due pulse: marked sources in dependency order, each at most once, so a
  source with two changed inputs runs once.
- A source that fails keeps its last good output and reports why: `status/1` says
  `{:down, {:derived, id, kind}}` and `faults/1` the detail, which never contains row
  values.
- `runs/1`, `schemas/1`, `sources_read/1` and `resolve/3` describe the engine.

### On a surface

`Engine.source(engine, path)` answers `{:ok, output}`, a `Macaw.Data.Derived.Output`, a
source over the engine's last good output, or `{:error, [{[:path], :unknown_path}]}` for
a path the engine doesn't define. Put it in your sources map, and cells read it like any
other:

```elixir
Engine.source(engine, ["best"])
#=> {:error, [{[:path], :unknown_path}]}

sources = %{"worst" => {Engine.source!(engine, ["worst"]), nil}}
registry = Macaw.Registry.new!([Macaw.Builtin])

{:ok, surface} =
  Macaw.Surface.new(
    name: "worst",
    cells: %{
      "hosts" => %{
        component: "macaw.table",
        settings: %{"caption" => "Worst latency", "sort" => "worst", "order" => "desc"},
        place: %{x: 0, y: 0, w: 6, h: 2},
        slots: %{"rows" => %{source: "worst"}}
      }
    }
  )

{:ok, validated} = Macaw.Surface.validate(surface, registry, sources)

validated
|> Macaw.Surface.render(sources: sources, now: ~U[2026-10-29 12:00:30Z], ceiling: 100)
|> Phoenix.HTML.safe_to_string()
|> IO.puts()
```

```html
<tbody><tr><td>web-1</td><td>48</td></tr><tr><td>web-2</td><td>47</td></tr></tbody>
```

Before the engine's first good output, the source answers `{:error, :loading}`, which a
surface draws as "Source unavailable". Re-render after each pulse to show new results.

## Pitfalls

- **Percentiles of percentiles.** A statistic of reduced or rolled-up rows isn't the
  statistic of the raw readings; compute a p95 from raw rows, in the source.
- **Reading the clock in a derived function.** There's no clock in its context by
  design; a window that moves with time belongs to its input.
- **A stored function using `length/1`.** Use `Enum.count/1`; the allowlist is narrow.
- **Forgetting `debounce: 0` in tests.** The default debounce waits 250 ms for more
  changes before a pulse is due.
- **A derived source with no identity under `per: :identity`.** Its input's schema must
  declare identity, and its output must declare the same.

## Recap

- `Operations.apply/4` runs checked pipelines of table operations; every fault at once.
- Thirteen statistics drop gaps and work alone or in nodes.
- A derived source is data: inputs, a schema, and a host function or a sandboxed stored
  function.
- The engine runs derived sources in pulses, and its outputs are tables;
  `Engine.source/2` makes one a source a surface can bind.

**Further reading:** [running operations](https://github.com/dcoai/macaw_data/blob/main/spec/04-operations.md#operations-run), [the table operations](https://github.com/dcoai/macaw_data/blob/main/spec/04-operations.md#operations-table) and [statistics](https://github.com/dcoai/macaw_data/blob/main/spec/04-operations.md#operations-statistics) in `macaw_data`'s spec/04; [derived sources](https://github.com/dcoai/macaw_data/blob/main/spec/02-derived.md#derived-model), [host functions](https://github.com/dcoai/macaw_data/blob/main/spec/02-derived.md#derived-functions), [the sandbox](https://github.com/dcoai/macaw_data/blob/main/spec/02-derived.md#derived-sandbox), [the engine](https://github.com/dcoai/macaw_data/blob/main/spec/02-derived.md#derived-engine) and [a derived source as a source](https://github.com/dcoai/macaw_data/blob/main/spec/02-derived.md#derived-as-source) in its spec/02.

That's the end of the tutorial. [Back to the overview](../tutorial.md), or on to the
specification and the API reference it links.
