# Changelog

## Unreleased

- Needs macaw_component `~> 0.2.2`: a column the table's `columns` role lists twice is `{:duplicate, field}` at its path, never shown twice (#240, #237).
- **Fixed:** a layout's bad options no longer hide its cells' place faults, at `new/1` or at validation, since `place/1` judges a place's shape alone; and `Surface.show/2` answers a failed `new/1` or `build/2` result's faults instead of raising (#238, #236).
- The table's docs and spec state its unbound column order as the code gives it: the delivered table's, name order for rows given as maps (#239, #237).
- The short code form (#231, #204): `Macaw.Surface.build/2` and `build!/2`, a surface's name and keys with its cells `{component, opts}` in a list, equal to the surface written out; with the defaults, a predefined source and the table are five lines.
- The host's default registry and the one-call render (#230, #204): `Macaw.Registry.default/0` (and `from_config/1`) from `config :macaw, packages:, layouts:`, `Macaw.Builtin` always included, kept in `:persistent_term` and rebuilt when the configuration changes; `Macaw.Surface.show/2` validates, fetches and renders in one call, `sources:` given once, the registry, `now:` (one clock read in the call), `ceiling:` (from `config :macaw, :ceiling`) and `mode:` (from a LiveView `socket:`) defaulted.
- **Fixed:** a list of cells none of which could be named also reported `:place_mixed` and `:empty`; it now gives only its entries' faults, a property over generated lists guarding it (#235, #233).
- **Fixed:** a bound cell under `:stack` or `:flow` (and a stacked list cell) was never fetched and always drew no data: the fetch read the cell's place as a comprehension filter, which drops a `nil` place. Every built-in layout's bound cells are now tested to fetch at their declared size (#234, #232).
- A cell's single source (#229, #204): `source:` (with `fields:` and `params:` beside it) binds the component's one slot, resolved at validation, kept short in the document; a component with no slot or several is `{:ambiguous_slot, slots}` at `[:cells, name, :source]`, and `source` with `slots` is `:source_and_slots`. `Cell.keys/0` gains `:source`, `:fields` and `:params`.
- Cells as a list (#228, #204): `cells: [cell, …]` keeps the list's order; a cell may omit its name, derived as `<component's last word>_<source>`, numbered on a collision; with no layout and no place, the cells stack in the list's order (`{:stack, order: …}`), and a list placing only some cells is `:place_mixed`. The forms write the expanded document.
- The `:areas` layout (#227, #198): named regions from a template, `{:areas, template: [["header", "header"], ["nav", "main"]]}`, a cell's place `%{area: name}`; unequal rows, an area that isn't a rectangle, an unknown area and two cells in one area are faults by path. Reading order is each area's first appearance. Its stylesheet is generated per template and served by its content address; `Macaw.Surface.stylesheet/1` gives any validated surface's layout sheet and its path.
- The `:stack` and `:flow` layouts (#226, #198): one column, and sections for prose, each in the order its one option gives, `{:stack, order: [...]}`, every cell's name once. A cell has no place; its declared size is the surface's width and four rows. Each has its own stylesheet, served by its address. A built-in layout's options are held checked, every name a string.
- A grid of 6, 12 or 24 columns: `{:grid, columns: 24}`, from an allowed set so the grid's one stylesheet stays static; a width outside it is `{:enum, [6, 12, 24]}` at `[:layout, :options, :columns]`. A layout with options has the JSON form `{"$layout": [name, options]}`. The behavior gains `container/1`, the cells' container's classes (#225, #198). The grid's stylesheet now holds every width, so its content address changes.
- A layout is a behavior, `Macaw.Layout` (spec/06 §3.3, #224, #198): the grid is the built-in one, and validation, fetching and rendering reach it only through the behavior. A host's registry holds the built-in layouts and the ones it adds (`Registry.new/2`'s `layouts:`), closed by default; a surface naming a layout no registry holds is `{:unknown, :layout}` at validation. **Changed:** `Surface.new/1` no longer refuses a layout name it doesn't know (it was `{:unknown_layout, name}`), since which layouts exist is the host's; a `layout` that is neither a name nor `{name, options}` is `{:type, :layout}`. `Validated` gains `layout`.
- The built-in table heads each column with its field's label from the source's schema, its unit after it (`Request time (s)`); a cell's context carries each slot's schema (`schemas`, read with `Context.label/3` and `unit/3`). Needs macaw_component `~> 0.2.1` (#219, #196).
- The built-in table has a static stylesheet, `Macaw.Builtin.Table.stylesheet/0` at its content address `stylesheet_path/0`, as the grid's is: every color a theme custom property, and the sorted column marked (#196, #220, spec/05 §6.1).
- The built-in table's columns are chosen by its `rows` slot's optional `columns` role (`fields: %{"columns" => ["host", "p50"]}`), in the order bound, each field checked against the source's schema at validation; unbound, every column shows, as before (#196, #218, spec/05 §6.1).
- **Breaking:** `Surface.from_map/1` and `from_json/2` give every fault by path from the document they were given. The faults `new/1` finds are now under `:surface` (`[:surface, :cells, "a", :kind]`, was `[:cells, "a", :kind]`), as a reader's own faults already were; `new/1` itself is unchanged (#215, #217, spec/06 §3.1).
- CI runs the family's dependency advisories guard (`ci/advisories.exs`, with a reasoned allowlist that defaults empty), so a locked package with a security advisory, or a retired one, fails the pipeline; phoenix_html is locked at 4.4.0 (EEF-CVE-2026-117645) (#216, macaw#214).
- `macaw_layers ~> 0.3.1`: an atom a setting or param spells that the reader wasn't given (neither the document's word nor in `vocabulary: %{atoms: [...]}`) is refused at its path as `{:unknown_atom, spelling}`, naming the spelling, no longer `{:enum, <the surface's own words>}` (#212, #213, spec/06 §3.1). Bundles read each entry with its type's vocabulary (macaw_layers#21, #192); the core reads no bundles, so nothing else changes here.

## v0.2.0 (2026-10-30)

### Upgrading from 0.1.4

1. **`Surface.from_map/2` is `from_map/1`,** and it judges the value as terms: the version, the envelope, then `new/1`. It takes no `limits:`; they bound reading JSON, so they are `from_json/2`'s.
2. **Settings and params are the terms they are.** `Cell.new/1` no longer refuses a value that isn't plain data (`{:not_plain, v}` is gone): a color term, a typed color, a time, a point or an atom is kept as given, and checked against the component's (or source's) declared parameter types at `Surface.validate/3`. A nested map's keys are kept as given too, no longer turned into strings. Only the setting and param names must be names (`{:type, :name}`), and settings and params must be maps (`{:type, :map}`).
3. **The JSON form writes terms by their tags** and refuses what it can't hold. A color is `$rgb`/`$color`/`$ramp`/…, a time `$time`, a point `$point`, an atom `$atom`; a value JSON can't hold makes `to_json/1` answer `{:error, faults}` at its path (`{:type, :term}`, or `{:type, :name}` for a non-string key in a setting's map). An atom a setting spells reads back only when `from_json/2` is given it in `vocabulary: %{atoms: [...]}`.
4. **Names in the value are strings everywhere:** `node/1`, `fragment/1` and `to_map/1` no longer write a name spelled like a document key (a cell named `"title"`) as that key's atom. The JSON form is unchanged for such a name: it is a string in a name map.

### Changes

- Surface validation reports every check's faults: each check runs on what it needs, so a bad component, kind or settings no longer hides a cell's binding faults; a check a failed prerequisite rules out is reported as `{:unchecked, :component | :settings}` at the cell's `slots` (#195, #199, spec/06 §3.4).
- `macaw_component ~> 0.1.5`: each cell's context carries its slots' resolved bindings, so a component reads the field bound to a role with `Context.field/3`; `Surface.Validated` holds each binding resolved by `Slot.resolve/3` (#194, #200, spec/06 §3.4, §3.6).
- `macaw_layers ~> 0.3.0`, `macaw_data ~> 0.7.0` and `macaw_component ~> 0.2.0`, where internal data is BEAM terms (#188, #209): colors are `%Color{}` terms and a theme's names strings, a category's values and a schema's field names read back as strings, and digests and schema versions change (see each library's "Upgrading" notes). `Surface.from_json/2` and `from_map/2` read through `Macaw.Layers.Form.read/3` (`Document.read/3` is gone), and the envelope is judged as its value; the surface itself is unchanged.
- **Breaking:** surfaces and cell settings are terms; JSON is the adapter (#188, #210, spec/00 §4.2, spec/06 §3.1–§3.2, spec/08 §2). `from_map/1` judges a value with no form written or read. A cell keeps its settings and params as the terms they are, checked against the component's and the sources' declared parameter types at validation (a setting with no declared parameter stays `:unknown_param`). Names are strings, normalized once at construction; the JSON adapter alone writes and reads them, through `name_map?/1` and the tags (`$point` new, the colors' from macaw_layers), and refuses at its path a value JSON can't hold.

## v0.1.4 (2026-10-29)

- `macaw_data ~> 0.6.0` and `macaw_component ~> 0.1.4`: a delivery keeps the rows its source gave (#185). A fetch tells no data by `Delivery.empty?/1`; the built-in table packs the rows into columns with `Delivery.table/2`, drawing no data when they don't pack (#186).

## v0.1.3 (2026-10-28)

- The macaw logo: `brand/` holds the owner's originals, transparent copies, the render script and GitHub social previews; the docs and the README show the scarlet macaw (#175).

## v0.1.2 (2026-10-28)

- On Hex: depends on `macaw_layers ~> 0.2.2`, `macaw_data ~> 0.5.3` and `macaw_component ~> 0.1.2` from Hex instead of their git tags; the README installs from Hex (#155).
- RELEASING.md names the eight packages instead of globbing `macaw_*` (#155).
- The README opens with the early-release notice (macaw#174).

## v0.1.1 (2026-10-28)

- The repository is `dco-tek/macaw/macaw`, in the `dco-tek/macaw` group; dependencies named by their group paths, on macaw_data v0.5.2 and macaw_component v0.1.1 (#151, #152).
- Package metadata for Hex: the public home, the changelog link, the files shipped, and docs with `ex_doc` (macaw_compose#155).

## v0.1.0 (2026-10-28)

- macaw v0.1.0: surfaces with a grid, validated and rendered without a socket, and the built-in table (#154)
