# 03 — State, exports and the page DAG {#state}

Interaction is state, and state is a source. A selection, a time window, a variable, a set of chosen skills and an open menu branch are **state sources**: typed values held by the runtime, written by events, and read like any other source.

## 1. State sources {#state-sources}

```elixir
state "skills",
  schema:  [skill: {:category, values_from: "projects.tags"}],
  multi:   true, max: 3,
  scope:   :surface,
  initial: {:host, :emphasis},   # a literal, a param, or a value supplied by the host
  record:  :full                 # the lowest capture level at which it may be recorded; omitted means never
```

- **Components declare state; the runtime holds it.** A component changes state only by an event. Components hold no storage and no adapter. That way state can be shared, recorded and tested in one place. (macaw_compose#3.)
- **Standard state sources** cover the special cases with fixed schemas:
  - `selection`, an identity `{field, value}`;
  - `window`, set by a brush;
  - each **variable**.

  (visualize.md C5; metresis.md C5.)
- **With no socket, the initial value is the rendered state,** so bots and no-JS visitors get a meaningful page. (dcotek_web.md C2.)

## 2. Scopes {#state-scopes}

| Scope | Lives for | Example |
|---|---|---|
| `:surface` (default) | one surface instance | a dashboard's window and selection; the picker's choices |
| `:page` | the page | the theme; a page-wide filter; sidebar open |
| `:region` | a persistent region's content, across live navigation | a table of contents' scroll position |
| `:session` | the visit, on screen or not | the site menu's open branches |
| `:viewer` | across visits (the host must know the viewer) | a preferred unit system |
| `:shared` | every viewer of that surface | a wall display's selection |

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
