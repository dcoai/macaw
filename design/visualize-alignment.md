# visualize and the Macaw component contract: alignment analysis

- **Date:** 2026-10-26. Read-only analysis; no project files, issues or git state were changed.
- **Outcome:** the owner accepted every recommendation in §5 on 2026-10-26, choosing for Q4 that the one event struct lives in `macaw_data`. The Macaw spec adopted R1–R20 under macaw_compose#22; visualize's side is visualize#940 with #941–#947.
- **Question:** can visualize's own visual types implement Macaw's component contract directly, through an optional dependency on `macaw_compose`, so that the `macaw_visualize` adapter package is not needed?
- **Sources read:**
  - Macaw: spec/00 to spec/14 (all of them), `design/requirements/visualize.md` (C1 to C13), and macaw_compose#15.
  - visualize issues, with all notes: #877, #880, #882, #886, #887, #888, #889, #893, #894, #902 to #909, #912, #913, #915, #916, #918, #919, #932, #936, #938, #939, #620, #755, #879 and #885. #910 and #911 are closed duplicates of #912 and #913.
  - visualize spec: 01, 08 §7 and §10 to §11, 10 §4 and §19, 11 §4 and §5, 14 §2, §4.7, §5.2, §12.6, §21 and §22, and 15 (most of it).
  - Code spot checks: `lib/visualize/components/board.ex:224, 244, 400, 402`; `components/chart.ex:409–443`; `backend/svg.ex` (`style_to_attrs`). `lib/visualize/` was grepped for `<style`.
- **Conventions:**
  - "M-05 §2" is Macaw `spec/05-components.md` §2; Macaw anchors are given where they help.
  - "v-spec/15 §8.2" is visualize `spec/15-boards.md` §8.2.
  - "#n" is a visualize issue, "macaw_compose#n" a Macaw one, and "C n" a section of Macaw's `design/requirements/visualize.md`.
  - **(uncertain)** marks anything I couldn't confirm from the text.

---

## 0. Summary

| Verdict | Count |
|---|---|
| aligned | 7 |
| aligned with a small change | 22 |
| gap | 10 |
| conflict | 15 |
| **total items** | **54** |

Every conflict and gap is resolved by one of 20 reconciled designs that both projects adopt (next section). Each design names its visualize issue amendments, its Macaw spec sections, and why it serves visualize both standalone and as a component.

**Eliminating the shim looks achievable.** No item is blocked in principle. The conflicts fall into three groups, and none needs an adapter package to resolve it:

1. **Things that move out of visualize anyway, because boards are superseded.** The board's shared state, server API, drill, `links`, the process model and pooling. These need decisions on the Macaw side, not adaptation.
2. **Web rules visualize must meet whatever package hosts it.** CSP, theme roles, the announcer, other-origin tiles. Visualize has to change for these whether or not a shim exists.
3. **Shape mismatches in two values, the event and the snapshot.** Either side can fix these with a rename and a few fields.

The adapter's remaining code is a thin `Visualize.Macaw.*` layer: callbacks, the event mapping, the declarations, and the migration of old board documents. That fits in visualize behind `Code.ensure_loaded?(Macaw.Compose.Component)` (§3).

**Two Macaw decisions must change first:**
- M-00 goal 6 and M-00 §4 say "visualize and `macaw_compose` never depend on each other". M-05 §6 and #939 (points 3 and 6) say the same. An optional dependency contradicts this.
- M-05 implicitly treats a component's declarations as static per module. A visual's slots, events and state writes depend on its design, which is data (§2.11).

---

## Reconciled designs

Every item marked **conflict** (15) or **gap** (10) in §1 is resolved here by one design that both projects adopt. Several items share a design, so there are 20. They are ordered by how much each unblocks: the earlier ones are prerequisites of the later ones.

Each design has the same four parts:
- **Design:** the one shared concept or shape.
- **visualize:** which issue to amend, and how.
- **Macaw:** which spec file and section changes.
- **Why both:** why it serves visualize on its own and visualize as a Macaw component.

**For a conflict or gap row, the design named here supersedes that row's "Change needed" cell in §1.**

| R | Design | Resolves |
|---|---|---|
| R1 | Optional, one-way dependency | E6 |
| R2 | Configured declarations | A1, and §2.11 |
| R3 | Parameters vs interaction state | C6, A8 |
| R4 | One interaction event, with a recorded form | A10, D2 |
| R5 | The budget as a declaration | A5 |
| R6 | The visual as a pure runtime value, rendered per mode | A7 |
| R7 | View-state scopes from browser to shared, with pooling | C9, C11 |
| R8 | Identity equivalence (`links`) | C8 |
| R9 | Cell actions | B6 |
| R10 | Viewer preferences as state sources | C10 |
| R11 | Color through roles; data color as typed content | B3, E3 |
| R12 | Same-origin delivery: classes, generated sheets, proxied media | B1, A17 |
| R13 | One announcer, reachable from hooks | A12 |
| R14 | An observation vocabulary on the event shape | A13 |
| R15 | Reading load for every component | A15 |
| R16 | Printout, record and state snapshot as three named values | D4 |
| R17 | Registry: explicit packages, derived members | E4 |
| R18 | Data operations live where derived sources live | E9 |
| R19 | One conformance kit with profiles | E5 |
| R20 | A scene is a visual, and its embeds are container panes | F2 |

### R1. Optional, one-way dependency (resolves E6)

**Design:** dependencies run one way. Macaw never depends on an adopter. An adopter may depend *optionally* on a Macaw library, compiling the integration only when that library is present. It must build, test and run without it. This is the rule visualize already applies to Phoenix, Nx, Jason and `table` (v-spec/01 §1.3–§1.6).

**visualize:**
- **#939:** replace point 3 with this rule, and point 6's `macaw_visualize` with `Visualize.Macaw.*` in `visualize_live`.
- **#902:** the consumer check (`scripts/consumer_check.exs`) builds every package without `macaw_compose`.

**Macaw:**
- **M-00 goal 6:** "No Macaw library depends on an adopter. An adopter may depend optionally on a Macaw library." The CI check forbids Macaw-to-adopter edges only.
- **M-00 §4:** remove the adapter paragraph.
- **M-05 §6:** the visualize bullet becomes "visualize's visuals, from visualize itself".

**Why both:**
- **Standalone:** visualize stays usable with no Macaw composition library.
- **Under Macaw:** visuals implement the contract with no third package and no version-lockstep triangle.
- **Macaw:** keeps its independence. It still knows nothing of visualize.

### R2. Configured declarations (resolves A1, and the §2.11 tension)

**Design:** one model of what a component declares. **Kinds** are static per module. **Everything else** is a pure function of the component's validated settings: the settings schema, slots, events, state writes, exports, budget, hooks, assets and observation. It is evaluated at document validation (M-07 §4), so the page DAG, the CSP plan and the observation plan still exist before render. Visualize contributes the declaration shape it already uses (a key table with type, default, merge rule and docs, #886's "one declaration") and the typed contract machinery (`requires`, `fact/3`). Macaw contributes `legal_for`.

A design variable becomes a **parameter**:
```
%{type: (M-02 type), default, values: [...] | nil,
  legal_for: {slot, field, fact} | nil, doc}
```

**visualize:**
- **#889:** add `Visualize.declarations(design)`, returning the configured declarations in Macaw's shape (plain maps, so there is no Macaw dependency), and the typed `:var` → parameter.
- **v-spec/14 §2.4:** amend to match, with the migration typing old untyped vars as `:term`.
- **#886, #887, #888:** their `options/0` uses the same parameter shape.

**Macaw:**
- **M-05 §1:** declarations other than kinds are `declarations(settings)`, pure and called at validation.
- **M-05 §2:** kinds alone are read without calling the component.
- **M-07 §3:** a component's settings schema is made of parameters in this shape.

**Why both:**
- **Standalone:** visualize's builder forms, validator and JSON vocabulary read the same shape, and an AI authors designs from it (macaw_compose#15).
- **Under Macaw:** the registry, the page validator and the AI catalog read one form for every component, and one generic visual module serves every design.

### R3. Parameters vs interaction state (resolves C6, A8)

**Design:** two concepts, one binding.
- **Parameters** (R2) configure a component and live in documents. They stack (defaults → preset → cell) through the fragment machinery, which is visualize's cascade generalized.
- **Interaction state** lives in **state sources**, held by a runtime and changed only by events.

A parameter's value is a literal **or a binding to a state source**: `vars: %{bins: {:state, "bins"}}`. A component **declares the state sources it writes** (`writes: [selection: :identity, window: :x_window]`) and writes them only by emitting events. It reads the state it needs through parameter bindings or slots.

The **runtime that holds the state** is Macaw's surface under Macaw. Standalone, it is visualize's own minimal holder: a pure `Visualize.Interaction` value (selection, window, variables) that a LiveView keeps in its assigns, applying events with `apply_event/2`. Today's `Board.Server` logic shrinks into that value.

**visualize:**
- **#889:** parameters may be bound to state.
- **New proposal, "Event v2 and interaction state":** `Visualize.Interaction` as the standalone holder. Retire `Board.Server.select/brush/window/vars` with the board.
- **#936:** `domain: :window` is a parameter bound to `window`.
- **v-spec/15 §5, §13:** superseded.

**Macaw:**
- **M-03 §1:** components declare `writes`; how a component reads state is "a parameter binding or a slot".
- **M-05 §1:** settings may bind to state sources; a change to a bound parameter re-applies (recompiles) the component, and re-fetches only when the budget changes.
- **M-04 §1:** "variables at its scope" means variable state sources.

**Why both:**
- **Standalone:** a LiveView gets selection, brush and variables without running a board process.
- **Under Macaw:** the same declarations feed the page DAG, recording and persistence, and a control written by another author can drive a visual's parameter.

### R4. One interaction event, with a recorded form (resolves A10, D2)

**Design:** a single struct, defined in visualize's terms but shaped to Macaw:
```
%Event{name, instance, element: %{frame, item, path}, identity,
       value, initiator: :visitor | :system, time,
       point, modifiers, row}
```
- `path` is innermost first (visualize, #620).
- `time` comes from the surface or holder's now, never a clock read (M-02 §6).
- `initiator` separates steps from markers (M-08 §1).
- `point` replaces `at`.
- D-170's **drawn-token rule** applies to every component whose elements map to data: a click resolves against the drawing it landed on, or is dropped.
- The struct has a **recorded form**, `Event.recordable/1`, which drops `row` and `point`. Data values are delivered live and never recorded.

Macaw owns the struct if visualize's optional dependency is acceptable for standalone users (open question Q4). Otherwise visualize keeps it, and Macaw's struct is field-identical, so the mapping is a rename.

**visualize:**
- **New proposal, "Event v2":** v-spec/10 §19 and v-spec/11 §5 rewritten.
- **#620:** "The event" section cites it; `paused` is a system event.
- **#908:** migration rows for the event.

**Macaw:**
- **M-01 §3:** the field list.
- **M-08 §2:** "state events are the recorded form; payload data is host-delivery only".
- **M-08 §1:** adopt the drawn-token rule.

**Why both:**
- **Standalone:** hosts match one shape, as today (D-170), and gain the initiator and time.
- **Under Macaw:** view paths and records are exact and carry no data, and any component can resolve clicks safely.

### R5. The budget as a declaration (resolves A5)

**Design:** a component declares a **per-slot row budget** as a function of its parameters and its measured size (R6's context). A **host ceiling** caps every slot. A slot over the ceiling is handed no rows and draws `over_budget`. Sources are pooled at the largest budget, and each reader reduces to its own, reporting `reduced_by`.

This is visualize's D-226, D-227 and D-230, lifted into the contract. Visualize's derivation (plot width × mark type, with a design override) is its implementation of the declaration.

**visualize:**
- **#889:** `declarations/1` includes `budget(size)`.
- **v-spec/15 §8.2:** the budget derivation moves to v-spec/14 §2.10 as a property of the design, not of the board.

**Macaw:**
- **M-05 §1:** a "budget per slot" row.
- **M-02 §6:** the ceiling, `over_budget`, and reduction per reader.
- **M-02 §3:** `reduced_by: :source | :runtime | :component`.

**Why both:**
- **Standalone:** `Chart.apply` hosts compute the same budget without a board.
- **Under Macaw:** every component that draws rows (charts, tables, metresis panels) gets correct fetch sizes, with one hard bound per host.

### R6. The visual as a pure runtime value, rendered per mode (resolves A7)

**Design:** a component with server work is a **pure value with transitions**:
```
init(settings, ctx) → delivery(state, slot, delivery) → size(state, size) → state(state, name, value) → render(kind, assigns)
```
The context carries the mode (live, socketless, neutral, print), the measured container size and root font size, the heading level, the instance id and the theme. The **process** around the value is the host's concern: Macaw's contained cell, or visualize's standalone component.

**Mode rules for visuals:**
- **live:** may use canvas per mark;
- **socketless and neutral:** SVG only, reduced to the budget, first frame from deliveries;
- **neutral:** no hooks or tokens;
- **print:** the print theme, literal colors.

This generalizes visualize's own precedents, `Feed.Monitor` and `VirtualSource.Engine` as values (C1, C2).

**visualize:**
- **New proposal, "The visual runtime as a value":** extracted from `Board.Cell` (v-spec/15 §8.3).
- **New proposal, "Render modes."**
- **#906:** `Components.Chart` holds the value.
- **#913:** canvas is live-only.

**Macaw:**
- **M-05 §4:** contained cells hold the value. The callback behavior lives in `macaw_compose`, the process in `macaw_live`.
- **M-05 §3 and M-10 §3:** the measured size and rem are in the context, for components that lay out on the server.

**Why both:**
- **Standalone:** a LiveView or a test drives a chart without processes, and every chart is complete without JS.
- **Under Macaw:** containment, restart and replay wrap the same value, and nothing about rendering differs between the two hosts.

### R7. View-state scopes from browser to shared, with pooling (resolves C9, C11)

**Design:** one scope ladder for interaction state, extending M-03 §2 downward and making `:shared` affordable.
- **`:local`:** a new scope, held in the browser and never recorded or persisted. It is shared between components only through a **declared client bus**, keyed by scope name, carrying domain values, never pixels. Visualize's `VisualizeSync` becomes this bus. The sync group's name becomes the local scope key. Components declare `local: [hover: :x_domain, brush_band: :x_window]`.
- **`:surface` / `:viewer`:** per viewer, as Macaw proposes and #620 asks.
- **`:shared`:** what a visualize board is today: one value for every viewer of a surface.

**Pooling:** identical, viewer-independent requests (as `reveals` declares) are fetched once across pages, through the host's PubSub. A `:shared` surface then costs what a board costs today.

**visualize:**
- **#906:** the hooks use the bus through the declared local scope.
- **v-spec/10 §4.3:** the bus spec moves out by reference.
- **v-spec/14 §2.9:** `interaction.sync` is a local scope key.
- **#620:** "Four kinds of state" maps world → sources, local → `:local`, per viewer → `:viewer`, animation → the visual's value.

**Macaw:**
- **M-03 §2:** the `:local` row.
- **M-00 goal 1, rule 2:** "a declared local scope is not a back door".
- **M-10 or `macaw_live`:** the client bus, a static module.
- **M-02 §6:** pooling across pages.
- **M-14:** close the visualize row.

**Why both:**
- **Standalone:** charts keep zero-latency linked hover, as today.
- **Under Macaw:** the linking is declared, so the runtime knows about it, and any component (a map, a table) can join a hover scope.

### R8. Identity equivalence, `links` (resolves C8)

**Design:** **identity equivalence** is declared once per composition, where components meet: `links: %{name: :service, svc: :service}`, one step (v-spec/15 §13.2). Selections are written and read through it. Schemas still declare identity (D-167). Links only say which differently named identity fields are the same.

The composition is the surface under Macaw. Standalone, it is the `Visualize.Interaction` holder (R3).

**visualize:** **v-spec/15 §13.2** moves to the interaction holder's spec, as part of R3's "Event v2 and interaction state" proposal.

**Macaw:** **M-03 §1 and §5:** a surface document carries `links`, and the `selection` state source applies it on write and on read.

**Why both:**
- **Standalone and under Macaw:** cross-highlighting works across feeds named differently, with no derived source per mismatch.
- **Macaw:** the "cross-highlighting without wiring" effect (M-00 goal 1) holds for real-world schemas.

### R9. Cell actions (resolves B6)

**Design:** a component emits events and never decides what they mean. The **placement** declares **actions**, each mapping an event to one of:
- `navigate(target_ref, params from event fields)`: a navigation step;
- `set(state, value from event fields)`: a view change.

Visualize's drill is exactly an action table, generalized:
- `{:datum, field}` becomes `{:event, [:row, field]}` or `{:event, :identity}`;
- `board: :self` with vars becomes `set` on variable state;
- another board becomes `navigate`.

Targets are typed references (M-09 §2). Parameters are validated against the target's declared params, which is visualize's "validated against the target's declared variables". A pick may carry both select and navigate, in declared order.

**visualize:**
- **v-spec/15 §1.3 and §13.3:** `drill` is superseded.
- **New "boards leave visualize" proposal:** standalone, `Components.Chart` accepts an `actions` assign, and resolves them into `{:visualize_action, …}` messages for the page: no routes, as D-151 requires.
- The migration (§3) converts `drill` to actions.

**Macaw:**
- **M-06 §5:** actions on cells, and **page params** (typed, with legal values).
- **M-03 §1:** `initial: {:param, …}` reads them.

**Why both:**
- **Standalone:** a page gets validated drill-like behavior without a board.
- **Under Macaw:** every component's clicks become steps of the right kind, and "the library never navigates" holds on both sides.

### R10. Viewer preferences as state sources (resolves C10)

**Design:** a viewer's display **preferences** (`theme`, `zone`, `units`) are standard state sources at `:viewer` or `:page` scope, persisted like any other state. They reach components through the context. Identity (the viewer) stays a separate argument, never stored. Visualize's `system:` and `zone` become reads of these, and `assigns:` for generators becomes the context's viewer.

**visualize:**
- **v-spec/14 §4.4 and v-spec/15 §1.5 and §8.2:** `system:` and `zone:` options remain for standalone use, as the values a holder supplies.
- **#889:** `apply/2` takes `context:` with them.
- **#936:** time scales read the zone from the context.

**Macaw:**
- **M-03 §1:** add `zone` and `units` next to `theme` (M-11 §3).
- **M-02 §2:** the viewer stays an argument; preferences are state.

**Why both:**
- **Standalone:** the options work unchanged.
- **Under Macaw:** one person's unit system follows them across every component, and there is no board per viewer per unit system.

### R11. Color through roles, data color as typed content (resolves B3, E3)

**Design:** one theme per page, one color model.
- **Drawing colors** come from **theme roles and ramps**, and derived values of them (`lighten(:warning)`), so contrast is checked on the theme.
- **Data-carried colors** (`:color` columns, schema `values` colors) are **typed content**, allowed only with a non-color cue (glyph, label or dash, as visualize's roles already carry, D-142) and a contrast guard against the surface. They are never the sole carrier of meaning.
- **Literal colors** in a design are permitted only by a **profile**: `colors: :open`, visualize's standalone default, versus `colors: :roles`, Macaw's.
- A design's `theme` key is an **override slot** the composition may mask. A page masks it; standalone, it applies.
- Visualize registers its theme slots into the shared theme document (#939 point 4).
- The theme class prefix is shared: `.mw-theme-<name>`, or whatever M-11 names it, emitted by both.

**visualize:**
- **#894:** the profile and role-derived values.
- **v-spec/14 §2.5:** `theme` is maskable.
- **v-spec/08 §7.3:** the class name, and dark mode by theme class plus `prefers-color-scheme` (dropping per-root `<style>`).
- **D-233:** `:color` data needs a cue.

**Macaw:**
- **M-11 §1:** "roles, role-derived values, and typed data colors with a cue".
- **M-02 §1:** reconcile "a schema never gives a drawing color" with `values` colors: the schema gives a *data* color, never a *drawing* color.
- **M-11 §2:** the prefix.
- **M-05 §3:** the profile.

**Why both:**
- **Standalone:** visualize users keep freedom, and get roles-only as an opt-in strict mode.
- **Under Macaw:** "one look" and contrast-once hold, and legitimate content colors (team colors) aren't banned.

### R12. Same-origin delivery: classes, generated sheets, proxied media (resolves B1, A17)

**Design:** one delivery rule for everything a component styles or loads, extending M-10 §1:
1. **A finite set of values becomes a class**, in a static stylesheet.
2. **A per-datum value is an SVG presentation attribute**, which visualize already uses (`style_to_attrs`).
3. **A finite set defined at runtime by a document** becomes a **content-addressed stylesheet asset from `'self'`**, generated on demand. This covers per-design motion: transitions and keyframes. M-11 §3 already does this for user themes.
4. **A dynamic value** is set by a trusted hook through CSSOM.
5. **No script evaluation.**
6. **Media from another origin is proxied** through a same-origin route. The URL policy gains `origin: :self`.

Both projects apply all six. Visualize's standalone default may stay permissive, but its strict profile is this rule.

**visualize:**
- **New proposal, "CSP-strict rendering":** inline `style=` to classes (root, blend, animate, canvas layers); motion to generated sheets; dark mode via R11.
- **#913:** delete the `:js` canvas path, explicitly.
- **v-spec/14 §10.3:** the `origin: :self` URL policy, with `:tiles` URLs as same-origin paths, and a tile-proxy `Plug` behind the Phoenix optional dependency.
- **#907:** the builder's sheet becomes a static file.

**Macaw:**
- **M-10 §1:** items 3 and 6.
- **M-05 §1:** assets may be generated, content-addressed sheets, and proxy routes are declared (the host mounts them).
- **M-08 §2:** generated sheets are captured with the base snapshot.

**Why both:**
- **Standalone:** a strict-CSP host can use visualize without Macaw.
- **Under Macaw:** the page's CSP holds for every visual, and motion stays as expressive as visualize designs are today.

### R13. One announcer, reachable from hooks (resolves A12)

**Design:** each composition (a surface, or a standalone chart) has **one polite and one assertive live region**. Components never own one. They **request** announcements, declared by name:
- from the server, as an event;
- from a hook, as a DOM event (`announce` with `{name, text, politeness}`) that the announcer hook queues, merges and rate-limits.

Visualize's `KeyboardHook` readout becomes a request. Standalone, `Components.Chart` renders the announcer itself, so one chart is one composition.

**visualize:**
- **#906:** the `announce` request and a standalone announcer hook.
- **v-spec/14 §21.5 and v-spec/10 §17:** the readout is a request.
- The visual declares `announces: [:point, :selection]`.

**Macaw:**
- **M-10 §4:** the client-side request shape.
- **`macaw_live`:** the announcer hook listens for it.

**Why both:**
- **Standalone and under Macaw:** the same hook code works, and screen-reader users hear one coordinated stream instead of competing regions.

### R14. An observation vocabulary on the event shape (resolves A13)

**Design:** observation reuses R4's event, recorded form only, with a **closed vocabulary**:
- `view`, `dwell`, `hover_item`, `focus_item`, `activate`, `select`, `brush`, `copy`, `scroll_into_view`;
- the element and identity, never data values.

A component **declares** which it can emit. A host **enables** a subset, and nothing is emitted otherwise. Visualize's hooks already resolve items by identity, so they emit `hover_item` and `focus_item` on enter and leave, not on pointer motion (#620: raw movement never reaches the server).

**visualize:**
- **#620:** its event vocabulary (hover enter and leave, focus) is shared with observation.
- **#906:** hooks emit only when enabled.
- The visual declares `observes`.

**Macaw:**
- **M-05 §1 or M-10:** list the vocabulary, and say observation events use the recorded event form.
- **M-00 goal 1:** the disclosure effect cites it.

**Why both:**
- **Standalone:** nothing is ever emitted, so visualize stays non-tracking by default.
- **Under Macaw:** the host's disclosure and plan match exactly what visuals can report.

### R15. Reading load for every component (resolves A15)

**Design:** reading load is a declaration of **every** component:
- `:glance`: a value, a chart's shape;
- `:scan`: a table, a list;
- `:read`: prose sections, which may give word counts.

Non-prose components default to `:glance`. Visualize derives `:scan` for visuals over many items, from the summary's counts (v-spec/14 §21.1).

**visualize:** **#889:** `declarations/1` includes `reading`.

**Macaw:** **M-05 §1:** the three levels and the default.

**Why both:**
- **Standalone:** nothing changes.
- **Under Macaw:** attention analysis (M-08 §3) treats a chart differently from an article.

### R16. Printout, record and state snapshot as three named values (resolves D4)

**Design:** three values, three names, three rules:

| Value | Holds | Data? |
|---|---|---|
| **printout** (today's `Board.Snapshot`, per visual) | the prepared design, deliveries, now, window and theme | carries data; never a record |
| **record** (M-08) | digests, recorded events, requests | never data |
| **state snapshot** (M-03 §4) | interaction state | never data |

Whole-page output in print mode assembles the components' printouts.

**visualize:**
- **New "boards leave visualize" proposal:** `Board.Snapshot` becomes a per-visual `Visualize.Printout`, and `Board.Export` becomes `Visualize.Output`.
- **#912:** it is a document kind.

**Macaw:**
- **M-01 §4 and §5:** the names.
- **M-08:** whole-page output may embed printouts; a record never does.
- **M-00 goal table:** "whole-page output" cites printouts.

**Why both:**
- **Standalone:** export and print work as today.
- **Under Macaw:** a page export is the composition of its components' printouts, and records stay data-free.

### R17. Registry: explicit packages, derived members (resolves E4)

**Design:** a host **enables packages explicitly** (closed by default). **Within an enabled package**, the members of a behavior (transforms, marks, frame kinds, aggregates, components, hooks) are **derived** from the modules that implement it. Each package exposes `__members__/0`, which a non-BEAM runtime calls from an explicit list (#886's portability). A document name resolves only among enabled packages' members, by string. A missing name is a fault naming the package that provides it (#886).

**visualize:**
- **#886, #887, #888, #909:** "derived from loaded applications" becomes "derived within enabled packages". Standalone, visualize's own packages are enabled by default, and others through `config :visualize, packages:`.

**Macaw:** **M-12 §1:** registration is by package, with members derived.

**Why both:**
- **Standalone:** keeps visualize's "no per-transform setting".
- **Under Macaw:** keeps "explicit and closed by default" where it matters: which code a document can reach.

### R18. Data operations live where derived sources live (resolves E9)

**Design:** the transform behavior, its table operations (filter, sort, take, fold, sum, bin, stack, window, lttb, m4, spectrum), and the aggregate behavior and statistics live in **`macaw_data`**, beside derived sources, whose sandbox allowlist is generated from them. Geometry-needing transforms (`needs: [:frame]` or `[:projection]`: layouts, geo) stay in visualize packages and register through R17.

**visualize:**
- **#939:** add it.
- **#903:** its transform amendment points to `macaw_data`.
- **#886, #909:** state the split by `needs:`.

**Macaw:**
- **M-04 §1:** the allowlist includes registered transforms and aggregates.
- **M-00 §4:** the `macaw_data` row lists them.

**Why both:**
- **Standalone:** visualize charts and metresis feeds reduce with the same code.
- **Under Macaw:** derived sources get the same operations designs use, so a computation can move between a design and a derived source unchanged.

### R19. One conformance kit with profiles (resolves E5)

**Design:** Macaw's component kit is the one kit. Visualize adds **visual-specific checks** to it as a profile: one tab stop, `role="img"` with a description and a table beside it, the drawn-token rule, and SVG in socketless mode. The kit runs over a **fixture set of documents**, because a visual's behavior is per design. The kit lives in `macaw_compose` `lib/`, and visualize runs it in CI when `macaw_compose` is present.

**visualize:** **new "visuals implement the Macaw contract" proposal:** fixture designs (one per mark, frame kind, backend and scene), plus `vis.check` running the kit.

**Macaw:** **M-12 §2:** profiles, and fixture-driven runs for settings-dependent components (R2).

**Why both:**
- **Standalone:** visualize's accessibility promises (D-142) are tested by a shared kit.
- **Under Macaw:** every visual is proven to meet the page rules.

### R20. A scene is a visual, and its embeds are container panes (resolves F2)

**Design:**
- **A surface** composes independent components that never flatten.
- **A scene** is one visual: one design, one coordinate tree, which flattens.

Everything #620 needs that is not drawing uses the shared concepts above:
- **Embedded host elements** are panes of a scene module of kind `:container`, positioned in scene coordinates (M-05 §4–§5).
- **Camera, playhead and breakpoints** are declared state (R3, R7).
- **The playhead** is the `window` state plus `as_of` (M-08 §4).
- **`paused`** is a system event (R4).
- **`Feed.Store`** is a writable `macaw_data` source with change notification (M-02 §5, M-13).
- **Key bindings** are focus-scoped. Page-level shortcuts go through a declared shortcut layer that the composition owns (WCAG 2.1.4).

Standalone, `Components.Chart` and the interaction holder play the surface's role.

**visualize:**
- **#620:** amend each section accordingly (state table, the event, embedded elements, bindings, playhead, `Feed.Store`).
- **#887:** viewport and camera are state.

**Macaw:**
- **M-05 §5:** a container may position its panes by a component's coordinate model.
- **M-10 §4:** the shortcut layer.
- **M-03 §1:** a `window` with `as_of`.

**Why both:**
- **Standalone:** scenes remain one library construct.
- **Under Macaw:** a scene with a live terminal or chart pane uses Macaw's isolation, and its state is recorded and shareable like any other.

---

## 1. Alignment table

Each row gives what visualize has today (spec section or module), what the proposals deliver (issues), the verdict, and the change needed, with the side that should make it.

### A. The component contract (M-05 §1, #components-declares)

| # | Contract item | visualize today | Proposals deliver | Verdict | Change needed, and who changes |
|---|---|---|---|---|---|
| A1 | **Settings schema**, may depend on bound slot schemas (`legal_for`) | A visual's settings are its design reference plus `vars`. A cell is `ref: {:composite, n}` plus `vars` (v-spec/15 §1.3). A `:var` declaration has **only `default: term`, with no type and no legal values** (v-spec/14 §2.4). Slot facts are checked against schemas through `requires` (v-spec/14 §2.3, §7.4). | #886 and #887 to #888: one declaration of options feeds the validator, the builder forms and the JSON vocabulary, but only for transforms, marks and frame kinds, not for a design's variables. #889: the front door. | **gap** | **visualize:** amend #889, or file a new proposal, so a `:var` declares `type` (Macaw's type vocabulary, M-02 §1), legal `values`, and `legal_for: {slot, field, fact}`, reusing the `fact/3` machinery of v-spec/14 §7.4. `Visualize.declarations(design)` then yields a Macaw settings schema. **Macaw:** M-05 §1 should say a settings schema may be derived from the configured settings themselves (see A3). |
| A2 | **Settings as stackable fragments** and presets | The design is a fragment stack: `compose/2`, `stack/1`, merge rules, use sites, masks, `explain/1` (v-spec/14 §8, §17, §19). Presets are stored preset designs plus an assign mapping (v-spec/14 §15). | #939 moves the machinery into `macaw_layers`. M-07 §2 and §3 adopt it whole: "defaults, then a preset, then the cell's local settings". | **aligned** | None; Macaw took visualize's model. Note that v-spec/15 §1.3 forbids inline designs on a cell ("a board holds no designs of its own"). In Macaw a cell holds local settings, so see open question Q3. |
| A3 | **Declarations readable by the runtime** (slots, events, state, exports) | A visual's slots (`sources`), events (mark `tooltip.event`, v-spec/14 §5.7), sync and brush (`interaction`, §2.9) and budget all live **in the design**. They are data and vary per design, and `Visualize.Event.declared/1` reads them (v-spec/10 §19.4). | #886 to #888: each behavior's `options/0` makes declarations introspectable. | **aligned with a small change** | **Macaw (M-05 §1, §2):** kinds stay static per module ("the registry reads them without calling the component"). Slots, events, state writes, exports and budgets may be **a pure function of the validated settings**, evaluated at validation time (M-07 §4). A generic "visual" component has no fixed slots. visualize's design is the better one here: it is what lets one component module serve every chart. **visualize:** one public pure function, `Visualize.declarations(design) :: %{slots, events, writes, budget, hooks, assets}`, to add to #889's front door. |
| A4 | **Slots, typed, with `requires` contracts** checkable before data flows | `sources` slots: `fields`, `types` (five types), `default`, `requires` (v-spec/14 §2.3). `Board.Binding.check/3` and `check_types/3` report every fault (v-spec/15 §4.3). | #916 makes `Data.Table` the currency; #903 and #939 move Schema to `macaw_data`. | **aligned** | None. Macaw's slot model is visualize's (M-02 §1, `design/requirements/visualize.md` C1). Small fix: v-spec/14 §2.3's `types` enum lists four types, while its prose and D-233 have five (`:color`). Correct the table when #893 touches it. |
| A5 | **Per-slot row budget** (not in M-05) | Derived per slot from plot width × mark type (`4w`, `ceil(w/2)`, `w`). A design may override with `n` or `{:per_px, k}`; the host ceiling gives `over_budget` (v-spec/15 §8.2; v-spec/14 §2.10; D-226, D-227, D-230). | #886 amendment: reducers are named transforms. | **gap** (on the Macaw side) | **Macaw:** M-02 §2 has `budget` in the request, and M-02 §6 pools "at the largest budget among them". But M-05 §1 gives the component no way to **declare** its per-slot budget, and M-03 and M-06 give the host no ceiling. Add to M-05 §1: "**budget** per slot, as a function of settings and measured size". Add to M-02 §6: "a host ceiling; a slot over it is handed no rows and draws `over_budget`". visualize's derivation is better than anything a host would repeat per panel (C1). |
| A6 | **Kinds**, one `render(kind, assigns)` clause each | No such notion. "Kind" in visualize means a fragment's derived type, a frame kind or a design kind (v-spec/14 §19.8, §4; #877 decision 7). | None. | **aligned with a small change** | **visualize:** visual modules offer `:content` only. A scene that holds embedded host elements (#620 step 2b) offers `:container` as a **separate module** (`Visualize.Macaw.Scene`), so kinds stay static per module (M-05 §2). Tables (#755) are `:content`. **Vocabulary:** "kind" collides; see E7. |
| A7 | **Modes:** live, socketless, neutral, print (M-01 §1; M-10 §2) | `Components.Chart` renders fully in the dead render. A **board cell draws `:loading` until the socket connects** (v-spec/15 §9.1; C10). A **canvas draws only through a hook** (v-spec/10 §7 to §8; v-spec/14 §21.4), so a canvas visual is blank without JS. Print is the `:print` theme plus `Export.pages/2` and `html/2` (v-spec/15 §12.4). | #938 lists "a board drawn in the first render from a pure realization". #913 replaces the `:js` path. | **gap** | **visualize** (new proposal, "render modes"): `render/2` reads the mode from the context. **Socketless and neutral always draw SVG**, reduced to the slot budget, never canvas. **Live** may pick canvas per mark (v-spec/14 §12.3). **Neutral** omits `phx-hook`, `data-tooltip-drawn`, the keyboard lists and per-viewer ids. **Print** uses the print theme in `:literal` mode. First render comes from deliveries, through the pure `Snapshot.realize/4` path (v-spec/15 §12.2). |
| A8 | **State it writes** (state sources) | Selection, window, brushed window and variables are **held by `Board.Server`**, changed by server calls (`select/2`, `brush/2`, `window/2`, `vars/2`) from the board's LiveComponent (v-spec/15 §8.2, §9.2, §13). Scenes add per-viewer camera, playhead and breakpoints "in the view's process" (#620, "Four kinds of state"). | #939 point 5: board runtime to `macaw_compose` and `macaw_live`; window and selection become state sources. #938: scope `:viewer` or `:shared`. | **conflict** | **visualize:** the visual **declares** the standard state sources it writes, `selection` (a pick) and `window` (a brush, from `interaction.brush`), plus scene-specific ones (`camera`, `playhead`, `breakpoints`). It writes them only by emitting events (M-03 §1: "a component changes state only by an event"). The server API of v-spec/15 §8.6 and §13.4 (`select/2`, `brush/2`, `pick/4`, `reset_window/1`, `vars/2,3`) is retired with the board, and debounce becomes the runtime's. **Macaw:** M-03 §1 should say how a component reads a state source it doesn't write (as a slot binding or in the context). The highlighting code needs the selection to draw `:selected` and `:muted` (v-spec/15 §13.2). |
| A9 | **Exports** | No notion. "Export" in visualize means **file output** (`Board.Export.svg/png/pages/html`, v-spec/15 §12). | None. | **aligned with a small change** | Exports are declared at surface and cell level in documents (M-03 §5). The visual only has to declare which of its written states are exportable (selection, window, camera). **Vocabulary:** "export" collides three ways (see E7). |
| A10 | **Event shape** (M-01 §3: "which component instance, which element, what name, which identity, when, and whether visitor- or system-initiated") | `%Visualize.Event{event, cell, frame, item, path, row, at, value, modifiers}`, sent as `{:visualize_event, id, event}` to the page (v-spec/10 §19.1; v-spec/11 §5; D-170). `at` is the **pointer position**, not a time. `row` carries the **typed data values**. The initiator and time are missing. #620 proposes the same shape for scenes, with `at` in frame space. | #620 ("The event"); none of #877's proposals change it. | **conflict** | **Both sides.** **visualize** (new proposal, "Event v2"; #620 amended to cite it): add `instance` (the Macaw instance id, replacing `cell`), `initiator` (`:visitor`/`:system`), and `time` (from the surface's now, never a clock read). Rename `at` to `point` so it is never read as "when". Keep `item`/`path` as the element and identity, and `value` as the payload. **Macaw (M-01 §3, M-08 §2):** define the event struct concretely. Visualize's `item`/`path` (innermost first) is a good model for "which element". Mark `row` and `point` as **delivered to the host, never recorded** (D2). Delivery is through the Macaw runtime, not a message to the page from a visualize LiveComponent. |
| A11 | **Each event marked visitor- or system-initiated**; steps vs markers (M-08 §1) | Runtime events are atoms (`:drill`, `:brush`, `:select`), declared events are strings (v-spec/10 §19.1). All are visitor actions today. #620 adds `paused`, raised by the runtime: a system event. | #620. | **aligned with a small change** | **visualize:** each event declares its initiator: mark events, pick, brush and drill are visitor; `paused` and a push-driven entity move are system (markers). **Macaw:** nothing; M-08 §1 already has the split. |
| A12 | **Announcements** requested as declared events; one announcer per surface (M-10 §4) | `KeyboardHook` keeps **its own polite live region** that reads the point (v-spec/14 §21.5; v-spec/10 §17). The board header shows "Selected: …" (v-spec/15 §9.2). | None. | **conflict** | **visualize:** under Macaw, `KeyboardHook` dispatches its readout to the surface announcer (a DOM event the `macaw_live` announcer hook listens for) and drops its own region. It keeps that region only when no announcer is present (standalone use). The visual declares `announces: [:point_readout, :selection_result]`. **Macaw:** specify the client-side announcement request (event name and payload, polite or assertive) in M-10 §4, because hooks need to request announcements without a server round trip for keyboard readouts (uncertain: M-10 §4 may intend server-side requests only). |
| A13 | **Observation**, in the host's closed vocabulary | None. visualize records and observes nothing (C12, implied). The hover bus deliberately never calls the server (v-spec/10 §4.3). | None. | **gap** | **visualize:** declare `observes: [:hover_item, :focus_item, :brush, :activate]`, emitted through Macaw's observer path only when the host enables it, and never carrying data values (identity only, consistent with D2). **Macaw:** M-05 §1 names "the host's closed vocabulary" but doesn't define it. List the vocabulary in M-05 or M-10, including "item hover on a composite widget", so visuals aren't left inventing words. |
| A14 | **Element ids**, stable, derived from content structure | Root id `vis-<hash(title, description)>`, or `<board id>-<cell>-chart` on a board (v-spec/14 §4.7; v-spec/15 §8.2; D-188). With `paths: true`, nodes carry `data-node` (`frames.<name>`, `marks[i]`, `labels[i]`; v-spec/14 §4.7, D-105). Mark items carry `data-vis-id` identity (motion, v-spec/15 §9.1). | None. | **aligned with a small change** | **visualize:** under Macaw the root id derives from the Macaw instance id. Always emit structural element ids from `data-node` paths, but key marks by their `id` (or name) rather than position `marks[i]`, because positions shift when a design is edited and attention would fail to aggregate across builds (M-05 §1). Data items use the declared identity (`data-vis-id`). |
| A15 | **Reading load** of its sections | None; not meaningful for a chart. | None. | **gap** | **Macaw:** M-05 §1 defines reading load for prose ("reading vs skimming", dcotek_web.md C3). Give non-prose components a default (`:glance`) or let them derive it. **visualize:** declare `:glance`, or derive it from the summary's size (v-spec/14 §21.1). Trivial once Macaw defines it. |
| A16 | **Client hooks as static files from `'self'`** | One ES-module bundle, `Visualize.Hooks.js_code/0`, written by `install!/0` into the **host's** `assets/js` and registered on `LiveSocket` (v-spec/10 §4.1, §4.2); 13 hooks. No JS build step (#913). | #906: a hook registry (`js_code(only: …)`), each package contributing its hooks. #939 point 6: "the hook registry [is] `macaw_live`'s". | **aligned with a small change** | **visualize** (#906 amended): ship each hook (and the shared `VisualizeSync`, `VisualizeMotion` and decoder modules) as static ES-module files under `priv/static`, imported by relative path, with no `install!` into host assets. Each visual declares the hooks it needs. **Macaw (M-12 §1):** fine as written; say that hook files may import sibling files of the same package. |
| A17 | **Assets** (CSS, images), and nothing from another origin | The `:tiles` basemap writes `<image href>` to a **tile server's URL**, which the browser loads (v-spec/14 §5.2: "the library never fetches a tile"). Image URLs pass a host URL policy (https by default; v-spec/14 §10.3). The builder renders its stylesheet in a `<style>` (v-spec/14 §18.13). Theme CSS comes from `Theme.stylesheet/1` (v-spec/08 §7.3). | None addresses origin. #913 covers wire format only. | **conflict** | **visualize:** under Macaw, the URL policy gets a **same-origin mode**, and a design's `:tiles` `url` must be a path on `'self'` (a host tile proxy). The policy already refuses `:relative` (v-spec/14 §10.3), so the mode inverts it. Images in neutral snapshots are captured as assets (M-08 §2). The builder's CSS becomes a static file (#907). **Macaw:** M-10 §1's `img-src 'self' data:` stands, but M-05 or M-12 should say that a component may ship a **proxy route** declaration, or that the host provides one (uncertain which side should own the proxy). |
| A18 | **Drawn states** (crashed, down, invalid, over_budget, loading, no_data, stale, capped, live) | Exactly this list and precedence; a theme role, glyph and words for each. `Board.State.render/4` draws the whole cell and `banner/4` a banner (v-spec/15 §8.4; D-146). | #939 point 5: "visualize keeps drawing visuals, **visual cell states**". | **aligned** | None to the model: M-05 §4 copied it. Who draws what: `crashed` is drawn by the surface while the cell is dead, so the drawing must stay a **pure function** (`State.render/4` is). Its `<style>` in `:css` mode must go (B1). |
| A19 | **Required access** | None. visualize is auth-agnostic (C11). | None. | **aligned** | None. A visual declares no access; gating happens through sources, which see the viewer (M-02 §2). |
| A20 | **Containment:** contained cells, heap-limited, restarted with 100 ms → 10 s backoff, reset after 30 s (M-05 §4) | Identical policy in `Board.Cell`, a GenServer with `max_heap_size` and `kill: true`, restarted **by the board** (v-spec/15 §8.3; D-146). Coalescing to the newest data. `Components.Chart` spawns a sized drawing process per update (D-206, D-216). | #939 point 5: cells as processes move to `macaw_live`. | **aligned with a small change** | **visualize** (new proposal, "the visual runtime as a value"): extract `Board.Cell`'s pipeline (place → apply → compile → step/tick → carry; resolve a pick or click against the drawn token; draw state) into a **pure value with transitions**, as `Feed.Monitor` and `VirtualSource.Engine` already are (C1, C2). `macaw_live`'s contained cell holds it. D-206's per-draw process may stay inside the cell. **Macaw:** put the contained-cell callback behavior (`init`, `handle_delivery`, `handle_size`, `handle_state`, `render`) in `macaw_compose` and the process in `macaw_live`, so visualize's optional dependency is on `macaw_compose` alone. |

### B. Web rules (M-05 §3; M-10; M-11)

| # | Item | visualize today | Proposals | Verdict | Change, and who |
|---|---|---|---|---|---|
| B1 | **CSP:** no inline `style=` or `<style>`, no inline script, no `eval`/`new Function` (M-10 §1) | **Inline `style=`:** the responsive root (`width:100%;height:auto`, v-spec/02 §2.1); the `animate` component; `:blend`; the board grid and cell placement (`components/board.ex:244, 400`); canvas layers (`components/chart.ex:409–443`); the Hybrid container (C10 a). **`<style>` in SVG:** automatic dark mode scoped to the root's id (v-spec/14 §4.7; v-spec/08 §7.3); motion classes and keyframes (`.vis-transition-<h>`, v-spec/14 §3.10–§3.12); the builder sheet. **`new Function`:** the `CanvasChart` `:js` path (`hooks/canvas.ex:102`; v-spec/10 §7.2). **CSSOM writes** from hooks (allowed). Per-element presentation attributes come from `style_to_attrs` (`backend/svg.ex`), which CSP permits. | #938 lists the CSP changes but **no proposal implements them yet**. #913 removes the JSON command format but doesn't explicitly remove the `:js` script path (C10 c). | **conflict** | **visualize** (new proposal, "CSP-strict rendering", the first in the web group): (1) the responsive root, `:blend` and `animate` become classes in a static stylesheet; (2) the board grid goes with the board; (3) canvas layers become classes, with sizes via SVG attributes or a trusted hook through CSSOM (M-10 §1's delivery rule); (4) **dark mode** becomes Macaw's theme class plus `prefers-color-scheme` in the static sheet (M-11 §2), dropping `color_scheme/2`'s per-root `<style>`; (5) **motion:** designs carry runtime motion, so a build-time sheet can't hold it. Compile each design's transitions and animations into a **content-addressed stylesheet asset served from `'self'`** (`/vis/motion/<hash>.css`), as M-11 §3 does for user themes and M-06 §6.4 allows for runtime templates; or constrain motion to a named vocabulary in the theme (open question Q8); (6) **remove the `:js` canvas path** (amend #913 to say so). **Macaw:** M-10 §1 should name "per-document generated stylesheet assets from `'self'`" as an allowed delivery for runtime-defined finite sets, generalizing M-11 §3. |
| B2 | **Size by container queries, never the viewport** (M-05 §3; M-10 §3) | Never the viewport. A chart is laid out **on the server at a pixel `size:`** (default 600×400, v-spec/14 §4.2) and scaled by `viewBox` (`responsive:`). A board measures its container through `BoardHook` and `ResizeHook` and **recompiles at the new width** (v-spec/15 §1.6, §8.2: "a resize is a recompile"). | None. | **aligned with a small change** | **Both.** Container queries can't drive server-side layout (ticks, legend fit, label sizes). **Macaw:** M-05 §3 should add that a component whose layout is computed on the server receives the **measured inline size of its container** (in CSS px, plus the root font size so rem breakpoints and the visitor's font size are honored, M-10 §3) in its context. A static `macaw_live` hook observes the container, and socketless renders use a declared default and scale. **visualize:** take the size from the context instead of `BoardHook`'s push, and move the responsive root to a class. |
| B3 | **Colors through theme roles only, never literals** (M-05 §3; M-11 §1) | Designs may hold **literal colors** and color operations (`Color.color`, `lighten`, …, v-spec/08 §1.9). A design literal **beats** the theme (#531 precedence revision). **`:color`-typed data columns draw as the color they are** (v-spec/14 §2.3, #875, D-233). Generators return styles or colors (v-spec/14 §3.13). Theme custom properties carry literal fallbacks (`var(--vis-axis, #666)`, v-spec/08 §7.3). | #894: `Color` becomes design values only; the API surface changes, the policy doesn't. | **conflict** | **visualize** (amend #894, or a sub-proposal of the Macaw-component proposal): a **validation profile** `colors: :roles` under which a design's literal colors, and generators that return literals, are faults at their path. Values derived from roles (`lighten(:warning)`) stay allowed, if Macaw accepts derived roles. **`:color` data columns** stay drawable only under an explicit opt-in. **Macaw:** decide whether data-carried colors (team colors, language colors) are content or a violation. M-02 §1 says "a schema never gives a drawing color", yet M-02 §1 also lets declared `values` carry colors, which is internally inconsistent. Recommend: data colors are **content**, drawn only with a non-color cue and a contrast guard, and never the sole carrier of meaning (M-10 §4 "never color alone"). See Q7. |
| B4 | **Heading levels from context** (M-05 §3; M-10 §4) | A chart's SVG has no headings: the title is `aria-label` (v-spec/14 §21.2, D-201). The board **hard-codes `<h2>`** for its title (`components/board.ex:224`) and **`<h3>`** for cell titles (`board.ex:402`). | #939: the board leaves visualize. | **aligned with a small change** | **visualize:** nothing for visuals; the hard-coded headings leave with `Components.Board`. Any visible caption a future visual renders (#755 table captions, scene panel titles) takes `heading_level` from the context. Cell titles become Macaw's (M-06 §3). |
| B5 | **Keyboard and accessible output:** composite widgets are one tab stop; charts are `role="img"` with a description and a data table beside them (M-10 §4) | A chart is one tab stop with arrows inside, Enter activates and Escape leaves (v-spec/14 §21.5, D-198); `role="img"`, `aria-label`, a generated `<desc>`, a hidden data table *beside* the SVG (v-spec/14 §21.1–§21.3, D-142, D-201). | None needed. | **aligned** | None. M-10 §4 is visualize's model. Escape-to-cell becomes Escape to the Macaw cell element. One check: v-spec/14 §21.5's live region moves to the announcer (A12). |
| B6 | **Links and navigation as events; a component never navigates** (M-05 §3); **drill is navigation** (M-00 §4) | `drill: %{board: :self \| ref, vars: %{var => {:datum, field} \| value}}` is **stored on the cell**, validated against the target board's declared vars, and resolved on pick into a `:drill` event the page follows (v-spec/15 §13.3, §9.2; D-151). The target is "the host's name for a board", not a store id (C, open question 3). | #939 point 5: "drill becomes navigation". | **conflict** | **Macaw:** a drill is not a component concern. Add a **cell-level action** declaration to M-06 §5: `on: {event, …} → navigate(page_ref, params from event fields)` or `→ set(state, value from event fields)`. Drill to `:self` with vars is a **view change** (setting variable state sources), **not navigation**. Drill to another board is navigation to a typed page reference (M-09 §2), with params validated against the target page's declared params (M-03 §1 already has `initial: {:param, …}`; M-06 doesn't define page params, which is the gap). **visualize:** remove `drill` from cells (the board leaves anyway). The visual only emits `pick` with item, identity and row. A pick that both selects and drills becomes "one event, two actions", decided by the cell's declaration. |

### C. Sources and state (M-02, M-03, M-04)

| # | Item | visualize today | Proposals | Verdict | Change, and who |
|---|---|---|---|---|---|
| C1 | **Source contract** (`describe`/`fetch`, params, `supports`, viewer, `reveals`, `as_of`) | `Visualize.Feed`: `describe/1 → {version, schema, supports}`, `fetch(feed, window, budget)`, optional `subscribe`/`unsubscribe`; `supports ⊆ [:window, :region, :latest, :budget, :push]` (v-spec/08 §11.1–§11.2; D-140). | #939 point 2: the feed contract, generalized, goes to `macaw_data`; #938 lists params, viewer, origin and reveals. | **aligned with a small change** | **visualize:** none beyond #939 (an existing feed is a source with no params, M-02). Spelling: visualize's `:region` capability is Macaw's `:box`, so align before `macaw_data` freezes it. |
| C2 | **Deliveries report what they served** (`served`, `origin`; `capped`, `reduced_by`) | `%Delivery{window, resolution, capped, reduced_by: :feed \| :visualize, version}` (v-spec/08 §10.4); the conformance kit checks them (v-spec/08 §12.3). | #916: `Delivery` carries a `Table`. | **aligned with a small change** | **visualize:** `reduced_by: :visualize` becomes `:Macaw` (M-02 §3) for runtime reductions. When the visual reduces to its own budget inside the cell, it should report `:visual`, or Macaw adds a value for that (uncertain: M-02 §3 names only `:source` and `:Macaw`). |
| C3 | **Push and change notification** | Push with the schema first, increments merged by the window field, coalesced between ticks (v-spec/08 §11.3–§11.4). No change notification. | None needed. | **aligned** | None. Change notification (M-02 §5) is the runtime's; visuals just re-render. #620's `Feed.Store` (a source the host writes to) becomes a `macaw_data` source with push plus change notification (see F2). |
| C4 | **Derived sources** | Virtual sources: data, checked or sandboxed, bounded by reductions, ranked pulses, scoped to board or cell (v-spec/08 §10.5; v-spec/15 §14). | #939: to `macaw_data`; #881 (`evaluate/4`) and #885 (hide `Engine`). M-04 adopts it whole. | **aligned with a small change** | **visualize:** #881 and #885 re-target to `macaw_data`. **New capability:** state sources and exports become inputs (M-04 §2). Selection, which "does not mark virtual sources" today (C2), now can. Joined fields (v-spec/15 §14.7) need a home in M-04 (uncertain whether Macaw intends to keep them). |
| C5 | **"Now" and the window** from the surface | The board's clock is read once per turn; the window is in UTC (`nil`, `%{last}`, `%{from, to}`) and applies only to feeds whose window field is `:time` (v-spec/15 §1.5, §8.2; D-154). | #936: `domain: :window`, written in "when the board prepares a cell". | **aligned with a small change** | **visualize** (amend #936): `:window` reads the **`window` state source bound to the visual** (or the request window in the render context), not "the board's". Outside Macaw, `apply/2`'s `window:` option stays. **Macaw:** M-03 §1's `window` state source should state its shape (`nil` / `last` / `from`–`to`, UTC), its window-field rule (D-154), and **reset** (v-spec/15 §13.1's *Reset window*, `moved`). |
| C6 | **Variables** | `vars` play **two roles**: a design's **parameters** (declared defaults, cascading cell → board → component, never renamed; v-spec/15 §5), and **viewer-changeable shared state** (`vars/2,3`, which re-prepares cells, recomputes budgets and marks context-taking virtual sources; v-spec/15 §8.2; D-229). | M-03 §1: "each **variable**" is a standard state source; M-04 §1: sources read "the variables at its scope". | **conflict** | **Both.** Split the two roles. **visualize:** a `:var` is a **setting** (typed, A1). A setting's value may be a literal or a **binding to a state source** (`vars: %{bins: {:state, "bins"}}`), so a control can change it. The cascade (cell → board) becomes Macaw's stacking (preset → cell local) plus surface-scoped state. **Macaw:** M-05 §1 needs "settings may be bound to state sources", because today state reaches components only through slots, and re-applying a design when a bound setting changes is a recompile, not a re-fetch. Define which setting changes recompile (any) vs re-fetch (budget-affecting; C1). |
| C7 | **Selection** (identity `{field, value}` or a composite map; drawn as `:selected`/`:muted`) | Board-held, drawn per datum through the `$vis_state` column and palette styles; a cell that doesn't hold it is byte for byte unchanged (v-spec/15 §13.2; D-151, D-171). Precedence for a pick: declared identity, else inference (D-167). | M-03 §1: `selection` is a standard state source; #939 point 5. | **aligned with a small change** | **visualize:** read `selection` from the bound state source instead of a board message; keep the highlighting entirely (it is drawing). **Macaw:** M-03 §1 should adopt D-167: a pick resolves the **declared** identity; inference is allowed only for a visitor's one-off pick, never for tracking. |
| C8 | **Links:** fields that mean the same thing under different names | `links: %{name: :service, svc: :service}`, board-level, one step (v-spec/15 §13.2). | None. | **gap** (Macaw) | **Macaw:** M-03 §1 and M-00's "cross-highlighting without wiring" rely on shared declared identity, but have **nowhere to put field aliasing**. Add `links` to the surface document (alongside `exports`), applied when a selection is written and read. Alternatively, declare that identity fields must share names, with a derived source renaming them (worse: a derived source per mismatch). See Q5. |
| C9 | **Local view state shared between components:** hover and the brush band across a sync group | `VisualizeSync`: a DOM `CustomEvent` bus between charts in a `sync` group, carrying domain units; a received hover never calls the server (v-spec/10 §4.3; v-spec/14 §2.9; D-116, D-117). #620 names "local view state" an owner of its own ("View, local | the browser"). | None. | **conflict** | **Macaw:** M-00 rule 2 says "a component never communicates with another directly", and M-03 knows no browser-held state. The sync bus is exactly such a back door, but **it is the right design**: hover at pointer rate must not round-trip. Recommend a **`:local` scope** (browser, never recorded, never persisted) in M-03 §2 for declared ephemeral view state (`hover_x`, `brush_band`), shared through a **Macaw-owned client bus** (a static `macaw_live` module). The runtime then sees the declaration, though not the values. **visualize:** move `VisualizeSync` onto that bus, and declare `local_state: [hover: :x_domain, brush_band: :x_domain]`. The sync group name becomes the local state's scope key. |
| C10 | **Viewer context:** time zone, unit system, generator assigns | `zone` is board display state, written into time scales (v-spec/15 §1.5). `system:` (unit system) and `assigns:` (the viewer, for generators) are board options; **a host runs one board per viewer or per unit system** (v-spec/15 §8.2; D-156, D-181). | None. | **gap** (Macaw) | **Macaw:** M-02 §2 passes `viewer` to sources and components, but zone and unit system are viewer or page **preferences**, not identity. Add them to M-03 §1 as standard state sources (`zone`, `units`, scope `:viewer`/`:page`), like `theme` in M-11 §3. Generators receive the viewer through the component context. **visualize:** read them from context, never from `assigns:` options. |
| C11 | **Shared vs per-viewer state; pooling across viewers** | One board process serves **every viewer**: one window, one selection, one fetch per feed, one width (a second viewer is scaled by `viewBox`) (v-spec/15 §8.2, §13.2). | #938: scope `:viewer` (proposed default) or `:shared`; M-14 lists it open (macaw_compose#3; visualize#938). | **conflict** | **Macaw:** M-02 §6 pools sources "by the page". A wall display with 20 viewers would fetch 20×, where visualize fetches once. Add **pooling across pages for identical requests** (keyed by source, request digest and viewer-independence; M-02 §2 `reveals`) at the host's PubSub level, so `:shared`-scope surfaces cost what a board costs today. **visualize:** none beyond A8; the board's semantics are the `:shared` scope. |

### D. Records (M-08)

| # | Item | visualize today | Proposals | Verdict | Change, and who |
|---|---|---|---|---|---|
| D1 | **Neutral base snapshot** of the page | `Board.Snapshot.views/2` draws every cell purely, byte for byte the live first frame (v-spec/15 §12.2). | None. | **aligned with a small change** | **visualize:** the visual's neutral render is the same pure path (A7), without hooks. Assets (tiles, fonts) are captured as M-08 §2 requires (A17). |
| D2 | **Semantic state events, no data stored** | Events carry `row`, typed data values (v-spec/10 §19.1). Snapshots carry **rows** (v-spec/15 §12.2). | None. | **conflict** | **visualize:** the **recorded form** of a visual's events is `{instance, element, name, identity, value, time, initiator}`, without `row` or `point`. `row` is delivered to the host live and never recorded. State values (a selection identity) are recorded under the state source's declared capture level (M-08 §5). **Macaw:** M-08 §2 should state that event payloads with data values are host-delivery only. |
| D3 | **Replay requeries; time travel via `:as_of`**, labeled "showing current data" (M-08 §4) | No `as_of` on feeds. Replay-by-scrubbing is planned in #620 ("the floor at 09:00") as a window over history. | #620 (the playhead's `seek(t)`). | **aligned with a small change** | **visualize:** none required. A visual whose sources lack `:as_of` gets Macaw's label. **Synergy:** #620's `seek(t)` and Macaw's `as_of` are the same request. Define the playhead as the `window` state source plus `as_of` (amend #620). |
| D4 | **State snapshot and records vs the visualize board snapshot** | `%Board.Snapshot{}`: a board frozen with **its data**, no viewer, never imported; the source of SVG, PNG, paged and HTML exports (v-spec/15 §12.2; D-150, D-156, D-181). | #939 point 5: "visualize keeps … exports from snapshots". | **conflict** | **Both.** The purposes differ: a visualize snapshot is a **printout** (data at an instant); a Macaw record is **reproduction without data**; a Macaw state snapshot is **interaction state only** (M-03 §4). Keep all three, but: **visualize** renames its value (a "printout" or "frozen view"; see E7) and reduces it to **one visual** (the prepared design, slots' deliveries, now, window, theme). The board-level snapshot is superseded by a Macaw whole-page output in print mode (M-00 goal table, "whole-page output"). **Macaw:** M-08 and M-00 should say whether "whole-page output" may embed data (a printout does; a record doesn't), because it's currently implied but not stated. |

### E. Layers, registry, packaging and vocabulary

| # | Item | visualize today | Proposals | Verdict | Change, and who |
|---|---|---|---|---|---|
| E1 | **Document kernel** (version, gates, limits, every fault, atom safety, map/JSON inverses, digest) | All of it (v-spec/14 §9–§11; C6). | #880, #893 and #912 to `macaw_layers` (#939). M-07 §1 adopts it. | **aligned** | None beyond #939. |
| E2 | **Store, typed refs, bundles** | The `Builder.Store` behavior, kind-tagged ids, import as relocation, transitive export (v-spec/14 §19.7; v-spec/15 §11). Themes are looked up **by name** (`Store.theme/2`; `{:theme_taken, name}`). The fragment code knows the `:board` kind (fragment.ex:44, 433), and `Chart.Validator` calls `Board.from_map` (validator.ex:179) (#877 §F). | #879 (Store and Bundle out of the Phoenix guard), #893, #939. M-09 adopts it. | **aligned with a small change** | **visualize:** cut the `:board` kind out of `Fragment` and `Validator` when boards leave. Themes are referenced by typed id, with the name as an attribute (M-09 §2). Bundles that carry a board become bundles that carry a surface; the migration is in §3. |
| E3 | **Theme system and delivery** | Per-design `theme` key: a built-in name or an inline theme (v-spec/14 §2.5). Root-scoped dark mode `<style>` (v-spec/08 §7.3). Class `.vis-theme-<name>` (v-spec/08 §7.3). `:literal` mode for canvas and PNG. | #939 point 4: visualize registers its slots into Macaw's theme. | **conflict** | **visualize:** under Macaw, **a design's `theme` key is masked by the page** (M-11: one theme for every surface; M-11 §3: the theme is a state source). An inline theme in a design becomes a fault in the Macaw validation profile. visualize's own slots (axis, grid, series palettes, the style palette) are registered as a theme extension. `:literal` resolution (canvas, PNG) reads the **current `theme` state source**, so a theme switch re-renders canvases (CSS recolors SVG for free). **Macaw:** M-11 §2's class prefix `.cx-theme-…` is a leftover of "composex"; rename it. |
| E4 | **Registry:** explicit and default-closed (M-12 §1) vs derived | Generators and virtual-source functions are registered **by module, from options and config** (C9), which matches Macaw. | **#886: "the registry is derived, not configured"** from loaded modules, with no setting; #887, #888 and #909 the same; #932 picks fnfont "by derivation"; #913 picks transport "by condition". #938: "an explicit, default-closed registry … **not** one derived from loaded modules (#886)". | **conflict** | **Both**, reconciled at two levels. **Package level is explicit** (Macaw): a host enables `visualize_geo` or `visualize_layouts` in Macaw's registry. **Module level within an enabled package is derived** (visualize): the package's transforms, marks and frame kinds are found by behavior, with no per-transform config. Amend #886 (and #887, #888, #909) so "derived" is scoped to enabled packages. M-12 §1 adds "registration by package, whose behaviors enumerate their modules". Outside Macaw, #886's derivation over loaded applications stands. #932's provider selection and #913's transport choice are not document-named, so they are unaffected. |
| E5 | **Component conformance kit** (M-12 §2) | Feed conformance kit only (v-spec/08 §12). Executed hook tests (dom_stub). | #919: a primitive conformance suite. | **gap** | **visualize:** run Macaw's component kit over a fixture set of designs (one per mark, frame kind, canvas/SVG, scene) in CI, with `macaw_compose` present. Kit items: kinds, headings, names and states, one tab stop, roles only, no inline style or script, complete socketless and neutral renders, stable ids. Ties to A7, A14, B1 and B3. |
| E6 | **Dependency rule** | Today: none. | **#939 point 3: "visualize … never depends on `macaw_compose`"**; point 6: the `macaw_visualize` adapter. M-00 goal 6 and §4; M-05 §6. | **conflict** | **Macaw:** amend M-00 goal 6 to "No Macaw library depends on visualize, metresis or dcotek_web. visualize may depend **optionally** on `macaw_compose`: it compiles, tests and runs without it." Rewrite M-00 §4's "visuals reach pages through a small adapter" and M-05 §6's `macaw_visualize` bullet. Change the CI check: Macaw → visualize edges are forbidden; visualize's consumer check (`scripts/consumer_check.exs`) builds it without `macaw_compose`. **visualize:** amend #939 points 3 and 6. |
| E7 | **Vocabulary** (M-01: one word, one meaning) | "kind" (fragment, frame, design kinds); "snapshot" (data printout); "export" (file output); "cell" and "component" (board terms: a component is a store entry, v-spec/15 §1.3); "board"; "panel" (state drawing); "layout" (already renamed by M-01 §5). | M-01 §5 renames visualize's "layout" and `Chart.Schema`; #893 renames `Chart.Schema`. | **aligned with a small change** | **visualize** (with #893 and #889's decision record): fragment and frame "kind" → **type** or **frame type** ("design kind" → "design type"), because Macaw "kind" is a render role; "snapshot" → **printout** (or "frozen view"); file "export" → **output** (`Visualize.Output.svg/png/pdf`); board "cell", "component" and "panel" leave with the board, so visualize's "component" means only a Macaw component. **Macaw:** add these rows to M-01 §5. |
| E8 | **Text measurement** | A fixed per-character advance in ems (`Chart.Text.width/2`, chart/text.ex:107-124). | **#932**: `Visualize.Text.Metrics`, estimation now and fnfont later, with sizes recorded in the plan. | **aligned with a small change** | **visualize** (amend #932): `face` comes from **the Macaw theme's font roles** (M-11 is the one theme system). Sizes are measured at the root font size reported with the container size (B2), so visitors who enlarge text get re-laid-out charts rather than scaled ones. That matters for M-10 §4's "usable at 200% zoom". **Macaw:** the theme document needs typed font roles (family, weight, size) that visualize and dcotek_web share (uncertain whether M-11 intends that). |
| E9 | **Home of transforms and aggregates** | Hard-coded in core (#886: six tables). | #903 amendment: the transform behavior, its registry and the eleven data ops go to `visualize_data`; #909: aggregates there too. **#939 is silent on both.** | **gap** | **visualize** (amend #939): the transform behavior, the table ops (filter, sort, take, fold, sum, bin, stack, window, lttb, m4, spectrum) and the aggregate behavior go to **`macaw_data`**, because derived sources' sandbox allowlist is generated from that registry (#886 amendment) and derived sources live in `macaw_data` (M-04). Layouts and geo stay in visualize packages (#904, #905). **Macaw:** M-04 §1's allowlist should name the registered transforms and aggregates. |

### F. Larger constructs

| # | Item | visualize today | Proposals | Verdict | Change, and who |
|---|---|---|---|---|---|
| F1 | **The builder vs AI as the builder** | `visualize_builder`: chart, board and theme modes; store, library, binding catalog `on_bind` (v-spec/14 §16–§20, §22). Its forms are generated from the schema (v-spec/14 §16.6). | #907 (package), #883 (internals). macaw_compose#15 (owner, 2026-10-26): "skip editors … provide what AI tools need": a machine-readable catalog, validation as feedback, preview, a data render mode. M-06 §6: the runtime page builder is deferred. | **aligned with a small change** | **visualize:** (1) **drop the board mode** (v-spec/14 §22) with the board; surfaces are Macaw's, and their editor is deferred. (2) Expose the vocabulary the builder's forms come from as a **document** (`Visualize.vocabulary/0`: every key, type, default, merge rule and doc, from `Chart.Schema` plus the #886–#888 behaviors), so Macaw's catalog (macaw_compose#15 item 1) lists a visual's whole design language, and an AI authors designs through the one format (M-07 §3). (3) Offer Macaw's **data render mode** (macaw_compose#15 item 4) from the summary and data table (v-spec/14 §21.1, §21.3), which visualize already has. (4) The builder's sheet and hook go static (A16, A17). The builder stays a human tool in its own package; the AI path doesn't need it. |
| F2 | **Scenes** (#620) as a top-level construct | Research. A scene is **one design, one coordinate tree**, distinct from a board, and "can be a board cell's component" (principle 3). It has its own interaction loop, per-viewer state (camera, playhead, breakpoints), key bindings with `capture: :page`, a `Feed.Store` source, embedded host elements in an overlay, and codecs. | #886–#888, #912, #919 and #932 amended for diagrams. | **gap** | **visualize** (amend #620): (1) a scene is a **visual** (a Macaw `:content` component), never a surface. It flattens; surfaces don't. Charts *inside* a scene are composites, not Macaw components. (2) **Embedded host elements** become panes of a Macaw **`:container`** (M-05 §4–§5: embedded applications are a container kind), placed in scene coordinates, so `Visualize.Macaw.Scene` offers `:container` (A6). The nesting depth of 3 applies. (3) Camera, playhead and breakpoints are **declared state sources** (`:viewer`/`:surface` scope), not "the view's process". (4) The playhead is the `window` state source plus `as_of` (D3); `paused` is a system event, recorded as a marker. (5) `Feed.Store` is a `macaw_data` writable source with change notification (M-02 §5; M-13). (6) **Key bindings:** `capture: :page` conflicts with M-10 §4 (no traps; one tab stop; WCAG 2.1.4 character-key shortcuts). Restrict to `capture: :focus` under Macaw, or route page-level keys through a Macaw-declared shortcut layer. (7) The event is Event v2 (A10). |
| F3 | **Tables** (#755) | Research; the owner's direction is pass-through HTML; option (b), an HTML table placed over a reserved box, is favored. | metresis#452 depends on it. | **aligned with a small change** | **visualize** (amend #755): on a Macaw page a table is **its own `:content` component** (HTML `<table>`, rows keyed by identity, sharing `selection`), not an element inside a visual's SVG. That resolves #755's points 1 to 3 for dashboards. A table *inside a scene* is an embed (F2.2). A visual table stays for standalone and PNG use (the server-side text grid). Macaw's records library (M-13) will also want tables, so decide the owning package (Q10). |
| F4 | **Binary hook transport** (#913) | base64 in `push_event` and data attributes. | #913: a binary Phoenix Channel on the LiveView socket, authorized by a signed token, with base64 as the fallback; #906 carries it. | **aligned with a small change** | Compatible with `connect-src 'self'` (M-10 §1). **Macaw:** `macaw_live` owns the socket setup a host mounts, so the channel is registered there, or the host mounts it (uncertain). **visualize:** amend #913 and #906 to name `macaw_live` as the place the channel is mounted when present. |

---

## 2. Conflicts and tensions, in detail

### 2.1 Process model: board and cell processes vs contained cells and surface processes

- **visualize** (v-spec/15 §8): `Board.Supervisor` (host-placed) → `Board.Server` (one per board) → one heap-limited `Board.Cell` per cell. The board owns shared state, the feed `Monitor` and the virtual-source `Engine`. Cells send frames straight to subscribers. One board process serves every viewer, and per-viewer behavior means one board per viewer (C5, C11).
- **Macaw:** the page and surface processes are LiveViews in `macaw_live` (M-00 §4). Contained cells (M-05 §4) carry the identical restart policy. Sources are pooled by the page and fetched out of process (M-02 §6). Derived sources run in the page DAG (M-03 §6). State is held by the runtime and scoped (M-03 §2).
- **What maps cleanly:** `Board.Cell` maps to a contained cell, its restart policy to M-05 §4, `Monitor` to `macaw_data`'s running sources, `Engine` to `macaw_data` derived sources, `Board.Server`'s now to the surface's now, and coalescing to M-02 §4.
- **The tensions:**
  - **Fan-out cost.** A board fetches once for N viewers; Macaw per page fetches N times (C11).
  - **Width.** A board draws at one width and scales; Macaw per viewer draws at each viewer's width. That costs more CPU and gives better legibility. Make it explicit in M-14 as the cost of per-viewer state.
  - **The cell's work must become a value** (A20). visualize already set that precedent with `Monitor` and `Engine`.
- **Recommendation:** visualize keeps **no processes** of its own for visuals: no `Board.*` runtime, and possibly the D-206 drawing process inside the cell. This also honors visualize's "the library starts no process of its own" (v-spec/15 §8.1). Macaw adds cross-page pooling for `:shared` scope.

### 2.2 `Visualize.Event` vs Macaw's event, steps and markers

Field-by-field mapping, with the gaps:

| Macaw (M-01 §3) | `Visualize.Event` (v-spec/10 §19.1) | Change |
|---|---|---|
| which component instance | `cell` (a board cell's name; `nil` outside a board) | `instance` (Macaw instance id) |
| which element | `frame`, `item`, `path` (innermost first) | keep; Macaw should adopt `path` |
| what name | `event` (string declared or atom runtime) | keep; the string/atom split stays visualize-internal; the Macaw-facing name is a string |
| which identity | `item = {mark, identity}` | keep |
| when | **none** (`at` is the pointer) | add `time` (surface now); rename `at` → `point` |
| visitor or system | **none** | add `initiator` |
| (payload) | `value`, `modifiers`, **`row`** | `row` and `point` are delivered live and never recorded (D2) |

- **Steps and markers:**
  - pick to select is a **view change** step; brush to window is a view change step;
  - drill to `:self` is a view change; drill elsewhere is a **navigation** step;
  - a declared mark event is a step or nothing, depending on what the cell's action does;
  - a pushed entity move, #620's `paused`, and data arriving are **markers**.
- **The drawn-token rule** (D-170: a click resolves against the drawing it landed on, or is dropped) is **better than anything in M-08**, and should be adopted as a Macaw rule for any component whose elements map to data. Replay can then trust that a recorded identity was really drawn.

### 2.3 Selection, brush, window and vars vs state sources and exports

- **selection:** Macaw's standard state source. visualize keeps the identity rules (D-167) and the drawing (`$vis_state`, D-171), and loses the holder (`Board.Server.select/2`). Exportable.
- **brush:** a visitor event that writes `window`, debounced by the runtime, with v-spec/15 §13.1's 250 ms debounce. `brush: :host` (D-161) **generalizes** to host-owned persistence of the `window` state source (M-03 §3), as #938 says. The **brush band** during a drag is local view state (C9).
- **window:** a standard state source. Its shape, D-154's window-field rule and *Reset window* belong in M-03 §1 (C5).
- **vars:** the real conflict (C6). Split them into **settings** (typed, A1) and **variable state sources** bound to settings.
- **links:** has no Macaw home (C8).
- **One rule to carry over:** "State changes only at events, never during recomputation" (M-03 §6). visualize already honors it: a selection change recompiles, and a recompile never writes selection.

### 2.4 Drill vs navigation

See B6. The key observation is that **visualize's drill conflates two Macaw step types**. `board: :self` with vars is a view change (it sets variable state sources); another board is navigation. Drill also leaves the component: it becomes a **cell-level action** in Macaw. visualize's validation, that a drill target's variables must be declared by the target, should survive as Macaw page-param validation (M-06 §5 needs page params). Open question 3 of C (drill targets named by "the host's name", not a store id) is resolved by Macaw typed refs (M-09 §2).

### 2.5 `visualize_builder` vs AI-as-builder

See F1. These are not rivals: the builder's form generation and the AI catalog consume the **same declarations** (#886 "one declaration feeds the validator, the builder's forms, the Build vocabulary and the JSON vocabulary"). The conflict is limited to the **board mode** (v-spec/14 §22) and the builder's **binding catalog** (`on_bind`, v-spec/14 §22.8). Both duplicate what Macaw surfaces and host bindings (M-02 §7) now own, so drop them. macaw_compose#15 wants a "data render mode", and visualize's summary and data table (v-spec/14 §21.1, §21.3) are already most of it for visuals.

### 2.6 One hook bundle vs static hooks per component

See A16. The difference is packaging, not design. visualize already has "no JS build step" and "no third-party JS" (#913), as Macaw does (M-12 §1).
- **Change:** files in `priv/static` instead of `install!/0` into the host's assets, and registration with `LiveSocket` done by `macaw_live`'s registry, not by visualize's `js_code(only:)` (#906).
- **Shared JS modules** (`VisualizeSync`, `VisualizeMotion`, the binary decoder) become sibling static modules. `VisualizeSync` should **become Macaw's** client bus (C9).
- **Standalone use** (no Macaw) keeps #906's registry. Both read the same files.

### 2.7 CSP

See B1, A17 and E3. The hard cases are **per-design motion** and **per-chart dark mode**:
- **Dark mode** dissolves into Macaw's theme class and `prefers-color-scheme`.
- **Motion** has two options:
  - (a) a content-addressed generated stylesheet per design from `'self'`; Macaw already accepts the pattern for user themes and runtime templates (M-11 §3; M-06 §6.4);
  - (b) a finite motion vocabulary compiled into the theme sheet.

  (a) keeps visualize's expressiveness. (b) is simpler and cacheable. This is the owner's call (Q8).
- **`:js` canvas:** must go, so amend #913.
- **Tiles from another origin:** need a same-origin proxy (A17).
- **Uncertain:** whether constructable stylesheets (`new CSSStyleSheet().replaceSync`) set by a trusted hook are governed by `style-src`. If not, they are a third motion option. Verify before choosing.

### 2.8 Board snapshot vs records

See D2 and D4. The snapshot's "carries data, not context" (D-156, D-181) is the inverse of Macaw's record ("definitions by digest, state by events, sources by request; never data", M-08 §2). **Both are right for their purposes.**
- Keep the snapshot as a **printout** of one visual, which is the source of visualize's file outputs.
- Macaw's whole-page print output assembles the components' print renders.
- A Macaw **state snapshot** (M-03 §4) holds no data.
- Rename visualize's value to end the word collision (E7).

### 2.9 Store and bundle moving to `macaw_layers`

See E2. This is aligned (M-09 was derived from visualize). Residue:
- the `:board` kind wired into `Fragment` and `Validator` (#877 §F);
- theme lookup by name;
- board bundles, which become surface bundles: a one-time migration (§3);
- per-kind integer sequences vs object storage (M-09 §4, deferred), which doesn't affect visualize.

### 2.10 Kinds a visual offers

See A6. Recommended: **`:content` for every visual**, and **`:container` only for a scene module that embeds host elements**, as a separate module so kinds stay static per module (M-05 §2). Not `:control`: a chart isn't a form control, and a brush is a composite widget, not a control. Not `:navigation`: a diagram of pages could render a `<nav>`, but that is better as a Macaw navigation component beside the diagram. A #755 table with checkbox row selection *could* be `:control` later.

### 2.11 Declarations that depend on settings (an unflagged conflict)

Macaw's text reads as if a component module carries fixed declarations (M-05 §1 table; M-05 §2 "registry reads them without calling the component"). A visualize visual is **one module whose slots, events, state writes, budget and hooks are functions of its design**. Requiring a module per design would be absurd: designs are data, stored and authored by AI.

Resolution: kinds stay static; every other declaration is a **pure function of validated settings**, evaluated at document validation (M-07 §4), so the page DAG, the observation plan and the CSP plan are still computed before render. This is the single most important Macaw-side amendment for eliminating the shim.

### 2.12 Element ids

See A14. visualize already derives ids from content (hashes) and structure (`data-node` paths), and uses declared identity for items. Two fixes: key marks by `id` rather than list position, and derive the root from the Macaw instance id (not from a title hash, which collides, D-188).

### 2.13 Text measurement

See E8. #932 is the right seam. Under Macaw the **font face is the theme's** and the **base size is the visitor's** (rem). Measuring at a fixed pixel size and scaling by `viewBox` shrinks text in narrow cells, which risks M-10 §4's 200% zoom and 320 px reflow. Measuring at the reported container width and root font size (B2) avoids that. The fnfont provider would let server and browser agree; until then the estimate errs, so labels need slack.

### 2.14 Scenes (#620) as the top-level construct

See F2. #620 already says "a board and a scene stay distinct", and that is the right line under Macaw too:
- **a surface** is independent components with independent processes, state and data, never flattened;
- **a scene** is one picture, one design and one coordinate tree, flattened.

The risk is scope creep: #620's embeds, key bindings, playhead and per-viewer state each have a Macaw home (container panes, the keyboard rules, the `window` state source plus `as_of`, declared state sources). #620 should cite them rather than build parallel mechanisms.

---

## 3. What remains for the shim

Nothing needs a separate package. What remains is adapter-shaped code, and all of it can live **in visualize behind the optional dependency**, compiled only when `Macaw.Compose.Component` is loaded. This is the pattern visualize uses for Phoenix (v-spec/01 §1.3; v-spec/10 §1.1).

| Residue | Where it belongs | Why |
|---|---|---|
| `Visualize.Macaw.Visual` (and `Visualize.Macaw.Scene`, `Visualize.Macaw.Table`): `@behaviour` the component contract; `kinds`; `declarations(settings)` delegating to `Visualize.declarations/1`; `render(kind, assigns)` | visualize (in `visualize_live` once #906 splits it, since render needs HEEx) | It is visualize's knowledge; Macaw must not know visualize (M-00 goal 6) |
| Contained-cell callbacks over the pure visual runtime value (A20) | visualize | Same |
| Event v2 → Macaw event mapping, and the recorded form (A10, D2) | visualize (or none, if Event v2 *is* the Macaw event struct; see Q4) | Same |
| Settings-schema generation from typed vars (A1) | visualize | Same |
| The validation profile under Macaw (roles only, theme masked, same-origin URLs) (B3, E3, A17) | visualize core (it is a validator option, not Macaw-specific code), switched on by the adapter | Useful standalone too, for strict-CSP hosts |
| **Migration of stored boards and bundles to Macaw surfaces** (cells → cells, `window`/`selection` → state sources, `virtual_sources` → derived sources, `drill` → cell actions, `links` → surface links, `sync` → local state scope) | visualize, behind the optional dependency, deprecated and removed at 1.0 | It must read the old board documents, which only visualize can; Macaw must not depend on visualize |
| Registering visualize's theme slots into Macaw's theme | visualize core (no optional dependency needed: `macaw_layers` is a hard dependency) | #939 point 4 |

**Belongs in Macaw**, because it is generic and every component package benefits:
- settings-derived declarations (2.11);
- per-slot budget and the host ceiling (A5);
- measured container size and rem in the context (B2);
- the `:local` scope and the client bus (C9);
- `links` (C8);
- cell actions for navigation and state (B6), and page params;
- zone and units state sources (C10);
- cross-page pooling (C11);
- the concrete event struct and its recorded form (A10, D2);
- the client-side announcement request (A12);
- the observation vocabulary (A13);
- reading load for non-prose components (A15);
- generated stylesheet assets (B1);
- package-level registry entries (E4).

**Uncertain:** a **tile proxy** (A17) could be a visualize `Plug` behind the Phoenix optional dependency, or a host concern. A generic "same-origin asset proxy" in Macaw would also serve dcotek_web's images.

---

## 4. Recommended amendments, in dependency order

### Step 1: decisions that unblock everything (Macaw spec, and #939)

1. **M-00 goal 6, M-00 §4, M-05 §6:** allow visualize's **optional** dependency on `macaw_compose`, remove `macaw_visualize`, and restate the CI check (E6).
2. **#939:** amend point 3 ("never depends on `macaw_compose`") and point 6 (the adapter). Add: the transform behavior, table ops and aggregates go to `macaw_data` (E9). Add: visual components live in visualize (in `visualize_live`) behind the optional dependency.
3. **#938:** record that this direction supersedes its "adapter" framing, and that the board-runtime open question becomes C11 (pooling) plus the `:shared` scope.

### Step 2: the Macaw contract (macaw_compose spec)

4. **M-05 §1–§2:** declarations other than kinds may be a pure function of validated settings (2.11). Add **budget per slot** (A5) and **local state** declarations (C9). Settings may be **bound to state sources** (C6). Say how a component reads state it doesn't write (A8).
5. **M-05 §3 and M-10 §3:** server-laid-out components receive the measured container size and root font size (B2).
6. **M-03 §1–§2:** define the `window`, `selection` and variable state sources concretely (window shape, D-154 rule, reset; D-167 identity rule). Add a **`:local` scope** (C9), **`links`** in the surface document (C8), and **`zone`/`units`** standard state sources (C10).
7. **M-01 §3 and M-08 §2:** a concrete event struct (instance, element path, name, identity, value, time, initiator); payload fields delivered but never recorded; adopt D-170's drawn-token rule (2.2). Add the new vocabulary renames to **M-01 §5** (E7).
8. **M-06 §5:** cell **actions** (event → navigate or set state) and **page params** (B6).
9. **M-02 §3, §6:** the host ceiling and `over_budget`; cross-page pooling for viewer-independent requests (A5, C11). Decide on `reduced_by` values (C2).
10. **M-10 §1 and M-11 §3:** generated per-document stylesheet assets from `'self'` (B1); the theme class prefix (E3); a client-side announcement request (A12); the observation vocabulary (A13); reading load for non-prose (A15); a policy for data-carried colors (B3, Q7).
11. **M-12 §1:** package-level explicit registration, module-level derivation inside a package (E4); hook files may import siblings (A16).

### Step 3: visualize foundations that move to Macaw (already planned, re-targeted)

12. **#880, #893, #912** → `macaw_layers` (per #939). In #893, also: remove the `:board` kind from `Fragment` and `Validator`; themes by typed id (E2); fix the `types` table to five types (A4); rename "kind" for fragments and frames (E7).
13. **#916, #903, #909, #886** (the data ops) → `macaw_data`. Amend **#886** (and **#887, #888, #909**): "derived" applies within packages a host enabled (E4). Re-target **#881** and **#885**: `evaluate/4` and the `Engine` live in `macaw_data`; #885's board half is moot.
14. **#879:** the board-document seams for the builder become moot; keep Store and Bundle out of the Phoenix guard, landing in `macaw_layers`.

### Step 4: visualize's own API (#877's milestones, amended)

15. **#889** (front door and decision record): add `Visualize.declarations/1` (A3), `Visualize.vocabulary/0` (F1), typed `:var` declarations with `legal_for` (A1, or a new proposal it links), the vocabulary renames (E7), and the statement that boards leave visualize.
16. **#894:** a `colors: :roles` validation profile (B3).
17. **#932:** `face` from the Macaw theme's font roles; measure at reported root font size (E8).
18. **#919, #887, #888:** no Macaw change needed. The plan is already portable, which suits contained cells.
19. **New proposal, "Event v2":** `instance`, `initiator`, `time`, `point`, and the recorded form (A10, A11, D2). #620 cites it.
20. **New proposal, "the visual runtime as a value":** extract `Board.Cell`'s pipeline (A20, 2.1).
21. **New proposal, "render modes":** socketless and neutral render SVG, never canvas; the first render from deliveries; neutral without hooks (A7, D1).
22. **New proposal, "CSP-strict rendering":** inline styles to classes; dark mode via theme class; motion stylesheets as assets (or a vocabulary, per Q8); the same-origin URL mode for `:tiles` (B1, A17). Amend **#913** to remove the `:js` canvas path explicitly, and to say the channel is mounted through `macaw_live` when present (F4).
23. **New proposal, "Announcer and observation":** `KeyboardHook` readouts to the surface announcer, and observation declarations (A12, A13).

### Step 5: packaging and the component

24. **#902:** the package graph gains optional `macaw_compose` (and Phoenix) edges on `visualize_live`, plus a consumer check without them.
25. **#906:** `visualize_live` hosts `Visualize.Live.*` (standalone components) and `Visualize.Macaw.*` (contract implementations). Hooks become static files under `priv/static`; the registry defers to `macaw_live` when present (A16). The sync bus moves onto Macaw's client bus (C9).
26. **New proposal, "visuals implement the Macaw component contract":** `Visualize.Macaw.Visual` and `.Scene`, contained-cell callbacks, the profile switch, the conformance kit in CI (E5). It depends on items 4–11 and 15–25.
27. **#882:** add a manifest audience for the Macaw-facing modules ("For Macaw" or "Extend").
28. **#907:** drop the board mode and the binding catalog; static CSS and hook; the builder previews through `Visualize.Macaw.Visual` so it shows what a page shows (F1).

### Step 6: retire the board

29. **New proposal, "boards leave visualize":** remove `Board.*` and `Components.Board` after a deprecation release; ship the board-to-surface **migration** behind the optional dependency (§3); rename `Board.Snapshot` to a per-visual printout and move the outputs (E7, D4).
30. **#936:** `domain: :window` reads the bound `window` state source (C5).
31. **#908:** the migration guide covers boards → surfaces, `Visualize.Event` → v2, feeds → sources, and the metresis cross-project proposal (metresis dashboards become Macaw surfaces).

### Step 7: research that builds on all of it

32. **#620:** amend per F2 (a scene is a visual; embeds are container panes; state sources for camera, playhead and breakpoints; the playhead is window plus `as_of`; `Feed.Store` in `macaw_data`; the key-capture rules; Event v2).
33. **#755:** a table is its own Macaw `:content` component on pages; a visual table stays for standalone and PNG use (F3).

---

## 5. Open questions for the owner

1. **The dependency reversal.** Confirm that M-00 goal 6 and #939 point 3 change to "visualize may depend optionally on `macaw_compose`", and that the visual components live in `visualize_live` rather than core.
2. **Settings-derived declarations.** Accept that a Macaw component's slots, events, state writes and budget may be computed from its validated settings (2.11), with only kinds static?
3. **Inline designs in cells.** v-spec/15 §1.3 forbids inline designs ("a board holds no designs of its own"). Macaw cells carry local settings (M-07 §3). May a Macaw cell hold a design stack inline, or only a reference plus local overrides? An inline design makes AI authoring one document; a reference keeps the library as the place designs live.
4. **One event struct?** Should Event v2 simply *be* Macaw's event struct (defined in `macaw_compose`, with visualize filling it), or should visualize keep `Visualize.Event` for standalone use and map it?
5. **Links.** Is field aliasing (`links`) a surface-level declaration in Macaw (C8), or must identity fields share names, with derived sources renaming them?
6. **Local view state.** Accept a `:local` (browser) scope and a Macaw client bus for hover and brush bands (C9), as a sanctioned exception to "no back doors"?
7. **Data-carried colors.** Are `:color`-typed data columns and schema `values` colors content (allowed with a cue and a contrast guard), or forbidden under Macaw's roles-only rule (B3)? M-02 §1 currently says both.
8. **Motion under CSP.** Generated per-design stylesheet assets from `'self'` (expressive), or a finite motion vocabulary in the theme (simple) (B1)?
9. **Shared boards' cost.** Is cross-page source pooling (C11) a Macaw v1 requirement, given that visualize boards today fetch once for every viewer?
10. **Tables.** Which package owns the HTML table component that dashboards (metresis#452, #755) and Macaw's records library both want: visualize, `macaw_compose`, or the records library?
11. **Transforms in `macaw_data`.** Confirm that the transform and aggregate behaviors and the table ops go to `macaw_data` (E9), not stay in a visualize data package.
12. **Tile proxy.** visualize `Plug`, host code, or a generic Macaw same-origin asset proxy (A17)?
13. **Scene key bindings.** Under Macaw, is `capture: :page` (#620) dropped, or does Macaw provide a declared page-shortcut layer that respects WCAG 2.1.4?
14. **The deprecation window for boards.** One release of `@deprecated` (as #877 decision 5), or removal at 0.9 with only the migration tool?
