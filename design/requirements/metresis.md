# Requirements: metresis

- **Project:** metresis (`~/Projects/metresis`), a measurement store with an API and a reporting UI.
- **Date:** 2026-10-25
- **Sources read:**
  - `spec.md`: §0–§1, §2.1 (#log-store, #public-url, #http-1), §2.2 (by reference), §3.1–§3.3, §4.1–§4.10, §5 (dashboards, dashboard_variables, panels, panel_templates, events, rollups, referential rules), §6.1, §6.4, §6.5, §7 preamble, §7.1–§7.13, §8.1–§8.7, §9.1–§9.6, §10.1–§10.2, §11.1–§11.3, §12.1–§12.3, §14.
  - `lib/`:
    - `lib/metresis/query/document.ex`
    - `lib/metresis/dashboards/{board,bundle,cell_sources,sources,dashboard_variable}.ex`
    - `lib/metresis_web/router.ex`
    - `config/config.exs:113`
  - `clients/metresis_client` (module list, `feed.ex`, `mix.exs`).
  - Issues:
    - #555, #549, #553, #452 (with comments), #480 (with comments), #506, #507 (with comment), #547, #548, #536 and the open-issue list;
    - visualize#908.
- **How to read the tags:** MUST/SHOULD is the strength. "(current)" means built and specified. "(planned: #n)" means proposed or accepted but not built. "(implied)" means my inference from the spec or the code.

---

## C1 Sources

### Requirements
- **MUST:** a source is a *query document*. It carries the metrics, a window, label filters, a `group_by` over dimension keys, an aggregation, a resolution and a limit. It is not an arbitrary fetch.
  - Rationale: "a feed **is** a query", so the API, the dashboard and the feed cannot drift.
  - Cite: §7.6, §7.12, §8.1, `Metresis.Query.Document`. (current)
- **MUST:** the aggregation a source may ask for is limited to the metric's legal set, `legal = allowed(type) ∩ allowed(quantity) ∩ override`, and any illegal one is refused. A unified source model must not let a consumer ask for an aggregation the type forbids (an ordinal `mean`, a cyclic arithmetic `mean`, a counter `sum`).
  - Rationale: "an ordinal mean is not a mistake you are trusted to avoid; it is a thing the UI cannot express."
  - Cite: §1.3, §4.2, §4.3, §4.4. (current)
- **MUST:** typed values. A source's `value` field is typed by the **aggregation and the metric together**:
  - a number in the metric's unit or quantity, with its bounds, its polarity and its `continuity` (the gap threshold);
  - a count (unit `1`);
  - a rate (unit per second);
  - a ratio from 0 to 1;
  - a duration in seconds;
  - a category of states with `order` and `status`;
  - a flag category ordered `false`, `true`.
  - Plus `metric_kind` (`rate` | `counter` | `gauge`).
  - Rationale: the axis measure is the aggregation's answer, not the metric's unit.
  - Cite: §7.12 #feed-schema table, §8.1 #axis-measure. (current)
- **MUST:** the schema is described in visualize's `Visualize.Data.Schema` vocabulary. Units are UCUM codes and quantities come from visualize's list, with no second vocabulary.
  - Rationale: "a chart, a feed and a front end read one vocabulary and nothing translates between two."
  - Cite: §4.4, §7.12. (current)
- **MUST:** a schema has a **version that is its content hash**, so a change to a name, a unit, a state's status, name or colour is a new version.
  - A client that rebuilds a schema whose version differs from the one sent must treat that as an error.
  - A push must send the new schema before any rows made under it.
  - Cite: §7.12 #feed-schema, #feed-push, §7.10 #client-feed. (current)
- **MUST:** a time-windowed pull takes `from`/`to` (an open end runs to now) or a box window by its `t` range.
  - A delivery reports the **window served, the resolution, `capped`, `reduced_by` and the schema version**.
  - Cite: §7.10 #client-feed, §7.12. (current)
- **MUST:** some sources have **no window field**. The thresholds feed holds across the whole window and `supports: []`. A unified source model must allow window-less, budget-less, push-less sources.
  - Cite: §7.12 #feed-thresholds. (current)
- **MUST:** budget semantics.
  - Resolution is chosen first (`auto` picks the finest bucket that fits). A budget never widens the window.
  - Map-valued aggregations are thinned by **whole buckets, never by keys**. If one bucket alone exceeds the budget, nothing is delivered.
  - Raw rows are never thinned (they are capped at `max_marks`, 5,000).
  - Rationale: "a part of a distribution is not a smaller one."
  - Cite: §7.12 #feed-budget, §7.12 raw, §8.1 #chart-marks. (current)
- **MUST:** a percentile is never re-aggregated across buckets ("a p95 of p95s is not a p95"). A source must be able to fall back to raw or a coarser bucket and say so.
  - Cite: §6.4, §8.1. (current)
- **MUST:** sources come in three resolutions:
  - bucketed (`auto` or a named bucket);
  - `raw`: one row per sample, carrying `series` as the label set's content hash, so two raw feeds can pair samples;
  - `whole`: map-valued aggregations summed across the window, one row per key per series, with `resolution: window`.
  - Cite: §7.12. (current)
- **MUST:** push is optional and declared in `supports`.
  - `/feed/stream` is SSE: the schema first, then the rows new since the last delivery, and the first delivery includes rows since *before* the schema was sent.
  - Whole feeds do not push ("a new total is not an increment of the last").
  - Cite: §7.12 #feed-push. (current)
- **MUST:** events are a source of their own. The rows are `{t, ends_at, kind, title, id}`, with `id` declared as the row's **identity** so a click resolves to the event. They are filtered by the panel's query filters and `kinds[]`, and an unlabelled event overlays everything.
  - Cite: §4.10, §7.12 #feed-events. (current)
- **MUST:** thresholds are a source.
  - The rows are `{value, label, status, id}`, where `status` is `bad` while firing and `neutral` otherwise.
  - A rule is matched by metric, **same aggregation**, and the panel's filters or a superset of them.
  - Cite: §7.12 #feed-thresholds. (current)
- **MUST:** dimension vs annotation labels.
  - `group_by` accepts only `dimension` keys. Filters accept both roles.
  - The role is presentation only: both are equally queryable.
  - A `group_by` key that is not a dimension in one of the domains read is an error naming that domain.
  - Cite: §4.6, §7.6. (current)
- **MUST:** a field name that collides with a reserved one (`t`, `value`, `state`, `sector`, `series`) is renamed `label:<key>`.
  - Cite: §7.12 #feed-schema. (current)
- **MUST:** time is `occurred_at` for every chart, window and rollup. `received_at` is kept for provenance and for absence alerts.
  - Cite: §4.8, §9.3. (current)
- **MUST:** absence is not zero. No source may fill a gap with 0.
  - Gaps are expressed by placing a no-value row in every silence longer than the larger of the gap threshold and the bucket.
  - Cite: §1.3, §4.9. (current)
- **MUST:** errors come back as data, not raises. A server error is `{"errors": [{path, error}]}` naming **every** fault. A client answers `{:ok, _} | {:error, _}` and never raises.
  - Cite: §7 preamble, §7.1, §7.10. (current)
- **MUST:** a feed is **one metric**. A document naming more is refused with 422. A multi-metric panel becomes one feed per metric (`m1`, `m2`, …).
  - Cite: §7.12, §8.3 #dashboard-board. (current)
- **SHOULD:** cross-domain references `<slug>/<key>` resolve for a signed-in viewer, but **never for a token**. A token reads through a resolver that knows no other domain.
  - Cite: §7.6. (current)
- **SHOULD:** a query reaching past raw retention says so (`pruned_before`) and falls back to rollups.
  - Cite: #547. (planned: #547)

### Current mechanism
`Metresis.Query.Document` (versioned, validated) is run by `Metresis.Query.Plan`. `Metresis.Feed` shapes the rows and `Metresis.Feed.Schema` builds the schema from the catalog. These are served at `/feed`, `/feed/schema`, `/feed/stream`, `/feed/events*` and `/feed/thresholds*`. Remotely, `Metresis.Client.Feed`, `EventFeed` and `ThresholdFeed` implement `Visualize.Feed` and pass visualize's conformance kit (§7.10).

### Constraints a unified model must not break
- The aggregation legality spine: no consumer-chosen aggregation outside `legal(metric)`.
- The schema version is a content hash, and is announced before the rows it governs.
- The budget never widens the window and never splits a bucket's keys.
- One metric per feed (or a model that keeps per-field typing equally strict).
- Window-less sources exist.

---

## C2 Virtual / derived sources

### Requirements
- **MUST:** a cell's shaping (stacking, gap breaks, markers, the percentile band, state blocks, bins, heatmap cells, scatter pairs, rose sectors, the compass needle) runs as **virtual sources**. These are checked Elixir functions over the cell's feeds, rows in and rows out. They travel with the board, so a remote host draws what metresis draws.
  - Cite: §8.3 #dashboard-board, #452 (comment 2026-10-19), #501–#505. (current for every moved family)
- **MUST:** a virtual source can read its **context**: its inputs' schemas, their deliveries' facts (the window served, the resolution), and the cell's variables.
  - Rationale: the distribution family needs the bin domain and the served window.
  - Cite: §8.3 (visualize 0.8's two-argument function, #505). (current)
- **MUST:** feeds are named once per board as `<cell>.<input>`, and sources read them as `{:feed, name}`, which no other source can shadow.
  - Cite: `CellSources.feed_name/2`, §8.3. (current)
- **MUST:** a source's output declares a typed schema (`x0/x1: time`, `fill: text`, and so on).
  - Cite: `lib/metresis/dashboards/cell_sources.ex:24-110`. (current)
- **MUST:** there are server-side derived computations that a virtual source must **not** replace, because they need raw rows or the database. These stay inside the source (the query), not in host-side transforms:
  - counter-reset-aware `delta`;
  - the circular mean;
  - distribution sectors and the cyclic mode;
  - series grouping by the database;
  - rollup vs raw selection.
  - Cite: §4.3 #cyclic-distribution, #cyclic-mode, §6.2, §8.1 #series-grouping. (current)
- **MUST:** series naming ("named by what tells it apart") is computed **once over the whole result, across every metric's feed**. A derived-source model must allow a function over *all* of a cell's inputs together, not only per input.
  - Cite: §8.5 #series-names, `Metresis.Dashboards.SeriesNames`. (current)
- **SHOULD:** the **brush window as a source/state.**
  - Today the brush's result goes to the server as a new window and into the URL. metresis does not expose selection as a feed.
  - Under `Board.Server` the runtime owns the brush, and metresis needs `brush: :host`, so the host can route it to the URL.
  - So if selection becomes a source, the host must still be able to own it and persist it to the URL.
  - Cite: §8.5 #overlays-as-marks (brush), #452, #507. (planned: #507)
- **SHOULD:** a **dashboard variable** (`label_values` or `static` picker, `multi`, `include_all`) is folded into every panel's filters. It is the nearest thing metresis has to "interactive state as a source".
  - It is not carried in the board bundle today.
  - Cite: §5 dashboard_variables, §8.4, `Bundle` has no variable export. (current; gap: implied)
- **MUST (sandboxing):** metresis's virtual sources are **trusted, compiled code**, registered by `config :visualize, virtual_sources: [Metresis.Dashboards.Sources]`. They are not sandboxed and not user-authored.
  - metresis requires no sandbox for its own sources. But a remote host can only run them if it has that module or an equivalent registry entry.
  - Cite: `config/config.exs:113`, `sources.ex:1-20`. (current; consequence implied)
- **SHOULD:** limits for derived sources come from the inputs, not from a derived-source cap: `max_marks` 5,000, the per-cell budget from the cell size (visualize#760).
  - Cite: §8.1 #chart-marks, #452 comment. (planned: visualize#760)

### Current mechanism
`Metresis.Dashboards.CellSources` declares, per visualization, `{slot id, inputs, output schema, function name}`. `Metresis.Dashboards.Sources` (`use Visualize.VirtualSources`, `defsource`) holds the functions. Until the board runtime runs dashboards, a panel runs its cell's sources itself in one pulse of `Visualize.VirtualSource.Engine` (`MetresisWeb.Charts.Design.Cell`).

### Constraints a unified model must not break
- Derived sources must be able to see every input of a cell together, plus schemas and delivery facts.
- Database-level derivations (reset-aware deltas, the circular mean, percentiles from raw) stay inside the query source.
- A remote host must be able to resolve metresis's source functions by name. This is an open question, below.

---

## C3 Parts / components

### Requirements
- **MUST:** a panel is **a query plus a visualization**, and its visualization is a **design**: a document saying what to draw (scales, axes, marks, the sources they bind to), stored as data and drawn by visualize at the panel's width. A design records no size.
  - Cite: §8.1, §8.2. (current)
- **MUST:** a part's offered settings are **constrained by the data's type**. `Viz.legal_for/1` decides which visualizations a type may have, and the aggregation dropdown is the legal set. Defaults are keyed on `(type, quantity)`.
  - Cite: §8.2, `Metresis.Dashboards.Viz`. (current)
- **MUST:** a part is a layered composition: house conventions, then the viz's default design, then a stored design. Two layers that disagree are refused (`composed!/1`).
  - Optional layers (second axis, thresholds, events, legend, band) are added only when their data exists, "so a panel without one draws exactly what it did."
  - Cite: §8.2, §8.5 #overlays-as-marks. (current)
- **MUST:** a part may **take ownership of its design**. An edited panel stores its composed design in `options.design`. An unedited one tracks the default, so improvements reach it.
  - A stored design that no longer fits its query says so on the panel rather than drawing something else.
  - Cite: §8.2, §5 panels. (current)
- **MUST:** declared **variables** bind facts into a design: `window`, `y_min`/`y_max`, `y_measure`/`y2_measure`, `metrics`, `second_axis`, `gaps`, `angle_domain`, `sector`, `bin_domain`. A design edited keeps its variables, so it follows its window rather than freezing it.
  - Cite: §8.2 #default-designs, §8.3. (current)
- **MUST:** `single_stat` and `table` are **not designs** and never will be ("a number and a grid of values have no scale and no mark"). They render as HTML pass-through on a board.
  - Cite: §8.2, #506 (depends on visualize#755). (current as HTML in metresis; planned on the board: #506)
- **MUST:** state colors and meanings.
  - A state carries a `status` (good, warning, bad, info, neutral) that travels with the data.
  - Its `color` is an override and only a **hint** that a design's own range outranks.
  - A verdict is drawn in the theme's role color, never a color spelled in a design.
  - Cite: §4.5 #state-status, §8.5 #status-colours. (current)
- **MUST:** panel options are a versioned document (`PanelOptions`), validated on write and migrated on read. A panel's own design is visualize's document, judged by visualize's validator. It is "the one field here whose shape another project owns."
  - Cite: §5 panels, §6.5. (current)
- **MUST:** library entries come in two kinds. A whole panel (query, viz, options, design) is added as a **copy, never a link**. A design fragment is saved from the chart editor.
  - "Adding rebinds by construction": an unqualified metric key reads the target dashboard's domain, and a qualified `<slug>/<key>` keeps pointing where it did.
  - Cite: §8.6. (current)
- **MUST:** profiles carry starter dashboards (parts with keys) that are **offered, never imposed**.
  - Adoption copies them, records provenance (`profile_panel_key`, footprints) and updates only untouched panels.
  - Cite: §3.3, §8.6 #adoption-*. (current)
- **SHOULD (packaging for others):** metresis already ships parts to other hosts as **board bundles** plus feed documents (§7.13), and the client ships `Visualize.Feed` implementations (§7.10).
  - What it would want to produce for a dcotek_web page is listed in the section "What metresis would produce for other hosts" below.

### Current mechanism
`Metresis.Dashboards.Panel` holds `{title, viz, x,y,w,h, query, options}`. Designs are under `priv/designs/`, through `DefaultDesigns`. A family's binding is in `MetresisWeb.Charts.Design.{XY,Bars,Distribution,States,Polar}`. Every panel is drawn as a one-cell `Visualize.Board` by `Board.realize/4`.

### Constraints a unified model must not break
- A part's settings are limited by the data's type. No generic "any chart over any field" for metresis data.
- `options.design` is visualize's document, not a third format.
- Library reuse is copy-on-add, not link.
- The status-role coloring is not overridable by a design color.

---

## C4 Composition / layout

### Requirements
- **MUST:** a dashboard is a **12-column grid**. A panel has `x, y, w, h`. Two panels never share a cell. A move or resize stays inside the grid and snaps to it.
  - Cite: §8.3, `MetresisWeb.Grid`. (current)
- **MUST:** the dashboard maps mechanically onto visualize's **board**: 12 columns, 80 px rows, 8 px gaps, cell `cell_n` for the nth panel, with no cap on the number of cells (names are strings, never atoms).
  - Cite: §8.3 #dashboard-board, #511. (current)
- **MUST:** a cell without a shared time axis (histogram, scatter, rose, compass, single_stat, table) says `sync: false`.
  - Cite: §8.3, `board.ex:24`. (current)
- **MUST:** editing the layout belongs to metresis.
  - A JS hook owns the 60 fps drag. The server owns the layout and saves on drop, with no Save button.
  - The drag grid stays metresis's even on the board runtime.
  - Cite: §8.3, #452 item 3, #507. (current)
- **MUST:** panels on one dashboard share a window and a resolution, so their axes widen alike and stay aligned.
  - Cite: §8.1 #time-axis-buckets. (current)
- **MUST:** a dashboard has an order (`position`, `starred`), a slug unique per domain, and is archivable. The board list leaves archived dashboards out.
  - Cite: §5 dashboards, §7.13. (current)
- **SHOULD:** no nesting. A dashboard holds panels, and panels hold no panels.
  - Cite: §5, §8.3. (current; implied as a constraint)
- **SHOULD:** a dashboard that cannot be a board (an invalid stored design, or refused by the board validator) is still listed, with `drawable: false` and the reason.
  - Cite: §7.13, #480. (current)
- **SHOULD:** responsive stacking and reading order are not specified. metresis's grid is fixed at 12 columns, and the rendering adapts width per panel ("the same design draws at any width").
  - Cite: §8.2. (implied: no requirement stated)
- **SHOULD:** domains are grouped by path (`ops/ci/runners`) in navigation only, and a group carries no data or permission.
  - Cite: #536. (planned: #536)

### Current mechanism
`MetresisWeb.Grid` (pure arithmetic, CSS out). `Metresis.Dashboards.Board.build/3` produces `Visualize.Board`, which is validated by `Visualize.Board.validate/3`. Navigation uses a tab strip, the ctrl-K palette and URL state (§8.4).

### Constraints a unified model must not break
- 12 columns and integer rectangles with no overlap: mechanical identity with visualize's board.
- Layout editing stays metresis's (the server owns the layout).
- `sync: false` for cells without a time axis.

---

## C5 Shared state, events and interaction between parts

### Requirements
- **MUST:** **URL state is the view.** The dashboard, the window, the variable values and `thresholds=off` all live in the query string. "Nothing about a shared link should depend on the recipient's session."
  - Explore: "the URL is the document."
  - Cite: §8.4, §8.7. (current)
- **MUST:** the dashboard window is shared by every panel, and a panel may override it.
  - Dashboard variables are folded into every panel's filters and re-run every panel.
  - Cite: §8.1 window, §8.4. (current)
- **MUST:** the brush. Its *result* (a window in the axis's own units) goes to the server and into the URL. The rubber band stays in the hook.
  - On the runtime, the host owns the brush (`brush: :host`).
  - Cite: §8.5, #452, #507. (current; on the runtime: planned #507)
- **MUST:** clicks.
  - A click on a mark that declares an event (`event_open`) arrives as visualize's one interaction shape: which mark, which row, and the drawing's token, **never the row's values**.
  - A click whose token is not the current drawing's is dropped.
  - On the runtime: `{:visualize_board_event, …}` handled by the host.
  - Cite: §8.5 #chart-clicks, #507. (current; on the runtime: planned #507)
- **MUST:** viewer-only state stays the viewer's. Legend series hiding is never sent to the server or stored, and a refresh re-hides.
  - Cite: §8.5 #legend-popup. (current)
- **MUST:** per-viewer display preferences (`unit_system`, `timezone`) convert **at render time, never in storage**. The values stay in the stored unit, so a threshold, the brush and a tooltip read what was stored. Only the axis converts.
  - Cite: §4.4 #unit-conversion, §8.1 #axis-measure, §10.2. (current)
- **SHOULD:** per-user persisted UI state (collapsed domain groups) is stored server-side per user.
  - Cite: #536. (planned: #536)
- **SHOULD:** cross-cell sync, selection and push updates are what metresis wants from the board runtime.
  - Cite: #452 problem statement. (planned: #452/#507)
- **SHOULD:** event vocabulary today: `event_open` (open the event on the domain's events page). Thresholds and alert lines link to a rule by `id`.
  - Cite: §8.5, §7.12 #feed-thresholds. (current)

### Current mechanism
LiveView `DashboardLive` holds the window and variables from `handle_params`. Hooks: the brush, `TooltipHook` and `LegendHook` (visualize's), and the drag grid. `MetresisWeb.Charts.click/3` and `resolve_click/2`.

### Constraints a unified model must not break
- The full view must be reconstructible from the URL alone.
- Clicks carry identities, never values.
- Unit conversion is a view concern only.
- The host owns the brush and click handling (metresis is the host for its own dashboards).

---

## C6 Documents

### Requirements
- **MUST:** a **versioned query document** with `v`.
  - It is validated by an embedded schema on write, and a document that fails cannot be saved.
  - It is migrated forward on read by a pure function, with a test per version.
  - A missing or unknown `v` is refused by name.
  - Rationale: so that "JSON means *versioned document*, not *untyped*."
  - Cite: §5 panels, §6.5, `document.ex`. (current)
- **MUST:** **unknown keys are refused by name**, never ignored (in a post, a query document or a top-level body).
  - Rationale: "A typo'd `lables` that silently discards every dimension … is the worst available failure."
  - Cite: §4.1, `document.ex` moduledoc. (current)
- **MUST:** every fault is reported, not the first, as `{path, error}` with nested paths such as `filters[1].op`.
  - Cite: §7.1, `document.ex`. (current)
- **MUST:** the same document is shared by a panel, an alert rule, `GET /query`, `/feed` and Explore's URL. "No second query language and no translation layer to drift."
  - An alert rule constrains it to exactly one own-domain metric, a relative window, and no map-valued aggregation.
  - Cite: §6.5, §7.6, §8.7, §9.1. (current)
- **MUST:** the alert `condition` is a separate versioned document, validated for shape and then for the metric's type, and migrated on read.
  - Cite: §9.1. (current)
- **MUST:** designs, fragments and bundles are **visualize's documents**.
  - They are stored in the form they were saved in and migrated where read, by visualize's own migrations, from JSON or a map. An upgrade rewrites nothing that is stored.
  - Shipped designs are in today's form, so reading migrates nothing.
  - Cite: §8.2 #stored-design-upgrades, #shipped-design-form. (current)
- **MUST:** every stored and shipped design is validated **at build time** over the house, so a broken shipped design fails the build, not a panel.
  - Cite: §8.2 #default-designs. (current)
- **MUST:** **atom safety.**
  - A stored vocabulary string becomes an atom only when the vocabulary knows it (`safe_atom/1`).
  - A board's names are strings, never atoms.
  - (Memory note: `to_existing_atom` fails in `bin/app eval`.)
  - Cite: §4.2, §8.3, #511. (current)
- **MUST:** profile documents (YAML in `priv/profiles`, JSON over the API) are checked exactly as publishing checks them.
  - Their wire name is `sha256:<hex>` of the canonical JSON, with keys sorted at every level, computed by one function shared by client and server.
  - Size ≤ 64 KB.
  - Cite: §3.3, §7.10, §7.11. (current)
- **MUST:** the board bundle wire form is the provenance, the board in visualize's JSON form, and each entry's `{id, name, kind, fragment}`. It is read back by `Bundle.from_map/1`.
  - **No binding** travels: no query, token or URL.
  - Cite: §7.13. (current)
- **SHOULD:** documents move to visualize's native document form (`Visualize.Document.encode/decode`) and `Document.digest/1` fingerprints, instead of hashing `Jason.encode!`.
  - Cite: visualize#908 amendment, #912. (planned: visualize#908)
- **SHOULD:** a profile panel with an invalid query should be refused at publish, not crash the adopting page.
  - Cite: #544. (planned: #544)

### Current mechanism
- `Metresis.Query.Document` (v1).
- `Metresis.Dashboards.PanelOptions` and `PanelDesign` (`parse/1`, `upgrade/1`).
- `Metresis.Alerts.Condition`.
- `Metresis.Profiles.Loader.check/1`.
- `Metresis.Dashboards.Bundle.to_map/from_map`.

### Constraints a unified model must not break
- Explicit `v` with forward-only pure migration.
- Unknown keys refused by name.
- Every fault reported with a path.
- One query document across panel, rule, API, feed and URL.
- Stored documents are never rewritten by an upgrade.
- No atoms minted from document content.

---

## C7 Snapshots / replay / provenance

### Requirements
- **MUST:** **two timestamps.** `received_at` is immutable provenance. `occurred_at` may be back-dated.
  - Cite: §4.8. (current)
- **MUST:** **idempotent replay.** A repeated `Idempotency-Key` returns the original response with `idempotent_replay: true` and writes nothing. Keys are kept 30 days.
  - Cite: §7.2. (current)
- **MUST:** **rollups are derived and rebuildable.** Raw samples are the source of truth, and a rebuild is a no-op on unchanged data.
  - Any snapshot of computed results must not be confused with the source of truth.
  - Cite: §5 rollups, §6.4. (current)
- **MUST:** the **result says how it was computed**:
  - the resolution used;
  - a note when coarsened ("from what");
  - percentile fallback stated in the footer;
  - the delivery's `capped`, `reduced_by`, window served and schema version.
  - Cite: §6.4, §8.1 #chart-marks, §8.5 footer, §7.12. (current)
- **MUST:** a **shared link reproduces the view**, through URL state (as of "now" for relative windows).
  - Cite: §8.4, §8.7. (current)
- **MUST:** provenance records.
  - A bundle's provenance is `metresis:<domain>/<dashboard>`.
  - A library entry records the domain and person that saved it.
  - Adopted dashboards and panels record the profile, its version and **footprints** (hashes of what a person can change), so "untouched since adoption" is decidable.
  - "Provenance is a record, not a link."
  - Cite: §7.13, §8.6 #library-store, #adoption-provenance. (current)
- **MUST:** history never silently changes meaning.
  - States and definitions are referenced by id.
  - A unit change within a dimension is an explicit, logged migration, and a change across dimensions is refused.
  - Archive, never delete.
  - Cite: §1.3, §4.5, §6.3, §5 referential rules. (current)
- **SHOULD:** a **byte-identical render comparison**: a dashboard drawn by metresis's path and by a remote host's path (bundle + feeds over HTTP) must match on the cn2 snapshot. That is a reproducibility requirement on any unified rendering pipeline.
  - Cite: #549 item 6, #553. (planned: #553)
- **SHOULD:** board exports draw the viewer's board (`Board.Server.export/2,3`).
  - Cite: #507 comment. (planned: #507)
- **SHOULD (no requirement found):** metresis has no "freeze what was shown" snapshot of a rendered dashboard or a result set. Nothing in the spec asks for one. (implied)

### Current mechanism
`samples.received_at/occurred_at`, `ingest_posts` with idempotency, `Metresis.Samples.Rollups.rebuild/1`, `Metresis.Dashboards.Footprint`, and bundle provenance.

### Constraints a unified model must not break
- Raw data is the record and derived results are caches.
- Results disclose their resolution and reduction.
- Provenance is a record, never a live link.

---

## C8 Stores

### Requirements
- **MUST:** **domains own their content.** Metric definitions, label vocabulary, samples, events, dashboards and alert rules all belong to one domain, and a domain's slug is immutable after creation.
  - A domain is never destroyed while it holds samples.
  - Cite: §3.1. (current)
- **MUST:** dashboard identity is `(domain, slug)` (unique per domain). A host lists the boards rather than hard-coding slugs.
  - Cite: §5 dashboards, §7.13, #480. (current)
- **MUST:** the library is **instance-wide**. Names are unique across the instance, and the domain an entry came from is provenance, not scope.
  - Cite: §5 panel_templates, §8.6. (current)
- **MUST:** a fragment's store id is `{kind, n}`. `n` comes from that kind's sequence and **is never reissued**, so a reference to a deleted entry "becomes a mask and never resolves to a different entry."
  - It implements visualize's `Visualize.Chart.Builder.Store` contract.
  - Cite: §8.6 #library-store, §5 library_sequences. (current)
- **MUST:** a board's components are held in a board store by number, `{:composite, n}`, and are exported through a read-only `BoardStore`.
  - Cite: §8.3, §7.13, `board.ex`. (current)
- **MUST:** shipped content (designs under `priv/designs/`, profiles under `priv/profiles/`) is versioned with the application.
  - Cite: §3.3, §8.2. (current)
- **MUST:** storage is portable across **three backends** (SQLite, Postgres, Timescale), with identical results. List columns are JSON, never arrays.
  - Cite: §2.2, #536 note. (current)
- **MUST:** the catalog is cacheable by `ETag`/`If-None-Match`. The client caches it as a value, not a process.
  - Cite: §7.5, §7.10. (current)
- **MUST:** an import from another store is relocated in one transaction (`PanelLibrary.import/2`).
  - Cite: §8.6. (current)
- **SHOULD:** retention per domain (raw vs rollups), with per-metric overrides.
  - Cite: #547. (planned: #547)

### Current mechanism
Ecto tables: `dashboards`, `panels`, `panel_templates`, `library_sequences`, `profiles*`. `MetresisWeb.PanelLibrary` is visualize's store. `Metresis.Dashboards.BoardStore` is read-only for export.

### Constraints a unified model must not break
- Ids are never reissued.
- The domain is the namespace for content (except the instance-wide library and profiles).
- Store contracts are visualize's (`Builder.Store`).
- Backend parity.

---

## C9 Registries / extension

### Requirements
- **MUST:** closed, code-owned vocabularies:
  - seven types;
  - aggregations per type (`Metresis.Aggregations.for_type/1`);
  - visualizations per type (`Viz.legal_for/1`);
  - visualize's quantities and UCUM units.
  - Extensions are not third-party. "Adding a visualization is a stored design, a binding and a legality entry."
  - Cite: §4.3, §4.4, §8.2. (current)
- **MUST:** virtual-source functions are registered by name in visualize's registry (`config :visualize, virtual_sources:`).
  - Cite: `config/config.exs:113`, §8.3. (current)
- **MUST:** **every hook visualize ships is registered**, as the generated file's default export spread whole, never a subset. A test fails on any hook name emitted but not registered.
  - Hooks are generated from the pinned visualize commit and never hand-edited.
  - Cite: §8.5 #hooks-registered, `mix visualize.hooks`. (current)
- **MUST:** profiles are the extension point for *domain knowledge*. They are data (shipped, written, or published by an emitter), guidance and never enforcement.
  - Cite: §3.3, §7.11. (current)
- **MUST:** collector *sources* are plugins in `collectors/metresis_collector`. Each is a module plus a profile, and the core learns nothing but the profile.
  - Cite: §11.3. (current)
- **SHOULD:** an "aggregation offered = aggregation answered" test: every pair is run through the arithmetic, so the registry and the implementation cannot drift.
  - Cite: §4.3 (#447). (current)
- **SHOULD:** the metresis migration onto visualize 0.9's renamed API (about 22 modules), with the guide generated from `@deprecated`.
  - Cite: visualize#908. (planned: visualize#908)

### Current mechanism
Compile-time module lists, the `priv/` data directories, `config :visualize`, and the generated `assets/js` hooks.

### Constraints a unified model must not break
- The type, aggregation and viz legality are closed and centrally answered.
- Registered names must resolve on any host that draws a metresis board.

---

## C10 Rendering targets and web constraints

### Requirements
- **MUST:** **server-rendered SVG** through visualize in LiveView function components, at the panel's width. `Backend.Canvas` and `Hybrid` are available for dense panels.
  - Cite: §8.2, §8.5. (current)
- **MUST:** the query layer caps points per series by pixel width, and marks per chart (`max_marks` 5,000). Over the ceiling, the query is refused with an error in the panel's own frame.
  - Rationale: visualize is "good to about 1000 data points."
  - Cite: §8.1 #chart-marks, §8.5. (current)
- **MUST:** interaction that must feel instant (tooltip, crosshair, brush, drag) lives in a JS hook. Only results go to the server.
  - Cite: §8.3, §8.5. (current)
- **MUST:** the legend popup is an HTML `popover` with CSS anchor positioning. It falls back to a hook where anchor positioning is missing, and never covers the chart.
  - Cite: §8.5 #legend-popup, #legend-placement. (current)
- **MUST:** themes. Verdict roles map to daisyUI's success and error colors, so light and dark themes both hold and a theme change recolors every verdict. A state's catalog color is data and draws as given.
  - Cite: §8.5 #status-colours. (current)
- **MUST:** accessibility.
  - A legend entry keeps its whole name for hover and screen readers.
  - Keyboard: one tab stop per chart, arrows across a state grid, Enter sends the click (from visualize 0.7).
  - Cite: §8.5 #legend-fit, #507 comment. (current in part; planned on the runtime: #507)
- **MUST:** a chart never fails to draw because of its legend.
  - Cite: §8.5 #legend-fit (#540). (current)
- **MUST:** HTTP/1.1 only (HTTP/2 is off).
  - The live socket accepts only the configured public origin and the origins the operator adds.
  - `put_secure_browser_headers` is used (Phoenix's default sets `x-frame-options: SAMEORIGIN`, so **iframing metresis into another host is blocked by default**).
  - Cite: §2.1 #http-1, #public-url, `router.ex:29`. (current; iframe consequence implied)
- **MUST:** the API is JSON in, JSON out, with gzip request bodies accepted. There is **no CORS** configuration, so browser-side cross-origin reads of the API are not supported. Hosts are expected to read server-side with a token.
  - Cite: §7 preamble; grep found no CORS in lib or config. (implied)
- **SHOULD:** for a remote host, draw from the bundle and feeds alone with visualize, **byte-identical** to metresis.
  - Cite: #549, #553. (planned: #549/#553)
- **SHOULD:** `single_stat` and `table` are pass-through HTML on the board (a reserved box or a `foreignObject`).
  - Cite: #506, visualize#755. (planned: #506)
- **SHOULD (no requirement found):** a static, no-socket render of a whole dashboard is not specified for metresis itself. Every UI route requires login and a LiveView. The bundle and feeds are the static or remote path. (implied)

### Current mechanism
`MetresisWeb.Charts.chart/1`, `Design.render/3,4` (a one-cell board realized), the hooks from `mix visualize.hooks`, the grid hook, daisyUI.

### Constraints a unified model must not break
- The point and mark budgets must hold on any target (a per-cell budget from the cell size: visualize#760).
- Verdicts use theme roles.
- Only interaction *results* reach the server.
- Embedding by iframe is not available. A host must render from the bundle and feeds with its own visualize.

---

## C11 Identity, auth and capabilities

### Requirements
- **MUST:** **the domain is the write boundary.** A token writes into exactly one domain, and changing anything needs a membership there. **A token names the domain; a body never does.**
  - Cite: §3.1, §3.2. (current)
- **MUST:** per-domain **API tokens** hold a **set of capabilities**: `ingest`, `read`, `alerts`, `propose`, `profile`, `admin`.
  - There are exactly three implications: `ingest` ⇒ catalog and latest read; `profile` ⇒ `propose`; `admin` ⇒ all. `read` does not cover `alerts`, and `alerts` does not cover `read`.
  - Tokens are hashed, shown once, revocable by timestamp, and expirable.
  - The format `mtr_<capability>_<random>` names the most a token can do, so a leaked token's blast radius is readable from its text.
  - Cite: §3.2. (current)
- **MUST:** **a token reads its own domain only.** A qualified `<slug>/<key>` is refused by name through a token. Cross-domain reads are only for a signed-in viewer.
  - Cite: §7.6, §7.9, §10.2. (current)
- **MUST:** the API authenticates by token only and the UI by session only: "a browser session can never be replayed as an ingest credential, nor the reverse."
  - Cite: §10.1. (current)
- **MUST:** **no public reads.**
  - Every UI route is behind `:require_authenticated_user`. Anonymous public dashboard links are out of v1.
  - Only `/health` and `/hooks/:name` are public, and the latter is authenticated by the source.
  - Cite: §0 Settled, §10.1, §12.3, §14. (current)
- **MUST:** **no data entry** in metresis's UI. Capture belongs to domain front ends holding an `ingest` token.
  - (Events and definitions may be made in the UI by members with `edit`. "Data entry" means samples.)
  - Cite: §1.2, §1.4, §4.10, §10.2, §14. (current)
- **MUST:** reading is instance-wide for signed-in users, with a `private` domain visible to members only. To anyone else a private domain's routes are 404 and its name is absent from every list. Visibility is a declared flag, never inferred.
  - Cite: §3.1, §10.2. (current)
- **MUST:** member capabilities: `edit`, `tokens`, `members`, `admin` (as a set; `admin` implies all). The last admin cannot be removed. `instance_admin` holds `admin` everywhere.
  - Cite: §10.2. (current)
- **MUST:** a viewer explores but cannot save. Saving a panel or alert is an editor's.
  - Cite: §8.7. (current)
- **MUST:** a bundle carries no token or URL. The token and URL stay the host's.
  - Cite: §7.13. (current)
- **SHOULD (MUST once built):** **scoped read tokens.**
  - A `read` token may carry `scope: {dashboards: [slug], metrics: [key]}`, and null means the whole domain.
  - **Default closed:** nothing is implied, not even a dashboard's metrics.
  - Checked on `/boards*`, `/feed*`, `/query` and `/samples`.
  - A refusal is a 403 naming the dashboard or metric.
  - The client is unchanged.
  - First consumer: dcotek_web's public pages ("dcotek_web is the public face; metresis keeps no public reads").
  - Cite: #555. (planned: #555)
- **SHOULD:** per-token ingest rate limits (samples per second plus a burst, and events per minute). Over the limit: a 429 with `Retry-After`, rejecting the whole post.
  - Cite: #548. (planned: #548)
- **SHOULD:** a token may carry its own profile, and whether it may is decided at minting. Adoption is `admin`'s, never `ingest`'s.
  - Cite: §3.3, §7.11. (current)

### Current mechanism
- `MetresisWeb.Plugs.Bearer.require_capability/2`.
- `Metresis.Domains.authorize/2`.
- `Metresis.Accounts.readable_domain/2`, `capabilities_for/2`.
- `MetresisWeb.UserAuth` (local and LDAP, session tokens).

### Constraints a unified model must not break
- The domain is the write boundary.
- The domain comes from the token, never the body.
- A token never reads across domains.
- No anonymous reads served by metresis.
- No sample entry UI in metresis.
- Capability names never lie: only the three listed implications hold.
- Scoped tokens are default-closed.

---

## C12 Privacy, tracking and observation

### Requirements
- **MUST:** the log store records only declared fields.
  - `api` entries: request id, method, path, operation, status, duration, declared body bytes, the token's domain and id, the client address.
  - `ui` entries: the signed-in user and the client address.
  - **Never** a header beyond the request id, a body, a query string or a token. Users, tokens and domains are stored as ids.
  - Retention is 24 h and 500k entries, and `log_capture: false` keeps nothing.
  - Cite: §2.1 #log-store. (current)
- **MUST:** a token's `last_used_at` is written off the request path, at most once a minute.
  - Cite: §3.2. (current)
- **MUST:** viewer-local UI state (hidden legend series) is never sent or stored.
  - Cite: §8.5 #legend-popup. (current)
- **MUST:** person-level data is a label (`person=<name-or-hash>`) chosen by the front end. metresis has no notion of a data subject.
  - Cite: §11.2. (current)
- **SHOULD:** metresis is a *destination* for other hosts' observation data: dcotek_web plans to push site-analytics rollups. That drives the retention (#547) and rate limiting (#548) needs.
  - Cite: #547, #548. (planned)
- **SHOULD (no requirement found):** no viewer analytics, view counts or disclosure requirements exist for metresis's own pages. (implied)

### Current mechanism
`Metresis.Logs` (a separate SQLite `logs.db`, one writer), `Metresis.Domains.TokenUse`.

### Constraints a unified model must not break
- A part rendered by another host must not cause metresis to log bodies, query strings or tokens.
- Viewer-hidden state stays client-side.

---

## C13 Isolation, limits and failure

### Requirements
- **MUST:** a failed part says so **in its own frame**, naming why. This covers:
  - over the mark ceiling ("names both counts");
  - a stored design that no longer fits ("says so on the panel");
  - a scatter with fewer than two metrics ("refused on the panel");
  - a query that does not plan ("its cell says why when drawn").
  - Cite: §8.1, §8.2, §8.3, `bundle.ex:98`. (current)
- **MUST:** an undrawable board is listed with `drawable: false` and the reason, and its bundle is a 422 with the reason.
  - Cite: §7.13. (current)
- **MUST:** **one rule cannot stop the others.** Each alert rule is evaluated as a supervised task, and a crash is reported with telemetry while the next rule runs.
  - Cite: §9.4 #rule-isolation. (current)
- **MUST:** scheduler ticks run on a period and are self-healing off watermarks. A crashed body is *observed, not caught*.
  - Cite: §12.2. (current)
- **MUST:** **no `try/catch/rescue`.** Failures surface.
  - Cite: §12 preamble; user CLAUDE.md. (current)
- **MUST:** ingest is all or nothing in one transaction. A contention failure is retried a bounded number of times (safe because the post is idempotent). Alert evaluation is never on the ingest path.
  - Cite: §6.1. (current)
- **MUST:** size and queue bounds:
  - the request body has a 413 bound;
  - a profile is ≤ 64 KB;
  - the proposal queue is capped per token (429 `profile_queue_full`);
  - raw reads are capped at 5,000;
  - the log writer drops and counts past 20k waiting entries.
  - Cite: §7.1, §7.11, §7.12, §2.1. (current)
- **MUST:** a chart never fails because its legend does not fit (visualize omits the legend).
  - Cite: §8.5 #legend-fit. (current)
- **SHOULD:** the SQLite single writer must not be held so long that ingest waits out `busy_timeout`. A dashboard load is the known trigger.
  - Cite: #468, #471. (planned: in progress)
- **SHOULD:** per-token rate limits.
  - Cite: #548. (planned: #548)
- **SHOULD:** a post larger than SQLite's bound-variable limit must still ingest.
  - Cite: #545. (planned: #545)
- **SHOULD (no requirement found):** no per-query timeout or heap or reduction limit is specified for queries or virtual sources. The limits are structural (marks, caps, budgets). (implied)

### Current mechanism
Budgets in `Metresis.Query` (`max_marks/0`), `Metresis.Query.Raw`, `Metresis.Ingest.Retry`, supervised rule tasks, and scheduler watermarks.

### Constraints a unified model must not break
- A failure is shown in the part, with a reason.
- A failure is never silently replaced by different output.
- The mark and point budgets bound what any host is sent.

---

## What metresis would produce for other hosts (e.g. a dcotek_web page)

| Part | Exists? | What it is | What metresis needs from the host |
|---|---|---|---|
| **A whole dashboard** | current: §7.13 bundle + `/boards` + `/boards/:slug/feeds`; byte-identical remote render planned #549/#553 | the board (cells, designs, virtual sources, fact variables), with feed documents per `<cell>.<input>` | a `read` token (scoped: #555), visualize (`Visualize.Board`, `Bundle.import_board/3`), a feed binding through `Metresis.Client.Feed.board_feeds/2`, **metresis's virtual-source functions resolvable by name**, a host-owned window, brush and click handling, theme role colors |
| **A single panel/chart** | implied: a panel is already drawn as a one-cell board (§8.3); no per-panel endpoint | one cell of a board, or a feed document plus a design | the same as a dashboard; a per-panel bundle or a way to address `cell_n` by panel (open question) |
| **Single stat** (number, sparkline, delta vs previous period, colored by polarity) | HTML in metresis; on the board planned #506 | pass-through HTML element | visualize#755 pass-through; polarity and unit from the feed schema; a `read` token |
| **Table** | as single stat (#506) | pass-through HTML | as above |
| **Alert status** (what is pending, firing, no data) | current API: `GET /api/v1/alerts` (`alerts` capability), threshold feed `status` | a list, or a status badge per rule or series | an `alerts`-scoped token (it is *not* covered by `read`, §3.2); a place to route "open rule" clicks |
| **Threshold lines** | current: `/feed/thresholds` | overlay rows `{value, label, status, id}` | the panel's query; `read` |
| **Events timeline / overlay** | current: `/feed/events` | rows with an identity `id` | `read`; a click target (metresis's events page is login-only) |
| **Latest value / high-water mark** | current: `GET /latest` (ingest or read) | the newest `occurred_at` per label value | a token |
| **Capture form controls** (for domain front ends) | current: `Metresis.Client.Form` (catalog → control descriptions as plain data) | a slider, select, toggle, angle or number per metric, with units and colors | an `ingest` token; the host renders and posts (metresis itself never hosts entry) |

Needs common to every produced part:
- the host holds the credential, and it is server-side (no CORS, no public reads in metresis);
- the host owns the binding (the bundle carries none);
- the host honors schema versions and budgets;
- clicks resolve by identity;
- the host supplies the theme's verdict roles.

---

## Vocabulary

| Term | Exact meaning in metresis |
|---|---|
| **domain** | The write boundary and namespace: owns metrics, labels, samples, events, dashboards and rules. Has an immutable slug and `visibility` `internal`/`private` (§3.1). |
| **token / API token** | A per-domain credential with a capability *set* (`ingest, read, alerts, propose, profile, admin`), format `mtr_<cap>_<random>` (§3.2). |
| **capability** | An element of a token's or member's set. Members have `edit, tokens, members, admin` (§10.2). |
| **scope** | (1) The older name for a token's capability (`require_scope/2`). (2) In #555: a read token's list of dashboards and metrics. |
| **membership** | A user's capability set in one domain (§10.2). |
| **profile** | A named bundle of *guidance* (metric suggestions, label roles, event kinds, starter dashboards and rules, unit defaults). Data, copied on adoption, never enforced (§3.3). |
| **catalog** | The domain's definitions as served by `GET /catalog`, the front-end contract (§7.5). |
| **metric** | A definition owned by a domain: `key, type, quantity, unit, polarity, …` (§4.2). |
| **type** | The semantic class: `gauge, counter, tally, enumeration, ordinal, flag, cyclic`. Decides the legal aggregations and conditions (§4.3). |
| **quantity** | The unit family, from visualize's list, or `number` (§4.4). |
| **state** | A row of an enumeration or ordinal, referenced by id, with `position`, `baseline`, `color` and `status` (§4.5). |
| **status** (of a state) | Its meaning: `good, warning, bad, info, neutral`. It travels with the data (§4.5). |
| **label** | A key/value on a sample or event (§4.6). |
| **dimension** | A label role: low cardinality, something to split by (group-by, variables) (§4.6). |
| **annotation** | A label role: high cardinality, something to filter to and display, never group by. Derived by ratio and demote-only (§4.6). |
| **label set** | An interned distinct label map, shared by every sample in a post (§4.6). |
| **sample** | One measured value with `occurred_at`/`received_at` and a label set (§4.1, §4.8). |
| **post** | An envelope of context plus an array of samples. All or nothing, idempotent (§4.1, §6.1, §7.2). |
| **event** | A dated, named occurrence with no value; a marker, or a span with `ends_at`. Overlays panels (§4.10). |
| **rollup** | A derived, rebuildable bucket aggregate (minute, hour, day) (§6.4). |
| **bucket / resolution** | A rollup interval. `auto` = window ÷ pixel width; feeds also have `raw` and `window` (§8.1, §7.12). |
| **window** | A relative (`-7d`) or absolute time range. The dashboard's is inherited by its panels (§8.1). |
| **query document** | The versioned (`v`) JSON `{metrics, window, filters, group_by, aggregation, resolution, limit}` shared by panel, rule, API, feed and URL (§6.5). |
| **aggregation** | A function legal per type × quantity × override. Some are map-valued (`count_by_state`, `time_in_state`, `distribution`) (§4.2, §9.1). |
| **panel** | A query plus a visualization, at `x,y,w,h` on a dashboard (§8.1). |
| **viz / visualization** | The panel's kind (`line … rose/compass`). Each one except `single_stat`/`table` is a design (§8.2). |
| **design** | visualize's document of scales, axes, marks and source bindings. Stored as data, records no size (§8.2). |
| **house** | The stored base design of house conventions, layered under every viz design (§8.2). |
| **layer** | An optional stored design piece (second axis, thresholds, events, legend, band) added when its data exists (§8.2, §8.5). |
| **family** | A group of vizzes sharing a binding: XY, Bars, Distribution, States, Polar (§8.2). |
| **binding** | (1) metresis-side: the code that computes a family's sources and variable values from a result (§8.2). (2) board-side: a cell's query/feed, which is "the host's and never part of the board" (§7.13, §8.3). |
| **variable** | (1) **dashboard variable**: a header picker (`label_values`/`static`) folded into panels' filters (§5, §8.4). (2) **design/cell variable**: a declared value a design reads (`y_min`, `y_measure`, `metrics`, `gaps`, …) (§8.2, §8.3). |
| **dashboard** | A domain's grid of panels, with a slug, `position`, `starred` and `time_range` (§5, §8.3). |
| **board** | visualize's `Visualize.Board`, which every dashboard also is. Cells `cell_n` on 12 columns (§8.3). |
| **cell** | A board's placed unit: a panel's rectangle, component ref, `sync`, virtual sources and vars (§8.3). |
| **board bundle** | The board, its components and provenance `metresis:<domain>/<dashboard>`, with no binding (§7.13). |
| **store** (board) | The board's components by number `{:composite, n}` (§8.3). |
| **store** (library) | The panel library as visualize's `Builder.Store`, ids `{kind, n}` never reissued (§8.6). |
| **feed** | A query as a `Visualize.Feed`: `describe` (schema) and `fetch` (rows for a window and budget), optionally push. One metric (§7.12). |
| **feed document** | A §7.12 `/feed` parameter set for one cell input (§7.13 `/boards/:slug/feeds`). |
| **source** | (1) A feed in visualize's sense. (2) An event's `source` (`api, ui, alert`). (3) A collector *source* plugin (GitLab, GitHub, Linux host) (§11.3). (4) A dashboard variable's `source`. (5) The result's `sources` (other domains read) (§7.6). Overloaded. |
| **virtual source** | visualize's derived source: a named Elixir function over a cell's feeds and its context, defined in `Metresis.Dashboards.Sources` (§8.3). |
| **slot** | A design's data placeholder filled by the source of the same name (§8.3). |
| **schema** | (1) A feed's typed field description, versioned by content hash (§7.12). (2) The database schema (§5). |
| **delivery** | A fetched result: rows, window served, resolution, `capped`, `reduced_by`, schema version (§7.10). |
| **budget** | The most rows a feed reader wants. **Mark budget**: the most marks a panel draws (§7.12, §8.1). |
| **fragment** | A piece of design saved from the chart editor, possibly partial (§8.6). |
| **library / panel template** | Instance-wide saved panels and fragments, added as copies (§8.6). |
| **footprint** | A hash of what a person can change on a panel or dashboard, for adoption provenance (§8.6). |
| **adoption** | Copying a profile's suggestions into a domain (§3.3, §8.6). |
| **provenance** | A record of origin (bundle source, library context, adoption), never a link (§8.6, §7.13). |
| **rule / condition** | An alert: a query document plus a versioned condition legal for the type (§9). |
| **threshold** | A rule's level drawn as a line, also a feed (§7.12, §8.5). |
| **silence / acknowledgement** | A time-boxed mute with a reason, and a "seen" that changes no state (§9.5). |
| **front end** | An external capture app holding one ingest token (§11). |
| **collector** | The application turning other systems' webhooks and APIs into posts (§11.3). |
| **snapshot** | Not a metresis concept. Used only for the cn2 *database snapshot* in render comparisons (#549, #553). |
| **layout** | The grid rectangles (`x,y,w,h`). No separate document (§8.3). |
| **manifest** | Not used. |
| **page / block** | Not used. |
| **domain group** | (planned #536) A path-named navigation container of domains, carrying nothing else. |

---

## Open questions found

1. **Remote virtual sources.** A board names its virtual-source functions (`:rose_sectors`, `:histogram_bins`, …) that are registered from `Metresis.Dashboards.Sources` in metresis's own app (`config/config.exs:113`). The client library does not ship them (no match in `clients/`). How does a remote host such as dcotek_web or exio resolve them? Through a shared package, by depending on metresis, or by visualize "storing them portably" (#452 comment, visualize#643)? #549 promises "a host with a read token draws every drawable dashboard", which presumes an answer.
2. **Dashboard variables are not in the bundle.** `Metresis.Dashboards.Bundle` exports no variables, so a host drawing a bundle cannot offer a dashboard's `person`/`station` pickers. Is a variable a board-level concept (shared state) or host binding?
3. **Granularity of parts produced.** There is a bundle per dashboard only. A host placing one panel (a single stat on a page) has no per-panel endpoint. Is it a one-cell board, a cell selected from a board, or a feed plus a design?
4. **Scoped tokens (#555) vs the derived feeds.** "Default closed, nothing implied, not even a dashboard's metrics". But `/boards/:slug/feeds` hands out feed documents for those metrics. Does a dashboard grant in a scope let the holder read those feeds through `/feed`, or must every metric be listed too? Can a scoped token re-query a granted metric with *other* filters, group-bys or windows than the panel's? (#555 says "query only those metrics", so yes as written. That may expose more than the page shows.)
5. **The alerts capability is separate from read.** An "alert status" part for a public page needs `alerts` (which can also acknowledge and silence), not `read`. A read-only alert-status scope does not exist.
6. **Click targets on remote hosts.** `event_open` opens metresis's login-only events page, and threshold `id` opens a rule. What does a click mean on a public dcotek_web page, where the viewer cannot log in to metresis?
7. **Window ownership.** On a remote host, the board's window (#552, visualize#936) is the host's. Does the host's window override the dashboard's `time_range`, and does a relative window resolve on the host's clock or metresis's?
8. **Push and the budget on the board runtime.** The per-cell budget from the cell size (visualize#760) is not yet available. Until then, does a remote host honor §8.1's mark budget?
9. **Embedding.** metresis serves no anonymous reads, has no CORS, and sends `x-frame-options: SAMEORIGIN` (Phoenix default, implied). So any public placement must be server-side through the host. Should a unified model assume server-side fetch only for metresis parts?
10. **"Source" is overloaded** (feed, event origin, collector plugin, variable source, result's other domains), and "binding" is used in two senses (metresis's binding code vs the board's host-owned binding). A unified vocabulary must separate them.
11. **Single stat's "delta against the previous period"** needs a comparison query (compare-to-previous-period, §8.2). There is no feed or source for a comparison series in §7.12. How would a remote single stat get it?
