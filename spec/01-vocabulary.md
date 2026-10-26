# 01 — Vocabulary {#vocab}

**One word, one meaning.** A duplicate concept becomes one concept, and distinct concepts that share a word get distinct words. Renaming one copy of a duplicate is not allowed (macaw_compose#2). "Part" is deliberately unused as a defined term, and appears in prose only.

## 1. Structure {#vocab-structure}

| Term | Meaning |
|---|---|
| **page** | the final browser document at one URL: everything visible. A template stack with its regions filled. One `<h1>`, one `main`, one title, one CSP and observation plan; the unit of a page view, its record and navigation |
| **template** | a registered, named arrangement of regions; the base of a stack |
| **layer** | a stackable fragment that changes a template: sets settings, fills regions, adds or hides regions, overrides collapse behavior |
| **mask** | in a layer, an explicit removal of keys from the layers below, so an override is intended rather than a conflict |
| **region** | a named area of a template, with a landmark role; holds surfaces in a flow |
| **persistent region** | a region that survives live navigation between pages, keeping its components' state and process |
| **surface** | a reusable composed unit: cells in a grid or a flow, with its own state. A dashboard, a set of prose components, a table with filters. A visualize *board* is superseded by a surface with a grid; a metresis *dashboard bundle* is a surface published by metresis |
| **cell** | a placement of a component in a surface: the component, its settings, its slot bindings, its place |
| **container** | a component kind whose content is surfaces: tabs, drawer, accordion, split |
| **section** | a headed flow unit inside a prose surface |
| **component** | a registered implementation of the component contract |
| **kind** | a role a component can render as: `:navigation`, `:content`, `:control`, `:container`. One `render(kind, assigns)` clause per kind |
| **mode** | how something is being rendered: live, socketless, neutral (for records), print |

## 2. Data and state {#vocab-data}

| Term | Meaning |
|---|---|
| **source** | anything a slot reads, through the source contract |
| **feed** | a source backed by a provider (fetch, optional push) |
| **derived source** (virtual source) | a source computed from other sources by a checked, deterministic function |
| **state source** | a typed value held by the runtime, written by events, read like any source |
| **export** | state an entity (surface, container, cell) publishes for others to bind to; others bind only to exports |
| **slot** | a component's typed data input |
| **binding** | slot → source (or export); owned by the host or the page document |
| **schema** | `Data.Schema`: a source's typed field meanings, versioned by content hash |
| **delivery** | one answer from a source: a table plus what was served |
| **viewer** | the host's context for who is viewing; passed to sources and components, never stored |
| **scope** | how long and how widely state lives: surface, page, region, session, viewer, shared |
| **change notification** | "this source's data changed; re-read it" |
| **the page DAG** | every source, state source and export on a page as nodes, bindings as edges; acyclic |
| **pulse** | one ranked recomputation of the marked nodes of the DAG |

## 3. Events and records {#vocab-records}

| Term | Meaning |
|---|---|
| **event** | the one interaction shape: which component instance, which element, what name, which identity, when, and whether visitor- or system-initiated |
| **view** | a page in a particular state |
| **view path** | a visit as a sequence of views |
| **step** | a visitor-initiated change on a view path: navigation (a new page) or a view change (a selection, an opened tab) |
| **marker** | a system-initiated change on the timeline (pushed data, a timer, another viewer's edit), recorded but not a step |
| **record** | what makes a view reproducible: definitions by digest, state by events, sources by request; never the viewer |
| **base snapshot** | the neutral render of one page version, content-addressed and shared by every visit |
| **observer** | (in hosts) an optional observation module, such as hover or focus tracking. dcotek_web's former "tracking parts" |

## 4. Documents and extension {#vocab-documents}

| Term | Meaning |
|---|---|
| **document** | any declarative value Macaw validates: pages, surfaces, templates, layers, themes, designs, settings, records |
| **fragment** | a reusable piece of a document, of a derived kind |
| **stack / compose** | cascade and union of fragments under per-key merge rules |
| **explain** | provenance of any value: which layer or fragment it came from |
| **store** | where documents live, behind the store behavior, with typed ids |
| **bundle** | the transitive closure of documents a page needs, portable between stores; never credentials, data or identity |
| **state snapshot** | current values of persisted state sources by scope; restorable, carrying no identity |
| **preset** | a fragment of component settings, stacked between a component's defaults and a cell's local settings |
| **registry** | the explicit, default-closed list of components, templates, layers, sources, functions and hooks a host enables |
| **conformance kit** | tests shipped in the library that any component or source author runs |

## 5. Terms that changed in the adopting projects {#vocab-adopters}

| Project | From | To |
|---|---|---|
| dcotek_web | trackable `data-dw` "component" | **element** |
| dcotek_web | tracking "parts" (hover, focus, copy …) | **observers** |
| dcotek_web | "level" | **capture level** and **access level** |
| dcotek_web | template `{:slot, …}` | **hole** |
| metresis | collector "sources" | **collectors** |
| metresis | family "binding" code | another name (its own choice) |
| visualize | a design's internal "layout" | **frame grid** |
| visualize | hierarchy and network layouts | **graph layouts** |
| visualize | `Chart.Schema` | renamed (visualize#893) |
