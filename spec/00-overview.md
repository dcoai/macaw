# 00 — Overview {#overview}

## 1. Purpose {#overview-purpose}

Macaw is a family of building blocks for live, data-driven applications (§4). Together they compose pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and Macaw runs them per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

Its first adopters are visualize (charts and boards), metresis (measurements and dashboards) and macaw_server (sites). The model was derived from their requirements (`design/requirements/`).

## 2. Goals {#overview-goals}

1. **Composition effects: the whole is greater than the sum of its parts.** This is why Macaw exists. Components composed through Macaw gain effects none of them can produce alone, for *every* combination, including combinations nobody planned.

   **The principle is N + M, not N × M.** Without composition, making N components interact needs code for every pair, so it never happens. With Macaw, each component declares itself once (its slots, identity, kinds, state, events, observation and renders), and every combination works.

   | Effect | What happens | Provided by |
   |---|---|---|
   | cross-highlighting without wiring | a selection in one component highlights or filters every component sharing the identity, though none knows the others | state sources, declared identity ([03](03-state.md)) |
   | one time, one "now" | every component shows the same window and freshness | the surface owns window and clock ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md)) |
   | a write updates everything | data changed through one component updates every reader, here and on other viewers' pages | change notification ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-change)) |
   | values derived across components and surfaces | a value computed from several components' data, shown in another | derived sources, exports, the page DAG ([03](03-state.md), [macaw_data 02](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/02-derived.md)) |
   | the whole view in one link | a shared link restores every component's state | host-owned persistence ([03](03-state.md#state-persistence)) |
   | whole-page replay | what a viewer saw, across everything on the page, at any step | records ([08](08-records.md)) |
   | "why this number?" | any shown value traces back through its derivations to its data | the declared graph ([03](03-state.md#state-dag)) |
   | disclosure that matches | the host's privacy note, observation code and CSP are right for this exact combination | declared observation, from one closed vocabulary ([05](05-components.md), [10](10-web.md#web-observation)) |
   | accessibility of the whole | one outline, one tab order, one announcer, landmarks | pages and templates own structure ([10](10-web.md#web-a11y)) |
   | one look | every component matches; contrast is checked once | one theme; drawing colors come from its roles ([macaw_layers 04](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/04-themes.md)) |
   | consistent access | every component honors what this viewer may see | the viewer reaches every source ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md)) |
   | shared fetching | components reading the same data cost one fetch, and so do pages making the same viewer-independent request | sources pooled by the page and across pages ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md)) |
   | whole-page output | the page prints, or is output, as one document | every component's neutral render and printout ([05](05-components.md), [08](08-records.md)) |
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
| how a change reaches other pages and nodes | notification: change notification and cross-page pooling ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-change)) | this node only, through a `Registry`; a host plugs in its PubSub to reach other nodes |

4. **Complete without a socket.** A page renders as complete server HTML, and `macaw_live` only adds to it.
5. **Strict web rules for every component:**
   - nothing inline: `script-src` limited to the app's own files plus the hash of a host's own inline script, `style-src` to the app's own files;
   - nothing from another origin;
   - WCAG 2.2 AA ([10](10-web.md)).

   A component that meets these works in any host.
6. **Dependencies run one way.** No Macaw library depends on an adopter (visualize, metresis, macaw_server or any other). An adopter may depend on a Macaw library, and may do so **optionally**: it compiles its Macaw integration only when that library is present, and builds, tests and runs without it. A CI check forbids every edge from a Macaw library to an adopter; edges from adopters to Macaw are theirs to choose (§4).
7. **Proven by an example app** in this repository, using none of the three, run in CI with accessibility and keyboard checks.
8. **Open to third parties.** Built-in components and sources use the same public contracts as any package, through an explicit, default-closed registry ([12](12-registry.md)).
9. **Portable: save and restore, right where you were.** Configuration travels as a **bundle**, and state as a **state snapshot**. Restored on another machine, the same pages, configuration and state come back, re-attached to whoever restores them ([macaw_layers 03](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/03-stores.md#stores-portable)). This works because everything configurable is composable data ([07](07-documents.md#documents-everything)).

## 3. Non-goals {#overview-non-goals}

- **A web framework.** Routing, sessions, sites and endpoints are the host's.
- **An identity or access system,** in the composition libraries. The viewer arrives from the host; `macaw_auth` is a separate host library a host may use for it (§4).
- **An analytics or tracking system.** Components declare what they would observe; the host decides and collects.
- **A charting library or a data store.** Charts are components (visualize). Data stores are sources (metresis, exio, a database).
- **Data-editing machinery.** Drafts, change sets and transactions belong to a component library on top, `macaw_edit` ([13](13-writes.md)).
- **A CMS or editor.** Macaw runs documents; editing tools sit on top. A **runtime page builder** is out of scope for v1 but not precluded ([06](06-pages.md#pages-runtime)).

## 4. The Macaw libraries {#overview-packaging}

**Macaw** is a family of building blocks that lead to applications (macaw_compose#18). Each library is one package with a descriptive suffix, and **each has its own spec in its own repository** (#61): `macaw_data`'s is in dco-tek/macaw_data; the host libraries' in theirs; the rest are in this repository's spec/ until their repositories exist, and move with them.

| Package | Module | Holds | Depends on |
|---|---|---|---|
| **`macaw_layers`** | `Macaw.Layers` | the document kernel; fragments, use sites, composites, stacking, masks, `explain`; the library (store, bundle); **themes**: document, roles, registry, stylesheet compilation, contrast ([macaw_layers' spec](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/README.md)) | nothing; no Phoenix |
| **`macaw_data`** | `Macaw.Data` | the data model (Table, Schema, Delivery, units, quantities, facts); the **interaction event** and its recorded form; the **source contract**, push, the source conformance kit; **derived sources**; the **transform** and **aggregate** behaviors and the table operations ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md), [macaw_data 02](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/02-derived.md)) | `macaw_layers` |
| **`macaw_compose`** | `Macaw.Compose` | sources on pages, state sources, exports, the page DAG; components, kinds, cells, containers; the built-in content components, the table among them; pages, templates, layers, regions, surfaces; records; the registry; the component conformance kit ([03](03-state.md), [05](05-components.md), [06](06-pages.md), [08](08-records.md), [10](10-web.md), [12](12-registry.md), [13](13-writes.md)) | `macaw_layers`, `macaw_data` |
| **`macaw_live`** | `Macaw.Live` | the LiveView runtime: mounting, page and surface processes, contained cells, persistent regions, static hooks, focus, the announcer, the client bus, the page-shortcut registry, the asset proxy | `macaw_compose`, Phoenix LiveView |
| `macaw_edit` (later) | `Macaw.Edit` | drafts, change sets, sinks, the Ecto adapter, the effect discipline ([13](13-writes.md)) | `macaw_compose` |

**visualize stays visualize.** It holds more than charts (geo and maps, scenes, the design builder) and is a product built on the blocks, not one of them. It depends on `macaw_layers` and `macaw_data`, and registers its theme roles into Macaw's themes. It may be folded into Macaw later, but not yet.

**visualize's visuals are Macaw components, from visualize itself.** visualize depends **optionally** on `macaw_compose` (goal 6), the way it already depends on Phoenix and Nx. When `macaw_compose` is present, `visualize_live` compiles `Visualize.Macaw.*`, which implements the component contract around visualize designs; without it, visualize builds and runs standalone. There is no adapter package (visualize#940, macaw_compose#22).

Other component packages (metresis's panels, components built on ryutronic) depend on `macaw_compose` and bring their own dependencies; Macaw never imports them.

**Host libraries.** Every deployable project also carried the same host-side code: request guards, configuration on the data volume, secrets, release tasks, the control script, and authentication. Implemented separately, the copies drifted, security fixes included (macaw_compose#32–#34). These are implemented once, as host libraries in the same family:

| Package | Module | Holds | Depends on |
|---|---|---|---|
| **`macaw_plug`** | `Macaw.Plug` | the client address behind trusted proxies, rate limiting, security headers and CSP hashing | Plug |
| **`macaw_host`** | `Macaw.Host` | the literal `config.exs` on the data volume, generated secrets, release tasks, health, build info, and the `<app>-ctl` generator | OTP; `ecto_sql` optionally |
| **`macaw_auth`** | `Macaw.Auth` | authentication: a narrow contract (the current user, plugs and hooks, sessions and revocation) and its native backend (passwords, LDAP, sessions, throttling, TOTP) | `macaw_plug`, Plug, Phoenix, Phoenix LiveView and PubSub, Ecto (all required since #51); the password hasher, bcrypt or Argon2, is the host's choice |
| **`macaw_auth_ash`** | `Macaw.Auth.Ash` | the same contract over AshAuthentication, and the native LDAP source as an Ash strategy | `macaw_auth`, AshAuthentication |

**They sit outside the composition model.** `macaw_layers`, `macaw_data`, `macaw_compose` and `macaw_live` never depend on them, and an identity or access system stays a non-goal of composition (§3): the viewer still arrives from the host ([00](00-overview.md#overview-goals) goal 3), which may get it from `macaw_auth` through `Macaw.Auth.viewer/1`. A host uses any of them alone; they are released by git tag like the rest of the family.

**Boards are superseded.** A visualize board is a surface with a grid region: shared window and selection are state sources, virtual sources are derived sources, drill is a cell action ([06](06-pages.md)). Its runtime moves into `macaw_compose` and `macaw_live`; visualize keeps drawing visuals, with their printouts and output. visualize ships a board-to-surface migration behind its optional dependency (visualize#947).

### 4.1 How a Macaw library is built {#overview-library-rule}

Every Macaw library, the host libraries included, is built the same way, from its first commit (owner, 2026-10-27; #61). A new library starts with all of it:

1. **Its own spec**, in its own repository's `spec/`: complete, not a summary, each section naming the public functions it governs and carrying test hints. Sections that wait in this repository for a library not yet created move with it, anchors unchanged. Links between repositories' specs are full URLs, checked by `ci/spec_links.exs` (against a sibling checkout where present, by shape otherwise), which every repository's CI runs.
2. **surfex** as a hard CI gate (`mix surfex.status`), a dev/test-only dependency: code counts as implementing a spec unit only when a test for that unit failed and then passed against it, or a reviewed test passes. Code that predates a library's adoption is adopted by review (`mix surfex.validate` with a note).
3. **depdep** in CI as the only dependency cache, set up as visualize's is: `scripts/depdep.exs`, a pull before `mix deps.get` and a push after a green build, the store named by the DCOTek group's `DEPDEP_*` variables (never set per project), no runner `cache:`. A store that can't be reached degrades to a cold build, never a failed one.
4. **extla** models **only where they make sense**: the GenServers that manage state and its transitions, where correctness depends on message orderings no example test explores. Each model is checked in CI, and the running process checked against it. A library with no such process has no model; nothing else is modeled.

The rest of each repository follows the family's conventions: private on GitLab, fast-forward merges with a green pipeline required, released by git tag (Hex later, the owner's decision), CI on the DCOTek runner, format, compile with warnings as errors, tests and American spelling as gates. A library that depends on another by git tag is added to that library's CI job-token allowlist (by numeric project id).

## 5. Order of work {#overview-order}

**Macaw builds first what its adopters consume, in the order they consume it** (macaw_compose#28). visualize moves its generic core into `macaw_layers` and `macaw_data` once, and metresis migrates once, so neither is ever blocked on Macaw features no one uses yet.

1. **`macaw_data`: the interaction event** ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-event)). It unblocks visualize's Event v2 (visualize#941).
2. **`macaw_layers`: the document kernel** ([macaw_layers 01](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/01-kernel.md)): Document and its faults, names and term tagging, the map and JSON forms, the digest. visualize's planned extractions (#880, #893, #912) are closed there as superseded by this step.
3. **`macaw_data`: the data model** ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-data)): the columnar Table (from visualize#916), Schema, Delivery, units, quantities and facts. `Schema.to_json/1` and `from_json/1` are public, so no adopter reads a hidden function (visualize#879).
4. **`macaw_data`: the source contract and its conformance kit** ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md)), a strict superset of `Visualize.Feed`, with the budget fields and `reduced_by`.
5. **`macaw_data`: derived sources** ([macaw_data 02](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/02-derived.md)): the engine and sandbox, with `evaluate/4` (from visualize#881). **The sandbox's gates move with it** ([macaw_data 02](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/02-derived.md#derived-gates)); until `macaw_data` passes them, visualize keeps its own sandbox.
6. **`macaw_data`: transforms, table operations and aggregates** ([macaw_data 02](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/02-derived.md#derived-operations)). Transforms that need geometry stay in visualize.
7. **`macaw_layers`: themes** ([macaw_layers 04](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/04-themes.md)), with an extension point for visualize's chart theme roles; and the fragment machinery: Fragment, Use, Composite, Store and Bundle ([macaw_layers 02](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/02-fragments.md#documents-fragments), [macaw_layers 03](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/03-stores.md)).
8. **Only then, `macaw_compose` and `macaw_live`**, starting with what adopters use optionally: the mode context, the announcer, the component conformance kit (visualize#946), and surfaces with a grid region, the target of the board migration (visualize#947) and of metresis's dashboards (metresis#452). State, the page DAG, pages and templates follow.

**Each step is released before an adopter switches to it:** tagged in git, and depended on by tag. Until then the adopter keeps a field-identical interim definition, and switches by alias. Publishing to Hex is the owner's decision and comes later.

**An adopter published on Hex switches at Hex publication** (owner, 2026-10-27; #55). Hex refuses a package with a runtime git dependency, so visualize, which is on Hex, can't depend on a foundation by git tag without stopping its own releases. It keeps its field-identical interim definition until the foundation is published on Hex, and **checks it against the real one** through a dev/test-only git dependency (which Hex ignores, as it does visualize's extla dependency): a test asserts the two definitions' fields are identical, so they can't drift. Adopters not on Hex (metresis's server, macaw_server, the host libraries) switch at the git tag.

**Adoption:** visualize on `macaw_layers` and `macaw_data`, with its visuals implementing the component contract (visualize#939, #940); metresis on `macaw_data` and, for its dashboards, Macaw surfaces, migrating once from where it paused (metresis#556, #452); macaw_server on `macaw_compose` and `macaw_live` (macaw#130).

The CI dependency check (goal 6) and the example app (goal 7) are acceptance criteria of the first implementation proposal that ships code.

## 6. Status {#overview-status}

Implemented and tagged, each with its own spec, surfex and CI (#61):
- **`macaw_layers` v0.2.0:** the document kernel (step 2, #56), and themes with the fragment machinery (step 7, #94): fragments, compose, stack and `explain` over a type's declared rules, variables, use sites, masks and composites flattened at deployment; the store behavior, the memory store, typed ids and portable bundles imported as a relocation; colors with OKLab and color-vision simulation; and the theme, its color table, ramps, roles and style palette under their contracts and contrast floors, extensions registered default closed, the color profile, the theme document and its stylesheet of `--mw-` properties. Ids on object storage stay open ([#4](https://gitlab.conet.yarina.org/dco-tek/macaw_compose/-/issues/4));
- **`macaw_data` v0.5.0:** the interaction event (order-of-work step 1), the data model (step 3, #57), the source contract with its conformance kit (step 4, #58), derived sources with the sandbox and its gates (step 5, #82), and transforms, table operations and aggregates (step 6, #83): the transform and aggregate behaviors and the default-closed registry of enabled packages (macaw_compose spec/12 §1 builds on it), twelve table operations and thirteen statistics, `Macaw.Data.Ops` through which a stored function reaches them by literal name, and budget reducers by name. Geometry-needing transforms stay in visualize. Of the source contract, the behavior, description, request and parameters, finishing, push and the kit are built. Running sources on pages (pooling across pages, change notification, fetching off the caller) waits for the page runtime ([#108](https://gitlab.conet.yarina.org/dco-tek/macaw_compose/-/issues/108));
- **the host libraries:** `macaw_plug` v0.1.2, `macaw_host` v0.1.2, `macaw_auth` v0.4.0 and `macaw_auth_ash` v0.3.0.

The rest is spec, built in the order of work (§5). Decisions are recorded on macaw_compose#1 (the anchor), #2 (vocabulary), #3 (state), #8 (templates), #9 (writes), #10 (composition effects) and #22 (agreement with visualize; the analysis is [`design/visualize-alignment.md`](../design/visualize-alignment.md)). Open and deferred questions are in [14](14-open.md).
