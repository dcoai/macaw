# macaw_compose

Part of **Macaw**, a family of building blocks for live, data-driven applications on Phoenix LiveView. `macaw_compose` is the composition library: it composes pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and Macaw runs them per viewer: rendered on the server, safe under a strict security policy, and reproducible afterwards.

Macaw exists for **composition effects**: components composed through it gain effects none of them has alone (cross-highlighting without wiring, a write updating every reader, whole-page replay and links, correct disclosure), for every combination, by declaring themselves once (N + M, not N × M). It does this in **any** Phoenix LiveView app: every host concern (viewer, observation, store, persistence, navigation) is a behavior with a working default.

## The family

| Package | Holds |
|---|---|
| `macaw_layers` | documents, fragments, stacking and masks, themes |
| `macaw_data` | the data model, sources, derived sources |
| `macaw_compose` | state, the page DAG, components, pages and surfaces, records (this project) |
| `macaw_live` | the LiveView runtime |
| `macaw_edit` | data-editing components (later) |
| `macaw_plug`, `macaw_host`, `macaw_auth` | host libraries: request guards, host glue, authentication (outside the composition model) |

**visualize** keeps its own name and depends on `macaw_layers` and `macaw_data`. Its visuals are Macaw components from visualize itself, through an optional dependency on `macaw_compose`. Dependencies run one way: an adopter may depend on Macaw, never the reverse.

## Status

Spec first. Nothing is implemented yet.

- [`spec/README.md`](spec/README.md): the model for the whole family, by library.
- [`design/requirements/`](design/requirements/): the requirement reports it was derived from, one per adopting project (visualize, metresis, and macaw_server under its former name, dcotek_web).

Changes go through proposals (GitLab issues): `Research` while a direction is being shaped, `Proposal` when it is ready to evaluate.

*Formerly "composex"; renamed 2026-10-26 when the libraries were split under the Macaw family name.*
