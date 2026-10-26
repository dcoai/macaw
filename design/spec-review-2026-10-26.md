# Spec review, 2026-10-26

A cold read of the spec after the #22 and #29 amendments, by a reviewer told to find contradictions, errors, gaps, over-specification, terminology drift and stale references. The review itself is below, unedited. Every finding was applied under macaw_compose#35, in five work items.

## Disposition

| Findings | Work item | Notes |
|---|---|---|
| T1–T18, S1–S4, G2 | #37 | `macaw_records` → `macaw_edit`; base snapshot → **base render**; capture level defined (default `:none < :basic < :full`, matching macaw) |
| C5, C7, C13, C15, E2, E4, G4–G7, G13, I6 | #38 | **C5: clamp** (owner decision): the host ceiling clamps, `over_budget` removed |
| C1, C2, C4, C6, C8, C10–C12, C16, C20, C21, E6, E8, E9, G1, G11, G15 | #39 | |
| C3, C9, C17–C19, E1, E3, E5, E7, E10, G3, G8–G10, G12, G14 | #40 | G12: built-ins are enabled like any package (default closed) |
| I1–I5, I7 | #41 | I5 answered on #35: `writes` kept, narrowed per C4 |
| C14 | #37 | one kit per contract, extended by check sets |

**Resolved differently from the review's suggestion** (reasons on #35):
- **C16:** no ban on `set` from a row field; the field becomes that state's value, recorded under its capture level.
- **E2:** pooling uses its own flag, `viewer_independent`, and pooled requests fetch as the anonymous viewer.
- **I5:** `writes` kept for the standard state sources; not collapsed into cell actions.
- **T2:** "base render" for the replay artifact; "state snapshot" stays.

---

I've read all 16 spec files and §6 of the alignment doc. Findings follow, grouped by category, high severity first within each.

## 1. Contradictions

**C1 (high) — Base snapshot vs neutral mode.** 08 §2: a base snapshot is "the **neutral** render of a page version, content-addressed and shared by every visit" and "No data is stored." But 05 §3 (mode table) and 10 §2 define neutral as "as socketless … the first render from the deliveries," i.e. a render that contains data, and 02 §2 says sources filter by viewer, so that render is per-viewer. A per-viewer, data-bearing render cannot be content-addressed and shared by every visit while storing no data. *Fix:* define the base snapshot as the neutral render with every slot in its initial (pre-delivery) drawn state, or as chrome only, and say replay re-renders components from requery.

**C2 (high) — "Data values never reach records."** 02 §8: "Records, observation and state snapshots only ever see the recorded form, so data values never reach them." But the recorded form keeps `identity: %{field => value}` and `value: term` (02 §8, 08 §2), and `identity` is by definition a data value (a service name, a team). 08 §5 then admits "State values can themselves be personal." *Fix:* restate as "row values never reach them; identity and the event's own value do, and are governed by the capture level."

**C3 (high) — Flat parameters vs inline designs.** 05 §1.1 says a settings schema is "a map of parameters" whose `type` is "a data-model type (02 §1)" (`:time | :number | :category | :text | :color`). 06 §3 and 07 §3 say a cell "may carry a component's whole settings inline (a complete visualize design)." A design is a nested document, not a flat map of scalars; and 05 §1.1 itself introduces type `:term`, which is not a data-model type. *Fix:* add a `:document` parameter type (`{:document, kind}`) and either admit `:term` to the parameter type list or drop it.

**C4 (high) — Who writes state: `writes` vs cell `set` actions.** 05 §1.3/03 §1: a component declares `writes: [selection: :identity, …]` and "changes state only by emitting an event; the runtime applies it." 06 §5: the placement maps an event to `set: {state: focus, value: {event: identity}}`, "applied by the runtime as if the state's own event had been emitted," and validation of `set` never mentions `writes`. Two write paths; the first never says how an event name maps to a state source or which event field is written. *Fix:* state that `writes` applies only to the standard state sources (selection, window, camera…) by fixed name and field, and that every other state source is written through a cell action.

**C5 (medium-high) — Host ceiling: cap or refuse.** 01 (budget) and 02 §6: the ceiling "caps every slot's budget." 05 §1.2 and 02 §3: "A slot whose budget exceeds the ceiling is handed no rows, and the component draws `over_budget`." Capping and refusing are different behaviors; refusing also means a chart on a wide screen draws nothing where `reduced_by: :runtime` already provides a reduction. *Fix:* pick one; clamping to the ceiling with `reduced_by: :runtime` makes `over_budget` unnecessary.

**C6 (medium-high) — "Binding" in documents vs not.** 01: "binding: slot → source … owned by the host or the page document"; 03 §6: "Bindings are edges" of the page DAG built from the page document. 02 §7, 07 §1, 09 §2/§3: "Credentials and bindings never appear in documents," "Documents hold no functions, bindings or credentials." Same word, two meanings, contradictory statements. *Fix:* call the name→configured-source mapping "source configuration" (02 §7, 07 §1, 09) and reserve "binding" for slot→source and parameter→state.

**C7 (medium) — Budgets known at validation vs evaluated at runtime.** 07 §4: `declarations(settings)` "is called here, so slots, events, state writes, **budgets** and observation are known before anything renders." 05 §1.1: "The budget is the one exception: it is a function evaluated at runtime, under a ceiling fixed at validation." *Fix:* 07 §4 should say "budget ceilings," not budgets.

**C8 (medium) — Preference scope when anonymous.** 03 §1: preferences live "at `:viewer` scope when the host knows the viewer and `:page` otherwise," yet the same sentence promises a unit system "follows them across every component on every page." 03 §2 table: `:page` lives for "the page." 11 §3: the theme "persists … otherwise in the session." `:page` and `:session` are different scopes, and `:page` cannot follow across pages. *Fix:* `:session` otherwise, in 03 §1 and the 03 §2 example column.

**C9 (medium) — Missing reference: fault or mask.** 09 §2: "A missing reference masks its own site and is reported. Rendering never fails because of it." 12 §1: "An unknown name is a validation fault at its path"; 07 §4: a broken fetched document "is refused." *Fix:* a missing reference is a validation fault when the document is loaded; a reference that disappears after validation (store entry deleted) masks its site at render.

**C10 (medium) — Default scope stated and open.** 03 §2 table: "`:surface` (default)". 03 §2 last paragraph and 14 (experiment): "The default scope … settled by experiment." *Fix:* "provisionally `:surface`" in the table.

**C11 (medium) — Exports: component declaration or surface document.** 05 §1 table and §1.3 list "exports" as something a *component* declares. 03 §5 shows exports declared in the *surface document* as paths (`selected_service: cells.map.selection`), and 01 says surfaces, containers and cells publish them. *Fix:* drop exports from the component's declaration table; they belong to the placement document.

**C12 (medium) — `:local` hover never reaches the server vs `hover_item` observation.** 03 §2/10 §6: hover is the canonical `:local` value and "never reaches the server." 10 §5: `hover_item` is an observation "reported on enter and leave" to the host. *Fix:* say the hover *position* is local; enter/leave of an item is an observation event the component emits when enabled.

**C13 (medium) — Socketless budget "at the measured container."** 05 §3: the budget is evaluated at "the measured container live and socketless." 05 §3 (sizing bullet): "Until the first measurement, it lays out at the size its placement declares." Socketless renders have no JS, so no measurement ever arrives. *Fix:* "the declared placement size socketless, neutral and for the first live render; the measured container afterward."

**C14 (medium) — One kit vs two.** 12 §2: "There is **one kit**; adopters add checks to it as profiles, never a kit of their own." README row 12 and 00 §4: a source conformance kit in `macaw_data` and a component conformance kit in `macaw_compose`. *Fix:* "one kit per contract," or put both in one package.

**C15 (medium) — Derived-source inputs cross the dependency line.** 04 (a `macaw_data` file) lists "state sources" and "exports" as inputs (§2) and "the variable state sources at its scope" in context (§1); those are defined in `macaw_compose` (03), which depends on `macaw_data`, not the reverse (00 §4). *Fix:* 04 takes "sources" by name; 03 notes that state sources and exports satisfy the source contract and so are valid inputs.

**C16 (low-medium) — `row` values "never recorded" vs `set` from `row`.** 06 §5: `{event: [row, field]}` "is used live and never recorded; the record holds the resulting step." But a `set` from `row.field` writes a state source, whose value is recorded as a state event (08 §2). *Fix:* allow `set` from `row` only into state sources with no `record` level, or drop the "never recorded" claim.

**C17 (low) — Style hashes.** 00 goal 5: "`script-src` and `style-src` limited to the app's own files plus hashes." 10 §1: `style-src 'self'` and "No inline `style=` and no `<style>`." *Fix:* goal 5 says hashes for scripts only.

**C18 (low) — Page example fills a non-fillable region.** 06 §2: "a page's own last layer may only … fill regions declared fillable"; the `:site` template marks only `:sidebar` fillable. 06 §1's page fills `main`. *Fix:* mark `:main` fillable or state that `main` is always fillable.

**C19 (low) — Print layer: automatic or registered.** 06 §2: "Print is an automatic layer, stacked by the print and export mode," yet the example registers `layer :print, on: :site` by hand. *Fix:* remove it from the example or say the automatic layer is `:print` when registered.

**C20 (low) — Scene state lists differ.** 03 §1: a scene declares "`camera` and `breakpoints`." 05 §5: "Its camera and playhead are state sources." 03 §1 also says the playhead *is* the window plus `as_of`. *Fix:* one list (camera, breakpoints; playhead = window).

**C21 (low) — Initiator per declared event vs per instance.** 05 §1 table: events are declared "each marked visitor- or system-initiated." 02 §8: `initiator` is a field of each emitted event, and the same `moved` can come from a brush (visitor) or a timer (system). *Fix:* drop "each marked" from the declaration; initiator is per emission.

## 2. Errors

**E1 (high) — Legal values from data at validation time.** 05 §1.1 `legal_for: {slot, field, fact}` ("legal values follow from a bound slot's schema"), 03 §1 `values_from: "projects.tags"`, 06 §5 `values_from: "services.name"` with "Params are validated before anything renders." 07 §4 says validation is pure and runs "at build or boot"; 05 §1 says `declarations/1` is "no I/O." Reading a source's schema needs `describe/2` (a callback with a context, possibly I/O and viewer-dependent), and reading its *values* needs a fetch. At build there is neither a source connection nor a viewer. *Fix:* split validation into a static pass (shape, types, closed `values`) and a request-time check for `values_from`/`legal_for`; require `describe` to be callable without a viewer and cache it at boot.

**E2 (high) — Cross-viewer pooling trusts the source's self-declaration.** 02 §6: a request "whose result doesn't depend on the viewer, as the source's `reveals` declares," is fetched once and delivered to every viewer. `fetch/2` always receives the viewer (02 §2) and "may refuse, filter or tease by it." A source that filters but misdeclares leaks one viewer's rows to another. *Fix:* fetch pooled cross-viewer requests with the anonymous viewer, so the result is viewer-independent by construction, and give the flag its own name instead of overloading `reveals`.

**E3 (medium) — Gate order is impossible for encoded documents.** 07 §1: (1) "refuse a newer version by name … before anything else is read," (2) "check size limits before decoding," and "`depth` and `items` are checked before decoding." The `$version` stamp and the depth cannot be read without decoding. *Fix:* byte size before decoding; decode with depth/item limits; then version; then migrate; then validate.

**E4 (medium) — `reduced_by: :component` and `over_budget` don't belong in a delivery.** 02 §3 puts `:component` ("the component reduced further while drawing") and `over_budget` in the delivery, but the delivery is produced before the component draws, and when the budget exceeds the ceiling no fetch happens, so there is no delivery. The struct in 02 §2 (`%Delivery{table, schema, served, origin}`) has no `over_budget` field. *Fix:* `reduced_by` has two values; `over_budget` and component-side reduction are drawn states (05 §4), not delivery facts.

**E5 (medium) — Reading load from data counts.** 05 §1.4: "visualize derives `:scan` … from its summary's counts," but reading load is a configured declaration (05 §1, pure over settings). If "summary" means the delivered data, this is a runtime value. *Fix:* say "from its design's mark and layer counts" if that is meant, else move reading load out of declarations.

**E6 (medium) — `:shared` scope has no holder.** 03 §2 defines `:shared` ("every viewer of that surface") but the only cross-process mechanism named is for persistent regions (03 §6, 14). A state source shared by many LiveView processes needs a named owner. *Fix:* add `:shared` and cross-page pooling to the 14 "cross-process" item and name the owner (a host behavior or a registered process).

**E7 (medium) — Hooks "without a build step."** 12 §1: "each package contributes its hooks as static files … There is no build step." A LiveView hook only runs if registered in the host's `LiveSocket` `hooks` option, which lives in the host's bundled JS. *Fix:* "no build step in Macaw; the host imports and registers each enabled package's hook modules in its LiveSocket."

**E8 (low-medium) — Links example fails its own validation.** 03 §7: "both sides must be declared identity fields of sources on the surface," but the example maps `name` and `svc` to `service`, which may be a field of no source. *Fix:* the canonical name may be any name; only the left side must be a declared identity field.

**E9 (low) — `cells.map.selection`.** 03 §5 exports a cell's `selection`, but `selection` is `:surface`-scoped by default (03 §2), so it is not the cell's. *Fix:* `selected_service: selection`.

**E10 (low) — Focus precedence on navigation.** 10 §4 table: navigation moves focus "to the new `<h1>`," and "within a persistent region | kept." Both apply when focus is in a persistent sidebar during live navigation. *Fix:* "to the new `<h1>`, unless focus was inside a persistent region."

## 3. Gaps

**G1 (high) — Source request params have no binding path.** 02 §2 gives sources `params` ("metresis's aggregation"), and 06 §5 says "source requests may bind them [page params]," but 01's binding definition covers only slot→source and parameter→state, and 03 §6's DAG has no edge for a state source feeding a request param. There is no declared way for a control to change a source's aggregation and trigger a re-fetch. *Fix:* define a request binding (`params: {aggregation: {:state, "agg"}}`) as a DAG edge.

**G2 (high) — Capture levels are never defined.** 03 §1 `record: :full`, 03 §3 "capped by capture level," 08 §5 "nothing finer than page level," 01 §5 renames dcotek_web's "level" to "capture level" — but no file lists the levels or their order. *Fix:* define the capture-level scale in 01 and 08.

**G3 (medium) — How a placement's kind is chosen.** 05 §2: "The region or container selects the clause … A cell is valid only where its placement's kind is one of the component's kinds." Regions declare landmark `role`s (06 §2), not kinds, and a surface holds many cells. The role→kind mapping and the per-cell kind are unspecified. *Fix:* give cells a `kind:` (defaulting from the region role) and state the mapping.

**G4 (medium) — `describe/2` context and `ParamSchema`.** 02 §2 uses `context` undefined (fetch uses `viewer` inside `Request`), and `ParamSchema.t()` is never related to 05 §1.1's parameter shape despite 07 §3's "one shape." *Fix:* define `context`, and say `ParamSchema` is a map of parameters (05 §1.1).

**G5 (medium) — The "window field."** 02 §2: window is "meaningful only when the schema has a window field"; 03 §1: "a `:time` window field." 02 §1's schema fields have no window marker, and `box` windows need a geo field type that `:time | :number | :category | :text | :color` lacks. *Fix:* add `window: true` to the schema and a geo/`:point` type, or say the window field is the first `:time` field.

**G6 (medium) — PubSub is a host behavior, missing from goal 3.** 02 §5 and §6 route change notification and cross-page pooling "through the host's PubSub," but 00 goal 3's behavior table (viewer, observation, store, persistence, recording, navigation) has no row for it, and goal 2 says a host needs no framework. *Fix:* add a "notification/pooling" behavior with a default (in-node, no PubSub).

**G7 (medium) — Derived source model fields.** 04 §1: `%{id, from: [{name, window}], schema, elixir | function, per}` — `per` is never explained, and `function` names a `defsource` reference while the same sentence says "It contains no function value." *Fix:* define `per` and rename the field `defsource`.

**G8 (medium) — Which components are contained.** 05 §4: pure components render in the page process; "a component with server work" gets a contained cell. No declaration says which a component is. *Fix:* add an `isolation`/`server_work` declaration to the 05 §1 table.

**G9 (medium) — Instance id and element shape.** `instance` (02 §8, 03 §2) is never defined in 01, and `element: %{frame, item, path}` is visual-specific; a prose component has no frame. *Fix:* define "instance" in 01; make `frame` optional and explain `path` for non-visual components.

**G10 (low-medium) — Fetched documents vs build-time CSS.** 07 §1/§4 accept documents fetched at runtime; 10 §3 compiles "one stylesheet per site, generated from the stacks in use" at build. A fetched page using a new combination of registered layers has no CSS. *Fix:* compile CSS per registered template and layer, not per stack, and say fetched pages may stack only registered layers.

**G11 (low) — Derived-source fault → drawn state.** 04 §1: "The last good output survives a fault." 05 §4 lists drawn states but never says which one a faulting input produces. *Fix:* `stale` with the fault as its words.

**G12 (low) — Built-ins and the registry.** 12 §1 enables packages by name; 00 goal 8 says built-ins "use the same public contracts as any package." Whether `macaw_compose`'s own components need enabling is unsaid. *Fix:* one sentence.

**G13 (low) — Geometry transforms in the sandbox allowlist.** 04 §5: transforms with `needs: [:frame]` "register through the registry like any other member," and the allowlist is "generated from the registered members." A derived source has no frame. *Fix:* exclude members with `needs` from the derived allowlist.

**G14 (low) — Store `get(id, context)`** takes an untyped id while 09 §2 says references are `{kind, id}` and wrong kinds are "refused before resolution." *Fix:* `get({kind, id}, context)`.

**G15 (low) — State snapshots tied to recording.** 03 §4: "a state source that may not be recorded is not exported either," so a persisted-but-unrecorded filter is lost on restore, undercutting goal 9. *Fix:* govern snapshots by persistence, with a separate opt-out for personal values.

## 4. Inefficiencies / over-specification

**I1 (medium) — The CSP delivery rule is stated twice in full.** 05 §3 (six bullets) and 10 §1 (six numbered rules) are near-identical, and "every first render has a static form" appears in both. *Fix:* keep 10 §1, and have 05 §3 cite it in one line.

**I2 (medium) — The data-color rule is stated three times.** 02 §1, 05 §3 and 11 §1 each give the full rule (non-color cue, contrast guard, never sole carrier). *Fix:* 11 §1 owns it; the others cite.

**I3 (medium) — Inline-or-referenced settings is stated three times.** 01 (cell), 06 §3 and 07 §3 each explain presets plus overrides stacking the same way. *Fix:* 07 §3 owns it.

**I4 (low-medium) — Import-as-relocation is duplicated.** 09 §2 and 09 §3 carry the same three bullets. *Fix:* delete one.

**I5 (low-medium) — Two write mechanisms where one suffices.** See C4: `writes` by fixed name plus cell `set` actions do the same job; if `set` is the general mechanism, `writes` reduces to a declaration of what the component's events carry. *Fix:* collapse into "events carry typed values; placements map them to state."

**I6 (low) — `over_budget` as a ninth drawn state** (05 §4) exists only because of the refuse-rather-than-clamp rule (C5); clamping removes a state, a delivery field and a mode rule. *Fix:* see C5.

**I7 (low) — Two client buses and two announcer paths.** 10 §6 has `macaw_live`'s bus plus visualize's "compatible bus of its own," while 10 §4 solves the same problem for the announcer with "found, not rendered." *Fix:* apply the found-not-created rule to the bus too.

## 5. Terminology drift

**T1 (high) — "record" / "records."** 01 §3: a *record* is "what makes a view reproducible." 13 and 00 §4: `macaw_records` is a data-*editing* library ("Editing records"). Same word, two unrelated meanings, in violation of 01's "one word, one meaning." *Fix:* rename the editing library (`macaw_edit`/`macaw_write`) or the replay artifact ("trace").

**T2 (medium-high) — "snapshot."** Two defined terms share it (base snapshot, 01 §3; state snapshot, 01 §4), visualize's `Board.Snapshot` was renamed *because* of it, and bare "snapshot(ted)" appears in 07 §1 ("Records and snapshots cite it"), 08 §2 ("a page's snapshot"), 10 §3 ("snapshotted") and 14. *Fix:* rename base snapshot → "base render," never use bare "snapshot."

**T3 (medium) — "kind."** 01 defines kind as a render role. It is also used for document kinds (07 §1 "per document kind," 09 §2 `{kind, id}`, 01 "fragment … of a derived kind"), for container types (05 §4 "a container kind running a nested LiveView"), and for "frame kinds" (12 §1). *Fix:* "document type" for 07/09, "container pattern" in 05 §4.

**T4 (medium) — "composition."** 10 §4: "which the composition owns," "however many compositions and adopters the page holds," "found, not rendered per composition." Not a defined term; 01's words are page and surface. *Fix:* "page" or "surface."

**T5 (medium) — "export."** 01 §2 defines export as published state; 03 §4 "exported and restored," 09 §2 "An export takes the transitive closure," 08 §2 "is an export, never a record," 00 goal 1 "prints or exports." 01 §5 renamed visualize's `Board.Export` to **output** to avoid exactly this. *Fix:* "output" for page/printout output, "bundle" for store export.

**T6 (medium) — "setting."** 01 defines parameter as "one typed setting of a component"; 06 §2 uses `setting :sidebar, values: …, default:` for a template option (a parameter by shape) and 11 §3 "the user's settings" for host storage. *Fix:* "A template declares its options as parameters"; "the host's user store" in 11 §3.

**T7 (medium) — "surface" as background.** 02 §1 and 11 §1: "a contrast guard against the surface." Surface is a defined composed unit (01). *Fix:* "against the background."

**T8 (medium) — "slot" for theme extension.** 00 §4 "registers its theme slots," 11 §1 "theme slots" and "an override slot the page masks." Slot is a component's typed data input (01). *Fix:* "theme roles" / "theme extension."

**T9 (medium) — "state" as the component's runtime value.** 05 §4: `init → state`, `state(state, name, value) → state`, while "state" everywhere else means interaction state and the `state/3` transition is the one that delivers *state sources*. *Fix:* call the runtime value "value" (the text already says "a pure value with transitions") and the transition `bound/3`.

**T10 (low-medium) — "visitor" vs "viewer."** 01 defines viewer only; "visitor-initiated," "the visitor moved," "the visitor's observation" run through 02, 05, 08. *Fix:* define visitor (the person; viewer is the host's context for them) or use viewer.

**T11 (low) — "placement" / "instance" / "cell" / "place."** 01: cell = "a placement of a component"; 02 §8 "the emitting placement's instance id"; 03 §2 "component instance (its place plus the component plus a key)." *Fix:* define instance; use cell for the document and instance for the runtime.

**T12 (low) — "layer."** Template layer (01), "the live layer" (00 goal 4, 03 §6, 14), "page-shortcut layer" (10 §4). *Fix:* "`macaw_live`" and "page-shortcut registry."

**T13 (low) — "profile."** Validation profile (`:roles`, `colors: :open`, 11 §1) vs conformance-kit profiles (12 §2). *Fix:* "check set" for the kit.

**T14 (low) — "action."** Cell action (01, 06 §5) vs write actions, "effect-shaped … `{:accepted, handle}`" (13 §2). *Fix:* "operation" in 13.

**T15 (low) — "`:shared` surface."** 02 §6 says "A `:shared` surface"; `:shared` is a state scope (03 §2). *Fix:* "a surface whose state is `:shared`."

**T16 (low) — "document" for a standalone file.** 10 §1 "A self-contained document is not a page" uses document (01: a validated declarative value) for an exported SVG/PNG. *Fix:* "a standalone file."

**T17 (low) — Registry member lists differ.** 01: "components, templates, layers, sources, functions and hooks"; 12 §1 first line: "… derived-source functions and hooks"; 12 §1 bullet 2: "components, templates, layers, sources, transforms, aggregates, marks, frame kinds, hooks." *Fix:* one list in 12 §1, cited by 01.

**T18 (low) — Neutral mode wording.** 05 §3 "no hooks, no tokens and no live regions"; 10 §2 "no hooks, scripts, prefixes or per-viewer markup." "Prefixes" is undefined. *Fix:* one definition in 10 §2.

## 6. Stale references

**S1 (medium) — Three names for one adopter.** `dcotek_web` (00 §1, 01 §5, 06 §5 `dcotek_web#130`, 14 `dcotek_web#130`, every `dcotek_web.md C<n>` citation), `macaw_server` (00 goal 6, 00 §5 "macaw_server on `macaw_compose` and `macaw_live` (macaw#130)"), and the issue cited as both `dcotek_web#130` and `macaw#130`. *Fix:* one name throughout, with the rename noted once in README (requirements file names can stay as filenames).

**S2 (low-medium) — Superseded issues cited as live.** 00 §5 step 2: "visualize's planned extractions (#880, #893, #912) are closed there as superseded." Yet 07 §1 "starts from visualize's planned `Visualize.Document` (visualize#912), which moves to Macaw," 07 §1 cites "(visualize#912; …)" for the digest, and 01 §5 "`Chart.Schema` renamed (visualize#893)." *Fix:* cite the Macaw step (00 §5 step 2) instead, or mark "(superseded)."

**S3 (low) — "composex."** README last line keeps the working name for the study draft; intentional and fine. No occurrences of `macaw_visualize`, `cx-` (themes use `mw-`), or "never depend on each other" remain.

**S4 (low) — Host-specific detail in a generic rule.** 10 §1: "Only a host's own small inline script (dcotek_web's tracking plan) is hashed," and 00 goal 1 "CSP hash … right for this exact combination" (the hash is of host code, not of the component combination). *Fix:* generalize to "a host's own inline script, if any."

---

Files reviewed: `/home/dco/Projects/macaw_compose/spec/README.md`, `00-overview.md` through `14-open.md`, and `/home/dco/Projects/macaw_compose/design/visualize-alignment.md` §6 (lines 835–863, used only to see which sections R1–R20 and Q3–Q14 touched; the amendments' footprints match where the above cross-file conflicts cluster: 02 §3/§6, 03 §1/§2, 05 §1–§3, 06 §5, 08 §2, 10 §1/§4). Nothing was edited.