# 05 — Components, cells and containers {#components}

A **component** is a registered implementation of one public contract. Built-in and third-party components use the same contract ([00](00-overview.md) goal 8). A **cell** places a component in a surface.

**Two libraries** (#137): §1–4, the contract, are `macaw_component`'s, so a component package implements them without the core; §5 and §6's built-in components are the core's, `macaw`. §7 settles where the contract names something the core runs.

## 1. What a component declares {#components-declares}

Each declaration buys a composition effect ([00](00-overview.md) goal 1, rule 1).

**Two sorts of declaration** (macaw_compose#22, R2):
- **Kinds are static.** A module declares them once, and the registry reads them without calling the component (§2).
- **Everything else is configured.** It is the value of a pure function, `declarations(settings)`, called with the component's validated settings when the document is validated ([07](07-documents.md#documents-validation-time)). A component whose behavior is fixed returns the same value for any settings. A component whose behavior is data computes it: a visualize visual's slots, events and state writes follow from its design.

`declarations/1` is pure: no I/O, no clock, no process. Equal settings give equal declarations. Because it runs at validation, the page DAG, the CSP plan, the observation plan and every budget ceiling exist before anything renders.

| Declares | Buys |
|---|---|
| **settings schema**, made of parameters (§1.1), which may depend on bound slot schemas (`legal_for`) | validated pages; type-legal options (metresis.md C3) |
| **slots**: typed inputs with `requires` contracts, checkable before data flows | any source works; faults found at validation (visualize.md C1) |
| **kinds** it renders as (static) | correct placement and landmarks (§2) |
| the **standard state** it writes (`writes`) and its **local state** (`local`) (§1.3) | interaction without wiring ([03](03-state.md)) |
| a **budget per slot** (§1.2) | correct fetch sizes; one hard bound per host ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-delivery)) |
| **events** it emits, by name, in the shared event struct; each emission carries its initiator | accurate view paths ([08](08-records.md)); cell actions ([06](06-pages.md#pages-actions)) |
| **announcements** it may request, by name (`announces`) | one coordinated announcer ([10](10-web.md#web-a11y)) |
| **observation** it can emit (`observes`), a subset of the closed vocabulary | disclosure that matches (dcotek_web.md C3, C12; [10](10-web.md#web-observation)) |
| **element ids**, stable and derived from content structure | attention that aggregates across builds (dcotek_web.md C3) |
| **reading load** (§1.4) | reading vs skimming vs glancing (dcotek_web.md C3) |
| **client hooks**, as static files from `'self'` | strict CSP ([10](10-web.md#web-csp)) |
| **assets**: static files, and generated content-addressed stylesheets (§3) | self-contained base renders ([08](08-records.md)) |
| **proxy routes** for media from another origin, mounted by the host | nothing from another origin ([10](10-web.md#web-csp)) |
| **renders** in each mode: live, socketless, neutral, print (§3) | complete without a socket; replay; output |

**Event names are unique within one component's declarations.** The events a component declares are every event it emits, including those its runtime raises when its configuration enables them (a visual's `brush`, `select` and `pick`). So a configuration that declares one of those names beside the runtime's is a validation fault naming both ([07](07-documents.md#documents-validation-time)). A component kind's runtime names are reserved by being declared, for that kind only: another kind may use the same name for its own event. There is no namespace and no separate field. `initiator` already separates visitor from system, and one list of names is what view paths and records key on (macaw_compose#73, #91; visualize#955).
| **isolation**: `:pure` (renders in the page's process) or `:contained` (has server work, held by a contained cell, §4) | a crash never takes down the page |
| **drawn states** | never blank; failures shown (§4) |
| **required access**, if any | consistent gating |

### 1.1 Parameters {#components-parameters}

A component's settings schema is a map of **parameters**, one shape for every component, so the registry, the page validator, builder forms and an AI author read one form (macaw_compose#15). **The shape, `conforms?/2` and its validation are `Macaw.Data.Parameter`'s**, specified in [macaw_data 01 §2.2](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-parameters): sources take parameters before any component exists, so macaw_data owns the shape and components use it (the owner's decision, 2026-10-27, #109). What follows is how components use it.

```elixir
%{type: type,                      # a data-model type (macaw_data 01 §1), {:document, type}, or :term
  default: value,
  values: [value] | nil,           # a closed list of legal values, or nil
  legal_for: {slot, field, fact} | nil,  # legal values follow from a bound slot's described schema
  bindable: false,                 # may this parameter be bound to state?
  doc: "…"}
```

**Types.** A parameter's `type` is one of:
- a **data-model type** (`:time`, `:number`, `:category`, `:text`, `:color`, `:point`, [macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-data));
- **`{:document, type}`**, a nested document of a document type ([01](01-vocabulary.md#vocab-documents)), validated by its own kernel rules: how a whole visualize design is a cell's settings;
- **`:term`**, any value the component validates itself in `declarations/1`, allowed only for documents migrated from untyped forms (visualize's old variables), never for new parameters.

A parameter's value in a document is a literal, or, when the parameter is `bindable`, a **binding to a state source**: `bins: {:state, "bins"}` ([03](03-state.md#state-sources)). Binding is closed by default: a parameter is bindable only when its component says so.

- **Declarations never read a bindable parameter,** so a binding can never change the page's shape after validation. The budget is the one exception (§1.2): it is a function evaluated at runtime, under a ceiling fixed at validation.
- **A change to a bound parameter re-applies the component:** the runtime passes the new value through `bound/3` (§4). It re-fetches only when the slot's budget changes.
- A design variable in visualize is a parameter (visualize#889); old untyped variables migrate as type `:term`.

### 1.2 Budget per slot {#components-budget}

A component that draws rows declares, for each slot, a **row budget** as a function of its parameters and its measured size: `budget(slot, params, size) → rows`. visualize's derivation (plot width by mark type, with a design override, its D-226, D-227 and D-230) is one implementation.

- **The host ceiling clamps every slot.** A slot whose budget exceeds the ceiling reads at the ceiling, reported as `reduced_by: :runtime` ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-delivery)), and draws those rows. A component is never handed nothing because it asked for too much.
- **Sources are pooled at the largest budget** among their readers, and each reader is reduced to its own, reporting how ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-delivery), `reduced_by`).
- A component without a budget declaration reads at the host ceiling.

### 1.3 State a component writes and reads {#components-state}

- **`writes`** names the **standard** state sources a component writes ([03](03-state.md#state-sources): `selection`, `window`, a scene's `camera` and `breakpoints`) and the type of value each takes: `writes: [selection: :identity, window: :x_window]`. Their meaning is built into the component. It writes them **only by emitting events**; the runtime applies the event. Any other state source is the page author's, written through a cell action ([06](06-pages.md#pages-actions)).
- **`local`** names keys in the `:local` scope it shares through the client bus, with the domain type each carries: `local: [hover: :x_domain, brush_band: :x_window]` ([03](03-state.md#state-scopes)). Pixels never travel on the bus.
- **Exports** are not a component's declaration: the placement document declares them ([03](03-state.md#state-exports)).
- **A component reads state it doesn't write** through a parameter binding (§1.1) or a slot bound to the state source. It never reads another component.

### 1.4 Reading load {#components-reading}

Every component declares its reading load, so attention analysis ([08](08-records.md#records-attention)) treats a chart differently from an article:
- **`:glance`:** a value, a chart's shape. The default for components that aren't prose.
- **`:scan`:** a table, a list, a visual over many items.
- **`:read`:** prose sections, which may also give word counts.

It may depend on settings, never on delivered data, since it is a declaration: visualize derives `:scan` from a design that draws a table or many series, `:glance` otherwise.

## 2. Kinds {#components-kinds}

A component offers one or more **kinds**, one `render/2` clause per kind:

```elixir
kinds [:navigation, :content]

def render(:navigation, assigns), do: ~H"<nav aria-label={@label}><ul>…</ul></nav>"
def render(:content, assigns),    do: ~H"<ul class=\"cards\">…</ul>"
```

- **A cell names its `kind`,** defaulting from where it sits: `:navigation` in a region whose role is navigation, `:content` elsewhere, and the container's pane kind inside a container. Validation checks that the kind is one the component offers and is allowed in that region, so a missing clause never fails at runtime.
- **Kinds are the only static declaration.** They are checked against the clauses at compile time, and the registry reads them without calling the component.
- **Each kind carries rules the output is checked against:**
  - `:navigation` renders a labeled `<nav>` of links;
  - `:control` renders real form controls;
  - `:container` renders an accessible pattern (a tab list, a disclosure, a dialog).
- **Kind and mode are separate axes.** Kind is the argument; mode comes in the context. Most components render the same markup in every mode, and the runtime changes what it wraps around it.

(macaw_compose#8, question 2.)

## 3. Rendering rules {#components-rendering}

- **Server first, complete without a socket.** Native HTML wherever it gives behavior: `<details>`, `popover`, `<dialog>`. (dcotek_web.md C3.)
- **Size by container queries, never by viewport,** so one component works in any region ([10](10-web.md#web-responsive)). A component that lays out on the server (a chart computing scales and ticks) receives the **measured container size and root font size** in its context. Until the first measurement, it lays out at the size its placement declares.
- **Colors by the theme's rules** ([macaw_layers 04](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/04-themes.md#themes-rules)): drawing colors from roles, data colors as typed content with a cue, literal colors refused under the `:roles` profile every Macaw page validates against.
- **Headings at the level given by context,** never hard-coded ([10](10-web.md#web-a11y)).
- **Links and navigation as events or host link helpers.** A component never navigates by itself; its placement maps events to actions ([06](06-pages.md#pages-actions)).
- **Announcements are requested, never owned.** A component never renders a live region; it requests an announcement by name, from the server or from a hook ([10](10-web.md#web-a11y)).
- **Styles and loads by the delivery rule** ([10](10-web.md#web-csp)): no inline `style` or `<style>`, no inline script or script evaluation, nothing from another origin. A component's part is to declare what the rule needs: its generated stylesheets as assets and its proxy routes (§1); and to give every first render a static form.
- **Each mode's rules** are defined once, in [10](10-web.md#web-modes): canvas only in live mode, complete SVG and HTML otherwise, no hooks in neutral and print.

- **The budget holds in every mode** (macaw_compose#29). Each slot's budget (§1.2) is evaluated at **that mode's size**, never the viewer's window:
  - socketless, neutral, and the first live render: the size the placement declares, since no measurement exists yet;
  - live, after the first measurement: the measured container;
  - print: the print box. The host ceiling applies in every mode, and no mode hands a component unbudgeted rows.
- **Every drawn state has a static render** (§4), so neutral and print show it without hooks.

## 4. Drawn states, the runtime value and isolation {#components-states}

- **Every component is always in exactly one drawn state:** `crashed`, `down`, `invalid`, `loading`, `no_data`, `stale`, `capped` or `live`, in that precedence. `capped` says the rows drawn are fewer than the data: the source capped them, the runtime reduced them, or the component drew fewer than it was handed. Each has a theme role, a glyph and words, and is never blank. (visualize.md C3.)
- **`:pure` components** (Markdown, cards) render in the page's process.
- **A `:contained` component, one with server work, is a pure value with transitions** (macaw_compose#22, R6):

  ```
  init(settings, ctx)              → value
  delivery(value, slot, delivery)  → value
  size(value, size)                → value
  bound(value, name, new)          → value      # a bound parameter or state source changed
  render(kind, assigns)            → markup
  ```

  The **context** carries the mode, the measured container size and root font size, the heading level, the instance id, the theme, and the viewer's preferences (`zone`, `units`; [03](03-state.md#state-sources)). The behavior is `macaw_component`'s. The **process** around the value is the host's: under Macaw, `macaw_live`'s contained cell; in an adopter's own host, whatever it uses (a LiveView's assigns, a test). The value never knows which.
- **Contained cells** hold that value: a heap-limited process each, restarted by its surface with a backoff (100 ms doubling to 10 s, reset after 30 s alive), shown as `crashed` meanwhile. A component's crash never takes down the page that carries the visitor's observation. (visualize.md C13; dcotek_web.md C13.)
- **Embedded applications** (macaw#9's demos) are a container pattern running a nested LiveView with its own limits.

## 5. Containers {#components-containers}

A **container** is a component of kind `:container` whose content is surfaces: tabs, drawer, accordion, split.
- Each pane is a surface, with its own state.
- Panes **render** lazily, but **compute** whatever other nodes depend on ([03](03-state.md#state-dag)).
- **Opening a pane is a view change** (a step), never navigation.
- Each container type follows its accessibility pattern ([10](10-web.md#web-a11y)).
- **A container may position its panes by its own coordinate model.** A visualize scene is one visual; the live elements embedded in it (a terminal, a chart) are its panes, placed in scene coordinates. Its camera and breakpoints are state sources, and its playhead is the `window` with `as_of` ([03](03-state.md#state-sources)), so they are recorded and shareable like any other state. (macaw_compose#22, R20.)
- **Nesting** is only through containers, to a **depth of 3** (surface → container → surface …). A surface's grid never directly contains a grid.

## 6. Packaging {#components-packaging}

Components ship in packages, which bring their own dependencies (Macaw never imports them) and register through the registry ([12](12-registry.md)).

**Built in,** in `macaw`: content components using the same contract as any package:
- **prose** (Markdown) and **cards**;
- **the table:** an HTML `<table>` of kind `:content`, with a caption, header cells with scope, sortable columns as real buttons, a budget per slot, reading load `:scan`, and rows that write `selection` by identity. Dashboards (metresis#452, visualize#755) and `macaw_edit` share it (macaw_compose#22, decision 10).

**Expected packages:**
- **visualize:** its visuals (charts, maps, scenes) implement the contract **from visualize itself**, as `Visualize.Macaw.*` in `visualize_live`, compiled when `macaw_component` is present ([00](00-overview.md) goal 6; visualize#946). Its visual table stays for standalone use and image output;
- **metresis:** dashboard and panel components, plus its shaping functions, so remote hosts can draw them (metresis#556);
- **`macaw_edit`:** data-editing components ([13](13-writes.md));
- **components built on ryutronic:** wizards, durable jobs, an assistant.

## 7. The contract and the core {#components-libraries}

The contract names four things the core runs. In each, **`macaw_component` owns the shape a component declares or receives, and `macaw` owns the behavior** (#137), so a component compiles and passes its kit with no core present, and another host (a plain LiveView, a test) can hold it.

| Case | `macaw_component` | `macaw` |
|---|---|---|
| **State** (§1.3) | the standard state names and value types a component may declare in `writes`, and the `local` keys' domain types; events as `Macaw.Data.Event`; the `bound/3` transition | state sources and scopes, applying emitted events, parameter and slot bindings, the page DAG ([03](03-state.md)) |
| **Context** (§4) | the context's fields (mode, measured size and root font size, heading level, instance id, theme, preferences) and the rules for using them (§3) | computing each instance's context on a page |
| **Containers** (§5) | kind `:container`, its output rules, and rendering the panes it is handed | panes as surfaces, lazy render and DAG compute, nesting depth, the built-in containers |
| **Cell actions** ([06](06-pages.md#pages-actions)) | declared event names, unique within a component (§1) | mapping a placement's events to actions |

- **A shape the contract owns is never redefined by the core.** The core reads it from `macaw_component`, so a component and the page that holds it agree by construction.
- **A host other than the core supplies the context and holds the value itself,** as §4 already requires: the value never knows which host it is in.
- **Nothing in the contract needs a process, a state source or a page.** A proposed addition that does belongs to the core.
