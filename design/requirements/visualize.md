# Requirements: visualize

- **Project:** visualize (`~/Projects/visualize`), a server-side charting and dashboard library for Elixir and Phoenix LiveView.
- **Date:** 2026-10-25.
- **Sources read:**
  - spec/README.md, spec/01-goals-and-scope.md, spec/02-architecture.md (§1–§4), spec/11-public-api.md (whole).
  - spec/08-utilities.md §7.3 (theme resolution, dark mode) and §10–§12 (schema, version, cache, delivery, virtual sources §10.5.1–§10.5.10, feed behaviour, monitor, Combine, providers, conformance kit).
  - spec/10-liveview-integration.md §1, §4 (hooks bundle, sync bus, view states, motion), §7.2 (CanvasChart), §18 (BoardHook), §19 (Event, Components.Chart), §20 (MotionHook).
  - spec/14-declarative-chart.md §1–§2 (map, types, design node, sources, vars, interaction, budget), §3.13 (generators), §4.7, §7 (variables, slots, application, schema contract and facts), §9 (version, limits, theme document, atoms), §10 (validation, untrusted strings and URLs), §11.1, §12 (compilation), §19 (fragments, ids, use sites, composites, store, library), §21 (accessibility), §22 (board mode).
  - spec/15-boards.md (whole, §1–§14).
  - spec/13-decisions.md: D-146, D-151, D-170, D-194 (with its amendments) in full; the headings of D-135 to D-235.
  - Open proposals: #755 (Research), #879, #881, #882, #885, #886, #889, #893, #902, #903, #904, #905, #906, #907, #908, #909, #912, #913, #916, #918, #919, #936. Research issues #620, #531 and #425, searched for state ownership and selection.
  - Code spot checks, read-only: `lib/visualize/components/board.ex` (lines 148, 244, 400), `lib/visualize/components/chart.ex` (lines 409–443), `lib/visualize/hooks/canvas.ex:102`, and the CSSOM writes in `hooks/{motion,crosshair,tooltip}.ex`.

**Conventions.** "spec/15 §8.2" means the file and section. "#n" is a visualize issue. "D-n" is an entry in spec/13. The status tags are those of the template: **(current)** means built (spec status Implemented), **(planned: #n)** means only proposed, and **(implied)** means inferred by me.

---

## C1 Sources

### Requirements
- **MUST: a source is a typed slot named by the design. The design never holds rows or names a provider.**
  - Rationale: one design binds to any source with the declared fields, and the same board serves every host.
  - Cites: spec/14 §1.1 req. 2, §2.3, §7.2; spec/15 §1.1. (current)
- **MUST: a feed describes itself with a schema of field *meanings*. Each field has a `type` (`:time | :number | :category | :text | :color`), and the schema may give `unit` (UCUM), `quantity`, `label`, `order`, `status`, `polarity`, `target`, `continuity`, `window`, `metric_kind`, `bounds`, `identity` and `values`, which may carry names and colors. A schema never gives a drawing color.**
  - Rationale: facts belong to the feed, not to each design. Designs read them as `fact/3` and state `requires` contracts.
  - Cites: spec/08 §10.1; spec/14 §7.4; D-136, D-224. (current)
- **MUST: a schema's version is a content hash (SHA-256 of a canonical encoding). A delivery names the version and never carries the schema.**
  - Rationale: a version is a cheap cache key. A schema change is detected by one comparison and forces a recompile.
  - Cites: spec/08 §10.2–§10.4; spec/14 §12.1 (`Compiled.stale?/2`). (current)
- **MUST: the fetch contract is `describe/1 → {version, schema, supports}` and `fetch(feed, window, budget) → {:ok, %Delivery{}} | {:error, reason}`, with optional `subscribe/2` and `unsubscribe/2` for push. `supports` is a subset of `[:window, :region, :latest, :budget, :push]`, and every capability is optional.**
  - Rationale: the minimum feed just gives rows. visualize finishes a window, region, latest or budget that the feed did not honor.
  - Cites: spec/08 §11.1–§11.2; D-140. (current)
- **MUST: the time window is a primary but not exclusive axis.**
  - A board's window is UTC (`nil`, `%{last: s}` or `%{from, to}`), and the board resolves it against *its own* now.
  - The window applies only to feeds whose window field is `:time`. A feed whose window field is `:number` (ticks) keeps its own span.
  - A window may be a **box**: ranges over any `:time` or `:number` fields, plus `latest:` for each identity's newest row.
  - Rationale: dashboards are time-first, but scenes and maps ask for regions and current state.
  - Cites: spec/15 §1.5; spec/08 §10.1 ("the window field"), §11.1 (box), §11.2; D-154, D-168. (current)
- **MUST: "now" comes from the board, never from a feed or a cell.**
  - Rationale: one instant per turn keeps windows, staleness and cell ages consistent.
  - Cites: spec/15 §1.5, §8.2. (current)
- **MUST: a budget is a request in rows.**
  - The board derives a budget per slot from the cell's plot width and the types of its marks: lines and areas `4 × w`, bars `ceil(w/2)`, others `w`.
  - A design may override it (`n` or `{:per_px, k}`).
  - A host ceiling caps everything. A slot over the ceiling is handed **no rows** and enters the `{:over_budget, rows, ceiling}` state.
  - Each feed is fetched once, at the largest budget among its slots. Each slot is then reduced (LTTB/M4) to its own budget.
  - Rationale: only the library knows what a cell can draw, and no host should repeat it for each panel.
  - Cites: spec/15 §8.2; spec/14 §2.10; D-226, D-227. (current)
- **MUST: push sends the schema before the data.**
  - The subscribe handshake sends the present schema first.
  - A pushed delivery is an increment, merged by the window field. Late rows are kept, not dropped.
  - An unknown version falls back to `describe`.
  - Pushes between two ticks are coalesced into one merge. There is no other backpressure.
  - Cites: spec/08 §11.3, §11.4; spec/15 §8.5. (current)
- **MUST: errors are values. A feed that cannot answer returns `{:error, reason}` and never raises.**
  - Feed state is `:loading | :live | :stale | {:down, reason}`. A down feed's last delivery is still handed out.
  - Cites: spec/08 §11.1, §11.4. (current)
- **MUST: a delivery reports what it actually served.** Its fields are `window` (the span served), `resolution`, `capped`, `reduced_by` (`:feed` or `:visualize`) and `schema`. The conformance kit checks each of these.
  - Rationale: the cell states "capped" and "stale" and the honesty checks depend on these facts.
  - Cites: spec/08 §10.4, §12.3. (current)
- **MUST: identity is declared in the schema (`identity: true`, composite allowed), never guessed for anything that tracks entities over time.**
  - A row with no identity names nothing. `latest`, `per: :identity` virtual sources and selection all read the declared identity.
  - Cites: spec/08 §10.1 "Identity"; spec/14 §7.3 step 3 (`{:identity_required, source}`); D-167, D-168. (current)
- **MUST: a design can state a contract on a source (`requires`, fact reads, `reads` with a need per scale), and the contract is checkable before any data flows.**
  - `Board.Binding.check/3` and `check_types/3` report every fault: unbound, missing attribute, schema type, type mismatch, not required.
  - Cites: spec/15 §4.1–§4.3; spec/14 §7.4; D-153. (current)
- **MUST: a feed's provider and its binding are the connector's (the host's).** A binding never travels with a board or bundle.
  - Cites: spec/15 §1.1, §4.2, §11.1; D-141, D-147. (current)
- **MUST: live data and history can combine in one slot.** `Feed.Combine` routes by window, freshest first, and takes the first schema whole. The later schemas must be compatible and use the same window field.
  - Cites: spec/08 §11.5; D-159. (current)
- **MUST: a feed contract that hosts can test.** The conformance kit (`Visualize.Feed.Conformance`) ships in `lib/`, has no ExUnit runtime dependency, measures cost in reductions and treats a timeout as a liveness bound.
  - Rationale: "two hosts can't drift".
  - Cites: spec/08 §12; D-145, D-221. (current)
- **SHOULD: rows are columnar. `Visualize.Data.Table` becomes the currency of deliveries, feeds, virtual sources, transforms and marks. Row lists stay accepted at the edge.**
  - Rationale: garbage-collection cost of row maps (22 ms per frame vs 5.6 ms).
  - Cites: #916; #903 amendment. (planned: #916)
- **SHOULD: a feed author depends on a data-only package (`visualize_data`): Data, Feed, VirtualSource, Unit, Quantity.**
  - Cites: #903. (planned: #903)
- **SHOULD: a `:time` scale can take the board's resolved window as its domain (`domain: :window`).**
  - Cites: #936 (source: metresis #549). (planned: #936)

### Current mechanism
`Visualize.Feed` is a behaviour over structs. `Visualize.Feed.Monitor` is a *value*, not a process, held by the board process (or a LiveView). It describes, fetches, drains pushes, resolves versions and finishes each tick, then hands out one delivery per feed and a schema cache. `Visualize.Data.Schema.Cache` is also a value. The providers are `Feed.Signals` (pull, a numeric tick window field) and `Feed.Telemetry` (push, a `:time` window field). (spec/08 §11.4, §11.6.)

### Constraints a unified model must not break
- A design names slots, not feeds. A binding is separate host data and does not travel.
- Schema identity is a content hash computed identically on any node or release. The encoding is named `visualize.schema/1`, and a schema's version is pinned by a test (spec/08 §10.2).
- A window has no meaning without a declared window field, and a numeric window field is never mapped to instants by the library (D-154).
- The budget belongs to the library (derived from pixels), with a host ceiling. A source contract therefore has to accept a per-request row budget, and has to report `reduced_by` and `capped` honestly.
- Feed errors are values, and providers never raise. A blocking `fetch` delays the board's turn, which D-146 leaves to the feed contract to bound.
- "Now" belongs to the board, never to the feed.

---

## C2 Virtual and derived sources

### Requirements
- **MUST: a virtual source is data:**
  `%VirtualSource{id, from: [{name, window}], schema, elixir | function, per}`
  It contains no function value. It has map and JSON forms.
  - Rationale: it is stored in a board, travels in a bundle and is edited in the builder.
  - Cites: spec/08 §10.5.5, §10.5.10. (current)
- **MUST: a function is either:**
  - *stored* Elixir source text, which is untrusted, checked and sandboxed; or
  - a *host* `defsource` in a module the host registered, which is trusted but still bounded.

  It is never a mini-language of the library's own.
  - Cites: spec/08 §10.5, §10.5.8; D-194. (current)
- **MUST: a stored function passes a static checker before anything runs.** The checker requires:
  - Exactly one `fn`, of arity 1 (inputs) or 2 (inputs, context).
  - An explicit allowlist of `{module, function, arity}`. The allowed modules are `Enum`, `Map`, `Keyword`, `String`, `Integer`, `Float`, `:math` and `Visualize.Data`, plus control forms, math, data literals, interpolation and `to_string/1`.
  - Refusal of `send`, `receive`, `spawn`, `try`, `raise`, `apply`, `import`, `quote`, sigils, module attributes, struct literals, module atoms and `:__struct__`, dynamic calls, and non-literal `into:`.
  - Field reads limited to the input and output schemas' fields (`fields:`).
  - Literal variable reads limited to the scope's variables (`vars:`).
  - No atom creation: a static atoms encoder and a fixed pool of 256 variable atoms.
  - A source of at most 10,000 bytes.
  - Every fault reported as `{line, reason}`.
  - A test that fails when a new Elixir release adds an export that is not yet on the allowlist.
  - Cites: spec/08 §10.5.1–§10.5.2; D-194 (and its #769 and D-195 amendments). (current)
- **MUST: compile once and cache by SHA-256.** A function is compiled into an interpreted closure (`Code.eval_quoted/3`). No module is made per function. Refusals are cached too. Map reads are rewritten to `Sandbox.Runtime.get/2`, so an atom receiver can never call a module.
  - Cites: spec/08 §10.5.3. (current)
- **MUST: every call, stored or host, runs in a process of its own, bounded by:**
  - **reductions:** `100_000_000` by default, counted rather than timed, so the verdict does not depend on the host's load;
  - **liveness:** a timeout of `30_000` ms, which only catches calls blocked in `receive`;
  - **heap:** `10_000_000` words, with `kill: true` set at the spawn.

  The outcome is read from the process exit, never rescued. A `per: :identity` batch is one bounded call.
  - Cites: spec/08 §10.5.4; spec/15 §14.3, §14.6; D-220. (current)
- **MUST: six fault kinds:** `:restricted`, `:reductions`, `:hung`, `:memory`, `:raised` (the exception module only), `:nonconforming`. Fault details **never carry a row or context value**.
  - Cites: spec/08 §10.5.4, §10.5.6 ("Values never leave it"), §10.5.7. (current)
- **MUST: output conformance.** Rows must match the declared schema: types, declared `values`, identity present, and under `per` the same identity as the input. A nonconforming answer is a fault. The last good output stays.
  - Cites: spec/08 §10.5.7. (current)
- **MUST: inputs and their history.**
  - An input names a feed, another virtual source (short id resolved from the inside out, or a full path) or `{:feed, name}`.
  - Its window is `nil` (everything held), `%{last: n}` (per identity when identity is declared) or a box.
  - The function "gets what is there". v1 does not align inputs in time.
  - Cites: spec/08 §10.5.6. (current)
- **MUST: a context with no clock.**
  - A function of arity 2 is given `context["inputs"][key]` (the schema in wire form with string keys, plus the delivery's `window`, `resolution` and `capped`) and `context["vars"]` (the variable cascade at the source's scope).
  - Rationale: a source runs only when marked. A clock read would make its output depend on pulse timing.
  - Cites: spec/08 §10.5.6; D-228. (current)
- **MUST: scoping and resolution.**
  - A source is defined at a container: the board (path `[id]`) or a cell (`[cell, id]`). Lookup goes from the inside out, so a cell's source shadows the board's.
  - At board start the sources go through three steps: references, then named cycles (strongly connected components), then ranks.
  - A board whose sources fail any step is not started.
  - Cites: spec/08 §10.5.9; spec/15 §14.1. (current)
- **MUST: recompute in pulses.**
  - A changed feed delivery, or a change in the variables of a context-taking source's scope, *marks* the readers.
  - A pulse comes `debounce:` (250 ms) after the first mark, so all changes within that time collapse into one pulse.
  - A pulse runs in rank order, each source at most once. An unchanged answer does not propagate, so there are no glitches.
  - A source runs only when all its inputs are present.
  - Each call gets the whole current window, not the changes since the last run.
  - Cites: spec/15 §14.2. (current)
- **MUST: a virtual source is consumed exactly as a feed is.**
  - A binding names it the way it names a feed. The cell receives a delivery, a schema and a state (`:loading | :live | {:down, {:virtual_source, id, kind}}`).
  - Its output is reduced to the slot's own budget (`reduced_by: :visualize`). It is over budget only when it cannot be reduced and exceeds the ceiling.
  - Cites: spec/15 §14.5; D-230. (current)
- **MUST: joined fields.** Each row of a per-identity source's identity input carries `"<id>.<field>"` columns, taken from the source's last good output. They are described in the slot's schema, so styles, `:choose` marks, legends and coverage read them.
  - Cites: spec/15 §14.7. (current)
- **MUST: one evaluation engine for the runtime and the builder.** It is a *value*, `VirtualSource.Engine`, held by the board process. The builder runs the same engine over sample rows with `debounce: 0`.
  - Cites: spec/15 §14; spec/14 §22.9; D-194 (#750 amendment). (current)
- **SHOULD: a one-shot evaluation, `VirtualSource.evaluate/4`, for hosts outside a board.** metresis drives the engine step by step today.
  - Cites: #881, #885. (planned: #881)
- **SHOULD: one transform behaviour shared by charts, feeds (`reduce`) and virtual sources.**
  - Each transform declares `needs: []`, `[:frame]` or `[:projection]`, and reducers declare `reduces:`.
  - The registry is derived. The sandbox allowlist entries for transforms are generated from the registry.
  - Its data contract is a `Data.Table`.
  - Cites: #886 (amendments), #909, #916. (planned: #886, #909)

### Is interaction state already, or could it be, a source?
**Today it is not.**
- The board's selection is a value held by `Board.Server`. It is sent to each cell, and the cell adds a `$vis_state` column (`:selected` or `:muted`) to its own rows (spec/15 §13.2; D-151, D-171). Selection does not mark virtual sources, and no virtual source can read it.
- The brush window does not reach sources directly. It changes the board's window, which re-asks every feed (`Monitor.refetch/1`). The new deliveries then mark the virtual sources that read those feeds. A source sees the served window only as `context["inputs"][k]["window"]` (spec/15 §13.1; spec/08 §10.5.6).
- The nearest existing channel is the **variables**. A viewer's control calls `Server.vars/2` or `vars/3`. That marks the context-taking sources of the affected scope and re-runs them. The examples' "Bins over" buttons do this (spec/15 §5, §8.2, §10, §14.2; D-229).

**It could become a source.** These requirements follow for that:
- **MUST: the source would have to be shared state of the board process, as selection is today.** "Every viewer of one board process sees it" (spec/15 §13.2). A per-viewer selection source therefore implies a board per viewer, which is what hosts already do for `system:` and `assigns:` (spec/15 §8.2), or a new per-viewer layer. (implied)
- **MUST: it would have to fit the pulse model: mark, debounce, rank order, and no clock read.** A selection change would mark readers the way a variable change does (spec/15 §14.2). (implied)
- **MUST: the identity forms would have to be kept:** `{field, value}`, or a map for a composite identity, read through `links` (spec/15 §13.2). (implied)
- **SHOULD:** research #620 already separates **world** state (rows, host-owned), **local view** state (browser), **per-viewer view** state (server, per view process) and **animation** state, and says a host that wants per-viewer state shared applies it to every view (#620, "Four kinds of state"). A unified model should place selection and brush in one of those owners explicitly. (planned: #620, Research)

### Current mechanism
`Visualize.VirtualSource` is the value. `VirtualSource.Sandbox` provides the checker, the allowlist, compilation and the bounded runner. `VirtualSource.Engine` is the per-board value that holds outputs, schemas, status, faults and run counts. `use Visualize.VirtualSources` / `defsource` provide host functions, registered by module and by `config :visualize, virtual_sources:` (spec/08 §10.5; spec/15 §14).

### Constraints a unified model must not break
- No atom is ever made from stored source text, and a joined field name is a string (D-195).
- Stored text is untrusted. Host code is trusted but bounded. Both go through the same runner.
- Cost is counted in reductions, never by wall clock. The verdict must be identical on a loaded host (D-220).
- Fault details never include data values.
- The last good output survives a fault, and a fault does not propagate past the failed source.
- A source is deterministic and clock-free. The window it reads is the feed's.
- Sources are scoped to board or cell containers, resolve from the inside out, and are rejected at start when a cycle is found (the cycle is named).

---

## C3 Parts and components

### Requirements
- **MUST: the unit placed on a board (a *cell*) is a placement plus a component reference `{:composite, n}` to a store entry. A board holds no inline designs.**
  - Rationale: whatever a board shows lives in the store, where the builder edits it and a bundle carries it.
  - Cites: spec/15 §1.3; spec/14 §19.2. (current)
- **MUST: a component is a design, pure data with no functions.** Its parts are `version`, `meta`, `sources` (slots), `vars`, `theme`, `styles`, `defs`, `defaults`, `layout`, `interaction`, `budget`, `frames`, `marks` and `labels`. Every key has a type, a facet, a default and a merge rule declared in the schema (`Chart.Schema.keys/1`).
  - Rationale: storable, diffable, buildable by a tool, renderable against different data.
  - Cites: spec/14 §1.1–§1.5, §2.1. (current)
- **MUST: one cell is one chart applied, compiled and drawn independently.** A board never flattens cells into one coordinate space. A composite *within* a component does flatten.
  - Cites: spec/15 intro, §6; spec/14 §19.6. (current)
- **MUST: the component lifecycle is `flatten` (resolve through the store) → `components/3` (write the board's sync group and zone, narrow the variables) → `Chart.apply/2` (variables, then slots, then facts, then validation and frame realization) → `Chart.compile/2` (static/dynamic regions, a render target per mark) → `step/3` or `tick/3` per data change.** The steps differ in when they are needed:
  - A recompile is needed on a schema-version change, a resize, or a new chart or new variables. Easing, motion and warm layouts are `carry/2`'d across.
  - A data change alone is a `step/3`.
  - Cites: spec/15 §6, §8.3; spec/14 §7.3, §12.1–§12.5. (current)
- **MUST: a cell is always in exactly one drawn state:** `crashed`, `down`, `invalid`, `over_budget`, `loading`, `no_data`, `stale`, `capped` or `live`, taken in that precedence order. Each state has a theme role and a glyph, and the cell is never blank.
  - Cites: spec/15 §8.4; D-146. (current)
- **MUST: variables cascade cell → board → component default, by name, never renamed.** A cell may set only variables its component declares. A board variable that no component declares is not a fault.
  - Cites: spec/15 §5. (current)
- **MUST: another project can ship parts through:**
  - store entries (fragments, composites, themes, boards) carried in bundles;
  - generator modules (`use Visualize.Generators`, `defgenerator`) for styles and colors resolved at render from row and viewer context;
  - virtual-source modules (`defsource`).

  Host-compiled code is trusted. A design names a generator and never contains code.
  - Cites: spec/14 §3.13, §19.7; spec/08 §10.5.8; D-177. (current)
- **MUST: presets.** The LiveView chart components are stored preset designs plus an assign mapping, not separate renderers.
  - Cites: spec/10 §1.2; spec/14 §15. (current)
- **SHOULD: marks and frame kinds become behaviours.** Marks plan into roughly 6 primitives (polyline, area, rect, arc, symbol, path, text), and executors for each primitive are held by one conformance suite. A plan is data, versioned and serializable.
  - Cites: #887, #888, #919. (planned: #887, #888, #919)
- **SHOULD: packaging as sibling Mix projects released in lockstep.** The packages are `visualize` (core), `visualize_data`, `visualize_live`, `visualize_builder`, `visualize_layouts` and `visualize_geo`. A design that names a transform from an absent package gets a fault naming that package.
  - Cites: #902–#907, #886. (planned: #902–#907)
- **SHOULD: table and stat parts drawn by the browser.** A `:table` or `single_stat` cell would be an HTML table placed over a reserved box, outside the `role="img"` SVG. This is the owner's direction of 2026-10-19 for metresis#452's panels.
  - Cites: #755 (Research). (planned: #755, Research)

### Current mechanism
`%Visualize.Chart{}` is the design. `Chart.Composite` and `Chart.Use` handle composition. `Chart.Applied` and `Chart.Compiled` are the application and compilation results. `Board.Cell` is a GenServer per cell. `Board.View` is what a cell sends: svg, note, hook attributes, size and the `drawn` token. `Board.State` draws the states.

### Constraints a unified model must not break
- A component is a store id of kind `:composite`, never an inline design or a name.
- A design is function-free. Escape hatches are applied to the struct after reading and are never stored (spec/14 §1.1).
- An applied chart and a compiled chart hold data and closures. They have **no** map or JSON form (spec/14 §7.3, §12.1).
- A cell's name is its identity. It namespaces the cell's slots, keys its variables and sets its root id (`<board id>-<cell>-chart`) (spec/15 §1.3, §8.2; D-188).
- A cell that cannot join the board's sync group must say `sync: false`, or the board is a fault (spec/15 §1.5).

---

## C4 Composition and layout

### Requirements
- **MUST: a board is a 12-column grid.**
  - Each cell has `x`, `y`, `w` and `h` in grid units, with `x + w ≤ 12`.
  - No two cells share a square, and an overlap is reported once, at the later cell by name.
  - Rows are unbounded.
  - `columns` is not a key. Adding it later is planned to be additive, through a new version.
  - Rationale: 12 divides into halves, thirds, quarters and sixths. It is metresis's grid, so migration is mechanical.
  - Cites: spec/15 §1.3–§1.4, §3.1; D-141. (current)
- **MUST: pixels are computed like a CSS grid.** `layout` = `breakpoint` (768), `row_height` (80) and `gap` (8). A column is `(width − 11·gap)/12`. `boxes/2` gives each cell's pixel box, and that box is the `size:` its component is applied at, so a resize is a recompile.
  - Cites: spec/15 §1.6. (current)
- **MUST: responsive stacking in reading order.**
  - Below the breakpoint, cells are ordered by `y`, then `x`, then name, and stacked full width (`x: 0, w: 12`), each keeping its own `h`.
  - Nothing is hidden, reordered by size or dropped.
  - The same order drives keyboard navigation between cells, and print pagination (bands that are never split).
  - Cites: spec/15 §1.6, §9.3, §12.4. (current)
- **MUST: within a design, frames are placed by `box`, or by `cell` on the design's own `layout` grid of column and row weights with a gap. Frames render in `z` order, ties broken by name.**
  - Cites: spec/14 §2.8, §4.7. (current)
- **MUST: composition of fragments.**
  - `compose/2` is a union and `stack/1` is a cascade, each under per-key merge rules (`:concat`, `:union`, `:deep`, `:override`).
  - Use sites are resolved in the order `ref → local → mask → bind → stack`.
  - Composites nest, and a cycle is refused.
  - A composite placed under a key lands its frames as that key, and its marks are retargeted.
  - Cites: spec/14 §1.5, §8, §19.3–§19.6. (current)
- **MUST: a board is never composed into a chart and never a use site's `ref`. Boards do not nest. The only way from one board to another is a drill.**
  - Cites: spec/14 §22.1; spec/15 §13.3. (current)
- **SHOULD: author-constrained and nested layouts** for diagrams and scenes: ELK-shaped named tables in and out, nesting by parent identity, and stable relayout.
  - Cites: #886 amendment (#620), #919 amendment. (planned: #886, #620)

### Current mechanism
`Visualize.Board.arrange/2`, `boxes/2` and `layout/1` are pure. `Components.Board` renders a CSS grid with `grid-column` and `grid-row`, and adds the class `vis-board-stacked` below the breakpoint. The builder's board mode places cells through `BuilderHook` drags. The server is the authority on placement (`Boards.place/3` validates), and a new cell goes to the first free place in reading order (spec/15 §9.1; spec/14 §22.3).

### Constraints a unified model must not break
- The grid is fixed at 12 columns, in integer units, with no overlaps. Validation reports every fault, never just the first.
- Reading order (`y`, `x`, name) is total. It is shared by reflow, keyboard focus and print.
- The rectangle is metresis's (`x/y/w/h`). spec/15 §1.3 states that "a metresis panel becomes a cell mechanically".
- Layout stays separate from shared state: cells share state, never pixels.

---

## C5 Shared state, events and interaction between parts

### Requirements
- **MUST: `Board.Server` owns one copy of the shared state per board process:** now, window, zone, variables, sync group, selection, width, and `moved` (whether the window differs from the start).
  - Every viewer of that process sees the same window and selection.
  - Cells never talk to each other. A cell tells the board, and the board tells every cell.
  - Cites: spec/15 §8.2, §13 intro, §13.2; D-146, D-151. (current)
- **MUST: per-viewer state today means one board process per viewer.**
  - The demo runs one board per unit `system:`, starts one per `assigns:` viewer (tenants), and starts the detail board per visitor.
  - A board draws at one width. A second viewer at another width sees the same frames scaled by `viewBox`.
  - Cites: spec/15 §8.2 (`system:`, `assigns:`, resize paragraph), §10. (current)
- **MUST: browser-local view state stays on the client.** Hover and the brush band are shared between charts of a sync group over a DOM `CustomEvent` bus, carrying domain units (never pixels). A received hover never calls the server.
  - Cites: spec/10 §4.3; spec/14 §2.9. (current)
- **MUST: window semantics.**
  - A brush on any cell sets the board's window. It is validated at once, then debounced in the board process (250 ms, the latest brush wins).
  - Setting the window re-asks every feed, push feeds included, and every cell follows, including cells outside the sync group.
  - `window/2`, called from host buttons, is never debounced. `reset_window/1` restores the starting window.
  - A cleared brush (a click) changes nothing.
  - Cites: spec/15 §13.1, §8.2. (current)
- **MUST: a host may own the window instead (`brush: :host`).** The page receives the `:brush` event, puts the window in its URL and calls `window/2`.
  - Rationale: a link must reproduce the view, and the URL and the board must not drift apart.
  - Cites: spec/15 §9.2, §13.1; D-161. (current)
- **MUST: selection semantics.**
  - The identity is `{field, value}`, or a map for a composite identity. A map of one field is normalized to the pair.
  - Fields are read through `links`, which goes one step only.
  - A pick resolves `{series, index}` in the cell process to the typed row and its identity. Precedence: the declared identity, then the series channel, then the first `:category` field, then `nil`.
  - Highlighting is per datum through the style grammar: the `$vis_state` column and the palette's `:selected` and `:muted` styles. A cell that does not hold the selection is drawn byte for byte unchanged.
  - Escape and *Clear selection* clear it. A selection with no identity changes nothing.
  - The host may keep the selection in its URL, through the `:select` event and `select/2`.
  - Cites: spec/15 §13.2, §9.2; D-151, D-167, D-171. (current)
- **MUST: drill semantics.**
  - A drill target is stored data on the cell: `drill: %{board: :self | ref, vars: %{var => {:datum, field} | value}}`.
  - It is validated against the target board's declared variables. A runtime board whose drill cannot be met is not started.
  - A pick in a drill cell *drills instead of selecting*.
  - The library never navigates. The page receives `:drill` with `%{board, vars}` and decides what to open.
  - Cites: spec/15 §13.3, §9.2; D-151. (current)
- **MUST: every interaction reaching a host is one `%Visualize.Event{}`, sent as `{:visualize_event, id, event}`.**
  - Its fields are always present: `event`, `cell`, `frame`, `item`, `path`, `row`, `at`, `value` and `modifiers`.
  - Event names declared by a design are strings. Runtime events are atoms (`:drill`, `:brush`, `:select`), and the name `pick` is reserved.
  - A click is resolved on the server against the drawing token it landed on, or dropped. The client never invents a row or an event. Rows are typed.
  - Cites: spec/11 §5; spec/10 §19; D-170. (current)
- **MUST: variables are shared state a viewer may change (`vars/2` for the board, `vars/3` for one cell).** A change is validated against the store, prepares the cells again, recomputes budgets, and marks the context-taking virtual sources of the affected scopes.
  - Cites: spec/15 §8.2, §5; D-229. (current)
- **MUST: subscribers receive `{:visualize_board, pid, {:board, info} | {:cell, name, view}}`.** Cells send frames straight to subscribers, never through the board's mailbox. A late subscriber is sent every cell's present view.
  - Cites: spec/15 §8.2. (current)
- **SHOULD: name the four owners of state explicitly:** world (host rows), local view (browser), per-viewer view (server, per view process) and animation (visualize). Per-viewer state should be per viewer by default.
  - Cites: #620 (Research). (planned: #620)
- **SHOULD: a richer event vocabulary:** hover enter and leave, focus, context, multi-select and rubber band, drag, drop, keys. Raw pointer movement never reaches the server.
  - Cites: #620. (planned: #620)

### Current mechanism
`Board.Server` holds the state. `Components.Board` (a LiveComponent running in the page's process) turns hook pushes into calls on the server: `resize` → `resize/2`, `brush` → `brush/2`, `select_clear` → `select/2`, `pick` → `pick/4` then drill or select, `visualize_event` → `event/3`. It forwards board messages through `forward/2`. Hooks push to their component with `pushEventTo` (spec/15 §9.2).

### Constraints a unified model must not break
- Shared state has one owner, the board process, and selection and window are shared by every viewer of that process. Any per-viewer model must say where it sits relative to that owner.
- A host can always take ownership of the window and the selection, so URLs reproduce a view.
- The page decides navigation, and the library holds no routes.
- Clicks resolve against the token of the drawn frame. A stale click is dropped, never re-resolved.
- The window is debounced in the board, not on the client, because only the board sees every viewer's brushes.
- No atoms are made from client data (`Event.decode/1`), and a URL's `select` parameter is read only for known fields (spec/15 §10).

---

## C6 Documents

### Requirements
- **MUST: every document this library writes is stamped with one schema version.** `Chart.Migration.current/0` is 3. A map form carries `version`, and a JSON form carries `"$version"` at the top level. Boards and snapshots start at version 2, and the board shares the designs' version number.
  - Cites: spec/14 §9, §9.1; spec/15 §2.3. (current)
- **MUST: a newer document is refused by name (`{:newer_schema, needs, this}`) before anything else is read.** Neither the limits, the decoding of a key nor any cell comes first. A document with no stamp reads as the current version. Older documents migrate step by step, purely.
  - Cites: spec/14 §9.1; spec/15 §2.3; D-137. (current)
- **MUST: sanity limits, which the host may tighten.**
  - `depth` (64) and `items` (100,000) are checked before decoding. `ticks` (1,000), `iterations` (10,000) and `counts` (1,000,000) are checked after migration.
  - A fault has the shape `{path, {:limit, name, max, given}}`.
  - Cites: spec/14 §9.2. (current)
- **MUST: validation reports *every* fault as `{path, reason}`, ordered by path, worded by one formatter.** The roots are named `board`, `snapshot` and `virtual source`.
  - Cites: spec/14 §10.1; spec/15 §3; spec/08 §10.5.5. (current)
- **MUST: unknown keys are `:unknown_key` at their own spelling and stay strings.**
  - Cites: spec/14 §9.4; spec/15 §2.2. (current)
- **MUST: atom safety.**
  - Names a document declares are strings: cells, variables, links, virtual source ids, fields, frames, styles.
  - Keys are decoded against the schema's tables, and closed vocabularies are looked up.
  - `String.to_existing_atom` is never called on document data.
  - The `mix vis.atoms` gate enforces this.
  - Cites: spec/14 §1.4, §9.4; spec/15 §1.1; D-195. (current)
- **MUST: map and JSON forms are exact inverses for valid values:** `from_map(to_map(x)) == {:ok, x}` for boards, snapshots, bundles, fragments, themes and virtual sources.
  - Values JSON cannot express use one table of `$` tags, for example `$id`, `$time`, `$atom`, `$datum`, `$generate`, `$per_px` and `$absent`. An unknown or retired tag is refused at its path.
  - Cites: spec/14 §11.2; spec/15 §2.2, §12.3; D-182. (current)
- **MUST: a board document holds no binding and no feed.** A board validates *alone* (keys, types, placement, window, zone, variables, links, virtual-source shape, drill shape) and *given a store* (dangling refs, cycles, component validity, undeclared variables, sync).
  - Cites: spec/15 §1.1, §3.1–§3.2. (current)
- **MUST: untrusted strings are sanitized where read and escaped where written.**
  - Font family, class and animation names are checked.
  - URLs are checked by a host policy (https only by default, http optional, `data:` only for png, jpeg or webp, an optional host allowlist). A read may be stricter than this policy, never looser.
  - A fault never prints the URL.
  - Cites: spec/14 §10.3. (current)
- **SHOULD: the stored form is a native value.** `Visualize.Document.encode/1` produces a versioned map with string keys and tagged atoms, and `decode/2` validates and migrates it. `digest/1` gives a canonical fingerprint. JSON becomes one edge codec (`Visualize.JSON` on the stdlib `JSON`) and Jason is dropped. A `Codec` behaviour admits other formats (Mermaid, D2, design tokens).
  - Cites: #912, #893, #889, #879. (planned: #912)

### Current mechanism
`Chart.from_map/2`, `from_json/2` and `to_json/1`, and the same functions on `Board`, `Board.Snapshot`, `Fragment`, `Bundle` and `Chart.Theme`, all apply the same gates in the same order: version, then limits, then migration, then the count limits, then validation. Jason is an optional dependency (spec/14 §11.1).

### Constraints a unified model must not break
- The gate order is: refuse newer by name, then limits before decoding, then migrate, then validate.
- No atom is made from a document.
- Every fault is reported with a path, never just the first.
- One version number covers every document kind.
- The binding stays outside the document.
- Documents are values with no functions in them. Applied and compiled charts are not documents.

---

## C7 Snapshots, replay and provenance

### Requirements
- **MUST: `%Board.Snapshot{}` is a board frozen at one instant, as one value.**
  - It holds the version, the board, now, the resolved window, the width, the theme, and for each cell the prepared component, its variables, its slots (each `%{delivery, schema, status}` as last handed out) and any crash reason.
  - It reopens with no store, no feed and no process.
  - Cites: spec/15 §12.2; D-150. (current)
- **MUST: a snapshot's drawing is byte for byte the live cell's first frame for the same data.** The live cell and the snapshot go through the same steps. A snapshot may differ only by where an easing stood.
  - Cites: spec/15 §12.2. (current)
- **MUST: a snapshot records data, not context:** no generators, no assigns (the viewer) and no unit system. The reader supplies them at draw time (`views/2`, the export options).
  - Cites: spec/15 §12.2; D-156, D-181. (current)
- **MUST: a bundle carries definitions (re-keyed on import). A snapshot carries data (never imported, no ids).**
  - Cites: spec/15 §12.2 ("A bundle carries definitions; a snapshot carries data"). (current)
- **MUST: snapshot codecs.**
  - Rows are written column by column, so field-name spelling survives.
  - A field a schema types `:color` is written in color form.
  - Statuses are reduced to words.
  - The schema is written beside the rows.
  - The JSON round trip is exact.
  - Cites: spec/15 §12.3. (current)
- **MUST: exports derive from snapshots:** SVG (each cell's own SVG embedded unchanged), PNG (literal mode through resvg), paginated SVG pages and printable HTML (`@page`).
  - Cites: spec/15 §12.1, §12.4. (current)
- **MUST: provenance.**
  - A bundle records its source store, the export time (`exported_at`) and the schema version, and each entry keeps its original id.
  - `Use.origin` records the entry an unlocked site was copied from.
  - `explain/1` and `explain/2` attribute every leaf and every element's look to its layer (generators included).
  - Cites: spec/14 §19.3, §19.7, §17.3. (current)
- **MUST: a pure path to a snapshot without a running board:** `Board.Snapshot.realize/4` over a board, a store and pools.
  - Cites: spec/15 §12.2. (current)
- **SHOULD: replay as scrubbing a history window** ("the floor at 09:00"), using the same window a brush moves, with pause and step by row.
  - Cites: #620 (Research). (planned: #620)
- **SHOULD: a canonical `Document.digest/1`, so fingerprints do not depend on JSON key order.** metresis currently hashes `Jason.encode!`.
  - Cites: #912, #908. (planned: #912)

### Current mechanism
`Board.Server.snapshot/1` (a call to the board process, which already holds everything; cells are not called). `Board.Export.svg/2`, `png/2`, `pages/2` and `html/2`. `Server.export/3` draws with the board's own generators, assigns and unit system.

### Constraints a unified model must not break
- A snapshot is self-sufficient and draws exactly what the live cell drew.
- The viewer context (assigns, unit system) is never baked in.
- A snapshot carries no ids and needs no store.
- The bundle/snapshot distinction stays: definitions versus data.

---

## C8 Stores

### Requirements
- **MUST: a store is a behaviour with an explicit context:** `list(context)`, `get(id, context)`, `put(entry, context)`, `delete(id, context)` and `import(bundle, context)`. The host supplies it as `{module, context}`.
  - Rationale: the context says who is saving and from where, so entries are traceable (metresis #148).
  - Cites: spec/14 §19.7. (current)
- **MUST: ids are tagged with their kind (`{:style, 11}`, `{:composite, 5}`, `{:board, 3}`), issued by the store from per-kind sequences, never reused, and unique within a store.** A wrong-kind id is refused before resolution.
  - Cites: spec/14 §19.2, §19.7. (current)
- **MUST: a name is never an identity.** An entry's name and group (`group:sub:name`) are attributes that are free to change, and fragment bodies carry no names.
  - Cites: spec/14 §19.2, §19.8. (current)
- **MUST: a missing id is transparent.** It masks only its own site, rendering never fails, and the builder reports it.
  - Cites: spec/14 §19.2. (current)
- **MUST: import is a relocation.**
  - Every check runs before anything is put.
  - New ids are issued, and references are rewritten through one table mapping old ids to new.
  - The import commits whole or not at all.
  - A carried theme whose name collides with a different theme in the receiving store is `{:theme_taken, name}`.
  - Cites: spec/14 §19.7; spec/15 §11.2. (current)
- **MUST: export takes the transitive closure.** A board bundle carries the board, every component, their closure and the stored themes they name.
  - Cites: spec/15 §11.1. (current)
- **MUST: a fragment's kind is derived from its singular wrapper, never stored.** `design` is not a kind of library entry; it is the deployed tier, the output of `flatten`.
  - Cites: spec/14 §19.8. (current)
- **MUST: a host keeps boards where it likes.** The builder keeps them as `:board` entries (`%{board: map}`).
  - Cites: spec/15 §1.7; spec/14 §22.1. (current)
- **MUST: a binding is never stored in the board or the bundle.** The builder sends `{on_bind, id, board_id, binding}`, and the host keeps it.
  - Cites: spec/14 §22.8. (current)
- **SHOULD: Store and Bundle move out from behind the Phoenix guard and become `Visualize.Library.*`.**
  - Cites: #879, #893. (planned: #879, #893)

### Current mechanism
`Visualize.Chart.Builder.Store` is the behaviour. The examples use a `Store` over an `Agent`. `Bundle.export/3`, `export_board/3`, `import_board/3`, `to_json/1` and `from_json/2`. `Store.encode_id/1` and `decode_id/1` (which makes no atom from a client's kind). A theme is looked up by name (`Store.theme/2`).

### Constraints a unified model must not break
- Ids are kind-tagged, issued by the store and never reused. References are ids, never names.
- A missing reference masks rather than failing.
- Import re-keys and is atomic.
- Bindings live outside the store's documents.

---

## C9 Registries and extension

### Requirements
- **MUST: host extensions are registered *by module*, from the option given to the reader or runner and from `config :visualize, …`.**
  - A module that lacks the introspection function, or two modules defining the same name, raises `ArgumentError`.
  - Names in documents are strings, matched against the registry by spelling. An atom is never made from them.
  - Examples: generators (`__generators__/0`, by `{name, arity}`), virtual sources (`__virtual_sources__/0`, `[{name, arity, source}]`).
  - Cites: spec/14 §3.13; spec/08 §10.5.8. (current)
- **MUST: an unknown name is a validation fault at its path.**
  - Generators: `{:undeclared, :generator, name}` and `{:arity, …}`.
  - Virtual sources: `{:undeclared, :function, name}`.
  - Cites: spec/14 §10.1; spec/08 §10.5.5. (current)
- **MUST: one hook bundle.** `Visualize.Hooks.js_code/0` is one ES module the host writes into its assets (`install!/0`) and registers on its `LiveSocket`. There is no JS build step and no third-party JS library. No top-level object repeats a key.
  - Cites: spec/10 §4.1–§4.2; #913 ("no JS build step is a project promise"). (current)
- **SHOULD: a derived registry for transforms.** Core lists the loaded modules that declare the behaviour at boot. Outside the BEAM the registry is built from an explicit list. An unregistered name gives a fault naming the package that provides it.
  - Cites: #886, #918. (planned: #886)
- **SHOULD: the same pattern for aggregates, marks and frame kinds, and a hook registry that each package contributes to (`js_code(only: …)`, no hard-coded builder entry).**
  - Cites: #909, #888, #887, #906. (planned)
- **SHOULD: a public surface declared in a manifest of public modules per audience, gated both ways.**
  - Cites: #882, #885. (planned: #882)

### Current mechanism
`Visualize.Generators.registry`, `Visualize.VirtualSources.registry/1`. Transforms, marks and frame kinds are hard-coded in core (#886 counts six scattered tables). Hooks are a fixed list of 13.

### Constraints a unified model must not break
- No atom is created from a registry lookup key that came from a document.
- Host code is trusted, and stored text is sandboxed. The two kinds never mix silently.
- Registration needs no global mutable process; it is module-based and derived.
- The portable set (engines, planning, executors, `Data.Table`, `Document`) stays pure: no processes, ETS, NIFs or Regex (#918, planned).

---

## C10 Rendering targets and web constraints

### Requirements
- **MUST: server-first rendering.** A chart is complete SVG produced on the server and interpolated into HEEx (`Phoenix.HTML.Safe`). It "MUST be embeddable without any client-side library".
  - Cites: spec/01 §1.1; spec/02 §5. (current)
- **MUST: first render before the socket connects.**
  - A plain chart renders fully in the dead render.
  - A board component subscribes to `Board.Server` only once `connected?(socket)`. Until then each cell draws the `:loading` panel from the `theme` assign, under its own root id, and the grid is laid out at the `width` assign (default 1200) until `BoardHook` pushes the real width.
  - Cites: spec/15 §9.1–§9.2; `components/board.ex:148`. (current)
- **MUST: hooks are optional progressive enhancement.** Hover, crosshair, brush, keyboard, tooltip, motion, resize and canvas replay are hooks. Without them, SVG still draws. A canvas draws only through a hook; its text layer and summary are SVG and HTML.
  - Cites: spec/10 §1, §19.3; spec/14 §21.4. (current)
- **MUST: the CSP-relevant behavior below must be either preserved or given a CSP-safe alternative.**

  **(a) Inline `style=` attributes in server-rendered markup** need `style-src 'unsafe-inline'`, or `'unsafe-hashes'` plus hashes:
  - the responsive root: `style="width:100%;height:auto"` (spec/02 §2.1 `root/3`; spec/10 §1.2);
  - the component `animate`: `style="transition: all 0.3s ease-in-out;"` on every mark (spec/10 §1.2);
  - the `:blend` style: `style="mix-blend-mode: …"` (spec/02 §5.1);
  - the board grid: `style="display:grid;grid-template-columns:…;grid-auto-rows:…;gap:…"`, plus a per-cell placement `style={@placement}` for `grid-column` and `grid-row` (`components/board.ex:244, 400`; spec/15 §9.1);
  - the chart component's canvas layers: `position: relative; width…`, `display:block`, `position:absolute…` (`components/chart.ex:409–443`; spec/10 §19.3);
  - the Hybrid backend's HTML container (spec/09 §6).

  (current)

  **(b) `<style>` elements inside SVG** need `'unsafe-inline'` or a nonce. A hash is impractical, because the content is scoped to per-chart ids and hashed class names:
  - automatic dark mode, `Theme.color_scheme/2`, scoped to the root's id, in `:css` output (spec/14 §4.7; spec/08 §7.3; D-173, D-188);
  - motion: `.vis-transition-<h>`, `.vis-animation-<h>`, `.vis-enter-<h>`, `@keyframes`, and the reduced-motion `!important` rules (spec/14 §3.10–§3.12, §21.6);
  - the `animate` component's reduced-motion `<style>` (spec/10 §1.2);
  - the IR `:style` element (`IR.Element.stylesheet/1`, spec/02 §2.1);
  - the builder's stylesheet, rendered in a `<style>` by `Chart.Builder.styles/1` (spec/14 §18.13).

  **No option for a CSP nonce exists anywhere in the spec** (grep for "nonce" and "csp" over spec/ found nothing). (current; gap noted)

  **(c) `new Function('ctx', script)`.** `CanvasChart` evaluates the `data-script` `:js` output that `Visualize.Backend.Hybrid` emits, which requires `script-src 'unsafe-eval'` (spec/10 §7.2; `hooks/canvas.ex:102`). The `data-commands` JSON path and the binary path do not evaluate anything. (current)
  - #913 removes the JSON command format and moves toward the binary path. It does not explicitly remove the `:js` script path. (planned: #913)

  **(d) CSSOM writes from hooks** (`el.style.left = …` in the motion, crosshair and tooltip hooks) are DOM property sets. Under CSP3 I believe they are not blocked by `style-src` (implied; to verify). Motion's `wrap.style.animation` names keyframes that must exist in a stylesheet the CSP admits (`hooks/motion.ex:522`). (implied)

  **(e) The hook bundle** is one ES module served from the host's own assets, which suits `script-src 'self'`. It needs no inline script and no CDN (spec/10 §4.2). (current)
- **MUST: theming through CSS custom properties with literal fallbacks** (`var(--vis-axis, #666)`), so a standalone `.svg` or `<img>` still draws.
  - Theme switching is by an ancestor class (`.vis-theme-<name>` from `Theme.stylesheet/1`). A forced-colors block maps the furniture to system colors.
  - `:literal` mode is used for canvas and PNG.
  - Cites: spec/08 §7.3; D-55. (current)
- **MUST: static, socket-free rendering.**
  - `Render.to_svg_string/2`.
  - `Render.to_png/2` through the host's resvg binary over a port. It refuses `var(--` (`{:error, :css_references}`).
  - Board exports and printed pages from a snapshot.
  - Cites: spec/02 §4; spec/15 §12; spec/01 §1.7; D-121. (current)
- **MUST: accessibility by construction.**
  - The root is `role="img"`, named by `aria-label` (never a `<title>`), and described by a generated summary `<desc>`.
  - A hidden data table sits *beside* the SVG, never inside it.
  - Each chart and each board cell is one tab stop. Arrow keys move between points and cells, Enter goes in, Escape comes out.
  - `prefers-reduced-motion` is honored on the server (`motion: :reduce`) and in the browser.
  - Roles carry a glyph and a dash as well as a hue.
  - Cites: spec/14 §21; spec/15 §9.3; D-142, D-201. (current)
- **MUST: a payload budget per update.** Keyed segments mean a move sends only changed items, and hook-owned elements use `phx-update="ignore"`. The drawing is made in a sized process of its own, with a hard heap bound.
  - Cites: spec/10 §19.3; D-202–D-206, D-216. (current)
- **MUST: no Phoenix, Nx, Jason, `table` or `:telemetry` dependency is required.** All are optional, and the components compile only when Phoenix is present.
  - Cites: spec/01 §1.3–§1.6; spec/10 §1.1. (current)
- **SHOULD: binary transport to the hooks.** A library Phoenix Channel on the LiveView socket, authorized by a `Phoenix.Token` the LiveView signs, would carry packed columnar buffers. base64 inside `push_event` is the fallback. Bulk data stays out of DOM attributes.
  - Cites: #913, #906. (planned: #913)
- **SHOULD: the plan is the boundary where rendering may move to a client.** SVG stays on the server.
  - Cites: #889, #919, #425. (planned)

### Current mechanism
Backends: SVG, Canvas JSON and JS, CanvasBinary, Hybrid, CanvasIncremental. Render targets are chosen per mark: SVG up to 1,000 points, otherwise binary or canvas (spec/14 §12.3). The LiveView layer is `Components.Chart`, `Components.Board` and `Components.Board.Cell` (a LiveComponent per cell, so a frame's diff is that cell's alone).

### Constraints a unified model must not break
- A chart must work with no client JS.
- SVG is computed on the server.
- Theme custom properties carry literal fallbacks.
- A11y wiring: `role="img"`, `aria-label`, the data table outside the SVG.
- A board is never blank: it shows a loading panel before the socket connects.
- A unified CSP story must account for inline `style=`, `<style>` blocks scoped to ids, and `new Function` on the canvas script path. Today all three exist and no nonce is plumbed.

---

## C11 Identity, auth and capabilities

### Requirements
- **MUST: visualize does no authentication or authorization. The host decides.** The viewer reaches the rendering only as `assigns:`, which carries the viewer for generators and context, and as the unit system `system:`. A host whose generators read the viewer runs one board per viewer.
  - Cites: spec/14 §3.13; spec/15 §8.2. (current)
- **MUST: the store's `context` carries who is saving.**
  - Cites: spec/14 §19.7. (current)
- **MUST: the URL policy is the host application's configuration.** A read may tighten it, never loosen it.
  - Cites: spec/14 §10.3. (current)
- **MUST: nothing a client sends is trusted.**
  - A cell refuses a placement that overlaps or runs off the grid, whatever the client sent.
  - A click resolves only against the drawn token.
  - A feed name or variable name from the page is matched against known names and never made an atom.
  - Cites: spec/14 §22.3–§22.4, §22.8; D-170. (current)
- **SHOULD: the binary channel is authorized by a token the LiveView signs for its own session, and refuses a token from another session.**
  - Cites: #913. (planned: #913)
- (implied) There are no roles, scopes or visitor levels anywhere in visualize. Capabilities from another project would have to reach visualize through `assigns:`, through the choice of binding and feeds (the connector), or through which board a host starts for a viewer.

### Current mechanism
None of its own, beyond `assigns:`, the store context and the URL policy.

### Constraints a unified model must not break
- The library stays auth-agnostic. Viewer identity is host data passed in, never recorded in documents or snapshots (C7).

---

## C12 Privacy, tracking and observation

### Requirements
- **MUST: fault details never carry data values.**
  - Virtual-source faults carry the exception module, the row index and the field, but not the values. Context values are excluded too.
  - Cites: spec/08 §10.5.4, §10.5.6, §10.5.7; spec/15 §14.3. (current)
- **MUST: a URL is never printed in a fault, since it may carry a credential.**
  - Cites: spec/14 §10.3. (current)
- **MUST: a snapshot records no viewer.** Neither `assigns` nor `system` is stored.
  - Cites: spec/15 §12.2. (current)
- **MUST: board `info/1` exposes runtime state only:** cells, states, restarts, virtual-source states, faults and run counts. Subscribers are pids, monitored and dropped when they exit, and nothing about them is stored.
  - Cites: spec/15 §8.2, §14.6. (current)
- (implied) visualize records nothing about viewers. There is no tracking and no telemetry emission of its own. `Feed.Telemetry` only *consumes* the host's `:telemetry`. Any observation or tracking requirement would come from the other projects.

### Constraints a unified model must not break
- No data values in errors or logs from the sandbox.
- No viewer data in persisted values.

---

## C13 Isolation, limits and failure

### Requirements
- **MUST: one heap-limited process per cell.**
  - The limit is `max_heap_size` with `kill: true`, at `max_heap:` 25,000,000 words by default (200 MB).
  - The *board* restarts a dead cell with a backoff (100 ms, doubling to 10 s, reset after 30 s alive). The supervisor never restarts it, because a design that dies on every frame would exhaust any restart intensity.
  - The cell shows `{:crashed, reason}` at once, and the board and its siblings are unaffected.
  - Cites: spec/15 §8.3; D-146. (current)
- **MUST: a board starts whole or not at all.** A board with an invalid store, a missing feed or bad virtual sources is refused with every fault before any process runs.
  - Cites: spec/15 §8.2. (current)
- **MUST: bad data is a fault, not a crash.** A delivery its slot cannot read gives `{:invalid, errors}`: the last drawing is kept, the process keeps running, and the state clears on the next good delivery. A type mismatch is invalid, not a crash.
  - Cites: spec/15 §8.3–§8.4; spec/14 §12.5; D-232, D-153. (current)
- **MUST: coalescing.** A slow cell skips to the newest data and drops only its own frames. A `send` never blocks the board.
  - Cites: spec/15 §8.3. (current)
- **MUST: virtual-source limits (C2).** Reductions 100M, liveness 30 s, heap 10M words, source 10 kB. The last good output survives a fault.
  - Cites: spec/08 §10.5.4. (current)
- **MUST: document limits.** `depth`, `items`, `ticks`, `iterations` and `counts` are applied on every read.
  - Cites: spec/14 §9.2. (current)
- **MUST: a budget ceiling.** A slot over the ceiling is not drawn and is shown as `over_budget`. With no ceiling, the cell heap limit is the only defense.
  - Cites: spec/15 §8.2; D-227. (current)
- **MUST: the drawing process of `Components.Chart` has its heap sized from outside, with a hard bound of 512 MiB.** The process is killed at four times the bound, which takes down its LiveView, not the node.
  - Cites: spec/10 §19.3; D-216. (current)
- **MUST: the library starts no process of its own and has no application callback.** The host places `Board.Supervisor`.
  - Cites: spec/15 §8.1. (current)
- **MUST: no `try`/`rescue`/`catch` for control flow. Failures are values, or exits read by monitoring.**
  - Cites: spec/11 §4; D-194 ("Rejected: rescuing a raise"). (current)
- (implied) **Known gap:** feeds are fetched inside the board process, so a blocking `fetch` delays the whole board's turn. D-146 leaves this to the feed contract, and the conformance kit's liveness bound is the only check.

### Constraints a unified model must not break
- Containment is per cell and per sandbox call.
- A failed part is drawn deliberately (a role, a glyph, words), never blank.
- Restarts are owned by the board, with a backoff.
- Limits are counted (reductions, words), not timed, so verdicts do not depend on load.

---

## Vocabulary

| Term | Exact meaning in visualize | Cite |
|---|---|---|
| **board** | A dashboard as data: cells on a 12-column grid sharing a window, zone, variables, sync group, links and virtual sources. It never flattens. "Dashboard" is used informally for it. | spec/15 intro, §1 |
| **cell** | A board entry: a placement (`x,y,w,h`), a component ref `{:composite, n}`, a title, variables, sync, drill and virtual sources. Its name is its identity. | spec/15 §1.3 |
| **component** | What a cell draws: a store entry holding a composite or a flat design. | spec/15 §1.3 |
| **design** | The chart as a nested map: version, sources, vars, theme, styles, frames, marks, labels. Function-free. In the library it is the *deployed tier* (the output of `flatten`), not a kind of entry. | spec/14 §1, §19.8 |
| **fragment** | A reusable piece of a design, in a singular wrapper that names its kind (`%{style: …}`). | spec/14 §19.2 |
| **composite** | A fragment whose content is use sites plus vars (and defaults). Flattened at deployment. | spec/14 §19.6 |
| **use site (`Use`)** | A fragment used at a position: `id`, `ref`, `mask`, `vars`, `local`, `key`, `origin`. | spec/14 §19.3 |
| **library / library entry** | The store's entries, browsed by derived kind or by stored group. | spec/14 §19.8 |
| **store** | The host's implementation of the `Builder.Store` behaviour: kind-tagged ids and a context. | spec/14 §19.7 |
| **bundle** | Definitions plus provenance for moving between stores. Re-keyed on import. May carry one board. | spec/14 §19.7; spec/15 §11 |
| **snapshot** | A board and its data frozen at one instant. Needs no store, feed or process. | spec/15 §12.2 |
| **binding** | `{cell, slot} → feed`. The connector's; it never travels. | spec/15 §4.2 |
| **connector** | The host software that knows its feeds and supplies the binding (metresis, Exio). | spec/15 §1.1 |
| **provider** | The feed implementation behind a binding. The board never sees it. | spec/15 §1.1 |
| **feed** | A struct whose module implements `Visualize.Feed`: describe, fetch, and optionally subscribe. In bindings and pools, "feed" also means *any term naming* a feed or pool entry. | spec/08 §11.1; spec/15 §4.2 |
| **source** | (1) In a design: a typed **slot** (`sources: %{name => %{fields, types, default, requires}}`). (2) Loosely: anything `Data.Table.rows/1` reads (rows, column map, tensor, delivery). | spec/14 §2.3, §7.2 |
| **slot** | A design's source declaration, namespaced on a board as `{cell, slot}`. | spec/14 §7.2; spec/15 §4.1 |
| **pool** | A map from name to source given to `apply/2`. A slot binds by its own name, else by its `default`. | spec/14 §7.2–§7.3 |
| **delivery** | One answer of a feed: rows plus `window`, `resolution`, `capped`, `reduced_by` and schema version. | spec/08 §10.4 |
| **schema** | (1) `Data.Schema`: a feed's field descriptions plus a content-hash version plus identity. (2) `Chart.Schema`: the design's key table. #893 renames (2). | spec/08 §10.1; spec/14 §1.3 |
| **version** | (1) A schema's SHA-256 content hash. (2) A document's schema version (`current/0` = 3). | spec/08 §10.2; spec/14 §9 |
| **contract / requires / fact** | The attributes a slot needs from a schema, and `fact(slot, field, key)`, a read of one attribute. | spec/14 §7.4 |
| **virtual source** | A source computed from other sources by a checked function. Defined at the board or a cell. | spec/08 §10.5 |
| **engine** | The value that defines, marks and runs virtual sources for one board. | spec/15 §14 |
| **pulse** | The unit of recompute for virtual sources. | spec/15 §14.2 |
| **path / scope** | A virtual source's address (`[id]` or `[cell, id]`) and the container a name is resolved from. | spec/08 §10.5.9 |
| **window** | The board's span of instants (UTC), and a feed request (`nil`, `[from, to]` or a box). | spec/15 §1.5; spec/08 §11.1 |
| **window field** | The schema field windows are over (`window: true`, or the single `:time` field). | spec/08 §10.1 |
| **box** | A window over ranges of any `:time` or `:number` fields, with `latest`. | spec/08 §11.1; D-168 |
| **budget / ceiling** | Rows asked for a slot (derived or declared), and the host's hard cap on any slot. | spec/15 §8.2; spec/14 §2.10 |
| **monitor** | The value that runs the feed loop, owned by the board process. | spec/08 §11.4 |
| **sync group** | Charts that share hover and the brush band on the client bus. | spec/14 §2.9; spec/10 §4.3 |
| **brush** | A dragged x range. It becomes the board's window, or a `:brush` event under `brush: :host`. | spec/15 §13.1 |
| **selection** | The board's single `{field, value}` or composite-map identity, drawn as `:selected` and `:muted`. | spec/15 §13.2 |
| **links** | Board map of fields with different names that mean the same thing. One step. | spec/15 §13.2 |
| **identity** | The schema-declared fields naming the entity a row is about. | spec/08 §10.1; D-167 |
| **pick** | Resolving a keyboard point `{series, index}` to its row and identity in the cell process. | spec/15 §13.2 |
| **drill** | A cell's stored target board and variables. The page follows it. | spec/15 §13.3 |
| **event** | `%Visualize.Event{}`, the one interaction shape. | spec/11 §5; spec/10 §19 |
| **view** | `%Board.View{}`: a cell's frame, state drawing, hook attributes, size and drawn token. | spec/15 §8.3 |
| **state (cell state)** | One of crashed, down, invalid, over_budget, loading, no_data, stale, capped, live. | spec/15 §8.4 |
| **panel** | In visualize, the *whole-cell drawing of a state* (`State.render/3`), or the builder's UI panels. In metresis, a panel is what becomes a cell. | spec/15 §8.4, §1.3 |
| **frame** | A coordinate system with its furniture (size, margin, scales, axes, legend), by name inside a design. | spec/14 §4 |
| **mark** | A data-drawing node (line, area, rect, …, `:choose`). | spec/14 §5 |
| **layout** | **Overloaded:** (1) a board's `layout` (breakpoint, row_height, gap); (2) a design's `layout` grid of weights; (3) hierarchy and network layouts (tree, force, …) as transforms. | spec/15 §1.6; spec/14 §2.8; #904 |
| **theme / style / palette** | Visual constants as slots; per-mark presentation in parts; the theme's named whole styles (hover, selected, muted, roles). | spec/14 §2.5–§3; spec/08 §7 |
| **generator** | A host function a design calls by name, resolved at render, for styles or colors. | spec/14 §3.13 |
| **variable (`Var`)** | A named term with a declared default, resolved at application, one level only. | spec/14 §7.1 |
| **applied / compiled / drawing** | A design plus bound data (`Chart.Applied`); a per-frame compiled form with static and dynamic regions (`Chart.Compiled`); the rendered output. | spec/14 §7.3, §12; #889 |
| **plan / table / primitive** | Planned vocabulary: a data-independent compiled program; columnar data; what a plan draws. | #889, #916, #919 |
| **catalog** | Builder-only: feed → schema map the host offers for binding. | spec/14 §22.8 |
| **flatten / deploy** | Resolve a composite through the store into a flat design. | spec/14 §19.6 |
| **kind** | A fragment's derived type (style, theme, frame, composite, board, …), also the tag of an id. | spec/14 §19.8 |
| **manifest** | Planned: the public-module list per package. Not a document kind. | #882 |

## Open questions found

1. **Per-viewer versus shared board state.** Window, selection, variables and width are per *board process* and shared by all its viewers (spec/15 §8.2, §13.2). Per-viewer behavior is achieved by running one board per viewer, per unit system or per assigns. #620 proposes per-viewer view state by default. Which applies in a unified model, and at what cost in processes and feed fetches? Feeds are fetched per board process.
2. **Interaction state as a source.** Selection is not readable by virtual sources, and the brush window reaches them only through re-fetched deliveries. Should selection, a brush and chosen items become inputs to the virtual-source graph? If so, are they owned by the board (shared) or per viewer, and do they mark pulses the way variables do?
3. **Drill targets name boards by "the host's name", not by a store id**, yet boards *are* `:board` store entries with `{:board, n}` ids (spec/15 §13.3 versus spec/14 §22.1). A unified store/reference model would have to reconcile these.
4. **No CSP nonce plumbing.** The SVG `<style>` blocks (dark mode, motion), the inline `style=` on the board grid, cells, canvas layers and responsive roots, and `new Function` on the canvas `:js` path all assume a permissive CSP. Is `'unsafe-inline'` or `'unsafe-eval'` acceptable to the other projects (dcotek_web)? Does the `:js` canvas output survive #913?
5. **The binding has no home in visualize.** It is sent to the host as `{on_bind, …}` and never stored. A unified model must say where bindings live, and whether a binding can name virtual sources across projects.
6. **A blocking feed blocks the board's turn** (D-146 consequence). Should a unified source contract mandate non-blocking or out-of-process fetch?
7. **Row maps versus columnar `Data.Table`** (#916). Any unified source or delivery contract set now risks a second breaking change if it fixes row lists.
8. **The 12-column grid is fixed and boards don't nest.** Do metresis pages and dcotek_web layouts need regions, nesting or flow layout that a board cannot express? `columns` is described as a future additive key (spec/15 §1.4).
9. **"Layout", "schema", "source" and "panel" are overloaded** within visualize itself (see Vocabulary). Unified names must avoid colliding with them.
10. **The time-scale domain from the window** (#936) and **tables and stats as browser-laid parts** (#755) are open dependencies of metresis on visualize that shape what a "part" must support.
11. **The virtual-source context has no clock**, and inputs are not time-aligned (v1). A unified derived-source model that needs "now", or joins by time, would conflict with the current deterministic pulse model.
