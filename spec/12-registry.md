# 12 — Registry and conformance {#registry}

## 1. The registry {#registry-model}

A host enables what pages may name: components, templates, layers, sources, derived-source functions and hooks.
- **The registry is explicit and closed by default.** A package's modules are listed in configuration, never discovered from loaded modules. Nothing is enabled implicitly.
- **Registration is by module,** through each behavior's introspection function. Duplicate names fail at boot, naming both modules.
- **Names in documents are strings,** matched by spelling. No atom is made from them.
- **An unknown name is a validation fault at its path,** naming the package that provides it if known.
- **Hooks:** each package contributes its hooks as static files from `'self'`. There is no build step and no third-party JS.

(visualize.md C9; dcotek_web.md C9.)

## 2. The conformance kit {#registry-kit}

Shipped in `lib/`, so any component or source author runs it, the way visualize's feed conformance kit works today.
- **Sources** are checked on the describe and fetch shapes, honest `served` facts, errors as values, the push handshake, and liveness.
- **Components** are checked on:
  - each declared kind's output rules;
  - heading levels taken from context;
  - names and states;
  - one tab stop for composite widgets;
  - theme roles only;
  - no inline style or script;
  - complete socketless and neutral renders;
  - stable element ids.
- **Templates and layers:** the stacked-result rules ([06](06-pages.md#pages-templates)).
