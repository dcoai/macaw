# 05 — Components, cells and containers {#components}

<!-- surfex: class architecture -->

A **component** is a registered implementation of one public contract. Built-in and third-party components use the same contract ([00](00-overview.md) goal 8). A **cell** places a component in a surface.

**Two libraries** (#137): the contract is `macaw_component`'s, specified in [its own repository](https://github.com/dcoai/macaw_component/blob/main/spec/README.md), so a component package implements it without the core; §5 and §6's built-in components are the core's, `macaw`. §7 settles where the contract names something the core runs. §1–4 moved to `macaw_component` with their anchors (#141); each keeps its heading here and points to where it is now.

## 1. What a component declares {#components-declares}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.2](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-declares), with the behavior and its static declarations ([§1](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-behavior)), slots ([§1.3](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-slots)), events, announcements, observation and shortcuts ([§1.6](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-events)), assets, hooks and proxy routes ([§1.8](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-assets)), and isolation and access ([§1.9](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-isolation)).

### 1.1 Parameters {#components-parameters}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.1](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-parameters).

### 1.2 Budget per slot {#components-budget}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.4](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-budget).

### 1.3 State a component writes and reads {#components-state}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.5](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-state).

### 1.4 Reading load {#components-reading}

<!-- surfex: class moved -->

Moved: [macaw_component 01 §1.7](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-reading).

## 2. Kinds {#components-kinds}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

Moved: [macaw_component 01 §2](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-kinds), with each kind's output rules in [02 §4](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-kind-rules). Which kind a cell takes, from where it sits, is the core's: a cell names its `kind`, defaulting to `:navigation` in a region whose role is navigation, `:content` elsewhere, and the container's pane kind inside a container, and validation checks that the component offers it and that the region allows it.

## 3. Rendering rules {#components-rendering}

<!-- surfex: class moved -->

Moved: [macaw_component 02 §5](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-rendering), with the assigns ([§1](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-assigns)), the context ([§2](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-context)) and the client protocols ([§8](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-client)).

## 4. Drawn states, the runtime value and isolation {#components-states}

<!-- surfex: class moved -->

Moved: [macaw_component 02 §6](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-states) and [§7](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-contained). The contained cell that holds a value, heap-limited and restarted by its surface with a backoff (100 ms doubling to 10 s, reset after 30 s alive) and shown as `crashed` meanwhile, is `macaw_live`'s, so a component's crash never takes down the page that carries the visitor's observation (visualize.md C13; dcotek_web.md C13). **Embedded applications** (macaw#9's demos) are a container pattern running a nested LiveView with its own limits.

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
- **the status grid** (§6.2): one tile per thing, its state's words and its role's color, reading load `:glance`;
- **the stat** (§6.3) and **the meter** (§6.4): one number from a slot's rows, alone or against its range, reading load `:glance`;
- **the record** (§6.5): one row as a definition list, reading load `:scan`;
- **the feed** (§6.6): time-ordered rows, newest first, reading load `:scan`.

**Expected packages:**
- **visualize:** its visuals (charts, maps, scenes) implement the contract **from visualize itself**, as `Visualize.Macaw.*` in `visualize_live`, compiled when `macaw_component` is present ([00](00-overview.md) goal 6; visualize#946). Its visual table stays for standalone use and image output;
- **metresis:** dashboard and panel components, plus its shaping functions, so remote hosts can draw them (metresis#556);
- **`macaw_edit`:** data-editing components ([13](13-writes.md));
- **components built on ryutronic:** wizards, durable jobs, an assistant.

### 6.1 The table {#components-table}

`Macaw.Builtin.Table`, registered as `"macaw.table"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`:
- **Parameters:** `caption` (text, `"Table"`), the table's name; `identity` (text, `""`), the field naming each row, `""` for rows that can't be selected; `sort` (text, `""`, bindable), the field rows are sorted by, `""` for the delivered order; `order` (category `"asc"` or `"desc"`, `"asc"`, bindable).
- **Declarations:** one slot, `rows`, of whole rows, with one optional role, `columns` (`many`, any type): the fields shown, in the order bound (`fields: %{"columns" => ["host", "p50"]}`). Being a role, each field is checked against the source's schema at validation ([06 §3.4](06-pages.md#pages-surface-validate)), so a field the source lacks is a fault at its path before any data flows; unbound, every column of the delivered table shows. Events `"sort"` and `"select"`; `writes: %{"selection" => :identity}`; `observes: [:activate, :select]`; reading load `:scan`. **Its order** (`order/2`, [macaw_component 01 §1.4](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-budget)): with `sort` naming a field, the rows slot asks for `[{sort, :asc | :desc}]` in its `order` direction, and `[]` without one, so a delivery capped at its budget holds the first rows in that order (spec/06 §3.5).
- **Budget:** the rows its declared height shows at `2rem` (32 px) a row, times four for scrolling, at least 10.
- **Markup:** a `<table class="mw-table">` with its `<caption>`; a header row of `<th scope="col">`, one per column shown (the `columns` bound, else the delivered table's columns in its column order: name order for rows given as maps), each a real `<button type="button">` emitting `sort` with the field as its value, its text the field's label from the source's schema, with its unit after it in parentheses when it has one, written as its display symbol with its annotations rather than its UCUM code (`Temperature (°C)` for `Cel`, `Request rate (request/s)` for `{request}/s`, the code itself only where it has no symbol; `Macaw.Builtin.Text.heading/3`, over `Context.label/3`, `Context.unit/3` and macaw_data's [display symbol](https://github.com/dcoai/macaw_data/blob/main/spec/03-units.md#units-symbol), the field's name when the schema gives no label), and the sorted column's `<th>` carrying `aria-sort` (`ascending` or `descending`); a row per delivered row, sorted when `sort` names a column (nil last, ties in delivered order), each `<td>` the value as text, `nil` empty; with an `identity` field, each row's first shown cell holds a `<button type="button">` named `Select` and the identity, emitting `select` with the row's identity, and the row's id is `Context.id/2` of `r-` and the identity's spelling, base64url-encoded so any identity makes an id, so ids are stable; a `capped` or `stale` table draws its notice above its rows, and any other non-live state its notice alone.
- **Stylesheet:** one static sheet, `Macaw.Builtin.Table.stylesheet/0`, served from `'self'` at `stylesheet_path/0`, its content address, as the grid's is ([06 §3.3](06-pages.md#pages-grid)): rules for the table, its caption, cells, header and select buttons, and the sorted column's mark (`aria-sort`'s ▲ or ▼). Every color is a theme custom property with the default theme's value as its fallback ([macaw_layers 04 §6](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-delivery)); it has no `url(` and no `@import`.
- **It passes `macaw_component`'s kit**, the core being the contract's first implementer ([macaw_component 00 §3](https://github.com/dcoai/macaw_component/blob/main/spec/00-overview.md#component-order)).

```test:table-declares
the table's parameters, slot, events, selection write, observations, reading load and budget are as declared
```

```test:table-order
the table's order is its sort column in its direction, none without a sort; a capped table holds the first rows in it from a source that orders and from one the runtime orders, and one cut by a capping source says it is a sample; slots pool only on equal orders, and a sort the schema can't answer draws the cell invalid
```

```test:table-headers
each column's header is its field's label, its unit's display symbol with annotations after it in parentheses when the schema gives one (the code where it has no symbol), the field's name when it gives no label; the sort button's value is the field, whatever the label
```

```test:table-columns
the columns role chooses the columns shown and their order, and the select button sits in the first shown cell; sorting by a field not shown still sorts; unbound, every column shows; a field the source lacks, or one listed twice, is a validation fault at its path
```

```test:table-stylesheet
the table's stylesheet has a rule for every class and element the table emits, every color a theme property, no url( and no @import, and its path is its content's address
```

```test:table-markup
the table renders a caption, scoped header buttons that sort, rows sorted by a field in either order with nil last, selection buttons and stable ids with an identity, and its notice when not live; it passes the component kit
```

### 6.2 The status grid {#components-status-grid}

`Macaw.Builtin.StatusGrid`, registered as `"macaw.status_grid"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`: one tile per thing, showing its state (#256).
- **Parameters:** `label` (text, `""`), the grid's heading, none when empty.
- **Declarations:** one slot, `rows`, with three roles, each checked against the source's schema at validation ([06 §3.4](06-pages.md#pages-surface-validate)): `name` (`:category`, `:text` or `:number`, `identity: true`), what each tile is about; `status` (`:category`), its state; `detail` (optional, `:time`, `:number`, `:category` or `:text`), a line under the state. Reading load `:glance`; no events and no writes.
- **Budget:** `nil`, every row up to the host's ceiling; no order.
- **Markup:** a `<div class="mw-status-grid">`, its `label` as a heading at the context's level (`Context.heading/2`) when given, and a `<ul>` of one `<li class="mw-status-tile mw-status-<role>">` per row, in the order of the `name` field's values compared by its type as a source orders them ([macaw_data 01 §2.3](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-request)), or as delivered when the slot has no schema. Each tile holds the name, the state's words and the detail:
  - **the role** is the one the `status` field's schema gives the state ([macaw_data 01 §1.6](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-schema-measure)), a theme's word: `neutral` for a state with none, for no state, and for a word that spells no class (lower-case letters, digits, `-` and `_`, starting with a letter). A theme's own word is kept as a class the theme may style;
  - **the state's words** are its value's display name from the schema, else its spelling, and an en dash for no state, so color is never the only cue;
  - **the detail** is its value as text, with its unit's display symbol after it (`Macaw.Builtin.Text.unit/3`, §6.1), and nothing for `nil`;
  - **the tile's id** is `Context.id/2` of `s-` and the name's spelling, base64url-encoded, so ids are stable;
  - a `capped` or `stale` grid draws its notice above its tiles, any other non-live state its notice alone, and a live slot with no rows draws `no_data`.
- **Stylesheet:** one static sheet, `Macaw.Builtin.StatusGrid.stylesheet/0`, served from `'self'` at `stylesheet_path/0`, its content address: the grid, its tiles, and a rule per built-in status role (`good`, `warning`, `bad`, `info`, `neutral`, `roles/0`), each a theme custom property with the default theme's value as its fallback ([macaw_layers 04 §6](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-delivery)); it has no `url(` and no `@import`.
- **It passes `macaw_component`'s kit.**

```test:status-grid-declares
the status grid's parameter, roles, reading load and budget are as declared and it is a member of Macaw.Builtin; a surface checks its roles against the source's schema, a status bound to a number and a field the source lacks being faults at their roles
```

```test:status-grid-markup
the status grid renders one tile per row in the name field's order, each tile's role from the schema's status (neutral without one or for a word that spells no class), the state's display words or spelling always, the detail with its unit's symbol, stable ids, a heading only with a label, no inline style, and its notice when not live; it passes the component kit
```

```test:status-grid-stylesheet
the status grid's stylesheet has a rule for every class it emits and each built-in role, every color a theme property, no url( and no @import, and its path is its content's address
```

### 6.3 The stat {#components-stat}

`Macaw.Builtin.Stat`, registered as `"macaw.stat"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`: one number from a slot's rows, with its label and unit (#256).
- **Parameters:** `label` (text, `""`), the heading, the field's label from the schema when empty; `reduce` (category, `"latest"`, bindable), one of `latest`, `delta`, `sum`, `mean`, `min`, `max`, `median` and `count`; `digits` (category, `""`), `"0"` to `"6"` decimal places, `""` for the number as it is.
- **Declarations:** one slot, `rows`, with two roles, each checked against the source's schema at validation ([06 §3.4](06-pages.md#pages-surface-validate)): `value` (`:number`), the field read; `t` (`:time`, `window: true`, optional), which `latest` and `delta` read by. Reading load `:glance`; no events and no writes.
- **Order and budget:** `latest` and `delta` ask for the rows newest first by the `t` role ([06 §3.5](06-pages.md#pages-surface-fetch)), and `latest` for one row, so a capped series holds its newest; the rest ask for no order, and every row up to the host's ceiling.
- **The number** (`Macaw.Builtin.Reading`): `latest` is the newest row's value, a gap being no reading; `delta` is the last reading in time minus the first; the others are the statistics of the same names ([macaw_data 04 §5](https://github.com/dcoai/macaw_data/blob/main/spec/04-operations.md#operations-statistics)) over the readings, gaps dropped. **Absence is never zero:** a slot whose readings are all gaps has no number, whatever the statistic, except `count`, which is `0`. `latest` or `delta` with no time field, neither bound nor the schema's window field, has no newest row, and draws `invalid` rather than call an arbitrary row the newest.
- **Markup:** a `<div class="mw-stat">`; the label as a heading at the context's level (`Context.heading/2`), of class `mw-stat-label`; a `<p class="mw-stat-value">` of the number in a `<data value="…">`, at its `digits`, and its unit's display symbol (`Macaw.Builtin.Text.unit/3`) in a `<span class="mw-stat-unit">`, none for `count`. No number is an en dash, with no `<data>` and no unit. A `capped` or `stale` stat draws its notice above its number, any other non-live state its notice alone. **A `latest` that is the whole answer draws none:** it asks for one row, so its delivery is always reduced and its cell `capped`, but when `served.ordered` is `:source` or `:runtime` and `served.capped` is false, that row is the newest and nothing is missing. It keeps the notice when the source cut its rows before they were ordered (`:sample`) or says it stopped short, and every other statistic keeps it, having read only part of the data.
- **Stylesheet:** one static sheet, `Macaw.Builtin.Stat.stylesheet/0`, served from `'self'` at `stylesheet_path/0`, its content address, every color a theme custom property with the default theme's value as its fallback; it has no `url(` and no `@import`.
- **It passes `macaw_component`'s kit.**

```test:stat-declares
the stat's parameters, roles and reading load are as declared and it is a member of Macaw.Builtin; digits outside its values is a fault; a surface checks the value role against the source's schema, a time and a field the source lacks being faults at the role
```

```test:stat-reduce
latest and delta ask for the rows newest first and latest for one row, the rest for neither; each statistic answers the operations' number over the readings, gaps dropped; delta is the last in time minus the first; on a surface, a capped series' latest is its newest from a source that orders and one that doesn't
```

```test:stat-markup
the stat renders its heading, its number in a data element at its digits, and its unit's symbol, none for a count, with no inline style; all-gap readings show an en dash and no data element, and a count of them is zero; latest or delta with no time field draws invalid and the other statistics still answer; capped and stale draw their notice above the number, other states the notice alone; a latest that is the whole answer, from a source that orders and one that doesn't, draws no notice, and a sample, a source's own capped, a statistic under a low ceiling and stale each keep it; it passes the component kit
```

```test:stat-stylesheet
the stat's and the meter's stylesheets have a rule for every class they emit, every color a theme property, no url( and no @import, and each path is its content's address
```

### 6.4 The meter {#components-meter}

`Macaw.Builtin.Meter`, registered as `"macaw.meter"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`: one number against its range (#256).
- **Parameters:** `label` and `reduce` as the stat's (§6.3); `min` (number, `0`); `max` (number, required), above `min`, else `{:not_above, min, max}` at `max`. The `<meter>` element's `low`, `high` and `optimum` wait on an optional number parameter, which macaw_data's parameters don't express yet (macaw_data#172).
- **Declarations, order and budget:** the stat's slot, roles, reading load, order, budget and number (§6.3).
- **Markup:** a `<div class="mw-meter">`; the label as a heading at the context's level, of class `mw-meter-label`, its id `Context.id/2` of `label`; a native `<meter>` named by that heading through `aria-labelledby`, with `value`, `min` and `max`, its fallback content the number; and a `<p class="mw-meter-value">` of the number and its unit's display symbol, so neither color nor length is the only cue. `<meter>` clamps its bar to the range, and the text shows the true value. No number is an en dash and no bar. Its states are drawn as the stat's.
- **Stylesheet:** one static sheet, `Macaw.Builtin.Meter.stylesheet/0`, as the stat's.
- **It passes `macaw_component`'s kit.**

```test:meter-declares
the meter's name and kind are as declared and it is a member of Macaw.Builtin; max is required, and a max not above min is a fault at its name
```

```test:meter-markup
the meter renders a native meter named by its heading, with its value and range, the true value and its unit's symbol beside it, a value past the range kept in both, and an en dash and no meter with no readings
```

### 6.5 The record {#components-record}

`Macaw.Builtin.Record`, registered as `"macaw.record"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`: one row as a definition list (#256).
- **Parameters:** `label` (text, `""`), its heading, none when empty; `identity` (text, `""`, bindable), the row whose identity field has this value, which state will bind so a record follows a table's selection; `pick` (category `"first"` or `"last"`, `"first"`), the row in time order when `identity` is empty.
- **Declarations:** one slot, `rows`, with two roles, each checked against the source's schema at validation ([06 §3.4](06-pages.md#pages-surface-validate)): `fields` (`many`, any type, optional), the fields shown, in the order bound, every column of the delivered table when unbound; `t` (`:time`, `window: true`, optional), which `pick` reads by. Reading load `:scan`; no events and no writes.
- **Order and budget:** with no `identity`, one row, oldest first for `first` and newest first for `last`, by the `t` role ([06 §3.5](06-pages.md#pages-surface-fetch)); with one, every row up to the host's ceiling, in no order.
- **The row:** by `identity`, the row whose identity field's value is written as that text, `no_data` for none, and `invalid` for a schema with no single identity field, since a composite identity has no one value to look up by; else the row the order put first. `last` with no time field, neither bound nor the schema's window field, draws `invalid` rather than call an arbitrary row the last.
- **Markup:** a `<div class="mw-record">`; the `label` as a heading at the context's level (`Context.heading/2`), of class `mw-record-label`, when given; a `<dl>` of each field's `<dt>`, its label and unit's display symbol (`Macaw.Builtin.Text.heading/3`), and its `<dd>`, the value as the table writes it (`Macaw.Builtin.Text.value/1`), `nil` empty. **A picked row that is the whole answer draws no notice:** it asks for one row, so its cell is `capped`, but with no `identity`, `served.capped` false and `served.ordered` not `:sample`, nothing is missing. A row looked up by `identity` may have been past the cap, so it keeps the notice above its list, as a sample, a source's own `capped` and `stale` do; any other non-live state draws its notice alone.
- **Stylesheet:** one static sheet, `Macaw.Builtin.Record.stylesheet/0`, as the stat's (§6.3).
- **It passes `macaw_component`'s kit.**

```test:record-declares
the record's parameters, roles, reading load, order, budget and membership are as declared; a surface checks the fields role against the source's schema, a field the source lacks being a fault at the role
```

```test:record-reads
on a surface, first and last are the oldest and newest row from a source that orders and one that doesn't, and identity finds its row; last with no time field draws invalid and first still answers
```

```test:record-markup
the record renders a definition list of labels and unit symbols, values as the table writes them, a gap empty, a heading only with a label, no inline style; the fields role chooses the fields and their order; no matching identity draws no_data, and no single identity field invalid; a picked row draws no notice, while a sample, a capped source, a lookup and stale keep theirs, and other states draw the notice alone; it passes the component kit
```

```test:record-stylesheet
the record's stylesheet has a rule for every element it emits, every color a theme property, no url( and no @import, and its path is its content's address
```

### 6.6 The feed {#components-feed}

`Macaw.Builtin.Feed`, registered as `"macaw.feed"` in the package `Macaw.Builtin`, of kind `:content`, `:pure`: time-ordered rows, newest first (#256).
- **Parameters:** `label` (text, `""`), its heading, none when empty; `limit` (number, `20`), the most items shown, a positive whole number, else `{:type, :pos_integer}` at `limit`.
- **Declarations:** one slot, `rows`, with four roles, each checked against the source's schema at validation ([06 §3.4](06-pages.md#pages-surface-validate)): `t` (`:time`, `window: true`), when; `title` (`:text` or `:category`), what happened; `body` (`:text`, optional); `level` (`:category`, optional), how much it matters. Reading load `:scan`; no events and no writes.
- **Order and budget:** the newest `limit` rows, newest first by the `t` role ([06 §3.5](06-pages.md#pages-surface-fetch)).
- **Markup:** a `<div class="mw-feed">`; the `label` as a heading at the context's level (`Context.heading/2`), of class `mw-feed-label`, when given; an `<ol>` of `<li class="mw-feed-item">`, each a `<time datetime>` of the row's time, written as the table writes it, a `<p class="mw-feed-title">`, and a `<p class="mw-feed-body">` when it has one. **A level** adds the class `mw-feed-<role>`, the role its schema's `status` gives it, `neutral` without one (as the status grid's, §6.2), and a `<p class="mw-feed-level">` of its words, so color is never the only cue. **The newest `limit` are the whole answer:** its cell is `capped` when there are more, but nothing it asked for is missing, so it draws no notice unless the source cut its rows before they were ordered (`:sample`) or says it stopped short. `stale` draws its notice above the list, any other non-live state its notice alone, and a live slot with no rows draws `no_data`.
- **Stylesheet:** one static sheet, `Macaw.Builtin.Feed.stylesheet/0`, as the stat's (§6.3), with a rule per built-in status role.
- **It passes `macaw_component`'s kit.**

```test:feed-declares
the feed's parameters, roles, reading load, order, budget and membership are as declared; a limit that isn't a positive whole number is a fault; a surface checks the roles against the source's schema, a title bound to a number and a field the source lacks being faults at their roles
```

```test:feed-reads
on a surface, the feed holds the newest limit rows, newest first, from a source that orders and one that doesn't, with no capped notice; a sample and a source's own capped keep the notice
```

```test:feed-markup
the feed renders its heading only with a label, a list of times, titles and bodies, a level's role class and words, neutral without a role, no inline style; stale draws its notice above the list, other states the notice alone, and no rows no_data; it passes the component kit
```

```test:feed-stylesheet
the feed's stylesheet has a rule for every class it emits and each built-in role, every color a theme property, no url( and no @import, and its path is its content's address
```

```test:builtins-end-to-end
a surface of every built-in component over in-memory sources validates and renders in every mode, with no inline style, and each is a member of Macaw.Builtin
```

## 7. The contract and the core {#components-libraries}

<!-- surfex: class architecture -->

The contract names four things the core runs. In each, **`macaw_component` owns the shape a component declares or receives, and `macaw` owns the behavior** (#137), so a component compiles and passes its kit with no core present, and another host (a plain LiveView, a test) can hold it.

| Case | `macaw_component` | `macaw` |
|---|---|---|
| **State** ([macaw_component 01 §1.5](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-state)) | the standard state names and value types a component may declare in `writes`, and the `local` keys' domain types; events as `Macaw.Data.Event`; the `bound/3` transition | state sources and scopes, applying emitted events, parameter and slot bindings, the page DAG ([03](03-state.md)) |
| **Context** ([macaw_component 02 §2](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-context)) | the context's fields (mode, measured size and root font size, heading level, instance id, theme, preferences) and the rules for using them ([02 §5](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-rendering)) | computing each instance's context on a page |
| **Containers** (§5) | kind `:container`, its output rules, and rendering the panes it is handed | panes as surfaces, lazy render and DAG compute, nesting depth, the built-in containers |
| **Cell actions** ([06](06-pages.md#pages-actions)) | declared event names, unique within a component ([01 §1.6](https://github.com/dcoai/macaw_component/blob/main/spec/01-contract.md#components-events)) | mapping a placement's events to actions |

- **A shape the contract owns is never redefined by the core.** The core reads it from `macaw_component`, so a component and the page that holds it agree by construction.
- **A host other than the core supplies the context and holds the value itself,** as [macaw_component 02 §7](https://github.com/dcoai/macaw_component/blob/main/spec/02-rendering.md#components-contained) already requires: the value never knows which host it is in.
- **Nothing in the contract needs a process, a state source or a page.** A proposed addition that does belongs to the core.
