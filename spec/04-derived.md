# 04 — Derived sources {#derived}

A **derived source** (visualize's *virtual source*) is computed from other sources by a function. composex adopts visualize's design whole; it is the most developed part of the three projects (visualize.md C2).

## 1. The model {#derived-model}

- **A derived source is data:** `%{id, from: [{name, window}], schema, elixir | function, per}`. It contains no function value, and has map and JSON forms.
- **Its function is either:**
  - **stored** Elixir source text: untrusted, checked and sandboxed; or
  - a **host** `defsource` in a registered module: trusted but bounded.

  It is never a mini-language.
- **The checker:** exactly one `fn` of arity 1 (inputs) or 2 (inputs, context), against an explicit allowlist of `{module, function, arity}`. It refuses:
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
- **Context has no clock.** A source reads its inputs' schemas, their deliveries' served facts, and the variables at its scope.

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
