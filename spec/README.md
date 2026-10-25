# composex specification

composex composes live, data-driven surfaces (dashboards, reports and pages) out of independent parts, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and composex runs the surfaces per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

It is the shared layer beneath **visualize** (charts and boards), **metresis** (measurements) and **dcotek_web** (sites).

**Status: draft.** This is the unified model from the 2026-10-25 design study across those three projects. Nothing here is implemented. The only settled decision is §14.6 (one theme system). Everything else is a proposal, to be shaped through Research issues and proposals in this project.

**Sources:** every claim about another project cites its requirement report in [`design/requirements/`](../design/requirements/) (`visualize.md`, `metresis.md`, `dcotek_web.md`, all following `TEMPLATE.md`), which cite that project's spec.

## 0. The finding in one paragraph

The three projects already agree on more than they differ. All three:
- describe data by typed field meanings, and version a schema by its content hash;
- report every fault with a path, and never make an atom from a document;
- keep credentials and bindings out of documents;
- treat errors as values.

Where they differ, it is because one project has met a case the others haven't:
- dcotek_web: the per-visitor **viewer** context, and replay of what one visitor saw;
- metresis: parameters whose legal values depend on type;
- visualize: sandboxed derived sources, contained failure, and drawn states.

So the unified model is not any one project's design. It is the union of what each has learned, organized around five ideas:

1. A **source** is anything a part reads. One contract serves feeds, queries, derived sources and *state*.
2. **Interaction is state, and state is a source.** A selection, a brush window, a set of chosen skills and a variable are all *state sources*: typed values owned by a scope and read like any other source. Wiring between parts is just binding a slot to a state source.
3. A **part** is a registered component placed in a **cell**. Its data inputs are typed **slots**. It declares everything the host must generate: settings, state, events, hooks, assets, observation, and its drawn states.
4. A **surface** is a board or a page: cells arranged in **regions**, where a region is a grid or a flow. A grid stacks into a flow below a breakpoint, which visualize already does.
5. A **record** is what makes a view reproducible: definitions by digest, data by delivery, and state by value, but **never the viewer**. visualize's board snapshot and dcotek_web's neutral page snapshot are two halves of it.

---

## 1. Sources

### What the three need

| Need | visualize | metresis | dcotek_web |
|---|---|---|---|
| Typed field meanings, version as a content hash | `Data.Schema` (current) | uses visualize's (current) | needs it for query parts |
| A time window | primary, not exclusive; boxes (current) | `from`/`to`; some sources have no window (thresholds) | mostly **not** temporal (projects, skills, fragments) |
| A budget in rows | derived from pixels, host ceiling (current) | never widens the window, never splits a bucket | needs a row limit for tables |
| **Parameters** | none (variables only reach virtual sources) | the query document: metric, aggregation, filters, `group_by`, limited to the **legal** set | named queries with schema-checked params, and token emphasis |
| **Viewer context** | none (`assigns:` for generators only) | the host's credential, per domain, scoped (#555) | capabilities per resource, capture level, site, share prefix, bot |
| A delivery that says what it served | `window`, `resolution`, `capped`, `reduced_by` (current) | the same, plus a coarsening note | the same, plus **provenance for replay** |
| Push | optional, schema first (current) | SSE, schema first (current) | not needed yet |
| Never blocks the caller | gap: a blocking fetch stalls the board (D-146) | — | first render blocks on it, so it must be bounded |
| Disclosure | — | — | what a source reveals, for the privacy note and D6 |

`Visualize.Feed` meets the first block of rows and none of the bold ones. A separate dcotek_web `DataSource` would meet the bold ones and lose the rest. Neither is the answer. The answer is one contract that is a strict superset of `Visualize.Feed`.

### The unified contract

```elixir
@callback describe(source, context) ::
  {:ok, %Description{
     schema:   Data.Schema,          # field meanings, content-hash version
     params:   ParamSchema,          # typed, with legal values (may depend on other params)
     supports: [:window | :box | :latest | :budget | :push],
     reveals:  Disclosure            # what a result tells about the viewer or the data
   }} | {:error, reason}

@callback fetch(source, %Request{
     params:  %{name => value},      # validated against ParamSchema before the call
     window:  nil | window | box,    # only meaningful when the schema has a window field
     budget:  nil | rows,
     viewer:  Viewer.t(),            # never stored, never in a document
     now:     instant                # given by the surface, never read by the source
   }) ::
  {:ok, %Delivery{
     table:   Data.Table,            # columnar (#916)
     schema:  version,
     served:  %{window, resolution, capped, reduced_by, params, note},
     origin:  %{source, request_digest, as_of}   # provenance for a record
   }} | {:error, reason}

@optional_callbacks subscribe: 2, unsubscribe: 2
```

- **A feed is a source with no params.** Every existing `Visualize.Feed` adapts with a one-line wrapper, and visualize keeps finishing whatever a source doesn't support (`supports`, D-140).
- **Parameters carry legality.** A `ParamSchema` uses the same type vocabulary as `Data.Schema` (time, number, category with declared values, text), so metresis's aggregation spine becomes declared values: `aggregation: category, values: legal(metric)`. A consumer can't ask for an ordinal mean, because the value isn't in the set. metresis's query document is the canonical example of a params value. dcotek_web's named queries are sources whose params are their arguments.
- **The viewer is an argument, not a setting.**
  - A source may refuse, filter or tease by it (dcotek_web's capability rules).
  - The library defines only the channel and one rule: a viewer is never written to a document, a delivery or a record (visualize C11/C12, dcotek_web D16).
  - metresis's per-domain credentials stay where they are. The host chooses which credential to fetch with, given the viewer.
- **`now` comes from the surface** (visualize C1), so the source stays deterministic.
- **The runtime fetches out of process with a liveness bound**, and never blocks the caller. This closes visualize's D-146 gap and bounds dcotek_web's first render.
- **`reveals` feeds observation.** dcotek_web generates its privacy note and enforces D6 from what each part and source declares.

---

## 2. State sources: interaction as data

This is the owner's idea, and the requirements support it directly.

**The nearest thing in each project:**
- **visualize:** variables already reach virtual sources and mark them for recompute. Selection and brush do not (they are board fields, spec/15 §13).
- **metresis:** dashboard variables fold into every panel's filters. The URL is the view.
- **dcotek_web:** gate states are per-visitor values that change rendering and are recorded per page view. Token emphasis is planned to seed highlights.

**The unified concept.** A **state source** is a source whose value is held by the runtime, not fetched from anywhere:

```elixir
state "skills", schema: [skill: {:category, values_from: "projects.tags"}],
                multi: true, max: 3,
                scope: :viewer,              # or :shared
                initial: {:token, :emphasis}, # or a literal, or {:param, name}
                persist: :host,              # the host decides: URL (metresis), session (dcotek_web)
                record: :full                # captured for replay at this level and above, else never
```

- **Written by parts through declared events** (the picker's `select`). **Read like any source**: a slot binds to it, and a derived source takes it as an input. That marks a recompute pulse exactly as a variable does today (visualize C2), so the deterministic pulse model holds.
- **Standard state sources replace special cases:**
  - `selection` (identity `{field, value}`, visualize C5);
  - `window` (the brush);
  - each **variable** (visualize's board vars, metresis's dashboard variables).

  They are the same thing with fixed schemas.
- **Scope** settles the open question in all three reports:
  - `:viewer` (per view process) is the default, because dcotek_web needs it and visualize's #620 wants it;
  - `:shared` (the surface process, all viewers) is for a wall display or a team board.
- **The host owns persistence** (`persist: :host`). metresis puts state in the URL. dcotek_web must not (design guide §3.3: no `?role=`), so it uses the token and the session. Generalizing `brush: :host` (D-161) to every state source covers both.
- **Initial values** can come from the token, which is dcotek_web's emphasis. With no socket, the initial value *is* the rendered state, so bots and black holes get a meaningful page (dcotek_web C2).
- **Recording** follows dcotek_web's gate-state pattern. A state change that alters what is shown is recorded per view at its declared level and applied at replay. At `basic` (anonymous) nothing finer than page level is recorded (D6).

**Example: skills → projects.** The picker writes `skills`. The project cards' `highlight` slot binds to `skills`. A table's `filter` param binds to `skills` too. A chart's `selection` state could drive the same cards. One mechanism, no special wiring.

---

## 3. Derived sources

visualize's virtual sources are the most developed part of any of the three projects, and the model adopts them whole:
- data, not functions;
- stored text checked against an allowlist and sandboxed;
- host `defsource` code trusted but bounded;
- cost counted in reductions, not time;
- no clock;
- scopes resolved from the inside out, with cycles named;
- pulses;
- conformance checked on output;
- fault details that never carry data values.

Two additions:
- **State sources are inputs** (§2). That is the only change to the engine's input list.
- **Database-level derivations stay in the source** (metresis C2): counter-reset-aware deltas, circular means, percentiles from raw rows. A derived source works on deliveries. It never re-aggregates what only the store can compute correctly ("a p95 of p95s is not a p95").

Open: metresis's shaping functions live in `Metresis.Dashboards.Sources`, so a remote host can't resolve them (metresis open question 1). Under this model they belong in a package both sides depend on: a part package (§4).

---

## 4. Parts, components and cells

**Placement vs implementation.** visualize already splits these: a **cell** is a placement, and a **component** is what it draws. The model keeps the split everywhere:
- a **cell** places one component in a region, with its settings and its slot bindings;
- a **component** is a registered module implementing the part contract.

**The part contract** is the union of the three reports' requirements. A component declares:

| Declares | Why (who needs it) |
|---|---|
| settings schema, which may depend on bound slot schemas (`legal_for`) | metresis's type-constrained settings; dcotek_web's validated manifests |
| **slots**: typed data inputs with `requires` contracts | visualize's slot concept, checkable before any data flows |
| state it writes (state sources) and events it emits | §2 wiring; dcotek_web's accepted-event rule |
| client hooks, as static assets served from `'self'` | dcotek_web's CSP; visualize's one-bundle rule |
| assets (CSS, images) | dcotek_web's self-contained snapshots |
| observation, in the host's closed vocabulary | dcotek_web's plan → script, CSP hash, note; D6 |
| **element ids**, stable and derived from content structure | dcotek_web's attention maps aggregate across builds |
| reading load for its sections | dcotek_web's reading-vs-skimming |
| a **neutral** render and a **socketless** render | dcotek_web's snapshots and plain HTML; visualize's server-first SVG |
| its **drawn states** | visualize's never-blank cell: crashed, down, invalid, over budget, loading, no data, stale, capped, live |
| capability required, if any | dcotek_web's gating per resource |

The kinds that fall out:
- **Chart:** settings are a visualize design (or a store ref).
- **Board:** a whole surface placed as a part.
- **HTML parts:** table, single stat (visualize #755, metresis #506).
- **Content parts:** Markdown fragment, project cards, timeline.
- **Interactive parts:** skill picker.
- **Embedded app:** dcotek_web #9's demo, a nested LiveView.

metresis ships its parts as a package (designs, defsources, and HTML parts) plus bundles. That answers its open question about remote virtual sources.

**Containment.** dcotek_web's page LiveView carries the visitor's observation, so a part crash must not take it down (dcotek_web C13). visualize's cell model already solves this: a heap-limited process per cell, restarted by its surface with a backoff, and drawn as `crashed` meanwhile. Pure parts (Markdown) render in process; parts with server work run as contained cells.

---

## 5. Surfaces, regions and layout

A visualize board, a metresis dashboard and a dcotek_web page are the same thing: **a surface** of cells arranged in regions, sharing state.

- A **region** is either:
  - a **grid** (12 columns, integer `x, y, w, h`, no overlaps, reading order `y, x, name`: visualize's and metresis's rules unchanged); or
  - a **flow** (an ordered list).
- **A grid stacks into its flow below the breakpoint, in reading order.** visualize already does exactly this (spec/15 §1.6), so flow is not a new layout system. It is the grid's own stacked form, used directly.
- A **page** is a flow of **sections**. A section has a heading, nests like headings, and holds cells or a nested region. That keeps dcotek_web's section tree, `s:` ids and reading order (dcotek_web C4).
- A dashboard on a page is a grid region inside a section. A grid region never contains another grid region, and drill is still the only surface-to-surface link (visualize C4).
- **State scopes follow structure:** surface, then region, then cell. Names resolve from the inside out, as virtual sources do.
- **Layout without inline style.** A 12-column grid has 12 starts and 12 spans, so column placement is 24 static classes. Rows are unbounded, so row placement needs a design decision: a bounded class set with flow fallback, or auto-placement by order. This is a visualize change, needed for dcotek_web's CSP (§9).

---

## 6. Documents

All three already follow the same policy:
- versioned, refusing a newer version by name;
- unknown keys refused by name;
- every fault reported as `{path, reason}`;
- pure forward migration;
- size limits checked before decoding;
- no atoms made from data.

The model makes it **one kernel** (visualize's planned `Visualize.Document`, #912) used by every document kind: designs, boards, page manifests, query documents, part settings, records. Each kind declares its own schema and version line. The kernel owns encoding, gate order, tags, digests and the fault format.

To settle: one stamp spelling (`$version` in visualize, `v` in metresis) and one canonical digest (`Document.digest`, replacing metresis's hashing of `Jason.encode!`).

---

## 7. Records: snapshots, replay and provenance

The word "snapshot" means three things today:
- **visualize:** a board's data frozen at one instant;
- **dcotek_web:** neutral page HTML, content-addressed, with per-view state applied at replay;
- **metresis:** nothing (results are rebuildable caches, and the URL reproduces the view).

They are parts of one thing. A **record** reproduces a view from three parts:

1. **Definitions, by digest.** Documents and fragment versions (exio object versions). dcotek_web's neutral HTML is a rendering cache of this part, keyed by its digest.
2. **Data, by delivery.** Each source delivery with its `origin` (visualize's board snapshot holds exactly this).
3. **State, by value.** The state sources' values over time, at their declared record level (dcotek_web's gate states are the first instance).

**Never the viewer.** Both visualize and dcotek_web already say this ("a snapshot records no viewer"; "per-request markup never forks a snapshot").

A metresis-style "the URL reproduces it" becomes a record with data omitted: re-query at replay, which is right for a store whose raw data is the record.

---

## 8. Stores and references

- **References are typed ids** (`{kind, id}`), resolved through a store behaviour with a context (visualize C8).
- **Names are attributes, not identities:** a route path, a slug or a title. visualize and metresis already hold this rule. dcotek_web's route path becomes an attribute of a page id.
- **Versions are digests**, or the store's object versions (exio).
- A missing reference masks its own site and is reported (visualize).
- Import re-keys atomically.

Open: visualize's ids come from per-kind sequences issued by the store, which is awkward on object storage. An exio-backed store may need ids derived from keys.

---

## 9. Rendering and the web

Every part must render on the server first and work without a socket, and that is already true of visualize charts and dcotek_web pages. The hard conflict is the **CSP**:
- dcotek_web: `script-src 'self' 'sha256-…'`, `style-src 'self'`, nothing inline;
- visualize today: inline `style=` (board grid, cells, roots, canvas layers), `<style>` elements in SVG (dark mode, motion), and `new Function` on the canvas `:js` path.

The model takes dcotek_web's policy as the rule for every part, because it is the strictest and the others can meet it. That means changes in visualize, and they benefit metresis as well:
- **Grid placement:** grid placement by class (§5).
- **Theme rules:** dark mode and motion as theme stylesheets keyed by theme name, not by chart id, served as static CSS.
- **Canvas:** remove the `:js` canvas path, which #913 starts.
- **Boards:** a board drawn in the first render from a pure realization (`Board.Snapshot.realize/4` exists), not a loading panel.

### 9a. Themes and styles: one system, delivered statically

*Added after draft 1. The requirements template had no concept for this, and it cuts across all three projects.*

**One theme system everywhere.** visualize's theme (a document with palettes, named whole styles and **roles**: good, warning, bad, info, neutral, selected, muted …) becomes the theme system of every surface, not just of charts:
- dcotek_web's brand tokens (`--ink`, `--paper`, `--accent`, light and dark) become a theme, so a chart on a page matches the page.
- metresis's verdict roles (§8.5) are the same roles.

**Components use roles and tokens, never literal colors.** That's metresis's rule ("a verdict is drawn in the theme's role color"), made general. Contrast (dcotek_web: 4.5:1 in both modes, muted text included) is then checked once, on the theme.

**Delivery under a strict CSP:**
- A theme compiles to **one static stylesheet** of custom properties per site (`Theme.stylesheet/1`, written at build time), with `prefers-color-scheme` for dark mode. It's served from `'self'` and snapshotted like any asset.
- Per-mark and per-datum styles resolve on the server into **SVG presentation attributes** (CSP doesn't govern them) or classes.
- Finite sets become classes: grid starts and spans, blend modes, named animations.
- Dynamic values are set by trusted hooks through CSSOM, which CSP allows.
- The rule: **finite set → class; per-datum → attribute; dynamic → trusted JS.**

**Changes:**
- **visualize:** emit theme CSS as a stylesheet rather than per-chart `<style>`; blend modes and animations as classes; presentation attributes in the CSS-variable mode.
- **dcotek_web:** its site CSS reads the theme's properties.
- **metresis:** map its UI framework's roles from the theme document.

---

## 10. Identity, capabilities and observation

- **The viewer** (§1) is the only channel from a host's identity model into sources and parts. visualize stays auth-agnostic. metresis's domains and tokens are the host's business when metresis is a source. dcotek_web's capabilities and capture levels ride on the viewer.
- **Observation stays the host's.**
  - Only dcotek_web observes viewers, and visualize and metresis record nothing about them (and must keep it that way, metresis C12).
  - Parts *declare* observation in the host's closed vocabulary, and the host generates code, acceptance and disclosure from the declarations.
  - **One event shape:** dcotek_web's `dw` clicks and `Visualize.Event` become one struct (part, element, name, identity, at), resolved on the server against the drawn frame and never carrying row values (visualize C5, metresis C5).

---

## 11. Vocabulary: one word, one meaning

Duplicate concepts become one concept. Distinct concepts that share a word get distinct words.

| Term | One meaning | Changes |
|---|---|---|
| **source** | anything a slot reads: §1 contract | metresis: collector "sources" are a different concept, so call them *collectors*; dcotek_web: drop the loose uses |
| **feed** | a source backed by a provider (fetch/push) | none |
| **state source** | runtime-held typed value, §2 | new; covers selection, window, variables |
| **virtual source** | a source computed from others, §3 | none (visualize's term) |
| **slot** | a part's typed data input | dcotek_web's template "slot" (`{:slot, :head}`) is a different concept: rename to *hole* |
| **binding** | slot → source, host-owned | metresis's "binding" code (family adapters) is different: rename |
| **component** | a registered part implementation | dcotek_web's trackable `data-dw` element becomes ***element***, matching its own `element_id` column |
| **cell** | a placement of a component in a region | metresis "panel" = cell plus its stored component, as metresis already maps it |
| **surface** | a board or a page | new umbrella. "Board" and "page" remain kinds of surface |
| **region** | a grid or a flow inside a surface | new |
| **section** | a headed flow unit of a page | dcotek_web's term, kept |
| **layout** | a surface's region arrangement | visualize's design-internal frame grid and graph layouts (#904) are different: *frame grid*, *graph layout* |
| **schema** | `Data.Schema` only | visualize #893 already renames `Chart.Schema` |
| **record** | definitions + data + state, never viewer, §7 | "snapshot" stays for visualize's board-data freeze; dcotek_web's neutral HTML becomes the *render cache* |
| **level** | — | dcotek_web: split into *capture level* and *access level* |
| **observer** | dcotek_web's optional tracking modules (hover, focus, copy …) | replaces dcotek_web's tracking "parts", freeing "part" |

---

## 12. Where it would live

Dependency direction decides it:
- metresis must not depend on dcotek_web;
- visualize must not depend on either;
- dcotek_web may depend on both.

The shared kernel is: the document kernel, the source contract, `Data.Table` and `Data.Schema`, state and derived engines, the part and surface contracts, the registry model, and records. It must sit below visualize.

visualize's planned `visualize_data` (#903: Data, Feed, VirtualSource, Unit, Quantity) is already most of it. The options are:
- (a) widen `visualize_data` into the kernel;
- (b) extract a neutrally named kernel package, which `visualize_data` becomes or depends on.

The LiveView runtime for surfaces (state process, contained cells, hooks) is `visualize_live`'s territory (#906), or its own package beside it. The owner's call, as the plan materializes.

---

## 13. What each project would change (draft)

**visualize**
- the source contract as a superset of `Feed`, with params, viewer, origin and reveals;
- state sources (selection, window and variables as standard ones), with `:viewer` scope;
- state sources as virtual-source inputs;
- flow regions;
- CSP-strict rendering: class placement, theme stylesheets, no `:js` canvas path;
- a pure first-render board;
- out-of-process fetch with a liveness bound;
- an explicit (default-closed) registry, not one derived from loaded modules (#886).

**metresis**
- a source adapter exposing the query document as params with legal values;
- its shaping functions and HTML parts in a part package;
- scoped read tokens (#555, filed);
- dashboard variables as state sources in bundles;
- rename collector "sources" and "binding" code.

**dcotek_web**
- composable pages as surfaces of sections and cells;
- the part contract with observation declarations;
- state sources with token-seeded initial values and level-capped recording;
- records extending the neutral snapshot;
- vocabulary: element, observer, capture level, access level, hole;
- the spec amendment for content as data in exio (the "not a CMS" non-goal).

---

## 14. Decisions for the owner

1. **The surface vocabulary:** surface, region, cell, component, part. Do these words work for you?
2. **State scope default:** `:viewer` (proposed) vs `:shared`.
3. **Where the kernel lives** (§12), when the plan is clear enough.
4. **Ids on object storage** (§8): key-derived ids for an exio store?
5. **Row placement under CSP** (§5): bounded classes or auto-placement?
6. ~~**One theme system** (§9a)~~ **Decided 2026-10-25:** visualize's theme document styles every surface, the site included.
7. **Order of work:** the kernel's source contract and document kernel first (everything depends on them), then state sources, then the part and surface contracts, then each project's adoption.
