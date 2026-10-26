# 13 — Writes {#writes}

Editing records is a **component's** job, not composex's (owner, 2026-10-26; composex#9).

## 1. What composex provides: four seams {#writes-seams}

1. **Reads come through sources,** so a data-editing component works over any backend ([02](02-sources.md)).
2. **Change notification:** after a write, the writer announces that a source changed, and every reader re-fetches, on this page and on others ([02](02-sources.md#sources-change)).
3. **The viewer reaches components,** so writes are authorized on the server against the actual viewer.
4. **Writes are declared events,** so the host can record or audit them like any other event.

## 2. What a records library provides (not composex) {#writes-library}

A component library on top (working name `composex_records`) provides:
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

**ryutronic is a component dependency, not a composex one.** The library keeps the door open: actions are effect-shaped, an action may complete later (`{:accepted, handle}`), and a long-running process is a source.

The owner's four cases are the library's design examples (composex#9):
1. edit one record;
2. commit a group, all or nothing;
3. transform and then persist or log;
4. edit for the session, then discard.
