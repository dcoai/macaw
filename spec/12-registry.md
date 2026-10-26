# 12 — Registry and conformance {#registry}

## 1. The registry {#registry-model}

A host enables what pages may name, by package.
- **The registry is explicit and closed by default.** A host enables **packages** by name in configuration. Nothing is enabled implicitly, and a package that is merely loaded is not enabled.
- **Members are derived within an enabled package.** The members of each behavior (the one list: components, templates, layers, sources, transforms, aggregates, marks, frame types and hooks) are the package's modules that implement it, reported by the package's `__members__/0`. A runtime that can't introspect calls it from an explicit list. So a host decides which code documents can reach, and a package author never maintains a second list (macaw_compose#22, R17).
- **Each member registers through its behavior's introspection function.** Duplicate names fail at boot, naming both modules and their packages.
- **Names in documents are strings,** matched by spelling. No atom is made from them.
- **An unknown name is a validation fault at its path,** naming the package that provides it if known.
- **Hooks:** each package contributes its hooks as static files from `'self'`, which may import sibling files of the same package. There is no build step and no third-party JS.

(visualize.md C9; dcotek_web.md C9.)

## 2. The conformance kit {#registry-kit}

Shipped in `lib/`, so any component or source author runs it, the way visualize's feed conformance kit works today. There is **one kit per contract** (the source kit in `macaw_data`, the component kit in `macaw_compose`); adopters add checks to a kit as **check sets**, never a kit of their own (macaw_compose#22, R19).
- **Sources** are checked on the describe and fetch shapes, honest `served` facts, errors as values, the push handshake, and liveness.
- **Components** are checked on:
  - each declared kind's output rules;
  - heading levels taken from context;
  - names and states;
  - one tab stop for composite widgets;
  - drawing colors from theme roles, data colors with a cue;
  - no inline style or script;
  - complete socketless and neutral renders;
  - stable element ids.
- **Templates and layers:** the stacked-result rules ([06](06-pages.md#pages-templates)).
- **Check sets** add checks for a family of components. The **visual** check set: one tab stop; `role="img"` with a description and a data table beside it; the drawn-token rule ([02](02-sources.md#sources-event)); SVG, never canvas, in socketless and neutral modes.
- **Fixture documents:** a component whose declarations depend on its settings ([05](05-components.md#components-declares)) ships a fixture set of settings documents, one for each distinct declaration shape (for visualize: one per mark, frame kind, backend and scene), and the kit runs over every one.
- **Adopters run it** in their own CI whenever `macaw_compose` is present (visualize#946).
