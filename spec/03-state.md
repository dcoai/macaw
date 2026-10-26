# 03 — State, exports and the page DAG {#state}

Interaction is state, and state is a source. A selection, a time window, a variable, a set of chosen skills and an open menu branch are **state sources**: typed values held by the runtime, written by events, and read like any other source.

## 1. State sources {#state-sources}

```elixir
state "skills",
  schema:  [skill: {:category, values_from: "projects.tags"}],
  multi:   true, max: 3,
  scope:   :surface,
  initial: {:host, :emphasis},   # a literal, a page param {:param, "service"}, or a value supplied by the host
  record:  :full                 # the lowest capture level at which it may be recorded; omitted means never
```

- **Components declare the state they write; the runtime holds it.** A component declares `writes` ([05](05-components.md#components-state)) and changes state only by emitting an event ([02](02-sources.md#sources-event)); the runtime applies it. Components hold no storage and no adapter. That way state can be shared, recorded and tested in one place. (macaw_compose#3.)
- **Standard state sources** cover the special cases with fixed schemas (visualize.md C5, C7; metresis.md C5):
  - **`selection`:** a declared identity, `{field, value}` or a composite map, or nothing. A pick writes the item's declared identity ([02](02-sources.md#sources-event)), through the surface's `links` (§7). Components holding no selection draw unchanged; components sharing the identity draw `:selected` and `:muted`.
  - **`window`:** `nil` (everything), `%{last: duration}` or `%{from: t, to: t}`, in UTC, with an optional **`as_of`** that reads the data as it was then ([08](08-records.md#records-requery)). It applies only to slots whose source has a `:time` window field; others ignore it. A brush writes it; **reset** returns it to its initial value and is itself an event (`moved`). A scene's playhead is this window plus `as_of`.
  - **variables:** one state source per declared variable, typed like a parameter ([05](05-components.md#components-parameters)). A control writes it; a component reads it through a bound parameter.
  - **preferences:** **`theme`**, **`zone`** (a time zone name) and **`units`** (a unit system), at `:viewer` scope when the host knows the viewer and `:page` otherwise. They reach every component in its context, so one person's unit system follows them across every component on every page. (macaw_compose#22, R10.)
  - a scene's **`camera`** and **`breakpoints`**, declared by the scene's component like any other state it writes.
- **With no socket, the initial value is the rendered state,** so bots and no-JS visitors get a meaningful page. (dcotek_web.md C2.)
- **Reading state:** a component reads a state source it doesn't write in one of two ways, and never by asking another component:
  - **a parameter bound to it** (`bins: {:state, "bins"}`), delivered through the component's `state/3` transition ([05](05-components.md#components-states));
  - **a slot bound to it,** read like any other source.

## 2. Scopes {#state-scopes}

| Scope | Lives for | Example |
|---|---|---|
| `:local` | the page in the browser; never on the server | a hover position; a brush band while it is drawn |
| `:surface` (default) | one surface instance | a dashboard's window and selection; the picker's choices |
| `:page` | the page | the theme; a page-wide filter; sidebar open |
| `:region` | a persistent region's content, across live navigation | a table of contents' scroll position |
| `:session` | the visit, on screen or not | the site menu's open branches |
| `:viewer` | across visits (the host must know the viewer) | a preferred unit system |
| `:shared` | every viewer of that surface | a wall display's selection |

**The `:local` scope** holds fast interaction state that would cost a round trip per pointer move. It lives in the browser only: it is **never recorded, persisted or exported**, and it never reaches the server. Components share it only through the **client bus** ([10](10-web.md)), keyed by scope name, and each declares the keys it reads and writes and the domain type each carries (`local: [hover: :x_domain]`, [05](05-components.md#components-state)). Values are domain values (a time, an identity), never pixels, so a map and a chart share a hover. Because it is declared, it is not a back door ([00](00-overview.md#overview-goals)); when a local value must count (a finished brush), the component emits an event that writes a real state source. visualize's sync groups are local scope keys (macaw_compose#22, decision 6).

**State belongs to a component instance** (its place plus the component plus a key), not to whatever a region currently shows. When an instance is replaced (a layer fills a persistent region differently), its state follows its scope: `:region` state is gone, and `:session` state returns when the instance does. (macaw_compose#8, question 1.)

The default scope and the persistence behavior's final shape are settled by experiment in the example app (macaw_compose#3).

## 3. Persistence and recording {#state-persistence}

Each has one owner:

| Layer | Owner | Default |
|---|---|---|
| live value | the Macaw runtime | — |
| **persistence:** survives a reload, a new page, a later visit | a host behavior: URL, session, token, database | **none** |
| **recording:** what it was over time, for replay | a host behavior, capped by capture level | **none** (closed by default) |

Persistence is for **interaction** state only. It is never how domain data is saved; that is the records library's job ([13](13-writes.md)). metresis persists in the URL; dcotek_web must not use the URL for visitor-specific state, and uses the session and token instead. (metresis.md C5; dcotek_web.md C1.)

## 4. State snapshots {#state-snapshots}

A **state snapshot** is the current value of every persisted state source in a set of scopes (a page, a session, a viewer), in the same shape as the state events in records ([08](08-records.md)). It can be exported and restored, alone or inside a bundle ([09](09-stores.md#stores-portable)).
- Restoring validates each value against its state source's current schema. A value that no longer fits is dropped, and reported by path.
- Values are restored for whoever restores them: a snapshot carries no identity.
- Recording rules apply: a state source that may not be recorded is not exported either.

## 5. Exports {#state-exports}

Surfaces, containers and cells publish **exports**: named state others may bind to.

```yaml
surface: service_health
exports:
  selected_service: cells.map.selection
  window: window
```

**Others bind only to exports, never to internals.** Encapsulation keeps a surface reusable: it can be rearranged inside without breaking anything that depends on it. An aggregate over several exports is a derived source at the scope where it is defined ([04](04-derived.md)). (macaw_compose#2.)

## 6. The page DAG {#state-dag}

Every source on a page is a node: feeds, derived sources, state sources and exports. Bindings are edges.

- **The graph is acyclic.** A cycle is refused at validation and named in full ("`notes.summary` → `health.filter` → `notes.summary`").
- **Recomputation runs in ranked pulses** (visualize's engine, extended to the page):
  - a change marks its readers;
  - a pulse comes after a debounce;
  - each node runs at most once per pulse, in rank order;
  - an unchanged result stops propagating, so there are no glitches.

  (visualize.md C2.)
- **State changes only at events (visitor or system), never during recomputation.** A component cannot write state *because* state changed. This keeps the graph a DAG however surfaces are combined, and makes event loops impossible.
- **Computing is separate from rendering.** A hidden surface (a closed tab, an unopened drawer) still computes whatever others depend on; only its rendering waits.
- **Provenance:** any value traces back through the graph ("why this number?").
- **Validation time, not build time.** The graph is built by pure library functions whenever a page document is loaded. In v1 that is at build or boot, and a runtime builder could call the same functions ([06](06-pages.md#pages-runtime)).
- **Across processes:** a persistent region runs in its own LiveView process, so edges into or out of it cross processes. The live layer carries marked changes between them (an engineering item, [14](14-open.md)).

## 7. Links: identity equivalence {#state-links}

Sources written by different authors name the same identity differently (`name` in one feed, `svc` in another, `service` in a third). A surface declares their equivalence **once, where the components meet**, instead of a derived source per mismatch:

```yaml
surface: service_health
links:
  name: service
  svc: service
```

- **Each link is one step:** a field maps to a canonical name, never through a chain.
- **The `selection` state source applies links on write and on read.** A pick on `svc = "api"` writes `service = "api"`, and every component whose identity field links to `service` reads it.
- **Schemas still declare identity** ([02](02-sources.md#sources-data)); links only say which differently named identity fields are the same.
- Links are validated: both sides must be declared identity fields of sources on the surface, with the same type.

Standalone, an adopter's own holder plays the surface's role (visualize's `Visualize.Interaction`, visualize#941). (macaw_compose#22, R8.)
