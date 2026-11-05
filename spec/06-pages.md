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

A **template** is a registered, named arrangement of regions, with its options declared as parameters ([05](05-components.md#components-parameters)), a landmark role per region and, per region, a default collapse behavior and a breakpoint. **Layers** stack on it, using visualize's fragment machinery (reused in Macaw, [macaw_layers 02](https://github.com/dcoai/macaw_layers/blob/main/spec/02-fragments.md#documents-fragments)):

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

- **A region holds surfaces in a flow.** A surface lays out its cells by its layout (§3.3): a **flow** (sections, for prose), a **stack** or a **grid** of 12 columns (or 6 or 24), metresis's and visualize's grid. (visualize.md C4; metresis.md C4.)
- **A surface is reusable:** the same surface can appear on several pages, in a tab or in a drawer.
- **A cell's settings are inline or referenced** ([07](07-documents.md#documents-everything)): a preset by typed reference, with the cell's own settings stacked over it.
- **Its title** takes the next heading level from context ([10](10-web.md#web-a11y)).

`macaw` v0.1.0 holds **surfaces with a grid**, validated and rendered complete without a socket (§3.1–§3.6, #154). Regions, flows, presets and the live runtime follow.

### 3.1 The surface document {#pages-surface-document}

**`Macaw.Surface` is a surface:** `%Macaw.Surface{name, title, layout, cells}`, a document whose value is a term ([00 §4.2](00-overview.md#core-terms)), read from JSON through the kernel's gates ([macaw_layers 01 §5](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-gates)) and stacked as a fragment ([macaw_layers 02](https://github.com/dcoai/macaw_layers/blob/main/spec/02-fragments.md#fragments-types)).

| Key | Value | Default |
|---|---|---|
| `name` | the surface's name: lower-case words joined by `_`, a name in the kernel's sense ([macaw_layers 01 §1](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-names)), unique where it is stored; it prefixes its cells' instance ids (§3.6) | required |
| `title` | a non-empty string, its heading; `nil` for a surface without one | `nil` |
| `layout` | the layout its cells are placed by (§3.3): a name, or `{name, options}`; `:grid` is the 12-column grid, `{:grid, columns: 24}` one of 24, `{:stack, order: [...]}` one column, `{:flow, order: [...]}` sections for prose, and `{:areas, template: [...]}` named regions. Built in, a name's options and its cells' places are judged here; one only the host's registry knows is held as given and judged by `validate/3` | `:grid` |
| `cells` | the cells by name (§3.2), a map, at least one; given as a list, each cell's name is its `name` or derived, and the list's order is kept (§3.2) | required |

- **Building one:** `Macaw.Surface.new/1` from a keyword list or a map with atom keys answers `{:ok, surface}` or `{:error, faults}`, every fault at once by path from the surface, as the kernel orders them ([macaw_layers 01 §3](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-faults)). A key it doesn't have is `:unknown_key`; a missing one `:required`. Names in it are strings; an atom is read as its spelling, and no atom is made.
- **The value** is `%{version: v, surface: node}` (`to_map/1`), the node the surface's keys with each cell as its map, every name a string and every setting and param the term it is. `from_map/1` judges a value as terms: the version first, so nothing of a newer document is judged, then the envelope (`surface` and no other key), then `new/1`, whose faults it puts under `:surface`: **every fault a reader gives is by path from the document it was given** (`[:surface, :cells, "a", :kind]`), where `new/1`'s are from the surface (`[:cells, "a", :kind]`). No form is written or read on the way, so a value JSON can't hold reads back as the term it is, and no limit applies.
- **The JSON form** is `{"$version": v, "surface": {…}}`, an adapter at the edge (`to_json/1`, `from_json/2`), written and read by macaw_layers' JSON adapter ([macaw_layers 01 §6](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-forms)):
  - the cells, the slots, a slot's `fields`, and the settings and params at every depth are **name maps**: their keys are names, strings written as they are (the surface's `name_map?/1` answer to the JSON adapter), so a name spelled like a document key (`title`) is never read as one;
  - a value JSON has no word for is tagged: an atom as `$atom`, a UTC time as `$time`, a color by the colors' own tags (`$rgb`, `$color`, `$ramp`, …, [macaw_layers 04 §1.6](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-color-adapters)), a `{longitude, latitude}` point as `{"$point": [lon, lat]}`, a layout with options as `{"$layout": [name, options]}` (`{"$layout": ["grid", {"columns": 24}]}`, the options a node of the surface's keys), each tag listed in the surface's tag table;
  - **what JSON can't hold is refused there, at its path:** another term (a tuple, a PID) is `{:type, :term}`, and a map key in a setting or param that isn't a string `{:type, :name}`. The surface itself is valid; only this form of it fails;
  - `from_json/2` reads through every gate (the bytes, the scan, the version, the migration, the limits, `limits:`), then the value, judged, then `new/1`, every fault by path from the document as `from_map/1` gives them. **No atom is made from a document:** an atom a setting or param spells reads back only when it is the document's own word or in `vocabulary: %{atoms: [...]}`, else it is `{:unknown_atom, spelling}` at its path ([macaw_layers 01 §3](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-faults)), naming the spelling the reader wasn't given. A kind spelled as a string that isn't one of the kinds is `{:unknown_kind, spelling}`, from `new/1`.

  A surface written by `to_map/1` reads back equal through `from_map/1`, and one written by `to_json/1` through `from_json/2` given the atoms its settings spell.
- **The version line** starts at 1 (`current/0`), with no migration step yet.
- **As a fragment type,** `cells` is a `:union` by name and every other key an `:override`, so a layer stacked on a surface adds or replaces cells by name and overrides its title.

```test:surface-new
a surface builds from its keys with title and layout defaulted; a missing name or cells, an unknown key, a bad name, title, layout and every bad cell are faults at once by path; no atom is made from a name
```

```test:surface-forms
a surface written to its map and JSON forms reads back equal through every gate; a document of a newer version, past a limit or with an unknown key is refused by the gate that catches it; every fault either reader gives, for any bad cell, is by path from the document
```

```test:surface-terms
settings holding a color term, a typed color, a time, a point and an atom validate against a component declaring those types and read back equal from the value and from JSON (the atom given in the reader's vocabulary, refused at its path by its spelling without it; a kind `$atom` the reader doesn't know refused the same way, and a kind spelled outside the kinds an unknown kind); a wrong type and an undeclared setting are faults at validation; a term JSON can't hold reads back from the value and is refused, at its path, only by the JSON adapter
```

```test:surface-fragment
stacking a layer on a surface adds and replaces cells by name and overrides the title
```

### 3.2 Cells {#pages-cells}

**`Macaw.Surface.Cell` places one component:** `%Macaw.Surface.Cell{component, kind, settings, slots, place}`.

| Key | Value | Default |
|---|---|---|
| `component` | the component's name, as its package registers it ([macaw_component 01 §1](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-behavior)), matched by spelling | required |
| `kind` | the kind it renders as, one of `Macaw.Component.kinds/0`, given as an atom or its spelling | `:content` |
| `settings` | its settings by parameter name, inline, each a term of its parameter's type: a color term, a typed color, a time, a point, an atom where the type takes one. The cell checks only that it is a map of names; each value is checked against the component's declared parameter types where the component is known (§3.4), and a setting with no declared parameter is `:unknown_param` | `%{}` |
| `slots` | each of its slots bound to a source: `%{source: name, fields: %{role => field}, params: %{name => value}}`, `fields` and `params` defaulting to `%{}`, a `many` role's fields a list; each param a term, checked against the source's declared parameters (§3.4) | `%{}` |
| `source`, `fields`, `params` | **the shorthand for the component's one slot:** the slot's binding with no slot name, `source: name` with `fields` and `params` as a slot's, which validation gives the component's one slot (§3.4). The document keeps it short: `to_map/1` and `to_json/1` write it as given, `fields` and `params` only when not empty. `source` beside `slots` is `:source_and_slots` at `[:source]`, and `fields` or `params` with no `source` `{:requires, :source}` at its key | `nil` |
| `place` | where it sits, as the surface's layout reads it (§3.3): `%{x, y, w, h}` on the grid. `Cell.new/2` takes the layout that judges it, the grid by default; `nil` holds it as given | required on a grid |

Cell names are names in the kernel's sense, unique within the surface (the map's keys).

**Cells may be given as a list,** `cells: [cell, …]`, an input form: the surface holds them as the map it always does, and their order where its layout reads one.
- **A listed cell's name** is its `name` key, a name, else one **derived** from it: its component's last word and its source (its `source`, or its one slot's), `<word>_<source>` (`"macaw.table"` reading `"services"` is `table_services`), the word alone with no single source. A derived name is numbered `_2`, `_3`, … past every name taken, the list's explicit names first, then the names derived before it in list order, so names are deterministic from the document and instance ids stable across renders.
- **Its faults** are at `[:cells, i | path]` until it has a name: an explicit name given again is `{:duplicate, name}` at `[:cells, i, :name]`, one that isn't a name `{:type, :name}` there, a cell with no name and no component `:required` at `[:cells, i, :component]`, and an entry that isn't a map `{:type, :map}` at `[:cells, i]`; a list none of whose entries can be named has only these faults. Once named, its faults are at `[:cells, name | path]` as a mapped cell's.
- **Placement by order** (§3.3): with no `layout`, listed cells none of which has a place are laid out by `{:stack, order: names}`, the list's names in its order; listed cells all with a place are on the grid, as mapped ones are; a list placing some cells and not others is `:place_mixed` at `[:cells]`, never a guess, and no place is judged. A `:stack` or `:flow` named with no `order` takes the list's.
- **The forms write the expanded document:** `to_map/1` and `to_json/1` write the map of cells and the layout with its order, so a stored surface never depends on a default that could change under it.

```test:cells-source
a cell's source binds its one-slot component and validates and renders as the explicit binding, which Validated holds; a component with no slot or several is {:ambiguous_slot, slots}, source beside slots and fields or params without source are faults; the shorthand's source, fields and an unknown component are faults at the cell's own keys; it round-trips as itself through the map and JSON forms
```

```test:surface-list
listed cells with no place expand to the explicit stack in the list's order, equal structs and equal map forms, and render in it; derived names are deterministic, numbered past every name taken, explicit names winning; a flow takes the list's order and placed cells a grid; a mixed list is :place_mixed, and every bad listed cell is a fault by path
```

```test:cells-shape
a cell builds with its defaults, kind read from an atom or its spelling, setting and param names normalized to strings and their values kept as given; a missing component or place, an unknown kind, settings or params that aren't a map of names, a slot without a source and an unknown key are faults at their paths
```

### 3.3 Layouts {#pages-layouts}

**A layout is a behavior, the way a component is one:** `Macaw.Layout`. A surface names its layout by `layout`, a name or `{name, options}`, and every rule of placing its cells is the layout's:

| Callback | Answers |
|---|---|
| `name/0` | the name a surface spells it by (`"grid"`) |
| `options/1` | its options checked, `{:ok, options}` or the faults by path (`[:layout, :options, key]`); none given is `%{}` |
| `place/1` | a cell's place checked, `{:ok, place}` or the faults by path from the place; `nil` is a cell with no place, which a layout that needs one refuses as `:required`. It judges the shape alone, never by the options, so places are judged even when the options fail: every fault at once (#236). A rule that needs the options (the grid's bounds) is `faults/2`'s |
| `faults/2` | the placement faults of the cells (each with a checked place) under the options, by path from the surface, all at once |
| `order/2` | the cells' names in reading order, which is the DOM order and the visual order ([10 §4](10-web.md#web-a11y)) |
| `container/1` | the classes of the element holding the cells, which the stylesheet styles |
| `classes/2` | a place's classes: placement is by classes only, never inline style ([10 §1](10-web.md#web-csp)) |
| `size/4` | a place's declared size in CSS pixels from the surface's width and row height, what its component lays out at and its budget is evaluated at, before any render (§3.5) |
| `stylesheet/1` | its static stylesheet for the options, served from `'self'` by its content address |

- **The built-in layouts** are `Macaw.Layout.builtins/0`: the grid (`Macaw.Grid`), the stack (`Macaw.Layout.Stack`), the flow (`Macaw.Layout.Flow`) and named areas (`Macaw.Layout.Areas`), below; `Layout.default/0`, the grid, is a surface's layout when it names none. `Layout.split/1` reads a `layout` value as its spelled name and its options; anything else is `{:type, :layout}` at `[:layout]`.
- **Which layouts exist is the host's** ([12 §1.1](12-registry.md#registry-host)): its registry holds the built-in layouts and the ones it adds, and nothing else. `Macaw.Surface.new/1` judges a built-in layout's options and its cells' places as it builds the surface; a name no built-in has is held as given, with its cells' places, and judged by `validate/3` through the registry (§3.4). A name the registry doesn't hold is `{:unknown, :layout}` at `[:layout]`, and nothing is placed.
- **A host serves the stylesheet a surface's layout uses:** `Macaw.Surface.stylesheet/1` of a validated surface is `{path, css}`, the layout's sheet for its options and its content address, served from `'self'`. The grid's, the stack's and the flow's are each one sheet whatever the surface; an areas layout's is its template's.
- **Nothing reaches a layout's module but through the behavior:** validation, fetching and rendering ask the validated surface's layout, never `Macaw.Grid` by name.

```test:layout-behavior
the grid, the stack, the flow and the areas are the built-in layouts, the grid the default, its callbacks its own rules; a surface holds :grid for the grid with no options and refuses options the grid doesn't take, and a layout that is neither a name nor {name, options}; nothing in the library reaches the grid but through the behavior
```

```test:layout-registry
a layout no registry holds is {:unknown, :layout} at validation, its places held as given until then; an adopter's layout, registered, validates its places and placement by path, orders, classes and sizes the rendered cells; a registry's layouts are layouts, each name once, the built-ins always among them
```

#### The stack and the flow {#pages-ordered}

**Two layouts order their cells by a list:** the stack, `:stack`, one column (what the grid collapses to on a narrow screen, chosen on purpose), and the flow, `:flow`, sections for prose. Their one option, **`order`**, required, is every cell's name once in reading order (`{:stack, order: ["header", "chart", "table"]}`), each a name read as its spelling. A surface's cells are a map, which keeps no order, so the order is the layout's to state; a layer that adds a cell restates the order, as it overrides the layout whole (§3.1).

- **A cell has no place:** one given is `{:not_taken, "stack"}` (or `"flow"`) at `[:cells, name, :place]`. The order missing is `:required` at `[:layout, :options, :order]`, one that isn't a list `{:type, {:list, :name}}` there, an entry that isn't a name `{:type, :name}` at its index, and another option `:unknown_key`.
- **The order names every cell exactly once,** checked at validation with the cells (§3.4): a name no cell has is `{:unknown_cell, name}` and a name given again `{:duplicate, name}`, each at `[:layout, :options, :order, i]`, and a cell it leaves out `{:missing, name}` at `[:layout, :options, :order]`, all at once.
- **Reading order is the order,** and so the DOM order and the visual order ([10 §4](10-web.md#web-a11y)).
- **Classes:** the stack's container is `"mw-stack"` and each cell `"mw-cell"`; the flow's container `"mw-flow"` and each cell `"mw-cell mw-section"`. Each has one static stylesheet served by its content address: `Macaw.Layout.Stack.stylesheet/0` (one column of rows at least `var(--mw-grid-row, 4rem)`, the grid's gap) and `Macaw.Layout.Flow.stylesheet/0` (block sections, each its content's height, `var(--mw-flow-gap, 1.5rem)` apart), at their `stylesheet_path/0`. No style is inline.
- **A cell's declared size** is the surface's width and four rows, `{width, 4 * row_height}`, known before it renders.

```test:layout-ordered
a stack and a flow render in the order given, which is the DOM order, with their classes and no inline style; a cell with a place is refused, and a missing, mistyped or extra option; at validation a name no cell has, a name given twice and a cell left out are all faults by path; a cell's size is the width and four rows; each stylesheet is served by its address; an ordered layout round-trips through the map and JSON forms
```

#### Named areas {#pages-areas}

**`:areas` lays out named regions from a template,** as CSS's `grid-template-areas` does: `{:areas, template: [["header", "header"], ["nav", "main"]]}`. Its one option, **`template`**, required, is rows of area names, each row naming the area of each of its columns and `nil` a column no area holds (written `.` in the stylesheet), every row as wide as the first, at most 64 rows of at most 24 columns. An area name is lower-case letters, digits and `_`, starting with a letter, given as a string or an atom read as its spelling, so it is safe in a stylesheet by its grammar.

- **The template's faults,** all at once, at `[:layout, :options, :template]`: missing is `:required`, not a non-empty list `{:type, :template}`; a row that isn't a non-empty list is `{:type, {:list, :name}}` at its index and an entry that isn't a name or `nil` `{:type, :name}` at `[..., i, j]`; a row of another width `{:width, first, given}` at its index; an area that isn't one rectangle (its columns don't fill the box they span) `{:not_rectangle, name}`; too many rows or columns `{:limit, :rows | :columns, max, given}`.
- **A cell's place names an area,** `%{area: "main"}`: a cell with none is `:required`, a missing or ill-spelled `area` `:required` or `{:type, :name}` at `[:cells, name, :place, :area]`, and another key `:unknown_key`. At validation, an area the template doesn't name is `{:unknown_area, area}` there, and a second cell in one area `{:taken, first}` at the later cell by name. An area no cell takes stays empty.
- **Reading order** is the order each area first appears in the template, row by row, and so the DOM order and the visual order ([10 §4](10-web.md#web-a11y)).
- **Classes:** the container is `"mw-areas mw-areas-<digest>"`, the digest the first twelve hex digits of the template's value's digest ([macaw_layers 01 §7](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-digest)), and each cell `"mw-cell mw-area-<area>"`. **The stylesheet is generated per template** (`Macaw.Layout.Areas.stylesheet/1`): under the template's class, its areas and equal columns, the rows of `var(--mw-grid-row, 4rem)` at least and the grid's gap, a rule placing each area, and a container query that stacks the areas into reading order when the surface is narrower than `40rem`. One template is one sheet and one address (`stylesheet_path/1`), whatever spelling gave it; another template has another class, so two never share a rule. No style is inline.
- **A cell's declared size** is its area's share of the width by its columns and its rows' height: `{columns * width / template_width, rows * row_height}`.

```test:layout-areas
a template's rows are names or nil as wide as the first, each area a rectangle, within the limits, every fault at once by path; a cell's place names an area, an unknown area and two cells in one are faults at validation; reading order is each area's first appearance, the DOM order, with no inline style; a cell's size is its area's share; one template is one stylesheet at one address, another another, and a host gets a validated surface's sheet; an areas layout round-trips through the map and JSON forms
```

#### The grid {#pages-grid}

A grid surface places its cells on **12 columns**, or on 6 or 24 by its one option, `columns` (`{:grid, columns: 24}`): `Macaw.Grid.widths/0`, an allowed set so the stylesheet stays static. A width outside it is `{:enum, [6, 12, 24]}` at `[:layout, :options, :columns]`, another option `:unknown_key` there; `Macaw.Grid.columns/0`, the width when none is chosen, is 12. Places are in integer units: `x` from 0 to one less than the columns, `w` from 1 with `x + w` at most the columns, `y` from 0, `h` from 1, and `y + h` at most **64** rows (`Macaw.Grid.rows/0`), so every placement has a class. `Macaw.Grid.faults/2` of the cells and the options (`faults/1` on 12) is every fault at `[:cells, name, :place]`: a bound broken is `{:out_of_bounds, what, value}` (`what` one of `:x`, `:w`, `:x_plus_w`, `:y`, `:h`, `:y_plus_h`), and two cells overlapping is `{:overlap, other}` at the later cell, later in reading order. A place that isn't four integers is the cell's own fault (§3.2).

- **Reading order** is by `y`, then `x`, then name (`Macaw.Grid.order/1`): the DOM order, so DOM order is visual order ([10 §4](10-web.md#web-a11y)).
- **Placement is by classes**, never inline style ([10 §1](10-web.md#web-csp)): `Macaw.Grid.classes/1` of a place is `"mw-cell mw-col-<x+1> mw-span-<w> mw-row-<y+1> mw-rows-<h>"`, the same on every width, and the cells' container is `"mw-grid"` on 12 columns and `"mw-grid mw-grid-<n>"` on another (`container/1`), each class one rule of **one static stylesheet** for every width, `Macaw.Grid.stylesheet/0`: the grid (`.mw-grid`: 12 equal columns, rows of `var(--mw-grid-row, 4rem)` at least, a gap of `var(--mw-grid-gap, 1rem)`; `.mw-grid-6` and `.mw-grid-24` the other widths' columns), one rule per column start and column span up to 24, per row start and row span, and a container query that stacks every cell into reading order, one column, rows auto, when the surface's container is narrower than `40rem`. Its bytes are a pure function of nothing, served from `'self'` at `Macaw.Grid.stylesheet_path/0`, its content address ([macaw_component 01 §1.8](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-assets)). This settles #5: exact placement with no inline style, by construction.
- **A cell's declared size** is its share of the surface's width and its rows' height: `Macaw.Grid.size/4` of a place, the options, the surface's width and its row height is `{w * width / columns, h * row_height}` in CSS pixels (`size/3` on 12), the size its component lays out at before any measurement and its budget is evaluated at (§3.5).

```test:grid-rules
placements in bounds pass; x, w, x+w, y, h and y+h out of bounds and non-integers are each a fault; an overlap is named at the later cell in reading order; reading order sorts by y, x and name
```

```test:grid-columns
a grid of 6 or 24 columns places and faults on its own bounds and sizes by its width, a width outside the set is a fault by path, in the value and the JSON form; one stylesheet holds every width's rules; a surface on 24 columns validates, renders its container's width and round-trips its layout through the map and JSON forms
```

```test:grid-classes
a placement's classes name its column, span, row and rows; the stylesheet has a rule for every class a valid placement can name and the stacking query, and its path is its content's address; a cell's size is its share of the width and its rows' height
```

### 3.4 Validating a surface {#pages-surface-validate}

**The static pass** ([07 §2](07-documents.md#documents-validation-time)): `Macaw.Surface.validate/3`, of a surface, the host's registry (`Macaw.Registry`, [12 §1.1](12-registry.md#registry-host)) and its sources by name, each `{source, context}` as `Macaw.Data.Source.describer/1` takes them. No I/O but `describe`, which a source answers from configuration, and no viewer. It answers `{:ok, %Macaw.Surface.Validated{}}` or `{:error, faults}`, every fault at once by path from the surface:
- **the layout**: the surface's from the registry (`{:unknown, :layout}` at `[:layout]` for one it doesn't hold), and every rule of its placement (§3.3; the grid's at `[:cells, name, :place]`);
- **the component**: a name the registry doesn't hold is `{:unknown_component, name}` at `[:cells, name, :component]`;
- **the kind**: one the component doesn't offer is `{:kind_not_offered, kind, kinds}` at `[:cells, name, :kind]`;
- **the settings and declarations**: `Macaw.Component.declarations/2`'s faults, at `[:cells, name, :settings | path]`;
- **the source shorthand**: a cell's `source` binds the component's one slot, its source and params checked as that slot's binding is, at the cell's own keys (`[:cells, name, :source]`, `[..., :params | path]`, `[..., :fields | path]`); a component with no slot or several is `{:ambiguous_slot, slots}` at `[:cells, name, :source]`, so a component that later gains a second slot faults loudly and is never silently rebound. An unknown component, or settings that fail, leave it `{:unchecked, :component}` or `{:unchecked, :settings}` there. `Validated` holds the explicit binding under the slot's name;
- **the slots**: every slot the component declares must be bound (`:unbound` at `[:cells, name, :slots, slot]`), and a binding of a slot it doesn't declare is `:unknown_slot`; a source not in the map is `{:unknown_source, name}` at `[..., slot, :source]`, an entry that isn't a `{source, context}` of a struct with the source contract's `describe/2` and `fetch/2` is `{:bad_source, name}` there, never echoing the entry, one whose `describe` fails `{:describe, reason}`; the binding's fields are checked by `Macaw.Component.Slot.check/3` against the described schema (at `[..., slot, :fields | path]`), and its params by `Macaw.Data.Parameter.validate/2` against the described params (at `[..., slot, :params | path]`).

**Each check runs on what it needs, so no failure hides another** (#195):
- **A binding's source and params need only the cell.** They are checked for every binding, whatever else in the cell fails.
- **The kind and the settings need the component.**
- **Which slots exist (`:unbound`, `:unknown_slot`) and each binding's fields need the configured declarations,** and so valid settings. A binding's fields also need its source described.
- **A check whose prerequisite failed is not run, and that is reported, never skipped silently:**
  - a cell with bindings whose component is unknown gets `{:unchecked, :component}` at `[:cells, name, :slots]`;
  - one whose settings fail gets `{:unchecked, :settings}` there.

`%Macaw.Surface.Validated{surface, cells, layout, order}` holds, for each cell, its component module, its validated settings, its declarations, and each slot's source, description, request params and **resolved binding** (`Macaw.Component.Slot.resolve/3`: the field each role reads, an unbound `window` role holding the window field and an unbound optional role absent); `layout` is the layout module and its checked options; `order` is the cells in its reading order. Rendering takes only a validated surface, so nothing renders that hasn't passed.

`sources` that isn't a map is the one fault `{:type, :map}` at `[:sources]`.

```test:validate-pass
a surface of known components bound to described sources validates, with each cell's module, settings, declarations and descriptions, in reading order
```

```test:validate-faults
an unknown component, an unoffered kind, bad settings, an unbound and an unknown slot, an unknown source, a failing describe, a binding the schema doesn't meet, bad params and a bad place are all reported at once by path
```

```test:validate-bad-source
a malformed entry is {:bad_source, name} at the binding's source, under the shorthand and a slot, from validate/3 and show/2, and the fault never echoes the entry; a source not in the map stays unknown, and sources that aren't a map are a fault at [:sources]
```

```test:validate-independent
one cell failing its kind, settings, a source and a binding's params reports every one, with {:unchecked, :settings} for the slot checks its settings rule out; an unknown component's binding source is still checked, with {:unchecked, :component}
```

### 3.5 Fetching {#pages-surface-fetch}

**`Macaw.Surface.fetch/2`** of a validated surface and an `env` answers each cell's deliveries and drawn state, `%{cell => %{deliveries: %{slot => delivery}, drawn: state}}`. `env` is a keyword list: `sources:` (the host's sources by name, as given to `validate/3`, required), `viewer:` (the host's viewer, opaque, `nil` the anonymous one), `now:` (required: the surface's now, never a clock read), `ceiling:` (the host's row ceiling, required), `width:` (the surface's width in CSS pixels, `1200` by default), `row_height:` (`64`), and `timeout:` (ms, `5_000`).
- **Budgets:** each slot's budget is `Macaw.Component.budget/4` at the cell's declared size, its layout's `size/4` (§3.3) (a component's bad budget draws its cell `invalid` and fetches nothing for that slot), clamped by `Macaw.Data.Source.Finish.ceiling/2` ([macaw_data 01 §6.1](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-budgets)); a clamped slot's delivery says `reduced_by: :runtime`.
- **Orders:** each slot's request carries the order its component asks for (its optional `order/2`, through macaw_component), its role keys resolved to fields through the slot's binding before the request and before pooling ([macaw_component 01 §1.4](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-budget)), so a delivery capped at its budget holds the first rows in it ([macaw_data 01 §2.3](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-request)): a source supporting `:order` serves them, else finishing orders what was served (`served.ordered`). An order of no shape, one a binding can't resolve, or one naming a field the slot's schema lacks, draws the cell `invalid` and nothing is fetched for that slot.
- **Pooling within the surface:** slots bound to one source with equal params and equal orders cost one fetch, at the largest of their budgets (`Finish.pooled/1`), and each slot is reduced to its own (`Finish.reduce`). Pooling across pages is #108's.
- **Fetching never blocks or crashes the caller:** each fetch runs in a process of its own (`Macaw.Data.Bounded`), the fetches concurrently, each bounded by `timeout:`; the delivery is finished by `Macaw.Data.Source.Finish.finish/4` against the description and reduced to each slot's budget. Every step answers a value (macaw_data 0.10): a ceiling, a request, a finishing or a reduction that refuses draws the slot's cell `invalid`, never a crash.
- **Drawn states** ([macaw_component 02 §6](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-states)), the highest of its slots': a fetch that answers an error or whose process exits is `down`; one that hasn't answered within `timeout:` is `loading`; a delivery with no rows is `no_data`, whatever else it says; one whose `served.stale` is true, an answer its source could not refresh ([macaw_data 01 §3](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-delivery)), is `stale`, also when capped, and also when it reached the slot through a derived source; one `capped` or `reduced_by` anything is `capped`; otherwise `live`, in the drawn states' one precedence. A cell with no slots is `live`.

- **A source gone or malformed by fetch:** `sources:` is read again at each fetch, so a host can pass a different map than it validated with. A slot whose source is missing there, or whose entry is malformed by the rule in §3.4, draws its cell `invalid` and fetches nothing for that slot; other cells are unaffected. The same goes for a missing `sources:` or one that isn't a map.

```test:fetch-bad-source
a source gone or malformed by fetch, and sources missing or not a map, draw their cells invalid with the caller alive, and one bad source leaves another cell's fetch alone
```

```test:fetch-budgets
each slot is fetched at its budget at its cell's size, under every built-in layout, a place or none, clamped to the ceiling and marked runtime when clamped; slots sharing a source and params are fetched once at the largest budget and each reduced to its own
```

```test:fetch-role-order
an order naming a role reaches the source as the field bound to it, an unbound window role as the schema's window field; a capped slot holds the first rows in it from a source that orders and one the runtime orders; two slots whose orders resolve to one field pool, and to different fields don't; a role the binding can't resolve draws the cell invalid with nothing fetched; a field-keyed order is unchanged
```

```test:fetch-drawn
a source error, a crashed fetch, a hung fetch, a capped or reduced delivery and an empty one draw down, down, loading, capped and no_data, a stale delivery draws stale, also when capped or through a derived source, an empty one no_data whether stale or capped, and a delivery finishing refuses draws invalid; a cell's state is its slots' highest; a cell without slots is live
```

### 3.6 Rendering a surface {#pages-surface-render}

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
- **Each cell renders with its context** ([macaw_component 02 §2](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-context)): `mode`, `instance` `"<surface>-<cell>"`, `size` its declared size (`measured: false`), `heading_level` one below the surface's title (the title's own level without a title), `theme`, the default `preferences`, `now`, `bindings`, each slot's resolved binding, so the component reads the field bound to a role with `Context.field/3` (#194), and `schemas`, each slot's source schema as its description gives it, so the component reads a field's label and unit with `Context.label/3` and `unit/3` (#219); its assigns are its settings, declarations, drawn state, and its deliveries (a `:pure` component) or its value through `init/2`, `delivery/3` and `size/2` (a `:contained` one).
- **A component's raise is the caller's to take**, as the contract says ([macaw_component 01 §1](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-behavior)): a host isolates a component by process (`macaw_live`'s contained cell); this render does not catch it.
- `Macaw.Surface.render/2` fetches and renders in one call.

```test:render-markup
a surface renders its title at its level and its cells in reading order, each with its grid classes and instance id, nothing inline, in every mode
```

```test:render-bindings
each cell's context carries its slots' resolved bindings, the window field for an unbound window role and no optional role left unbound, and each slot's source schema, in a pure cell's render and a contained cell's init
```

```test:render-cells
each cell renders with its context: its instance, declared size, heading level below the title, theme and now; its drawn state and deliveries, or a contained component's value through its transitions
```

### 3.7 One call {#pages-surface-show}

**`Macaw.Surface.show/2`** validates, fetches and renders a surface in one call: `{:ok, html}`, a `Phoenix.HTML` safe value, or `{:error, faults}`, the faults `validate/3` gives, unchanged. Its first argument is a `%Macaw.Surface{}`, `{:ok, surface}` or `{:error, faults}` (a pipe from `new/1` or `build/2`, whose faults it answers as they are), or the attrs `new/1` takes. Its `env` is `fetch/2`'s and `render/3`'s, with the defaults a host would otherwise restate on every call:
- `sources:`, given once, required;
- `registry:`, `Macaw.Registry.default/0` ([12 §1.1](12-registry.md#registry-host)) unless given;
- `now:`, **one clock read in this call**, a host-side call, unless given; never in a source or a component, and never in a test, which gives its own;
- `ceiling:`, `config :macaw, :ceiling` unless given; with neither it answers `{[:ceiling], :required}`, a host's configuration mistake, as a value ([00 §4.3](00-overview.md#core-errors));
- `mode:`, `:socketless` unless given; given a LiveView `socket:`, `:live` once it is connected and `:socketless` before, as `Phoenix.LiveView.connected?/1` reads it (a socket with a transport process is connected), so `macaw` needs no LiveView.

It renders exactly what `validate/3` then `render/2` render, given the same `now`. **Its faults,** in order: a first argument that isn't a surface answers `new/1`'s; an `env` that can't show it answers every fault of the `env`, by its key: `{[:sources], :required}` or `{:type, :map}`, `{[:registry], {:type, :registry}}`, a configured registry's faults from `Registry.default/0` under `[:registry]`, and `{[:ceiling], :required}`; then validation's.

```test:surface-show
show/2 renders what validate/3 then render/2 render given the same now, from a surface, {:ok, surface} or attrs, with the default registry or a given one; it answers validation's and new/1's faults unchanged; the ceiling comes from the host's config, and its absence is a fault; a missing or wrong sources, a registry that isn't one and a configured registry that can't be built are faults by key, all at once; a first argument that isn't a surface answers new/1's faults; with no now it reads the clock once itself; its mode is socketless unless given and follows a LiveView socket's connection
```

### 3.8 The short code form {#pages-surface-build}

**`Macaw.Surface.build/2`** writes a surface in code, `build(name, keys)`: the surface's other keys as `new/1` takes them, its `cells` a list in which each cell is `{component, opts}` (`opts` the cell's other keys, a keyword list or a map) or a component's name alone. It is `new/1` of the same keys, with the list's order and derived names (§3.2), so the surface it answers is equal to the one written out, and `to_map/1` writes that one. `build!/2` answers the surface or raises `ArgumentError` naming every fault, a mistake in the code that wrote it.

With the defaults of §3.2, §3.3 and §3.7, a surface of a predefined source and the built-in table is five lines:

```elixir
{:ok, html} =
  "status"
  |> Macaw.Surface.build!(title: "Service status", cells: [{"macaw.table", source: "services"}])
  |> Macaw.Surface.show(sources: %{"services" => {%MyApp.Services{}, nil}})
```

```test:surface-build
the short form in five lines renders, byte for byte, the surface written out; build/2 is new/1 of the same keys, cells as {component, opts} or a name, and build!/2 raises naming the faults
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
- **`navigate`** goes to a typed reference ([macaw_layers 03](https://github.com/dcoai/macaw_layers/blob/main/spec/03-stores.md#stores-references)) with params taken from the event's fields: a navigation step, performed by the host's navigation behavior. The library never navigates.
- **Event fields** are named as paths into the event ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event)): `{event: identity}`, `{event: [identity, service]}`, `{event: value}`, or `{event: [row, field]}`. Only the named field is read: the row itself is never recorded. A field written by `set` becomes that state source's value, recorded under its capture level like any other ([08](08-records.md#records-stores)); one used by `navigate` is recorded as the step's params.
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
