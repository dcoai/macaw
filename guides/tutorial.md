# Tutorial

This tutorial teaches Macaw from nothing to the depths of what `macaw` 0.3.0 ships. It's
for Elixir developers new to Macaw: you'll write sources, compose surfaces, build and
test components, store documents, theme them and serve them from Phoenix, with every
example run against the released code.

## What Macaw is

Macaw is a family of building blocks for live, data-driven applications on Phoenix. It
composes pages out of **independent components** that share **typed data** through one
**source contract**. You declare the arrangement and the data flow in validated
documents, and Macaw renders them on the server: complete HTML, nothing inline, safe
under a strict Content Security Policy.

The reason to compose through Macaw is **composition effects**: components that declare
themselves once (their data inputs, the state they write, what they observe, how they
render) gain behavior none of them has alone, for every combination, without wiring each
pair. Shared fetching, one "now" across a page, honest notices when data is missing, one
theme and one heading outline are the effects the released core already delivers; the
rest arrive with the runtime still to come.

## The family

```text
macaw_layers ← macaw_data ← macaw_component ← macaw
  documents,     sources,     the component     the core: surfaces,
  faults,        schemas,     contract, its     layouts, the registry,
  fragments,     tables,      context, drawn    validation, fetching,
  stores,        deliveries,  states and its    rendering, the built-in
  themes         operations,  conformance kit   table
                 derived
                 sources
```

- **`macaw_layers`**: the document kernel (names, faults, digests, and the JSON adapter
  with its gates), fragments and stacking, stores and bundles, colors and themes.
- **`macaw_data`**: the data model (schemas, tables, deliveries, units), the source
  contract and its conformance kit, operations, and derived sources.
- **`macaw_component`**: the component contract, rendering rules, drawn states and the
  component conformance kit. Component packages depend on it without the core.
- **`macaw`**, this package: surfaces and their layouts (the grid, the stack, the flow
  and named areas), the registry of enabled components and layouts, validation, fetching
  and rendering, the one-call `show/2` and the short code form, and the built-in table.

Dependencies run one way, left to right. Installing `macaw` brings the other three.

Across the family, **internal data is BEAM terms**. A surface, a schema, a theme or a
cell's settings is the Elixir value it is: a color is a `%Macaw.Layers.Color{}`, a time
a `DateTime`, a point a `{longitude, latitude}` tuple, and every name a string. Identity
and validity are judged on that value. JSON is an adapter at the edge, for storing and
sending documents, and it refuses what it can't hold.

## How to read it

Read chapters 1 to 4 in order: they build one running example and introduce every core
idea. After that, chapters stand on their own; read the ones you need. Each chapter
starts with what you'll learn and ends with pitfalls and a recap.

Code blocks build on earlier blocks in the same chapter. Modules (`defmodule`) go in your
project's `lib/` (tests in `test/`); the rest you can run in `iex -S mix`. A line
`#=> value` shows what the expression above it returns. The examples use modules from
earlier chapters, `MyApp.Services` and `MyApp.Latency` most of all.

## Contents

1. [Your first surface](tutorial/01-first-surface.md): install Macaw, write a source,
   render a surface in five lines, and see what they expand to.
2. [Sources](tutorial/02-sources.md): the source contract, descriptions, parameters,
   requests, finishing, the ceiling and pooling, and pushing sources.
3. [Schemas, tables and deliveries](tutorial/03-schemas-and-data.md): what data means,
   units and quantities, columnar tables, and deliveries' served facts.
4. [Surfaces in depth](tutorial/04-surfaces.md): cells, layouts (the grid, the stack,
   the flow and named areas), cells as a list, the registry, validation and its faults,
   fetching, viewers, drawn states, rendering options.
5. [The built-in table](tutorial/05-the-table.md): settings, sorting, selection,
   columns and headers, budgets, notices, its stylesheet, and what it leaves to you.
6. [Writing components](tutorial/06-components.md): the component contract, slots and
   roles, rendering, contained components, packages and hooks.
7. [Testing with the conformance kits](tutorial/07-testing.md): the component kit, the
   source kit, and testing surfaces.
8. [Surfaces as documents](tutorial/08-documents.md): a surface's value and its JSON
   adapter, gates and limits, faults, layering with fragments, stores and bundles.
9. [Themes and styles](tutorial/09-themes.md): themes, the stylesheet, colors, data
   colors and styling surfaces.
10. [Surfaces in a Phoenix app](tutorial/10-phoenix.md): configuration, controllers,
    LiveViews and serving stylesheets.
11. [Operations and derived sources](tutorial/11-operations-and-derived.md): table
    operations, statistics, derived sources and their engine.

## What's released, and what isn't

`macaw` 0.3.0 holds **surfaces**, validated and rendered complete without a socket, and
the built-in table, on `macaw_layers` 0.4, `macaw_data` 0.10 and `macaw_component` 0.4. A
surface's layout is a behavior, `Macaw.Layout`, with the grid (6, 12 or 24 columns), the
stack, the flow and named areas built in, and a host's registry holds the layouts it
allows as it holds components. A surface and its cells' settings are terms, checked at
validation against the types the components and sources declare, with JSON as their
adapter; validation reports every fault a check can find; and a component reads the
fields a document bound to its roles, and their labels and units, from its context. The
host's defaults (its configured registry, the clock read once, its ceiling) let
`Macaw.Surface.show/2` validate, fetch and render in one call, and `build!/2` write a
surface in a few lines. The table chooses its columns by a role, heads them with the
schema's labels, and has its own stylesheet. Everything in this tutorial runs on it.

Not yet released, and so not taught here: state sources and the page graph, pages,
templates and regions, records and replay, the web plans, the built-in prose and cards,
and `macaw_live`, the LiveView runtime that will apply components' events, push changes
and isolate components in processes. The specification describes them; the order of work is
in [spec/00 §5](https://github.com/dcoai/macaw/blob/main/spec/00-overview.md#overview-order).

Macaw is a very early release, and every 0.x version may change its API.

## Where to go next

- **The specification**, the source of truth for every rule here:
  [the core's spec](https://github.com/dcoai/macaw/blob/main/spec/README.md), with
  [surfaces](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-regions),
  [the built-in table](https://github.com/dcoai/macaw/blob/main/spec/05-components.md#components-table) and
  [the registry](https://github.com/dcoai/macaw/blob/main/spec/12-registry.md#registry-host);
  [sources](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md) and
  [derived sources](https://github.com/dcoai/macaw_data/blob/main/spec/02-derived.md) in
  `macaw_data`;
  [the component contract](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#contract)
  and [rendering](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#rendering)
  in `macaw_component`;
  [the document kernel](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#documents-kernel)
  and [themes](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes)
  in `macaw_layers`.
- **The API reference:** `Macaw.Surface`, `Macaw.Layout`, `Macaw.Grid`,
  `Macaw.Registry` and `Macaw.Builtin.Table` here; `Macaw.Data.Source`, `Macaw.Component`,
  `Macaw.Layers.Theme` and the rest in their packages' documentation on
  [hexdocs.pm](https://hexdocs.pm).
