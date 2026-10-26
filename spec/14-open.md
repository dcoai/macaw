# 14 — Open and deferred questions {#open}

## By experiment, once code exists {#open-experiment}

| Question | Issue | How it's settled |
|---|---|---|
| the default state scope, and the persistence behavior's shape | macaw_compose#3 | the example-app experiment: a picker, cards and a table, and a persistent menu, with persistence switched between none, session and URL |
| grid row placement | macaw_compose#5 | DOM order plus column classes, if every visualize and metresis board fixture renders identically |

## Deferred until needed {#open-deferred}

| Question | Issue | Needed when |
|---|---|---|
| ids on object storage | macaw_compose#4 | an exio-backed store is built |
| the records library's shapes (actions, change sets, conflict display, how writes are recorded) | macaw_compose#9 | the records library starts |
| edges of the page DAG crossing processes (persistent regions) | — | the live layer is built |
| a runtime page builder | — | after v1 ([06](06-pages.md#pages-runtime)) |

## In the adopting projects {#open-adopters}

| Project | Questions | Issue |
|---|---|---|
| dcotek_web | live navigation when pages' observation plans differ; where token emphasis lives, and whether it narrows down share chains; the PDF résumé as a page view or an event; content in exio (spec amendment) and when it is snapshotted | dcotek_web#130 |
| metresis | placing a single panel; what a click means on a public page; a read-only alerts scope; a comparison source | metresis#556 |
| visualize | `Board.Server`'s shared state vs per-viewer state; which open proposals to re-scope against Macaw | visualize#938 |
