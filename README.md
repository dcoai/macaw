<img src="brand/logo/macaw_scarlet.svg" alt="The Macaw logo, a scarlet macaw in flight" width="128">

# macaw

> **This software is a very early release, and not ready for general use.**

Public home: [github.com/dcoai/macaw](https://github.com/dcoai/macaw) · Docs: [hexdocs.pm](https://hexdocs.pm/macaw)

The core of **Macaw**, a family of building blocks for live, data-driven applications on Phoenix LiveView. `macaw` composes pages out of independent components, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and Macaw runs them per viewer: rendered on the server, safe under a strict security policy, and reproducible afterwards.

Macaw exists for **composition effects**: components composed through it gain effects none of them has alone (cross-highlighting without wiring, a write updating every reader, whole-page replay and links, correct disclosure), for every combination, by declaring themselves once (N + M, not N × M). It does this in **any** Phoenix LiveView app: every host concern (viewer, observation, store, persistence, navigation) is a behavior with a working default.

## Status

From Hex:

```elixir
{:macaw, "~> 0.1.2"}
```

**v0.1.0: surfaces with a grid,** validated and rendered complete without a socket, and the built-in table ([spec/06 §3](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-regions)). State, pages and templates, records, the web plans and the live runtime follow, each tracked by its own issue ([spec/00 §5](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-order)).

```elixir
registry = Macaw.Registry.new!([Macaw.Builtin])
sources = %{"latency" => {my_source, my_context}}

{:ok, surface} =
  Macaw.Surface.new(
    name: "service",
    title: "Service",
    cells: %{
      "latency" => %{
        component: "macaw.table",
        settings: %{"caption" => "Latency", "sort" => "ms"},
        place: %{x: 0, y: 0, w: 8, h: 4},
        slots: %{"rows" => %{source: "latency"}}
      }
    }
  )

{:ok, validated} = Macaw.Surface.validate(surface, registry, sources)
html = Macaw.Surface.render(validated, sources: sources, now: DateTime.utc_now(), ceiling: 10_000)
```

Serve `Macaw.Grid.stylesheet/0` at `Macaw.Grid.stylesheet_path/0`; nothing is inline.

| Module | What it is | Spec |
|---|---|---|
| `Macaw.Surface`, `Macaw.Surface.Cell` | the surface document and its cells: forms, version line, fragment type; validation, fetching and rendering | [06 §3.1–3.6](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-document) |
| `Macaw.Grid` | the 12-column grid: bounds, overlaps, reading order, classes and the static stylesheet | [06 §3.3](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-grid) |
| `Macaw.Registry` | a host's registry of components, built from the packages it enables | [12 §1.1](https://github.com/dcoai/macaw/blob/main/spec/12-registry.md#registry-host) |
| `Macaw.Builtin`, `Macaw.Builtin.Table` | the built-in package and its table | [05 §6.1](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-table) |

## The family

| Package | Holds |
|---|---|
| `macaw_layers` | documents, fragments, stacking and masks, stores, themes |
| `macaw_data` | the data model, sources, derived sources, operations |
| `macaw_component` | the component contract and its conformance kit, used without the core |
| **`macaw`** | the core: state, the page DAG, pages and surfaces, records (this repository, `dco-tek/macaw/macaw`) |
| `macaw_live` | the LiveView runtime (later) |
| `macaw_edit` | data-editing components (later) |
| `macaw_plug`, `macaw_host`, `macaw_auth`, `macaw_auth_ash` | host libraries: request guards, host glue, authentication (outside the composition model) |

What another library uses lives in its own library: **visualize** keeps its own name, depends on `macaw_layers` and `macaw_data`, and makes its visuals Macaw components through an optional dependency on `macaw_component`, never the core. Dependencies run one way.

Every Macaw library is built the same way: its own spec, surfex as a CI gate, depdep in CI, and extla models only for state-managing GenServers ([spec/00 §4.1](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-library-rule)).

- [`spec/README.md`](https://github.com/dcoai/macaw/blob/main/spec/README.md): the model for the whole family, and the core's spec.
- [`design/requirements/`](https://github.com/dcoai/macaw/blob/main/design/requirements/): the requirement reports it was derived from, one per adopting project (visualize, metresis, and macaw_server under its former name, dcotek_web).

Changes go through proposals (GitLab issues): `Research` while a direction is being shaped, `Proposal` when it is ready to evaluate.

*Formerly "composex", then `macaw_compose`; the core became `macaw` on 2026-10-28 (#137), and every Macaw project moved into the `dco-tek/macaw` group (#151, #152).*
