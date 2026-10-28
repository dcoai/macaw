# 06 — Pages, templates and surfaces {#pages}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

```
page          the final browser document at one URL
 └ template stack       base template + layers (with masks)
    └ region            a named, landmarked area; holds surfaces in a flow
       └ surface        a reusable composed unit: cells in a grid or a flow
          └ cell        a component placed in the surface
             └ (container cell → surfaces → …, to depth 3)
```

## 1. The page {#pages-page}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

The **page** owns what exists once per browser document:
- the title and the one `<h1>`;
- exactly one `main`;
- the template stack;
- the CSP and the host's observation plan (the union of its components' declarations);
- navigation;
- the page view and its record ([08](08-records.md)).

A page document picks a template stack and fills its regions with surfaces:

```yaml
page: "/p/exio"
template: [site, project_toc]
regions:
  main:
    - surface: project_overview
    - surface: project_status
```

## 2. Templates and layers {#pages-templates}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

A **template** is a registered, named arrangement of regions, with its options declared as parameters ([05](05-components.md#components-parameters)), a landmark role per region and, per region, a default collapse behavior and a breakpoint. **Layers** stack on it, using visualize's fragment machinery (reused in Macaw, [macaw_layers 02](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/02-fragments.md#documents-fragments)):

```elixir
template :site do
  region :header,  role: :banner
  region :sidebar, role: :navigation, persistent: true, fillable: true,
                   collapse: :drawer, content: [surface: :site_menu]
  region :main,    role: :main, fillable: true
  region :footer,  role: :contentinfo
  param :sidebar, values: [:shown, :collapsed, :hidden], default: :shown
end

layer :full_width,  on: :site, do: hide(:sidebar)
layer :project_toc, on: :site, do: fill(:sidebar, surface: :table_of_contents)
```

- **Merge rules per key:**
  - regions: `:deep` by name;
  - a region's content: `:override`;
  - params: `:override`;
  - responsive rules and collapse: `:deep` (a layer can override one region's collapse).
- **Masks** explicitly drop keys from below. A masked override is intended, so it raises no error, and `explain` names the mask. An unmasked collision on a conflicting key is an error, or a warning when a later layer silently undoes an earlier one.
- **The stacked result is validated as a whole,** never layer by layer. It must have:
  - exactly one `main`;
  - a landmark per region role, and labeled navs;
  - DOM order equal to visual order;
  - CSP-safe classes;
  - every kind placed where it is allowed.

  A failing stack fails validation, naming the layer at fault. A mask can redesign a page but never bypasses validation.
- **Where layers come from:**
  - **registered layers**, authored with the template and tested, may be stacked by any page;
  - **a page's own last layer** may only set declared params and fill regions declared fillable.
- **Print** is an automatic layer, stacked by the print mode and for output: it hides every region but `main` and opens disclosures. A template may declare its own `print:` layer in its place.
- **One stack per page** replaces nested page and site templates.

(macaw_compose#8, question 2.)

## 3. Regions and surfaces {#pages-regions}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

- **A region holds surfaces in a flow.** A surface lays out its cells as a **flow** (sections, for prose) or a **12-column grid** (§3.3), metresis's and visualize's grid. (visualize.md C4; metresis.md C4.)
- **A surface is reusable:** the same surface can appear on several pages, in a tab or in a drawer.
- **A cell's settings are inline or referenced** ([07](07-documents.md#documents-everything)): a preset by typed reference, with the cell's own settings stacked over it.
- **Its title** takes the next heading level from context ([10](10-web.md#web-a11y)).

`macaw` v0.1.0 holds **surfaces with a grid**, validated and rendered complete without a socket (§3.1–§3.6, #154). Regions, flows, presets and the live runtime follow.

### 3.1 The surface document {#pages-surface-document}

**`Macaw.Surface` is a surface:** `%Macaw.Surface{name, title, layout, cells}`, a document read through the kernel's gates ([macaw_layers 01 §5](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/01-kernel.md#kernel-gates)) and stacked as a fragment ([macaw_layers 02](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/02-fragments.md#fragments-types)).

| Key | Value | Default |
|---|---|---|
| `name` | the surface's name: lower-case words joined by `_`, a name in the kernel's sense ([macaw_layers 01 §1](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/01-kernel.md#kernel-names)), unique where it is stored; it prefixes its cells' instance ids (§3.6) | required |
| `title` | a non-empty string, its heading; `nil` for a surface without one | `nil` |
| `layout` | `:grid`, the only layout of v0.1.0 | `:grid` |
| `cells` | the cells by name (§3.2), a map, at least one | required |

- **Building one:** `Macaw.Surface.new/1` from a keyword list or a map with atom keys answers `{:ok, surface}` or `{:error, faults}`, every fault at once by path from the surface, as the kernel orders them ([macaw_layers 01 §3](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/01-kernel.md#kernel-faults)). A key it doesn't have is `:unknown_key`; a missing one `:required`. Names in it are strings; an atom is read as its spelling, and no atom is made.
- **The map form** is `%{version: v, surface: node}` (`to_map/1`), the node the surface's keys with each cell as its map; **the JSON form** is `{"$version": v, "surface": {…}}` (`to_json/1`). A cell's settings and a slot's params are plain data in both forms: strings, numbers, booleans, `nil`, lists and maps with string keys. `from_map/2` and `from_json/2` read them back through every gate (the version, the limits, the migration) and then `new/1`, so a surface written by `to_map/1` reads back equal.
- **The version line** starts at 1 (`current/0`), with no migration step yet.
- **As a fragment type,** `cells` is a `:union` by name and every other key an `:override`, so a layer stacked on a surface adds or replaces cells by name and overrides its title.

```test:surface-new
a surface builds from its keys with title and layout defaulted; a missing name or cells, an unknown key, a bad name, title, layout and every bad cell are faults at once by path; no atom is made from a name
```

```test:surface-forms
a surface written to its map and JSON forms reads back equal through every gate; a document of a newer version, past a limit or with an unknown key is refused by the gate that catches it
```

```test:surface-fragment
stacking a layer on a surface adds and replaces cells by name and overrides the title
```

### 3.2 Cells {#pages-cells}

**`Macaw.Surface.Cell` places one component:** `%Macaw.Surface.Cell{component, kind, settings, slots, place}`.

| Key | Value | Default |
|---|---|---|
| `component` | the component's name, as its package registers it ([macaw_component 01 §1](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-behavior)), matched by spelling | required |
| `kind` | the kind it renders as, one of `Macaw.Component.kinds/0`, given as an atom or its spelling | `:content` |
| `settings` | its settings by parameter name, inline, plain data | `%{}` |
| `slots` | each of its slots bound to a source: `%{source: name, fields: %{role => field}, params: %{name => value}}`, `fields` and `params` defaulting to `%{}`, a `many` role's fields a list | `%{}` |
| `place` | where it sits in the grid: `%{x, y, w, h}` (§3.3) | required on a grid |

Cell names are names in the kernel's sense, unique within the surface (the map's keys).

```test:cells-shape
a cell builds with its defaults, kind read from an atom or its spelling; a missing component or place, an unknown kind, settings or params that aren't plain data, a slot without a source and an unknown key are faults at their paths
```

### 3.3 The grid {#pages-grid}

<!-- surfex: deferred #160: the grid -->

A grid surface places its cells on **12 columns** in integer units: `x` from 0 to 11, `w` from 1 to 12 with `x + w` at most 12, `y` from 0, `h` from 1, and `y + h` at most **64** rows (`Macaw.Grid.rows/0`), so every placement has a class. Two cells overlapping is `{:overlap, other}` at the later cell's `place`, later in reading order.

- **Reading order** is by `y`, then `x`, then name (`Macaw.Grid.order/1`): the DOM order, so DOM order is visual order ([10 §4](10-web.md#web-a11y)).
- **Placement is by classes**, never inline style ([10 §1](10-web.md#web-csp)): `Macaw.Grid.classes/1` of a place is `"mw-cell mw-col-<x+1> mw-span-<w> mw-row-<y+1> mw-rows-<h>"`, each class one rule of **one static stylesheet**, `Macaw.Grid.stylesheet/0`: the grid (`.mw-grid`: 12 equal columns, rows of `var(--mw-grid-row, 4rem)` at least, a gap of `var(--mw-grid-gap, 1rem)`), one rule per column start, column span, row start and row span, and a container query that stacks every cell into reading order, one column, rows auto, when the surface's container is narrower than `40rem`. Its bytes are a pure function of nothing, served from `'self'` at `Macaw.Grid.stylesheet_path/0`, its content address ([macaw_component 01 §1.8](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-assets)). This settles #5: exact placement with no inline style, by construction.
- **A cell's declared size** is its share of the surface's width and its rows' height: `Macaw.Grid.size/3` of a place, the surface's width and its row height is `{w * width / 12, h * row_height}` in CSS pixels, the size its component lays out at before any measurement and its budget is evaluated at (§3.5).

```planned-test:grid-rules
placements in bounds pass; x, w, x+w, y, h and y+h out of bounds and non-integers are each a fault; an overlap is named at the later cell in reading order; reading order sorts by y, x and name
```

```planned-test:grid-classes
a placement's classes name its column, span, row and rows; the stylesheet has a rule for every class a valid placement can name and the stacking query, and its path is its content's address; a cell's size is its share of the width and its rows' height
```

### 3.4 Validating a surface {#pages-surface-validate}

<!-- surfex: deferred #161: validating a surface -->

**The static pass** ([07 §2](07-documents.md#documents-validation-time)): `Macaw.Surface.validate/3`, of a surface, the host's registry (`Macaw.Registry`, [12 §1.1](12-registry.md#registry-host)) and its sources by name, each `{source, context}` as `Macaw.Data.Source.describer/1` takes them. No I/O but `describe`, which a source answers from configuration, and no viewer. It answers `{:ok, %Macaw.Surface.Validated{}}` or `{:error, faults}`, every fault at once by path from the surface:
- **the grid**: every rule of §3.3, at `[:cells, name, :place]`;
- **the component**: a name the registry doesn't hold is `{:unknown_component, name}` at `[:cells, name, :component]`;
- **the kind**: one the component doesn't offer is `{:kind_not_offered, kind, kinds}` at `[:cells, name, :kind]`;
- **the settings and declarations**: `Macaw.Component.declarations/2`'s faults, at `[:cells, name, :settings | path]`;
- **the slots**: every slot the component declares must be bound (`:unbound` at `[:cells, name, :slots, slot]`), and a binding of a slot it doesn't declare is `:unknown_slot`; a source not in the map is `{:unknown_source, name}` at `[..., slot, :source]`, one whose `describe` fails `{:describe, reason}`; the binding's fields are checked by `Macaw.Component.Slot.check/3` against the described schema (at `[..., slot, :fields | path]`), and its params by `Macaw.Data.Parameter.validate/2` against the described params (at `[..., slot, :params | path]`).

`%Macaw.Surface.Validated{surface, cells, order}` holds, for each cell, its component module, its validated settings, its declarations, and each slot's source, description and request params; `order` is the cells in reading order. Rendering takes only a validated surface, so nothing renders that hasn't passed.

```planned-test:validate-pass
a surface of known components bound to described sources validates, with each cell's module, settings, declarations and descriptions, in reading order
```

```planned-test:validate-faults
an unknown component, an unoffered kind, bad settings, an unbound and an unknown slot, an unknown source, a failing describe, a binding the schema doesn't meet, bad params and a bad place are all reported at once by path
```

### 3.5 Fetching {#pages-surface-fetch}

<!-- surfex: deferred #162: fetching and rendering -->

**`Macaw.Surface.fetch/2`** of a validated surface and an `env` answers each cell's deliveries and drawn state, `%{cell => %{deliveries: %{slot => delivery}, drawn: state}}`. `env` is a keyword list: `viewer:` (the host's viewer, opaque, `nil` the anonymous one), `now:` (required: the surface's now, never a clock read), `ceiling:` (the host's row ceiling, required), `width:` (the surface's width in CSS pixels, `1200` by default), `row_height:` (`64`), and `timeout:` (ms, `5_000`).
- **Budgets:** each slot's budget is `Macaw.Component.budget/4` at the cell's declared size (§3.3), clamped by `Macaw.Data.Source.Finish.ceiling/2` ([macaw_data 01 §6.1](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-budgets)); a clamped slot's delivery says `reduced_by: :runtime`.
- **Pooling within the surface:** slots bound to one source with equal params cost one fetch, at the largest of their budgets (`Finish.pooled/1`), and each slot is reduced to its own (`Finish.reduce`). Pooling across pages is #108's.
- **Fetching never blocks or crashes the caller:** each fetch runs in a process of its own (`Macaw.Data.Bounded`), the fetches concurrently, each bounded by `timeout:`; the delivery is finished by `Macaw.Data.Source.Finish.finish/4` against the description.
- **Drawn states** ([macaw_component 02 §6](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-states)), the highest of its slots': a fetch that answers an error or whose process exits is `down`; one that hasn't answered within `timeout:` is `loading`; a delivery `capped` or `reduced_by` anything is `capped`; one with no rows is `no_data`; otherwise `live`. A cell with no slots is `live`.

```planned-test:fetch-budgets
each slot is fetched at its budget at its cell's size, clamped to the ceiling and marked runtime when clamped; slots sharing a source and params are fetched once at the largest budget and each reduced to its own
```

```planned-test:fetch-drawn
a source error, a crashed fetch, a hung fetch, a capped or reduced delivery and an empty one draw down, down, loading, capped and no_data; a cell's state is its slots' highest; a cell without slots is live
```

### 3.6 Rendering a surface {#pages-surface-render}

<!-- surfex: deferred #162: fetching and rendering -->

**`Macaw.Surface.render/3`** of a validated surface, its fetched deliveries and an `env` is the surface's markup, a `Phoenix.HTML` safe value, in the mode `env` names (`mode:`, `:socketless` by default), with `theme:` (`Macaw.Layers.Theme.default/0`), `heading_level:` (the surface title's level, `2`), `now:`, `width:` and `row_height:` as for fetching:

```html
<div class="mw-surface" id="<name>">
  <h2 class="mw-surface-title">Title</h2>
  <div class="mw-grid">
    <div class="mw-cell mw-col-1 mw-span-6 mw-row-1 mw-rows-2" id="<name>-<cell>">…</div>
  </div>
</div>
```

- **One `div` per cell, in reading order,** with the grid's classes and the instance's id; nothing inline. The surface is not a landmark: regions and the page own landmarks ([10 §4](10-web.md#web-a11y)).
- **Each cell renders with its context** ([macaw_component 02 §2](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/02-rendering.md#components-context)): `mode`, `instance` `"<surface>-<cell>"`, `size` its declared size (`measured: false`), `heading_level` one below the surface's title (the title's own level without a title), `theme`, the default `preferences`, and `now`; its assigns are its settings, declarations, drawn state, and its deliveries (a `:pure` component) or its value through `init/2`, `delivery/3` and `size/2` (a `:contained` one).
- **A component's raise is the caller's to take**, as the contract says ([macaw_component 01 §1](https://gitlab.conet.yarina.org/dco-tek/macaw_component/-/blob/main/spec/01-contract.md#components-behavior)): a host isolates a component by process (`macaw_live`'s contained cell); this render does not catch it.
- `Macaw.Surface.render/2` fetches and renders in one call.

```planned-test:render-markup
a surface renders its title at its level and its cells in reading order, each with its grid classes and instance id, nothing inline, in every mode
```

```planned-test:render-cells
each cell renders with its context: its instance, declared size, heading level below the title, theme and now; its drawn state and deliveries, or a contained component's value through its transitions
```

## 4. Persistent regions {#pages-persistent}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

A region marked `persistent: true` survives live navigation between pages that share it (LiveView's sticky nested LiveView). Its components keep their processes and state, and focus inside it is kept. When a layer fills it with different content, the old content's state follows its scope ([03](03-state.md#state-scopes)).

## 5. Steps and navigation {#pages-steps}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

- **Navigation** changes the page (live, or a full load when the plans differ; macaw#130).
- **A view change** stays on the page: a selection, an opened tab or drawer, a sorted table.
- Both are steps on a view path ([08](08-records.md)).

### Cell actions {#pages-actions}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

**A component emits events and never decides what they mean.** Its **placement** decides, by declaring **actions**: each maps one of the component's declared events to one of two effects (macaw_compose#22, R9).

```yaml
cells:
  latency:
    component: visual
    settings: {ref: service_latency}
    actions:
      - on: pick
        set: {state: focus, value: {event: identity}}
      - on: pick
        navigate: {to: {page: service}, params: {service: {event: [identity, service]}}}
```

- **`set`** writes a state source from the event's fields: a view change, applied by the runtime as an event on that state source.
- **`navigate`** goes to a typed reference ([macaw_layers 03](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/03-stores.md#stores-references)) with params taken from the event's fields: a navigation step, performed by the host's navigation behavior. The library never navigates.
- **Event fields** are named as paths into the event ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-event)): `{event: identity}`, `{event: [identity, service]}`, `{event: value}`, or `{event: [row, field]}`. Only the named field is read: the row itself is never recorded. A field written by `set` becomes that state source's value, recorded under its capture level like any other ([08](08-records.md#records-stores)); one used by `navigate` is recorded as the step's params.
- **Several actions on one event run in their declared order,** so one pick may select and then navigate.
- **Validated with the page:** the event must be one the component declares, the state must accept the value's type, and a `navigate` action's params are checked against the target page's declared params, by type and legal values.

visualize's `drill` is an action table: `{:datum, field}` becomes `{event: [row, field]}` or `{event: identity}`, a drill to the same board with variables becomes `set`, and a drill to another board becomes `navigate` (visualize#947).

### Page params {#pages-params}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

A page declares the **params** it accepts, as parameters ([05](05-components.md#components-parameters)): typed, with a default and legal values, read from the URL path or query by the host's router.

```yaml
page: "/service/:service"
params:
  service: {type: category, values_from: "services.name"}
```

- Params are validated before anything renders; an illegal value is a `404`-class refusal, never a fault inside a component. A `values_from` param is checked against the source's current values at that moment ([07](07-documents.md#documents-validation-time)).
- State sources read them with `initial: {:param, "service"}`, and source requests bind them like state (`params: %{service: {:param, "service"}}`, [03](03-state.md#state-sources)).
- A `navigate` action's params are validated against them (§5).

## 6. A runtime page builder (out of scope for v1) {#pages-runtime}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

It is out of scope, but not precluded:
1. validation and the page DAG are pure library functions over documents;
2. pages are data, with names resolved through the registry and no atoms;
3. activation is an atomic swap of a validated definition;
4. template CSS is compiled ahead. A runtime template would generate a stylesheet file served from `'self'`, as user themes do.

Out of scope for v1: the builder UI, editing a page while viewers are on it, and runtime CSS generation for new templates.
