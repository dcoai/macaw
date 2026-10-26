# 04 — Derived sources {#derived}

A **derived source** (visualize's *virtual source*) is computed from other sources by a function. Macaw adopts visualize's design whole; it is the most developed part of the three projects (visualize.md C2).

## 1. The model {#derived-model}

- **A derived source is data:** `%{id, from: [{name, window}], schema, elixir | function, per}`. It contains no function value, and has map and JSON forms.
- **Its function is either:**
  - **stored** Elixir source text: untrusted, checked and sandboxed; or
  - a **host** `defsource` in a registered module: trusted but bounded.

  It is never a mini-language.
- **The checker:** exactly one `fn` of arity 1 (inputs) or 2 (inputs, context), against an explicit allowlist of `{module, function, arity}`, generated from the transforms and aggregates registered by enabled packages (§5). It refuses:
  - `send`, `receive`, `spawn`, `try`, `raise` and `apply`;
  - `import`, `quote`, sigils, struct literals and module atoms;
  - dynamic calls.

  Field reads are limited to the declared schemas, and the source text to 10,000 bytes. It reports every fault with its line.
- **Bounds,** with the outcome read from the process exit and never rescued:
  - each call runs in a process of its own;
  - reductions: 100,000,000, **counted, not timed**, so the verdict is the same on a loaded host;
  - liveness: 30 s;
  - heap: 10,000,000 words.
- **Faults never carry data values.** The last good output survives a fault.
- **The output conforms to its declared schema,** or it is a fault.
- **Context has no clock.** A source reads its inputs' schemas, their deliveries' served facts, and the variable state sources at its scope ([03](03-state.md#state-sources)).

## 2. Inputs {#derived-inputs}

Inputs may be:
- feeds;
- other derived sources;
- **state sources**;
- **exports** ([03](03-state.md#state-exports)).

The function may take all of a scope's inputs together. metresis's series naming is computed once over every metric's feed. (metresis.md C2.)

## 3. Scoping {#derived-scoping}

A derived source is defined at a scope: the page, a surface, a container or a cell. Names resolve from the inside out, so an inner definition shadows an outer one. Cycles are refused with the cycle named ([03](03-state.md#state-dag)).

## 4. What stays in the source {#derived-database}

Derivations that need raw rows or the store stay **inside the source**, never in a derived source:
- counter-reset-aware deltas;
- circular means;
- percentiles from raw rows ("a p95 of p95s is not a p95");
- rollup vs raw selection.

(metresis.md C2.)

## 5. Transforms and aggregates {#derived-operations}

The operations a visualize design applies to its data and the operations a derived source may call are **the same code**, in `macaw_data` beside derived sources (macaw_compose#22, decision 11):
- **the transform behavior,** with the table operations: filter, sort, take, fold, sum, bin, stack, window, lttb, m4 and spectrum;
- **the aggregate behavior,** with its statistics.

A computation can therefore move between a design and a derived source unchanged, and a metresis feed and a visualize chart reduce data the same way.

- **Transforms that need geometry** (they declare `needs: [:frame]` or `needs: [:projection]`: layouts, geographic operations) stay in the package that draws, and register through the registry like any other member ([12](12-registry.md)).
- **The sandbox allowlist is generated** from the registered members of enabled packages, never written by hand, so enabling a package is the only way to widen it.
