# 02 — Sources {#sources}

A **source** is anything a component's slot reads. One contract serves feeds, queries, derived sources, state sources and exports. It is a strict superset of visualize's `Visualize.Feed`: an existing feed is a source with no parameters.

## 1. The data model {#sources-data}

- **`Data.Table`:** columnar typed data, the currency of deliveries, derived sources and components. Row lists are accepted at the edge. (From visualize #916; visualize.md C1.)
- **`Data.Schema`:** each field's **meaning**: `type` (`:time | :number | :category | :text | :color`), and where known `unit` (UCUM), `quantity`, `label`, `order`, `status`, `polarity`, `continuity`, `bounds`, `identity`, and declared `values` with names and colors. A schema never gives a drawing color. (visualize.md C1.)
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
- **`supports`:** every capability is optional. composex finishes a window, box, latest or budget that the source did not honor, and reports it. (visualize.md C1, D-140.)
- **Window-less sources are allowed** (thresholds, projects, fragments). (metresis.md C1; dcotek_web.md C1.)
- **The budget never widens the window.** A source may refuse to split a bucket's keys, delivering nothing rather than a partial distribution. (metresis.md C1.)
- **`reveals`** declares what a result tells about the data or the viewer. Hosts generate disclosure from it. (dcotek_web.md C12.)
- **The viewer is an argument, not a setting.** A source may refuse, filter or tease by it. composex never writes a viewer to a document, delivery or record. (dcotek_web.md C11; visualize.md C11.)
- **Errors are values.** A source never raises. (visualize.md C1; metresis.md C1.)

## 3. Deliveries {#sources-delivery}

A delivery reports what it actually served:
- `served`: the window, resolution, `capped`, `reduced_by` (`:source | :composex`), the params, and a note (for example, "coarsened from raw");
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

**"This source's data changed; re-read it."** Any writer (a records component after a commit, a host after an import) announces a change to a source by name, or the source pushes. Every reader on the page, and on other viewers' pages through the host's PubSub, re-fetches. Components never need to know who else reads the same data. (composex#9.)

## 6. Running sources {#sources-running}

- **Pooling:** sources are named and pooled by the page. Several readers of the same source and request cost one fetch, at the largest budget among them. (visualize.md C1.)
- **Fetching never blocks the caller.** It runs out of process, with a liveness bound. The first render waits for a bounded time and then draws the loading state. (visualize.md C13 gap; dcotek_web.md C13.)
- **`now` comes from the surface.** One instant per pulse keeps windows, freshness and ages consistent. (visualize.md C1.)

## 7. Credentials {#sources-credentials}

Credentials and bindings never appear in documents. A page names a source; the host maps the name to a configured source. For metresis, that is a per-domain token, ideally scoped (metresis#555). (visualize.md C1, D-141; metresis.md C11.)
