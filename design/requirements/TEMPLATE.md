# Requirements template: unified concepts across visualize, metresis and dcotek_web

For EACH concept below, report the project's **requirements**: what it needs, and the constraints a shared model must honor. Describe the current mechanism only briefly, as evidence. Each requirement must be:
- tagged MUST or SHOULD;
- given a one-line rationale;
- cited (spec file and section, or issue number);
- marked "(current)" if built, "(planned: #n)" if only proposed, or "(implied)" if inferred by you.

## Concepts
C1  Sources: data a part consumes. Parameters, time window or not, schema/semantics of fields, budget/limits, push vs pull, errors, versioning of results.
C2  Virtual / derived sources: data computed from other sources (transforms, joins, aggregates), sandboxing, limits. ALSO: could a part's interactive state (a selection, chosen items, a brush window) be exposed as a source others consume?
C3  Parts / components: the units placed on a surface (chart, cell, panel, block): settings schema, rendering, lifecycle, packaging so another project can ship parts.
C4  Composition / layout: how parts are arranged (grid, flow, regions, responsive stacking, reading order, nesting).
C5  Shared state, events and interaction between parts: variables, window, selection, drill, wiring, who owns state (per viewer vs shared), event vocabulary.
C6  Documents: the declarative form (manifest, design, board): shape, validation and error reporting, versioning and migration, size limits, atom safety.
C7  Snapshots / replay / provenance: freezing what was shown or computed, and reproducing it later.
C8  Stores: where documents and content live and how they are referenced (ids, names, versions, object storage).
C9  Registries / extension: how new parts, sources, transforms and hooks are registered; third-party extension.
C10 Rendering targets and web constraints: server first render, LiveView, hooks/JS, CSP, static/no-socket rendering, themes and dark mode, accessibility.
C11 Identity, auth and capabilities: who may see or do what (tokens, scopes, domains, roles, visitor levels), and how that reaches sources and parts.
C12 Privacy, tracking and observation: what is recorded about viewers, declared disclosure, limits.
C13 Isolation, limits and failure: timeouts, heap or reduction limits, crash containment, how a failed part is shown.

## Output format
- A header with project, date and the sources read.
- One section per concept C1–C13 (write "no requirements" if truly none): Requirements (bulleted, tagged and cited), Current mechanism (2–4 lines), Constraints a unified model must not break.
- A final section, "Vocabulary": every term the project uses for these concepts, with its exact meaning (e.g. "slot", "layout", "snapshot", "store", "schema", "cell", "panel", "feed", "source", "board", "dashboard", "design", "manifest", "binding").
- A final section, "Open questions found".
