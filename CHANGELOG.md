# Changelog

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
