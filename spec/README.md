# composex specification

composex composes live, data-driven pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and composex runs them per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

**Status:** spec only; nothing is implemented. Decisions are recorded on composex#1 and the issues it links.

| File | Covers |
|---|---|
| [00 — Overview](00-overview.md) | purpose, goals (composition effects first), non-goals, packaging, order of work |
| [01 — Vocabulary](01-vocabulary.md) | every term, one meaning each, and the renames in the adopting projects |
| [02 — Sources](02-sources.md) | the data model, the source contract, deliveries, push, change notification |
| [03 — State](03-state.md) | state sources, scopes, persistence and recording, exports, the page DAG |
| [04 — Derived sources](04-derived.md) | checked, bounded, deterministic functions over sources |
| [05 — Components](05-components.md) | the component contract, kinds, drawn states, isolation, containers |
| [06 — Pages](06-pages.md) | pages, templates, layers and masks, regions, surfaces, persistent regions, the runtime builder (deferred) |
| [07 — Documents](07-documents.md) | the document kernel, fragments and stacking, validation time |
| [08 — Records](08-records.md) | view paths, base snapshots and events, attention, requery, the two stores |
| [09 — Stores](09-stores.md) | the store behavior, typed references, bundles |
| [10 — The web](10-web.md) | CSP, rendering modes, responsive layout, accessibility |
| [11 — Themes](11-themes.md) | one theme system, delivery, runtime switching, user themes |
| [12 — Registry](12-registry.md) | explicit registration, the conformance kit |
| [13 — Writes](13-writes.md) | the four seams; what belongs to a records library |
| [14 — Open questions](14-open.md) | by experiment, deferred, and in the adopting projects |

**Sources:** requirements from the adopting projects are in [`design/requirements/`](../design/requirements/) (`visualize.md`, `metresis.md`, `dcotek_web.md`), cited in each file as `<project>.md C<n>`. The first draft of the model is kept as [`design/study-draft-1.md`](../design/study-draft-1.md).
