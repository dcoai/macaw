# 2. Sources

Every piece of data on a Macaw surface comes through a **source**. This chapter covers the
source contract in full: describing a source, its parameters, the request it answers,
how Macaw finishes what a source doesn't do itself, and sources that push.

**What you'll learn:**

- the `Macaw.Data.Source` behavior and its dispatch functions;
- descriptions (`Macaw.Data.Source.Description`) and capabilities;
- parameters (`Macaw.Data.Parameter`): declaring, validating and binding them;
- requests (`Macaw.Data.Source.Request`): window, order, budget, viewer and `now`;
- finishing (`Macaw.Data.Source.Finish`): the window, `latest`, the order, budgets, the
  ceiling and pooling;
- push subscriptions (`Macaw.Data.Source.Push`).

Schemas, tables and deliveries, the data a source answers with, are
[chapter 3](03-schemas-and-data.md).

## A time-series source

Chapter 1's source ignored its request. Real sources rarely can. Here is one that serves
per-host latency, one reading a minute, takes a parameter and honors a time window. It
computes its readings from the request's `now`, so its answers are reproducible:

```elixir
defmodule MyApp.Latency do
  @moduledoc "Per-host request latency, one reading a minute, computed from `now`."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct hosts: ["web-1", "web-2"], minutes: 60

  @schema Schema.new!(%{
            "t" => %{type: :time},
            "host" => %{type: :category, identity: true},
            "ms" => %{type: :number, unit: "ms", quantity: :duration, polarity: :lower_is_better}
          })

  @impl true
  def describe(%__MODULE__{hosts: hosts}, _context) do
    Description.new(
      schema: @schema,
      params: %{
        "host" => %{type: :category, values: ["all" | hosts], default: "all", doc: "one host, or all"}
      },
      supports: [:window]
    )
  end

  @impl true
  def fetch(%__MODULE__{} = source, request) do
    # A window of something other than times is the caller's mistake: answer it as a value.
    case Macaw.Data.Window.check(request, @schema) do
      :ok -> {:ok, delivery(source, request)}
      {:error, faults} -> {:error, {:request, faults}}
    end
  end

  defp delivery(source, request) do
    hosts = if request.params["host"] == "all", do: source.hosts, else: [request.params["host"]]
    last = %{request.now | second: 0, microsecond: {0, 0}}

    rows =
      for {host, h} <- Enum.with_index(source.hosts),
          host in hosts,
          i <- (source.minutes - 1)..0//-1,
          t = DateTime.add(last, -i * 60),
          within?(t, request.window),
          do: %{"t" => t, "host" => host, "ms" => 20 + rem(i * 7 + h * 13, 30)}

    Delivery.new(rows,
      schema: Schema.version(@schema),
      served: [window: request.window, params: request.params]
    )
  end

  defp within?(_t, nil), do: true

  defp within?(t, [from, to]),
    do:
      (from == nil or DateTime.compare(t, from) != :lt) and
        (to == nil or DateTime.compare(t, to) != :gt)
end
```

The source is a struct, and its fields are its configuration: which hosts, how much
history. That's the usual shape. A database-backed source would hold a repo or a table
name; the struct is what you put in the `sources` map you give a surface.

## The behavior

`Macaw.Data.Source` has two required callbacks and two optional ones:

| Callback | Answers |
|---|---|
| `describe(source, context)` | `{:ok, %Description{}}` or `{:error, reason}` |
| `fetch(source, request)` | `{:ok, %Delivery{}}` or `{:error, reason}` |
| `subscribe(source, pid)` *(optional)* | `{:ok, ref}`: pushes go to `pid` |
| `unsubscribe(source, ref)` *(optional)* | `:ok` |

You rarely call a source's module directly. The **dispatch functions** in
`Macaw.Data.Source` call it for you and add guarantees on top:

```elixir
alias Macaw.Data.Source
alias Macaw.Data.Source.Request

now = ~U[2026-10-29 12:00:30Z]
latency = %MyApp.Latency{}

{:ok, description} = Source.describe(latency, nil)
{:ok, request} = Request.new(now: now, params: %{"host" => "web-1"})
{:ok, delivery} = Source.fetch(latency, description, request)

length(Macaw.Data.Delivery.rows(delivery))
#=> 60
```

`Source.fetch/3` takes the description as well as the request, because it checks the
request's parameters against it **before** calling the source. A bad parameter never
reaches your code:

```elixir
Source.fetch(latency, description, %{request | params: %{"host" => "web-9"}})
#=> {:error, {:params, [{["host"], {:enum, ["all", "web-1", "web-2"]}}]}}

Source.fetch(latency, description, %{request | params: %{"region" => "eu"}})
#=> {:error, {:params, [{["region"], :unknown_param}]}}
```

And it fills in defaults, so your `fetch/2` always sees every parameter:
`request.params["host"]` is `"all"` when nobody asked for a host.

The dispatch functions also turn a source's malformed answer into a value. A `describe/2`
that answers anything but `{:ok, %Description{}}` or `{:error, _}` comes back as
`{:error, {:bad_describe, answer}}`, and a bad fetch as `{:error, {:bad_fetch, answer}}`,
so a broken source is a fault you can show, not a crash.

`Source.describer/1` turns a `sources` map into a function from a name to that source's
schema, the shape `Macaw.Data.Schema.Cache` and push subscriptions use:

```elixir
describe = Source.describer(%{"latency" => {latency, nil}})

{:ok, %Macaw.Data.Schema{}} = describe.("latency")
describe.("nope")
#=> {:error, :no_source}
```

## Descriptions

`Macaw.Data.Source.Description.new/1` builds a description from these fields:

| Field | Value | Default |
|---|---|---|
| `schema` | a `Macaw.Data.Schema`, required | |
| `params` | the parameters it takes, by name | `%{}` |
| `supports` | the capabilities it honors itself | `[]` |
| `viewer_independent` | `true` when every viewer gets the same answer | `false` |
| `lateness` | for a pushing source, the most a change may lag its watermark (a `Duration`, or a number over a number window field) | `nil`, any age |
| `idle_after` | milliseconds of silence before a derived source's watermark leaves this source out | `nil`, never idle |
| `chunk_span` | the span of the window field one chunk of the source's table holds | `nil`, from the resolution |

It reports every fault at once, by path, like every constructor in Macaw:

```elixir
alias Macaw.Data.Source.Description

Description.new(schema: description.schema, supports: [:window, :teleport])
#=> {:error, [{[:supports, 1], {:enum, [:window, :box, :region, :latest, :order, :budget, :push, :as_of]}}]}

Description.capabilities()
#=> [:window, :box, :region, :latest, :order, :budget, :push, :as_of]
```

`Description.new!/1` raises `ArgumentError` instead, which suits a description built
from constants.

**Capabilities are all optional.** `supports` lists what the source does itself, so Macaw
knows what's left to do. `MyApp.Latency` says `[:window]`: it trims rows to a requested
window. It doesn't say `:budget`, so when a reader wants fewer rows, Macaw reduces them
after the fetch (see "Finishing" below). A source that can do something cheaply (a
database that can `LIMIT` and downsample) should declare it; one that can't should leave
it out rather than half-do it.

**`viewer_independent: true`** promises that the answer doesn't depend on who asks. It
lets a runtime share one fetch across viewers. Leave it `false` unless it's really true:
the source conformance kit (chapter 7) checks the promise by asking as two viewers.

## Parameters

A parameter is a typed option. Sources and components share one shape,
`Macaw.Data.Parameter`:

```elixir
%{
  type: :category,             # required: :time, :number, :category, :text, :color, :point, :term or {:document, type}
  default: "all",              # absent: the parameter is required
  values: ["all", "web-1"],    # a closed list of legal values
  bindable: false,             # may it be bound to state? (components; closed by default)
  doc: "one host, or all"
}
```

`Parameter.keys/0` lists the keys a parameter takes; `check/1` checks a declaration;
`validate/2` checks given values against declarations, filling in defaults;
`conforms?/2` says whether a value is of a type:

```elixir
alias Macaw.Data.Parameter

Parameter.keys()
#=> [:type, :default, :values, :legal_for, :bindable, :doc]

Parameter.check(%{type: :number, default: "ten", bindable: 1})
#=> {:error, [{[:bindable], {:type, :boolean}}, {[:default], {:type, :number}}]}

Parameter.validate(description.params, %{})
#=> {:ok, %{"host" => "all"}}

Parameter.validate(description.params, %{"host" => "web-3", "zone" => "a"})
#=> {:error, [{["host"], {:enum, ["all", "web-1", "web-2"]}}, {["zone"], :unknown_param}]}

import Macaw.Layers.Color, only: [sigil_RGB: 2]

{Parameter.conforms?(:color, ~RGB"#ff8800"), Parameter.conforms?(:color, "#ff8800"),
 Parameter.conforms?(:point, {13.4, 52.5}), Parameter.conforms?(:number, "12")}
#=> {true, false, true, false}
```

**A value is the term it is.** A `:time` is a `DateTime`, a `:point` a
`{longitude, latitude}` tuple, and a `:color` a color term: a `%Macaw.Layers.Color{}`
literal, written `~RGB"#ff8800"` in code (or read from text with
`Macaw.Layers.Color.parse!/1` at your input's edge), or a theme color like
`{:color, "good"}` (chapter 9). **A string is never a color**, even one that looks like
it. JSON is only an adapter for these terms, at the edge (chapter 8).

A parameter with no `default` is **required**: `validate/2` reports it as `:required` when
it's missing. `legal_for: {slot, field, fact}`, which says the legal values follow from a
bound slot's schema, is for the page runtime and isn't resolved by `macaw` 0.3.0.

### Binding parameters on a surface

A cell gives a source's parameters in its slot binding, under `params:`. Validation checks
them against the source's description, so a bad value is caught before anything renders:

```elixir
registry = Macaw.Registry.new!([Macaw.Builtin])
sources = %{"latency" => {latency, nil}}

cell = fn params ->
  %{
    component: "macaw.table",
    place: %{x: 0, y: 0, w: 6, h: 4},
    slots: %{"rows" => %{source: "latency", params: params}}
  }
end

{:ok, surface} = Macaw.Surface.new(name: "latency", cells: %{"web_1" => cell.(%{"host" => "web-1"})})
{:ok, _validated} = Macaw.Surface.validate(surface, registry, sources)

{:ok, surface} = Macaw.Surface.new(name: "latency", cells: %{"web_9" => cell.(%{"host" => "web-9"})})
Macaw.Surface.validate(surface, registry, sources)
#=> {:error, [{[:cells, "web_9", :slots, "rows", :params, "host"], {:enum, ["all", "web-1", "web-2"]}}]}
```

The fault's path leads from the surface to the value: cell `web_9`, slot `rows`,
parameter `host`.

A cell keeps its params as the terms you give it. `Surface.new/1` checks only that they
are a map with names for keys; whether each value is of its parameter's type is
validation's question, answered against the source's description:

```elixir
{:ok, surface} = Macaw.Surface.new(name: "latency", cells: %{"web" => cell.(%{"host" => ~D[2026-10-29]})})
Macaw.Surface.validate(surface, registry, sources)
#=> {:error, [{[:cells, "web", :slots, "rows", :params, "host"], {:type, :category}}]}
```

## Requests

A `Macaw.Data.Source.Request` is what a reader asks. `Request.new/1` builds one, `now`
required, every fault at once:

| Field | Value | Default |
|---|---|---|
| `params` | the parameters by name | `%{}` |
| `window` | `[from, to]` over the window field; either bound `nil` for open | `nil` |
| `box` | `%{west, south, east, north}` over a `:point` window field, in degrees | `nil` |
| `region` | `%{field => [from, to]}`, ranges over named fields | `nil` |
| `latest` | `true` asks for each identity's latest row | `false` |
| `order` | `[{field, :asc \| :desc}, …]`, the order the reader looks at the rows in | `[]` |
| `budget` | the most rows the reader wants | `nil` |
| `as_of` | the instant the answer is as of, for a source supporting `:as_of` | `nil` |
| `viewer` | the host's viewer, opaque to Macaw; `nil` is anonymous | `nil` |
| `now` | the instant the request is made at | required |
| `subscription` | the push subscription a fetch is a snapshot for (see "Sources that push") | `nil` |

```elixir
Request.new(now: now, budget: 0, latest: :yes, zone: 1)
#=> {:error, [{[:budget], {:type, :pos_integer}}, {[:latest], {:type, :boolean}}, {[:zone], :unknown_key}]}

Request.box?(%{west: -10, south: 35, east: 30, north: 60})
#=> true
```

Three rules make sources predictable:

- **`now` comes from the request.** A source never reads the clock: the surface gives
  one instant to every source it fetches, so "the last hour" means the same hour
  everywhere on the page, and a test controls time by passing it.
- **The viewer is an argument.** `request.viewer` is whatever your host uses to identify
  the person (a user struct, an id); a source may filter or refuse by it. Macaw passes it
  through and never stores it. You give it to a surface with
  `Macaw.Surface.fetch(validated, viewer: user, …)` (chapter 4).
- **The budget never widens the window.** A budget asks for at most so many rows *of the
  window*; it is not a reason to fetch more history.

## Finishing: what Macaw does for a source

A source that doesn't declare a capability still gets requests that use it.
`Macaw.Data.Source.Finish.finish/4` does the rest after the fetch, in a fixed order
(window, box, region, latest, order, budget), only ever **removing** rows, and records what it
did in the delivery's `served` facts. A surface finishes every delivery this way; you
call it yourself only when you fetch outside a surface.

Ask `MyApp.Latency` for each host's latest reading. It doesn't support `:latest`, so
finishing picks the newest row per identity (`"host"`, declared in the schema):

```elixir
alias Macaw.Data.Source.Finish

latest = Request.new!(now: now, latest: true)
{:ok, all} = Source.fetch(latency, description, latest)
finished = Finish.finish(all, description, latest)

Macaw.Data.Delivery.rows(finished)
#=> [%{"host" => "web-1", "ms" => 20, "t" => ~U[2026-10-29 12:00:00Z]},
#    %{"host" => "web-2", "ms" => 33, "t" => ~U[2026-10-29 12:00:00Z]}]
```

Ask for at most 10 rows. The source doesn't support `:budget`, so finishing reduces each
host's series with LTTB (Largest-Triangle-Three-Buckets, run as MinMaxLTTB, chapter 11),
which keeps the shape of a line with far fewer points, and marks who did it:

```elixir
budgeted = Request.new!(now: now, params: %{"host" => "web-1"}, budget: 10)
{:ok, delivery} = Source.fetch(latency, description, budgeted)
finished = Finish.finish(delivery, description, budgeted)

{length(Macaw.Data.Delivery.rows(finished)), finished.served.reduced_by}
#=> {10, :runtime}
```

A reduced line is a sample, which suits a chart. A reader that looks at rows in an order
("slowest first") wants the **first** rows in it instead, so it says so in the request's
`order`. Finishing sorts by it before the budget, and keeps the head:

```elixir
slowest = Request.new!(now: now, params: %{"host" => "web-1"}, order: [{"ms", :desc}, {"t", :desc}], budget: 3)
{:ok, delivery} = Source.fetch(latency, description, slowest)
finished = Finish.finish(delivery, description, slowest)

{Enum.map(Macaw.Data.Delivery.rows(finished), & &1["ms"]), finished.served.ordered}
#=> {[49, 49, 48], :runtime}
```

- **Rows compare by their field's type:** a time by its instant, a number by value, text
  by string, a category by its declared order, a missing reading last in either
  direction, ties kept stable.
- **`served.ordered` says who ordered them.** `:source` for a source that declares the
  `:order` capability and serves its first `budget` rows in the order; `:runtime` when
  finishing sorted every row served; `:sample` when the source had already cut its rows
  (`capped`, or `reduced_by: :source`), so they need not be the first.
- **An order the schema can't answer is refused** before the source is called, as a bad
  parameter is: `Source.fetch/3` answers `{:error, {:order, [{[:order, 0],
  {:unknown_field, "cpu"}}]}}` for an order on a field the schema lacks.
- **A component asks for one** with its optional `order(slot, settings)` callback
  (chapter 6), read through `Macaw.Component.order/3`, `{:ok, []}` without it. A surface
  fetched by `macaw` 0.3.0 doesn't ask it yet: its requests carry no order.

`finish/4` takes `reduce: "m4"` to use the M4 reducer instead of LTTB. A request the
schema can't answer, such as a `box` on a source with no `:point` field, raises
`ArgumentError`: that's a bug in the caller, not a data problem.
`Macaw.Data.Window.check/2` tells you beforehand:

```elixir
Macaw.Data.Window.check(Request.new!(now: now, box: %{west: 0, south: 0, east: 1, north: 1}), description.schema)
#=> {:error, [{[:box], {:invalid_for, :time}}]}
```

### The ceiling and pooling

Two more rules from `Finish` decide how much a surface fetches. Both are applied for you
by `Macaw.Surface.fetch/2`; knowing them explains what you see.

- **The ceiling.** `ceiling/2` clamps a reader's budget to the host's ceiling, the
  `ceiling:` you give a surface, and says whether it clamped. A reader that wants every
  row (`nil`) reads at the ceiling:

  ```elixir
  {Finish.ceiling(5_000, host: 1_000), Finish.ceiling(50, host: 1_000), Finish.ceiling(nil, host: 1_000)}
  #=> {{1_000, true}, {50, false}, {1_000, false}}
  ```

- **Pooling.** Readers of one source with equal parameters share one fetch, made at the
  largest of their budgets (`nil` when any wants everything); each reader then gets its
  own reduction with `reduce/5`:

  ```elixir
  {Finish.pooled([10, 40, 20]), Finish.pooled([10, nil])}
  #=> {40, nil}

  {:ok, everything} = Source.fetch(latency, description, Request.new!(now: now))
  reduced = Finish.reduce(everything, description.schema, 20)
  {length(Macaw.Data.Delivery.rows(reduced)), reduced.served.reduced_by}
  #=> {20, :runtime}
  ```

## Sources that push

A source whose data arrives over time (a message queue, a metrics stream) can **push**
changes instead of being polled. It declares `:push`, implements `subscribe/2` and
`unsubscribe/2`, and sends the subscriber three kinds of message, built by
`Macaw.Data.Source.Push`:

- `Push.schema_message(ref, schema)`, first, and again whenever the schema changes;
- `Push.increment_message(ref, seq, delivery)`, a change numbered `seq`, from 1 for each
  subscription: the rows new since the last;
- `Push.snapshot_message(ref, delivery)`, optionally, the whole relation as of
  `served.position`, the number of the last increment it reflects.

Here's a small pushing source. Each subscriber's pid and the number of its next
increment live in an `Agent`, and `tick/2` stands for whatever brings new data in:

```elixir
defmodule MyApp.Ticker do
  @moduledoc "A source that pushes readings to its subscribers as they arrive."
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.{Description, Push}

  defstruct [:subscribers]

  @schema Schema.new!(%{"t" => %{type: :time}, "value" => %{type: :number}})

  @doc "A ticker with no subscribers yet."
  def new do
    {:ok, agent} = Agent.start_link(fn -> %{} end)
    %__MODULE__{subscribers: agent}
  end

  @doc "Sends `rows` to every subscriber as its next numbered increment."
  def tick(%__MODULE__{subscribers: agent}, rows) do
    delivery = Delivery.new(rows, schema: Schema.version(@schema))

    numbered =
      Agent.get_and_update(agent, fn subscribers ->
        {subscribers, Map.new(subscribers, fn {ref, {pid, seq}} -> {ref, {pid, seq + 1}} end)}
      end)

    for {ref, {pid, seq}} <- numbered, do: send(pid, Push.increment_message(ref, seq, delivery))
    :ok
  end

  @impl true
  def describe(%__MODULE__{}, _context), do: Description.new(schema: @schema, supports: [:push])

  @impl true
  def fetch(%__MODULE__{}, _request), do: {:ok, Delivery.new([], schema: Schema.version(@schema))}

  @impl true
  def subscribe(%__MODULE__{subscribers: agent}, pid) do
    ref = make_ref()
    Agent.update(agent, &Map.put(&1, ref, {pid, 1}))
    send(pid, Push.schema_message(ref, @schema))
    {:ok, ref}
  end

  @impl true
  def unsubscribe(%__MODULE__{subscribers: agent}, ref),
    do: Agent.update(agent, &Map.delete(&1, ref))
end
```

The subscriber holds a `Push`, a plain value it keeps in its state (a GenServer's, a
LiveView's). `receive/2` takes each message: a schema is cached, an increment or a
snapshot buffered. `drain/2` applies everything buffered at once, increments in the
order of their numbers, so a burst of pushes costs one drain. `held/1` is the relation so
far, a delivery whose rows are a `Macaw.Data.Table` (chapter 3), ordered by the window
field:

```elixir
alias Macaw.Data.Source.Push
alias Macaw.Data.Table

ticker = MyApp.Ticker.new()
{:ok, ref} = Source.subscribe(ticker, self())
push = Push.new("ticker", ref)

:ok = MyApp.Ticker.tick(ticker, [%{"t" => ~U[2026-10-29 12:01:00Z], "value" => 2}])
:ok = MyApp.Ticker.tick(ticker, [%{"t" => ~U[2026-10-29 12:00:00Z], "value" => 1}])

push =
  Enum.reduce(1..3, push, fn _message, push ->
    receive do
      message ->
        {:ok, push} = Push.receive(push, message)
        push
    end
  end)

describe = Source.describer(%{"ticker" => {ticker, nil}})
push = Push.drain(push, describe)

{:ok, held} = push |> Push.held() |> Macaw.Data.Delivery.table()
{Table.column(held, "value"), Table.column(held, "t")}
#=> {[1, 2], [~U[2026-10-29 12:00:00Z], ~U[2026-10-29 12:01:00Z]]}
```

The second reading arrived first but is held in time order. **Rows are never
deduplicated**: an identical row pushed again is a second row. A source guards
redelivery by the number instead, and `Push` drops an increment it has already applied,
whole, counting it in `ignored`:

```elixir
again = Macaw.Data.Delivery.new([%{"t" => ~U[2026-10-29 12:01:00Z], "value" => 2}])
{:ok, push} = Push.receive(push, Push.increment_message(ref, 1, again))
push = Push.drain(push, describe)

{Table.size(push |> Push.held() |> Macaw.Data.Delivery.table!()), push.ignored, Push.refetch(push)}
#=> {2, %{repeat: 1}, nil}
```

An increment past the next number is held back until the missing ones arrive, and
`Push.refetch/1` answers `{:gap, from, to}`: the holder fetches a snapshot (a request
with `subscription: ref`) and hands it over with `Push.snapshot/2`, which replaces what
is held and drops the increments the snapshot already reflects.

`Push.receive/2` answers `:ignore` for a message that isn't this subscription's, so a
process can hold several. `drain/2`'s second argument is a describe function: an
increment naming a schema version the push hasn't cached is resolved through it, once.
A source without `subscribe/2` answers `{:error, :no_push}`:

```elixir
Source.subscribe(latency, self())
#=> {:error, :no_push}
```

A surface rendered by `macaw` 0.3.0 fetches; it doesn't subscribe. Pushing pays off with
the live runtime, and today in your own processes.

## How a surface calls sources

When a surface fetches, it runs each source's `fetch/2` in a process of its own through
`Macaw.Data.Bounded.run/2`, bounded by a timeout, so a slow or crashing source can't block
or crash the caller. You can use it for your own calls the same way:

```elixir
{:ok, 3, _reductions} = Macaw.Data.Bounded.run(fn -> 1 + 2 end, timeout: 1_000)

Macaw.Data.Bounded.run(fn -> Process.sleep(:infinity) end, timeout: 10)
#=> :hung
```

It answers `{:ok, value, reductions}`, `:hung`, `{:down, reason}` for a crash, or
`{:reductions, spent}` when given a `reductions:` cap. Chapter 4 shows how each outcome
becomes a cell's drawn state.

## Pitfalls

- **Raising in a source.** Answer `{:error, reason}`. A surface turns an error into a
  "Source unavailable" notice on the cells that read it; a raise is treated the same way,
  but loses your reason.
- **Reading the clock or global state in `fetch/2`.** Use `request.now`, and keep the
  source's configuration in its struct. Two fetches of one request should give one answer;
  the conformance kit checks it.
- **Declaring a capability you only half do.** If `supports` says `:window`, every row
  you return must be inside the window, and the served window must say so. Otherwise
  leave it out and let finishing do it.
- **Putting secrets in documents.** A surface names a source; the `sources` map you build
  in code turns the name into a configured struct. Credentials stay in your code and
  configuration.
- **Atom keys in rows with string field names.** The schema names fields, and rows should
  spell them the same way. Macaw reads either spelling, but mixing them in one source
  invites confusion.

## Recap

- A source is a struct implementing `describe/2` and `fetch/2`; call it through
  `Macaw.Data.Source`, which checks parameters and turns bad answers into values.
- A description holds the schema, parameters, capabilities and viewer independence.
- Parameters share one shape with components'; cells bind them under `params:`.
- A request carries the window, order, budget, viewer and `now`; finishing does
  whatever the source didn't, and the ceiling and pooling decide budgets on a surface.
- Pushing sources send a schema, then numbered increments and optionally snapshots;
  subscribers hold a `Push` value, whose held rows are a table.

**Further reading:** [the contract](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-contract), [descriptions](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-description), [parameters](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-parameters), [requests](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-request), [finishing](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-finishing), [the ceiling and pooling](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-budgets) and [push](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-push), in `macaw_data`'s spec/01.

Next: [chapter 3, Schemas, tables and deliveries](03-schemas-and-data.md).
