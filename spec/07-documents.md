# 07 — Documents {#documents}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

Every declarative value Macaw reads is a **document**: pages, surfaces, templates, layers, themes, visualize designs, component settings and records. One kernel reads them all: the **document kernel**, specified in [macaw_layers 01](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#documents-kernel). It generalizes what visualize built for its designs, spread over `Visualize.Chart.Migration`, `Chart.Limits`, `Chart.Codec.Tags`, `Chart.Codec`, `Chart.Validator`, `Chart.Names` and `Visualize.Vocabulary` ([00](00-overview.md#overview-order) step 2). **Fragments and stacking** are specified in [macaw_layers 02](https://github.com/dcoai/macaw_layers/blob/main/spec/02-fragments.md#documents-fragments). Both moved to `macaw_layers` with its repository (#95); what stays here is how pages and components use documents.

## 1. Everything is composable data {#documents-everything}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

**Every configurable thing is a document of the fragment shape,** and there is no second configuration format (owner, 2026-10-26). That covers:
- pages, surfaces and cells;
- **component settings;**
- templates, layers, themes and styles;
- source declarations.

Each stacks, masks, validates and explains the same way ([macaw_layers 02](https://github.com/dcoai/macaw_layers/blob/main/spec/02-fragments.md#documents-fragments)). A configured component is a stack: its defaults, then a **preset** (a fragment), then the cell's local settings. So "why is this table sorted by date?" answers through `explain`, like any other value.

**A component's settings schema is made of parameters** ([05](05-components.md#components-parameters)): typed, with a default, legal values and documentation. One shape describes every component's options, so validation, builder forms and an AI author read the same thing.

**A cell's settings may be inline or referenced.** A cell may carry a component's whole settings inline (a complete visualize design, for instance), or a reference to a preset plus local overrides. Both are the same stack and validate the same way. Inline settings keep a page in one document, which suits AI authoring; a reference keeps a shared design in the library, where every page using it follows its changes (macaw_compose#22, decision 3). This uniformity is what makes portability possible ([macaw_layers 03](https://github.com/dcoai/macaw_layers/blob/main/spec/03-stores.md#stores-portable)), and what lets an AI author anything through one format.

## 2. Validation time {#documents-validation-time}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

Validation runs **whenever a document is loaded**, through pure functions, in two passes:
- **The static pass**, at load: shapes and types, closed `values`, references, the page DAG, the CSP and observation plans, and `legal_for`, whose schemas come from each source's `describe`, answered at boot and cached ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-contract)). No I/O and no viewer.
- **The request-time check**, for legal values that come from data (`values_from`): a page param against the source's current values before render, an illegal one refused as `404`; a state value at each change, an illegal one refused while the state keeps its value. It runs with the request's viewer, through the source. The static pass includes each placed component's configured declarations ([05](05-components.md#components-declares)): `declarations(settings)` is called here, so slots, events, state writes, budget functions and observation are known before anything renders. (A budget's value depends on the measured size, so it is computed at render, clamped to the host ceiling.) In v1 that is at build or boot. A broken shipped document fails the build, and a broken fetched document is refused, keeping the last good version. (metresis.md C6; dcotek_web.md C13.)
