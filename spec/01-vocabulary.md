# 01 — Vocabulary {#vocab}

**One word, one meaning.** A duplicate concept becomes one concept, and distinct concepts that share a word get distinct words. Renaming one copy of a duplicate is not allowed (macaw_compose#2). "Part" is deliberately unused as a defined term, and appears in prose only.

## 1. Structure {#vocab-structure}

| Term | Meaning |
|---|---|
| **page** | the final browser document at one URL: everything visible. A template stack with its regions filled. One `<h1>`, one `main`, one title, one CSP and observation plan; the unit of a page view, its record and navigation |
| **template** | a registered, named arrangement of regions; the base of a stack |
| **layer** | a stackable fragment that changes a template: sets params, fills regions, adds or hides regions, overrides collapse behavior |
| **mask** | in a layer, an explicit removal of keys from the layers below, so an override is intended rather than a conflict |
| **region** | a named area of a template, with a landmark role; holds surfaces in a flow |
| **persistent region** | a region that survives live navigation between pages, keeping its components' state and process |
| **surface** | a reusable composed unit: cells in a grid or a flow, with its own state. A dashboard, a set of prose components, a table with filters. A visualize *board* is superseded by a surface with a grid; a metresis *dashboard bundle* is a surface published by metresis |
| **cell** | a placement of a component in a surface, in a document: the component, its settings (inline, or a preset reference with overrides), its slot bindings, its actions, its place |
| **instance** | one live occurrence of a cell's component on a page: the cell's place, the component and a key. Its id is what events name; state belongs to it ([03](03-state.md#state-scopes)) |
| **action** | a placement's mapping from one of a component's events to an effect: `set` a state source, or `navigate` |
| **page param** | a typed value a page accepts from its URL, with legal values |
| **container** | a component kind whose content is surfaces: tabs, drawer, accordion, split |
| **section** | a headed flow unit inside a prose surface |
| **component** | a registered implementation of the component contract |
| **kind** | a role a component can render as: `:navigation`, `:content`, `:control`, `:container`. One `render(kind, assigns)` clause per kind |
| **mode** | how something is being rendered: live, socketless, neutral (for records), print ([10](10-web.md#web-modes)) |

## 2. Data and state {#vocab-data}

| Term | Meaning |
|---|---|
| **source** | anything a slot reads, through the source contract |
| **feed** | a source backed by a provider (fetch, optional push) |
| **derived source** (virtual source) | a source computed from other sources by a checked, deterministic function |
| **state source** | a typed value held by the runtime, written by events, read like any source |
| **export** | state an entity (surface, container, cell) publishes for others to bind to; others bind only to exports |
| **slot** | a component's typed data input |
| **binding** | slot → source (or export), or a bindable parameter → state source; owned by the host or the page document |
| **parameter** | one typed entry in a settings schema (a component's, a page's params, a template's options): type, default, legal values, `legal_for`, whether it is bindable, and documentation |
| **settings** | the parameter values a component is given: its defaults, a preset, and the cell's own values, stacked |
| **budget** | the rows a component may draw for one slot, a function of its parameters and size; capped by the **host ceiling** |
| **pooling** | one fetch for every reader of the same request: on a page, and across pages when the result doesn't depend on the viewer |
| **schema** | `Data.Schema`: a source's typed field meanings, versioned by content hash |
| **delivery** | one answer from a source: a table plus what was served |
| **visitor** | the person at the page |
| **viewer** | the host's context for the visitor (identity and access); passed to sources and components, never stored |
| **scope** | how long and how widely state lives: local, surface, page, region, session, viewer, shared |
| **local scope** | interaction state held only in the browser, shared through the client bus, never recorded or persisted |
| **client bus** | the browser-side channel through which components share local-scope keys, carrying domain values only |
| **links** | a surface's declaration of which differently named identity fields are the same identity |
| **preferences** | a viewer's display choices (theme, zone, units), held as state sources, never part of the viewer |
| **change notification** | "this source's data changed; re-read it" |
| **the page DAG** | every source, state source and export on a page as nodes, bindings as edges; acyclic |
| **pulse** | one ranked recomputation of the marked nodes of the DAG |

## 3. Events and records {#vocab-records}

| Term | Meaning |
|---|---|
| **event** | the one interaction shape, `Macaw.Data.Event`: which component instance, which element, what name, which identity, what value, when, and whether visitor- or system-initiated; live, it may also carry the data row and the point |
| **recorded form** | an event without its data row or point: what records, observation and state snapshots see |
| **printout** | a component's prepared output with its data, for print and output; never a record |
| **output** | a page or component written out as a standalone file (print, PDF, SVG, PNG): self-contained, never a record |
| **view** | a page in a particular state |
| **view path** | a visit as a sequence of views |
| **step** | a visitor-initiated change on a view path: navigation (a new page) or a view change (a selection, an opened tab) |
| **marker** | a system-initiated change on the timeline (pushed data, a timer, another viewer's edit), recorded but not a step |
| **record** | what makes a view reproducible: definitions by digest, state by events, sources by request; never the viewer |
| **base render** | the neutral render of one page version, content-addressed and shared by every visit |
| **capture level** | how much a session may record, on an ordered scale the host defines (default `:none < :basic < :full`), decided per session by the host. A state source declares the lowest level at which it may be recorded ([08](08-records.md#records-stores)) |
| **observer** | (in hosts) an optional observation module, such as hover or focus tracking. macaw_server's former "tracking parts" |

## 4. Documents and extension {#vocab-documents}

| Term | Meaning |
|---|---|
| **document** | any declarative value Macaw validates: pages, surfaces, templates, layers, themes, designs, settings, records |
| **fragment** | a reusable piece of a document, of a derived document type |
| **document type** | the type a document or reference names (page, surface, template, theme, design …), with its own version line; never called a "kind" |
| **stack / compose** | cascade and union of fragments under per-key merge rules |
| **explain** | provenance of any value: which layer or fragment it came from |
| **store** | where documents live, behind the store behavior, with typed ids |
| **bundle** | the transitive closure of documents a page needs, portable between stores; never credentials, data or identity. Writing one is the only "export" of documents |
| **state snapshot** | current values of persisted state sources by scope; restorable, carrying no identity |
| **preset** | a fragment of component settings, stacked between a component's defaults and a cell's local settings |
| **registry** | the explicit, default-closed set of packages a host enables, and the members derived from them ([12](12-registry.md#registry-model)) |
| **conformance kit** | tests shipped in the library that any author of a contract's implementations runs: one kit per contract, extended by **check sets** |
| **profile** | a validation rule set for which colors a document may name: `:roles` on Macaw pages, `:open` in an adopter standalone ([11](11-themes.md#themes-rules)) |

## 5. Terms that changed in the adopting projects {#vocab-adopters}

| Project | From | To |
|---|---|---|
| macaw_server (was dcotek_web) | trackable `data-dw` "component" | **element** |
| macaw_server | tracking "parts" (hover, focus, copy …) | **observers** |
| macaw_server | "level" | **capture level** and **access level** |
| macaw_server | template `{:slot, …}` | **hole** |
| metresis | collector "sources" | **collectors** |
| metresis | family "binding" code | another name (its own choice) |
| visualize | a design's internal "layout" | **frame grid** |
| visualize | hierarchy and network layouts | **graph layouts** |
| visualize | `Chart.Schema` | renamed when the kernel moves ([00](00-overview.md#overview-order) step 2) |
| visualize | `Visualize.Event` | **event** (`Macaw.Data.Event`, visualize#941) |
| visualize | a design's `:var` | **parameter** |
| visualize | `drill` | **cell actions** |
| visualize | sync group | **local scope** key |
| visualize | `Board.Snapshot` | **printout** (`Visualize.Printout`, visualize#947) |
| visualize | `Board.Export` | **output** (`Visualize.Output`) |
| visualize | "kind" for fragments and frames | **document type**, **frame type** |
| visualize | a design's theme slots | **theme roles** |
| Macaw | `macaw_records` | **`macaw_edit`** ("record" means the replay artifact only) |
| Macaw | base snapshot | **base render** |
