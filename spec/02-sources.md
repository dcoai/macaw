# 02 — Sources {#sources}

A **source** is anything a component's slot reads. One contract serves feeds, queries, derived sources, state sources and exports. It is a strict superset of visualize's `Visualize.Feed`: an existing feed is a source with no parameters.

## 1. The data model {#sources-data}

- **`Data.Table`:** columnar typed data, the currency of deliveries, derived sources and components. Row lists are accepted at the edge. (visualize.md C1.)
- **`Data.Schema`:** each field's **meaning**: `type` (`:time | :number | :category | :text | :color`), and where known `unit` (UCUM), `quantity`, `label`, `order`, `status`, `polarity`, `continuity`, `bounds`, `identity`, and declared `values` with names and colors. (visualize.md C1.)
- **A schema gives data colors, never drawing colors.** A `:color` field, or a color on a declared value (a team's color), is **content**: it may be shown only with a non-color cue (a glyph, a label or a dash) and under a contrast guard against the background, and it is never the sole carrier of meaning. Drawing colors come from the theme's roles ([11](11-themes.md#themes-rules); macaw_compose#22, decision 7).
- **A schema's version is the SHA-256 of a canonical encoding.** A delivery names the version, and a push sends the schema before rows made under it. (visualize.md C1; metresis.md C1.)
- **Identity is declared** (`identity: true`, composite allowed), never guessed. Selection, `latest` and per-identity derivations read it. (visualize.md C1.)
- **Units and quantities** come from one vocabulary (visualize's), so nothing translates between two. (metresis.md C1.)

## 2. The contract {#sources-contract}

```elixir
@callback describe(source, context) ::
  {:ok, %Description{
     schema:   Data.Schema.t(),
     params:   ParamSchema.t(),
     supports: [:window | :box | :latest | :budget | :push | :as_of],
     reveals:  Disclosure.t()
   }} | {:error, reason}

@callback fetch(source, %Request{
     params:  %{String.t() => term},   # validated against ParamSchema before the call
     window:  nil | window | box,      # meaningful only when the schema has a window field
     budget:  nil | pos_integer,       # rows
     as_of:   nil | DateTime.t(),      # only if supports :as_of
     viewer:  Viewer.t(),              # never stored
     now:     DateTime.t()             # given by the surface; a source never reads a clock
   }) ::
  {:ok, %Delivery{table, schema, served, origin}} | {:error, reason}

@optional_callbacks subscribe: 2, unsubscribe: 2
```

- **`params`** use the same type vocabulary as `Data.Schema`, with **legal values**. For example, metresis's aggregation is a category whose values are `legal(metric)`, so no consumer can ask for an aggregation the type forbids. (metresis.md C1.)
- **`supports`:** every capability is optional. Macaw finishes a window, box, latest or budget that the source did not honor, and reports it. (visualize.md C1, D-140.)
- **Window-less sources are allowed** (thresholds, projects, fragments). (metresis.md C1; dcotek_web.md C1.)
- **The budget never widens the window.** A source may refuse to split a bucket's keys, delivering nothing rather than a partial distribution. (metresis.md C1.)
- **`reveals`** declares what a result tells about the data or the viewer. Hosts generate disclosure from it. (dcotek_web.md C12.)
- **The viewer is an argument, not a setting.** A source may refuse, filter or tease by it. Macaw never writes a viewer to a document, delivery or record. (dcotek_web.md C11; visualize.md C11.)
- **Preferences are state, not part of the viewer.** A viewer's display preferences (`theme`, `zone`, `units`) are state sources ([03](03-state.md#state-sources)), persisted like any other state and passed to components in their context. The viewer argument carries identity and access only.
- **Errors are values.** A source never raises. (visualize.md C1; metresis.md C1.)

## 3. Deliveries {#sources-delivery}

A delivery reports what it actually served:
- `served`: the window, resolution, `capped`, `reduced_by`, the params, and a note (for example, "coarsened from raw");
- `reduced_by` says who brought the rows within budget: `:source` (the source honored the budget), `:runtime` (Macaw reduced a pooled delivery to this reader's budget, or finished a budget the source didn't honor) or `:component` (the component reduced further while drawing, and reports it);
- `over_budget`: true when the slot's budget exceeded the host ceiling, so no rows were handed over ([05](05-components.md#components-budget));
- `origin`: the source, a digest of the request, and `as_of` when used.

Absence is never zero: a source never fills a gap with 0. (metresis.md C1.)

## 4. Push {#sources-push}

Push is optional and declared:
- the subscribe handshake sends the schema first;
- a pushed delivery is an increment, merged by the window field;
- pushes between two pulses are coalesced;
- an unknown schema version falls back to `describe`.

(visualize.md C1; metresis.md C1.)

## 5. Change notification {#sources-change}

**"This source's data changed; re-read it."** Any writer (an editing component after a commit, a host after an import) announces a change to a source by name, or the source pushes. Every reader on the page, and on other viewers' pages through the host's PubSub, re-fetches. Components never need to know who else reads the same data. (macaw_compose#9.)

## 6. Running sources {#sources-running}

- **Pooling:** sources are named and pooled by the page. Several readers of the same source and request cost one fetch, at the largest budget among them, and each reader is reduced to its own budget (`reduced_by: :runtime`). (visualize.md C1.)
- **Pooling across pages** is required in v1 (macaw_compose#22, decision 9). A request whose result doesn't depend on the viewer, as the source's `reveals` declares, is fetched once for every page making it, through the host's PubSub, and delivered to each. A surface whose state is `:shared`, watched by many viewers, then costs one fetch per pulse, as a visualize board does today. A request whose result depends on the viewer is never pooled across viewers.
- **The host ceiling** caps every slot's budget ([05](05-components.md#components-budget)). A host sets it once; a page may lower it, never raise it.
- **Fetching never blocks the caller.** It runs out of process, with a liveness bound. The first render waits for a bounded time and then draws the loading state. (visualize.md C13 gap; dcotek_web.md C13.)
- **`now` comes from the surface.** One instant per pulse keeps windows, freshness and ages consistent. (visualize.md C1.)

## 7. Credentials {#sources-credentials}

Credentials and bindings never appear in documents. A page names a source; the host maps the name to a configured source. For metresis, that is a per-domain token, ideally scoped (metresis#555). (visualize.md C1, D-141; metresis.md C11.)

## 8. The interaction event {#sources-event}

Every component emits interaction in **one struct**, `Macaw.Data.Event`, defined in `macaw_data` so that an adopter using no other Macaw library (visualize standalone) emits the same value it emits on a Macaw page (macaw_compose#22, decision 4; visualize#941):

```elixir
%Event{
  name:      String.t(),               # a name the component declares
  instance:  String.t(),               # the emitting instance's id (01)
  element:   %{frame: id, item: id, path: [id]},  # path innermost first
  identity:  %{field => value} | nil,  # the declared identity of the item, when it maps to data
  value:     term,                     # the event's own value: a window, a chosen option
  initiator: :visitor | :system,
  time:      DateTime.t(),             # the surface's (or standalone holder's) now; never a clock read
  point:     {x, y} | nil,             # where, in the drawing; live only
  modifiers: [atom],
  row:       map | nil                 # the data row, delivered to the host, never recorded
}
```

- **`initiator`** separates the steps of a view path (a visitor did something) from its markers (the system did something) ([08](08-records.md#records-paths)). A paused animation is a system event.
- **The recorded form,** `Event.recordable/1`, drops `row` and `point`. Records, observation and state snapshots only ever see the recorded form, so data values never reach them ([08](08-records.md#records-content)).
- **The drawn-token rule:** an event on an element that maps to data resolves against the drawing it landed on. Each drawing carries a token; an event whose token is not the current drawing's is dropped, never resolved against newer data. (visualize D-170.)
- **Identity is the declared identity** of the item (§1). Inference from other fields is allowed only for a visitor's one-off pick, never for tracking or recording. (visualize D-167.)
