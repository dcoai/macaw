# 13 — Writes {#writes}

<!-- surfex: deferred #9: writes -->

Editing data is a **component's** job, not Macaw's (owner, 2026-10-26; macaw_compose#9).

## 1. What Macaw provides: four seams {#writes-seams}

<!-- surfex: deferred #9: writes -->

1. **Reads come through sources,** so a data-editing component works over any backend ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md)).
2. **Change notification:** after a write, the writer announces that a source changed, and every reader re-fetches, on this page and on others ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-change)).
3. **The viewer reaches components,** so writes are authorized on the server against the actual viewer.
4. **Writes are declared events,** so the host can record or audit them like any other event.

## 2. What `macaw_edit` provides (not Macaw's core) {#writes-library}

<!-- surfex: deferred #9: writes -->

A component library on top, **`macaw_edit`** (`Macaw.Edit`), provides:
- drafts, with auto or manual commit;
- change sets, writable sources with declared operations, and sinks (append-only destinations);
- an Ecto adapter, with operations as changesets and a batch as one `Ecto.Multi`;
- conflict detection and display;
- the **effect discipline** after ryutronic's effect adapters:
  - describe, then perform;
  - classes: pure, local, external;
  - declared dispositions: reversible, retriable, terminal;
  - `prepare` votes, witnesses and `applied?` probes;
  - sagas with compensation across backends.

**ryutronic is a component dependency, not a Macaw one.** The library keeps the door open: its operations are effect-shaped, an operation may complete later (`{:accepted, handle}`), and a long-running process is a source.

The owner's four cases are the library's design examples (macaw_compose#9):
1. edit one record;
2. commit a group, all or nothing;
3. transform and then persist or log;
4. edit for the session, then discard.
