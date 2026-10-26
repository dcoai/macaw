# 00 — Overview {#overview}

## 1. Purpose {#overview-purpose}

composex composes live, data-driven pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and composex runs them per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

Its first adopters are visualize (charts and boards), metresis (measurements and dashboards) and dcotek_web (sites). The model was derived from their requirements (`design/requirements/`).

## 2. Goals {#overview-goals}

1. **Composition effects: the whole is greater than the sum of its parts.** This is why composex exists. Components composed through composex gain effects none of them can produce alone, for *every* combination, including combinations nobody planned.

   **The principle is N + M, not N × M.** Without composition, making N components interact needs code for every pair, so it never happens. With composex, each component declares itself once (its slots, identity, kinds, state, exports, events, observation and renders), and every combination works.

   | Effect | What happens | Provided by |
   |---|---|---|
   | cross-highlighting without wiring | a selection in one component highlights or filters every component sharing the identity, though none knows the others | state sources, declared identity ([03](03-state.md)) |
   | one time, one "now" | every component shows the same window and freshness | the surface owns window and clock ([02](02-sources.md)) |
   | a write updates everything | data changed through one component updates every reader, here and on other viewers' pages | change notification ([02](02-sources.md#sources-change)) |
   | values derived across components and surfaces | a value computed from several components' data, shown in another | derived sources, exports, the page DAG ([03](03-state.md), [04](04-derived.md)) |
   | the whole view in one link | a shared link restores every component's state | host-owned persistence ([03](03-state.md#state-persistence)) |
   | whole-page replay | what a viewer saw, across everything on the page, at any step | records ([08](08-records.md)) |
   | "why this number?" | any shown value traces back through its derivations to its data | the declared graph ([03](03-state.md#state-dag)) |
   | disclosure that matches | the host's privacy note, observation code and CSP hash are right for this exact combination | declared observation ([05](05-components.md)) |
   | accessibility of the whole | one outline, one tab order, one announcer, landmarks | pages and templates own structure ([10](10-web.md#web-a11y)) |
   | one look | every component matches; contrast is checked once | one theme, roles only ([11](11-themes.md)) |
   | consistent access | every component honors what this viewer may see | the viewer reaches every source ([02](02-sources.md)) |
   | shared fetching | components reading the same data cost one fetch | sources pooled by the page ([02](02-sources.md)) |
   | whole-page output | the page prints or exports as one document | every component's neutral render ([05](05-components.md)) |
   | an assistant that understands the page | an agent sees structure, state and declared actions, and acts within a person's rules | everything declared |

   **Two design rules follow:**
   - **Every declaration must buy a composition effect.** A proposed addition to a contract states which effect it enables, or it doesn't belong.
   - **No back doors.** A component never communicates with another directly, never fetches outside a source, and never keeps state the runtime can't see. Each back door silently breaks an effect.

   **The test** is the example app (goal 7). Its components are written as if by different authors, none references another, and a page document alone assembles them. It shows the effects, and **a component added later joins every effect with no change to the existing ones.**

2. **Composes components in any Phoenix LiveView app.** composex is the composition layer, not a framework a host is built around. Any LiveView mounts a page or a surface with one call, from a document plus a map of sources. It needs no host framework, database, tracking or router.

3. **Every host concern is a behavior with a working default.** The smallest app is a few lines; a host replaces only what it cares about.

   | Concern | Behaviour | Default |
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
6. **No dependency on its adopters.** composex depends on none of visualize, metresis or dcotek_web. A CI check enforces it.
7. **Proven by an example app** in this repository, using none of the three, run in CI with accessibility and keyboard checks.
8. **Open to third parties.** Built-in components and sources use the same public contracts as any package, through an explicit, default-closed registry ([12](12-registry.md)).
9. **Portable: save and restore, right where you were.** Configuration travels as a **bundle**, and state as a **state snapshot**. Restored on another machine, the same pages, configuration and state come back, re-attached to whoever restores them ([09](09-stores.md#stores-portable)). This works because everything configurable is composable data ([07](07-documents.md#documents-everything)).

## 3. Non-goals {#overview-non-goals}

- **A web framework.** Routing, sessions, sites and endpoints are the host's.
- **An identity or access system.** The viewer arrives from the host.
- **An analytics or tracking system.** Components declare what they would observe; the host decides and collects.
- **A charting library or a data store.** Charts are components (visualize). Data stores are sources (metresis, exio, a database).
- **Records editing machinery.** Drafts, change sets and transactions belong to a component library on top ([13](13-writes.md)).
- **A CMS or editor.** composex runs documents; editing tools sit on top. A **runtime page builder** is out of scope for v1 but not precluded ([06](06-pages.md#pages-runtime)).

## 4. Packaging {#overview-packaging}

| Package | Contains | Depends on |
|---|---|---|
| `composex` | the pure core: documents and fragments, the data model, the source contract, state and the page DAG, derived sources, the component, surface, template and page contracts, records, themes, the registry, the conformance kit | no Phoenix |
| `composex_live` | the LiveView runtime: mounting, the page and surface processes, contained cells, persistent regions, hooks, the announcer | `composex`, Phoenix LiveView |

Component packages (visualize's charts, metresis's panels, a records library) depend on these and bring their own dependencies; composex never imports them.

## 5. Order of work {#overview-order}

1. The document kernel, with the fragment and stacking machinery ([07](07-documents.md)).
2. The source contract and data model ([02](02-sources.md)).
3. State sources, exports and the page DAG ([03](03-state.md)).
4. Component, surface, template and container contracts ([05](05-components.md), [06](06-pages.md)).
5. Themes and the web rules ([10](10-web.md), [11](11-themes.md)).
6. The live layer (`composex_live`).
7. Adoption in each project (visualize#938, metresis#556, dcotek_web#130).

The CI dependency check (goal 6) and the example app (goal 7) are acceptance criteria of the first implementation proposal that ships code.

## 6. Status {#overview-status}

Spec only; nothing is implemented. Decisions are recorded on composex#1 (the anchor), #2 (vocabulary), #3 (state), #8 (templates), #9 (writes) and #10 (composition effects). Open and deferred questions are in [14](14-open.md).
