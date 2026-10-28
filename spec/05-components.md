# 05 — Components, cells and containers {#components}

<!-- surfex: class architecture -->

A **component** is a registered implementation of one public contract. Built-in and third-party components use the same contract ([00](00-overview.md) goal 8). A **cell** places a component in a surface.

**Two libraries** (#137): the contract is `macaw_component`'s, specified in [its own repository](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/README.md), so a component package implements it without the core; §5 and §6's built-in components are the core's, `macaw`. §7 settles where the contract names something the core runs. §1–4 moved to `macaw_component` with their anchors (#141); each keeps its heading here and points to where it is now.

## 1. What a component declares {#components-declares}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.2](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-declares), with the behavior and its static declarations ([§1](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-behavior)), slots ([§1.3](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-slots)), events, announcements, observation and shortcuts ([§1.6](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-events)), assets, hooks and proxy routes ([§1.8](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-assets)), and isolation and access ([§1.9](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-isolation)).

### 1.1 Parameters {#components-parameters}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.1](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-parameters).

### 1.2 Budget per slot {#components-budget}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.4](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-budget).

### 1.3 State a component writes and reads {#components-state}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.5](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-state).

### 1.4 Reading load {#components-reading}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.7](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-reading).

## 2. Kinds {#components-kinds}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

Moved: [macaw_component 01 §2](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-kinds), with each kind's output rules in [02 §4](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-kind-rules). Which kind a cell takes, from where it sits, is the core's: a cell names its `kind`, defaulting to `:navigation` in a region whose role is navigation, `:content` elsewhere, and the container's pane kind inside a container, and validation checks that the component offers it and that the region allows it.

## 3. Rendering rules {#components-rendering}

<!-- surfex: class moved -->

Moved: [macaw_component 02 §5](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-rendering), with the assigns ([§1](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-assigns)), the context ([§2](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-context)) and the client protocols ([§8](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-client)).

## 4. Drawn states, the runtime value and isolation {#components-states}

<!-- surfex: class moved -->

Moved: [macaw_component 02 §6](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-states) and [§7](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-contained). The contained cell that holds a value, heap-limited and restarted by its surface with a backoff (100 ms doubling to 10 s, reset after 30 s alive) and shown as `crashed` meanwhile, is `macaw_live`'s, so a component's crash never takes down the page that carries the visitor's observation (visualize.md C13; dcotek_web.md C13). **Embedded applications** (macaw#9's demos) are a container pattern running a nested LiveView with its own limits.

## 5. Containers {#components-containers}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

A **container** is a component of kind `:container` whose content is surfaces: tabs, drawer, accordion, split.
- Each pane is a surface, with its own state.
- Panes **render** lazily, but **compute** whatever other nodes depend on ([03](03-state.md#state-dag)).
- **Opening a pane is a view change** (a step), never navigation.
- Each container type follows its accessibility pattern ([10](10-web.md#web-a11y)).
- **A container may position its panes by its own coordinate model.** A visualize scene is one visual; the live elements embedded in it (a terminal, a chart) are its panes, placed in scene coordinates. Its camera and breakpoints are state sources, and its playhead is the `window` with `as_of` ([03](03-state.md#state-sources)), so they are recorded and shareable like any other state. (macaw_compose#22, R20.)
- **Nesting** is only through containers, to a **depth of 3** (surface → container → surface …). A surface's grid never directly contains a grid.

## 6. Packaging {#components-packaging}

<!-- surfex: deferred #168: the built-in prose and cards -->

Components ship in packages, which bring their own dependencies (Macaw never imports them) and register through the registry ([12](12-registry.md)).

**Built in,** in `macaw`'s package `Macaw.Builtin`: content components using the same contract as any package:
- **prose** (Markdown) and **cards**;
- **the table:** an HTML `<table>` of kind `:content`, with a caption, header cells with scope, sortable columns as real buttons, a budget per slot, reading load `:scan`, and rows that write `selection` by identity. Dashboards (metresis#452, visualize#755) and `macaw_edit` share it (macaw_compose#22, decision 10).

**Expected packages:**
- **visualize:** its visuals (charts, maps, scenes) implement the contract **from visualize itself**, as `Visualize.Macaw.*` in `visualize_live`, compiled when `macaw_component` is present ([00](00-overview.md) goal 6; visualize#946). Its visual table stays for standalone use and image output;
- **metresis:** dashboard and panel components, plus its shaping functions, so remote hosts can draw them (metresis#556);
- **`macaw_edit`:** data-editing components ([13](13-writes.md));
- **components built on ryutronic:** wizards, durable jobs, an assistant.

### 6.1 The table {#components-table}

`Macaw.Builtin.Table`, registered as `"macaw.table"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`:
- **Parameters:** `caption` (text, `"Table"`), the table's name; `identity` (text, `""`), the field naming each row, `""` for rows that can't be selected; `sort` (text, `""`, bindable), the field rows are sorted by, `""` for the delivered order; `order` (category `"asc"` or `"desc"`, `"asc"`, bindable).
- **Declarations:** one slot, `rows`, of whole rows; events `"sort"` and `"select"`; `writes: %{"selection" => :identity}`; `observes: [:activate, :select]`; reading load `:scan`.
- **Budget:** the rows its declared height shows at `2rem` (32 px) a row, times four for scrolling, at least 10.
- **Markup:** a `<table class="mw-table">` with its `<caption>`; a header row of `<th scope="col">`, one per column in the delivered table's column order, each a real `<button type="button">` emitting `sort` with the field as its value, and the sorted column's `<th>` carrying `aria-sort` (`ascending` or `descending`); a row per delivered row, sorted when `sort` names a column (nil last, ties in delivered order), each `<td>` the value as text, `nil` empty; with an `identity` field, each row's first cell holds a `<button type="button">` named `Select` and the identity, emitting `select` with the row's identity, and the row's id is `Context.id/2` of `r-` and the identity's spelling, base64url-encoded so any identity makes an id, so ids are stable; a `capped` or `stale` table draws its notice above its rows, and any other non-live state its notice alone.
- **It passes `macaw_component`'s kit**, the core being the contract's first implementer ([macaw_component 00 §3](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/00-overview.md#component-order)).

```test:table-declares
the table's parameters, slot, events, selection write, observations, reading load and budget are as declared
```

```test:table-markup
the table renders a caption, scoped header buttons that sort, rows sorted by a field in either order with nil last, selection buttons and stable ids with an identity, and its notice when not live; it passes the component kit
```

## 7. The contract and the core {#components-libraries}

<!-- surfex: class architecture -->

The contract names four things the core runs. In each, **`macaw_component` owns the shape a component declares or receives, and `macaw` owns the behavior** (#137), so a component compiles and passes its kit with no core present, and another host (a plain LiveView, a test) can hold it.

| Case | `macaw_component` | `macaw` |
|---|---|---|
| **State** ([macaw_component 01 §1.5](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-state)) | the standard state names and value types a component may declare in `writes`, and the `local` keys' domain types; events as `Macaw.Data.Event`; the `bound/3` transition | state sources and scopes, applying emitted events, parameter and slot bindings, the page DAG ([03](03-state.md)) |
| **Context** ([macaw_component 02 §2](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-context)) | the context's fields (mode, measured size and root font size, heading level, instance id, theme, preferences) and the rules for using them ([02 §5](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-rendering)) | computing each instance's context on a page |
| **Containers** (§5) | kind `:container`, its output rules, and rendering the panes it is handed | panes as surfaces, lazy render and DAG compute, nesting depth, the built-in containers |
| **Cell actions** ([06](06-pages.md#pages-actions)) | declared event names, unique within a component ([01 §1.6](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-events)) | mapping a placement's events to actions |

- **A shape the contract owns is never redefined by the core.** The core reads it from `macaw_component`, so a component and the page that holds it agree by construction.
- **A host other than the core supplies the context and holds the value itself,** as [macaw_component 02 §7](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-contained) already requires: the value never knows which host it is in.
- **Nothing in the contract needs a process, a state source or a page.** A proposed addition that does belongs to the core.
