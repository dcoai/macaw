# 00 — Overview {#overview}

## 1. Purpose {#overview-purpose}

Macaw is a family of building blocks for live, data-driven applications (§4). Together they compose pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and Macaw runs them per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

Its first adopters are visualize (charts and boards), metresis (measurements and dashboards) and dcotek_web (sites). The model was derived from their requirements (`design/requirements/`).

## 2. Goals {#overview-goals}

1. **Composition effects: the whole is greater than the sum of its parts.** This is why Macaw exists. Components composed through Macaw gain effects none of them can produce alone, for *every* combination, including combinations nobody planned.

   **The principle is N + M, not N × M.** Without composition, making N components interact needs code for every pair, so it never happens. With Macaw, each component declares itself once (its slots, identity, kinds, state, exports, events, observation and renders), and every combination works.

   | Effect | What happens | Provided by |
   |---|---|---|
   | cross-highlighting without wiring | a selection in one component highlights or filters every component sharing the identity, though none knows the others | state sources, declared identity ([03](03-state.md)) |
   | one time, one "now" | every component shows the same window and freshness | the surface owns window and clock ([02](02-sources.md)) |
   | a write updates everything | data changed through one component updates every reader, here and on other viewers' pages | change notification ([02](02-sources.md#sources-change)) |
   | values derived across components and surfaces | a value computed from several components' data, shown in another | derived sources, exports, the page DAG ([03](03-state.md), [04](04-derived.md)) |
   | the whole view in one link | a shared link restores every component's state | host-owned persistence ([03](03-state.md#state-persistence)) |
   | whole-page replay | what a viewer saw, across everything on the page, at any step | records ([08](08-records.md)) |
   | "why this number?" | any shown value traces back through its derivations to its data | the declared graph ([03](03-state.md#state-dag)) |
   | disclosure that matches | the host's privacy note, observation code and CSP hash are right for this exact combination | declared observation, from one closed vocabulary ([05](05-components.md), [10](10-web.md)) |
   | accessibility of the whole | one outline, one tab order, one announcer, landmarks | pages and templates own structure ([10](10-web.md#web-a11y)) |
   | one look | every component matches; contrast is checked once | one theme; drawing colors come from its roles ([11](11-themes.md)) |
   | consistent access | every component honors what this viewer may see | the viewer reaches every source ([02](02-sources.md)) |
   | shared fetching | components reading the same data cost one fetch, and so do pages making the same viewer-independent request | sources pooled by the page and across pages ([02](02-sources.md)) |
   | whole-page output | the page prints or exports as one document | every component's neutral render and printout ([05](05-components.md), [08](08-records.md)) |
   | an assistant that understands the page | an agent sees structure, state and declared actions, and acts within a person's rules | everything declared |

   **Two design rules follow:**
   - **Every declaration must buy a composition effect.** A proposed addition to a contract states which effect it enables, or it doesn't belong.
   - **No back doors.** A component never communicates with another directly, never fetches outside a source, and never keeps state the runtime can't see. Each back door silently breaks an effect.

     **A declared local scope is not a back door.** Fast interaction state (hover, a brush band in flight) may stay in the browser in the `:local` scope ([03](03-state.md)). Components share it only through the client bus, and each declares what it reads and writes there, so the runtime knows the scope exists, who shares it and what it carries.

   **The test** is the example app (goal 7). Its components are written as if by different authors, none references another, and a page document alone assembles them. It shows the effects, and **a component added later joins every effect with no change to the existing ones.**

2. **Composes components in any Phoenix LiveView app.** Macaw is a set of building blocks, not a framework a host is built around. Any LiveView mounts a page or a surface with one call, from a document plus a map of sources. It needs no host framework, database, tracking or router.

3. **Every host concern is a behavior with a working default.** The smallest app is a few lines; a host replaces only what it cares about.

   | Concern | Behavior | Default |
   |---|---|---|
   | who is viewing | viewer | none (anonymous) |
   | what is observed | observation | nothing |
   | where definitions live | store | in memory |
   | where state persists | persistence | nowhere |
   | what is recorded | recording | nothing (closed by default) |
   | where a link or drill goes | navigation | an event to the host |

4. **Complete without a socket.** A page renders as complete server HTML, and the live layer only adds to it.
5. **Strict web rules for every component:**
   - nothing inline: `script-src` and `style-src` limited to the app's own files plus hashes;
   - nothing from another origin;
   - WCAG 2.2 AA ([10](10-web.md)).

   A component that meets these works in any host.
6. **Dependencies run one way.** No Macaw library depends on an adopter (visualize, metresis, macaw_server or any other). An adopter may depend on a Macaw library, and may do so **optionally**: it compiles its Macaw integration only when that library is present, and builds, tests and runs without it. A CI check forbids every edge from a Macaw library to an adopter; edges from adopters to Macaw are theirs to choose (§4).
7. **Proven by an example app** in this repository, using none of the three, run in CI with accessibility and keyboard checks.
8. **Open to third parties.** Built-in components and sources use the same public contracts as any package, through an explicit, default-closed registry ([12](12-registry.md)).
9. **Portable: save and restore, right where you were.** Configuration travels as a **bundle**, and state as a **state snapshot**. Restored on another machine, the same pages, configuration and state come back, re-attached to whoever restores them ([09](09-stores.md#stores-portable)). This works because everything configurable is composable data ([07](07-documents.md#documents-everything)).

## 3. Non-goals {#overview-non-goals}

- **A web framework.** Routing, sessions, sites and endpoints are the host's.
- **An identity or access system.** The viewer arrives from the host.
- **An analytics or tracking system.** Components declare what they would observe; the host decides and collects.
- **A charting library or a data store.** Charts are components (visualize). Data stores are sources (metresis, exio, a database).
- **Records editing machinery.** Drafts, change sets and transactions belong to a component library on top ([13](13-writes.md)).
- **A CMS or editor.** Macaw runs documents; editing tools sit on top. A **runtime page builder** is out of scope for v1 but not precluded ([06](06-pages.md#pages-runtime)).

## 4. The Macaw libraries {#overview-packaging}

**Macaw** is a family of building blocks that lead to applications (macaw_compose#18). Each library is one package with a descriptive suffix:

| Package | Module | Holds | Depends on |
|---|---|---|---|
| **`macaw_layers`** | `Macaw.Layers` | the document kernel; fragments, use sites, composites, stacking, masks, `explain`; the library (store, bundle); **themes**: document, roles, registry, stylesheet compilation, contrast ([07](07-documents.md), [09](09-stores.md), [11](11-themes.md)) | nothing; no Phoenix |
| **`macaw_data`** | `Macaw.Data` | the data model (Table, Schema, Delivery, units, quantities, facts); the **interaction event** and its recorded form; the **source contract**, push, the source conformance kit; **derived sources**; the **transform** and **aggregate** behaviors and the table operations ([02](02-sources.md), [04](04-derived.md)) | `macaw_layers` |
| **`macaw_compose`** | `Macaw.Compose` | sources on pages, state sources, exports, the page DAG; components, kinds, cells, containers; the built-in content components, the table among them; pages, templates, layers, regions, surfaces; records; the registry; the component conformance kit ([03](03-state.md), [05](05-components.md), [06](06-pages.md), [08](08-records.md), [10](10-web.md), [12](12-registry.md), [13](13-writes.md)) | `macaw_layers`, `macaw_data` |
| **`macaw_live`** | `Macaw.Live` | the LiveView runtime: mounting, page and surface processes, contained cells, persistent regions, static hooks, focus, the announcer | `macaw_compose`, Phoenix LiveView |
| `macaw_records` (later) | `Macaw.Records` | drafts, change sets, sinks, the Ecto adapter, the effect discipline ([13](13-writes.md)) | `macaw_compose` |

**visualize stays visualize.** It holds more than charts (geo and maps, scenes, the design builder) and is a product built on the blocks, not one of them. It depends on `macaw_layers` and `macaw_data`, and registers its theme slots into Macaw's themes. It may be folded into Macaw later, but not yet.

**visualize's visuals are Macaw components, from visualize itself.** visualize depends **optionally** on `macaw_compose` (goal 6), the way it already depends on Phoenix and Nx. When `macaw_compose` is present, `visualize_live` compiles `Visualize.Macaw.*`, which implements the component contract around visualize designs; without it, visualize builds and runs standalone. There is no adapter package (visualize#940, macaw_compose#22).

Other component packages (metresis's panels, components built on ryutronic) depend on `macaw_compose` and bring their own dependencies; Macaw never imports them.

**Boards are superseded.** A visualize board is a surface with a grid region: shared window and selection are state sources, virtual sources are derived sources, drill is a cell action ([06](06-pages.md)). Its runtime moves into `macaw_compose` and `macaw_live`; visualize keeps drawing visuals, with their printouts and exports. visualize ships a board-to-surface migration behind its optional dependency (visualize#947).

## 5. Order of work {#overview-order}

1. The document kernel, with the fragment and stacking machinery, in **`macaw_layers`** ([07](07-documents.md)). This absorbs visualize's planned extractions #880, #893 and #912.
2. The data model and source contract, in **`macaw_data`** ([02](02-sources.md)). This absorbs visualize's #903 and #916.
3. Derived sources in **`macaw_data`** ([04](04-derived.md)); state sources, exports and the page DAG in **`macaw_compose`** ([03](03-state.md)).
4. Component, surface, template and container contracts, in **`macaw_compose`** ([05](05-components.md), [06](06-pages.md)).
5. Themes in **`macaw_layers`** ([11](11-themes.md)), and the web rules in **`macaw_compose`** ([10](10-web.md)).
6. The live layer, **`macaw_live`**.
7. Adoption: visualize on `macaw_layers` and `macaw_data` (visualize#938, #939), with its visuals implementing the component contract (visualize#940), metresis on `macaw_data` (metresis#556), dcotek_web on `macaw_compose` and `macaw_live` (dcotek_web#130).

The CI dependency check (goal 6) and the example app (goal 7) are acceptance criteria of the first implementation proposal that ships code.

## 6. Status {#overview-status}

Spec only; nothing is implemented. Decisions are recorded on macaw_compose#1 (the anchor), #2 (vocabulary), #3 (state), #8 (templates), #9 (writes), #10 (composition effects) and #22 (agreement with visualize; the analysis is [`design/visualize-alignment.md`](../design/visualize-alignment.md)). Open and deferred questions are in [14](14-open.md).
