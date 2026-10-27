# Macaw specification

Macaw is a family of building blocks for live, data-driven applications. Together they compose pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and Macaw runs them per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

**Status:** `macaw_layers` v0.1.0 (the document kernel), `macaw_data` v0.3.0 (the interaction event, the data model, and the source contract with its kit) and the host libraries are implemented; the rest is spec. Decisions are recorded on macaw_compose#1 and the issues it links.

**Each component has its own spec in its own repository** (owner, 2026-10-27; #61). This one holds the family's anchor (00 overview, 01 vocabulary, 14 open questions) and the specs of components that have no repository yet, each row naming its library; a component's sections move to its repository when the repository is created. Sections keep their anchors when they move, so links into them stay stable.

| File | Covers | Library |
|---|---|---|
| [00 — Overview](00-overview.md) | purpose, goals (composition effects first), non-goals, the libraries, order of work | all |
| [01 — Vocabulary](01-vocabulary.md) | every term, one meaning each, and the renames in the adopting projects | all |
| [macaw_data 01 — Sources](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md) | the data model, the source contract, deliveries, push, change notification, the interaction event | `macaw_data` (moved, #62) |
| [03 — State](03-state.md) | state sources, scopes, persistence and recording, exports, the page DAG | `macaw_compose` |
| [macaw_data 02 — Derived sources](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/02-derived.md) | checked, bounded, deterministic functions over sources | `macaw_data` (moved, #62) |
| [05 — Components](05-components.md) | the component contract, kinds, drawn states, isolation, containers | `macaw_compose` |
| [06 — Pages](06-pages.md) | pages, templates, layers and masks, regions, surfaces, persistent regions, the runtime builder (deferred) | `macaw_compose` |
| [macaw_layers 01 — The document kernel](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/01-kernel.md) | names, vocabularies, faults, version lines, the gates, the forms and tags, the digest | `macaw_layers` (moved, #95) |
| [macaw_layers 02 — Fragments and stacking](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/02-fragments.md) | fragments, composites, use sites, stacking, masks, `explain` | `macaw_layers` (moved, #95) |
| [07 — Documents](07-documents.md) | composable data, validation time | `macaw_compose` |
| [08 — Records](08-records.md) | view paths, base renders and events, attention, requery, the two stores | `macaw_compose` |
| [macaw_layers 03 — Stores](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/03-stores.md) | the store behavior, typed references, bundles, portability | `macaw_layers` (moved, #95) |
| [10 — The web](10-web.md) | CSP, rendering modes, responsive layout, accessibility | `macaw_compose`, `macaw_live` |
| [macaw_layers 04 — Themes](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/04-themes.md) | one theme system: rules and delivery | `macaw_layers` (moved, #95) |
| [11 — Themes](11-themes.md) | switching at runtime, user themes | `macaw_compose`, `macaw_live` |
| [12 — Registry](12-registry.md) | explicit registration, the conformance kits (one per contract) | `macaw_compose` (source kit: `macaw_data`) |
| [13 — Writes](13-writes.md) | the four seams; what belongs to `macaw_edit` | `macaw_compose`, `macaw_edit` |
| [14 — Open questions](14-open.md) | by experiment, deferred, and in the adopting projects | all |

**Sources:** requirements from the adopting projects are in [`design/requirements/`](../design/requirements/) (`visualize.md`, `metresis.md`, `dcotek_web.md`), cited in each file as `<project>.md C<n>`. `dcotek_web` is the former name of **macaw_server**, the content server (renamed 2026-10-26); its requirements file and citations keep the old name, and its issues are cited as `macaw#<n>`. The first draft of the model, written under the working name "composex", is kept as [`design/study-draft-1.md`](../design/study-draft-1.md).
