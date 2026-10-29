# Changelog

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
