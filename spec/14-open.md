# 14 — Open and deferred questions {#open}

## By experiment, once code exists {#open-experiment}

| Question | Issue | How it's settled |
|---|---|---|
| the default state scope, and the persistence behavior's shape | macaw_compose#3 | the example-app experiment: a picker, cards and a table, and a persistent menu, with persistence switched between none, session and URL |

Grid row placement (#5) is settled by construction: placement by classes from one static stylesheet, rows included ([06 §3.3](06-pages.md#pages-grid), #154).

## Deferred until needed {#open-deferred}

| Question | Issue | Needed when |
|---|---|---|
| ids on object storage | macaw_compose#4 | an exio-backed store is built |
| `macaw_edit`'s shapes (operations, change sets, conflict display, how writes are recorded) | macaw_compose#9 | `macaw_edit` starts |
| edges of the page DAG crossing processes: persistent regions, `:shared` state's owner, cross-page pooling | — | `macaw_live` is built |
| a runtime page builder | — | after v1 ([06](06-pages.md#pages-runtime)) |

## In the adopting projects {#open-adopters}

| Project | Questions | Issue |
|---|---|---|
| macaw_server | live navigation when pages' observation plans differ; where token emphasis lives, and whether it narrows down share chains; the PDF résumé as a page view or an event; content in exio (spec amendment) and when its base render is taken | macaw#130 |
| metresis | placing a single panel; what a click means on a public page; a read-only alerts scope; a comparison source | metresis#556 |
| visualize | settled by macaw_compose#22: shared vs per-viewer state is scopes plus cross-page pooling, and the re-scoping is visualize#940's amendments. Open there: the board deprecation release (one release, the owner's choice) and the details of the board-to-surface migration | visualize#940, #947 |
