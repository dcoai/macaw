# Changelog

## Unreleased

- Surface validation reports every check's faults: each check runs on what it needs, so a bad component, kind or settings no longer hides a cell's binding faults; a check a failed prerequisite rules out is reported as `{:unchecked, :component | :settings}` at the cell's `slots` (#195, #199, spec/06 §3.4).
- `macaw_component ~> 0.1.5`: each cell's context carries its slots' resolved bindings, so a component reads the field bound to a role with `Context.field/3`; `Surface.Validated` holds each binding resolved by `Slot.resolve/3` (#194, #200, spec/06 §3.4, §3.6).
- `macaw_layers ~> 0.3.0`, `macaw_data ~> 0.7.0` and `macaw_component ~> 0.2.0`, where internal data is BEAM terms (#188, #209): colors are `%Color{}` terms and a theme's names strings, a category's values and a schema's field names read back as strings, and digests and schema versions change (see each library's "Upgrading" notes). `Surface.from_json/2` and `from_map/2` read through `Macaw.Layers.Form.read/3` (`Document.read/3` is gone), and the envelope is judged as its value; the surface itself is unchanged.

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
