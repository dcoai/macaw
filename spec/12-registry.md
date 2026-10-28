# 12 — Registry and conformance {#registry}

<!-- surfex: class architecture -->

## 1. The registry {#registry-model}

A host enables what pages may name, by package. **The package side is `macaw_component`'s:** `__members__/0` and each behavior's introspection function, which every package implements ([macaw_component 03](https://github.com/dcoai/macaw_component/blob/main/spec/03-packages.md#components-packages)). **The host side is `macaw`'s:** enabling packages, the boot-time duplicate check and resolving names in documents (#137). Sources, transforms and aggregates register through `macaw_data`'s default-closed registry, which the host side builds on.
- **The registry is explicit and closed by default.** A host enables **packages** by name in configuration. Nothing is enabled implicitly, and a package that is merely loaded is not enabled. `macaw`'s built-in components are a package too, enabled like any other.
- **Members are derived within an enabled package.** The members of each behavior (the one list: components, templates, layers, sources, transforms, aggregates, marks, frame types and hooks) are the package's modules that implement it, reported by the package's `__members__/0`. A runtime that can't introspect calls it from an explicit list. So a host decides which code documents can reach, and a package author never maintains a second list (macaw_compose#22, R17).
- **Each member registers through its behavior's introspection function.** Duplicate names fail at boot, naming both modules and their packages.
- **Names in documents are strings,** matched by spelling. No atom is made from them.
- **An unknown name is a validation fault at its path,** naming the package that provides it if known.
- **Hooks:** each package contributes its hooks as static files from `'self'`, which may import sibling files of the same package. Macaw adds no build step and no third-party JS. A LiveView hook runs only once it is registered in the host's `LiveSocket`, so the host imports the enabled packages' hooks in its own JS: `macaw_live` provides one module that collects them, generated from the registry.

(visualize.md C9; dcotek_web.md C9.)

### 1.1 The host side {#registry-host}

**`Macaw.Registry` is a host's registry of components:** built from the packages it enables, in its configuration, and nothing else.
- **`Macaw.Registry.new/1`** of a list of packages reads each package's components through `Macaw.Component.Package.components/1` ([macaw_component 03](https://github.com/dcoai/macaw_component/blob/main/spec/03-packages.md#components-packages)) and answers `{:ok, registry}`, or `{:error, faults}` with every fault at once: a package's own faults at `[package]`, and **two components of one name across packages** as `{:duplicate, name, [{module, package}, {module, package}]}`. **`new!/1`** answers the registry or raises `ArgumentError` with every fault formatted, which is how a host fails at boot.
- **Closed by default:** `new([])` holds nothing, and a component whose package isn't listed is unknown though its module is loaded. `macaw`'s built-in components are the package `Macaw.Builtin`, listed like any other.
- **Lookup by spelling:** `component(registry, name)` answers `{:ok, module}` or `:error`, a name a string or an atom read as its spelling; no atom is made from a document's name. `components/1` lists `{name, module}` in name order, and `packages/1` the packages as given, each once.
- **Hooks:** `hooks/1` is `Macaw.Component.Package.hooks/1` over the registry's packages, from which a host or `macaw_live` generates the module that registers them.

```test:registry-build
a registry built from packages holds their components by name, closed to unlisted packages, and looks names up by either spelling without making atoms
```

```test:registry-faults
a package's faults and a name two packages share are faults at once; new!/1 raises with every fault; hooks come from the listed packages
```

## 2. The conformance kit {#registry-kit}

<!-- surfex: deferred #165: pages, templates, layers, containers and navigation -->

Shipped in `lib/`, so any component or source author runs it, the way visualize's feed conformance kit works today. There is **one kit per contract** (the source kit in `macaw_data`, the component kit in `macaw_component`, the template and layer checks in `macaw`); adopters add checks to a kit as **check sets**, never a kit of their own (macaw_compose#22, R19).
- **Sources** are checked on the describe and fetch shapes, honest `served` facts, errors as values, the push handshake, and liveness.
- **Components** are checked by `macaw_component`'s kit, its twelve checks and its check sets, the **visual** check set among them, over a component's **fixture documents** ([macaw_component 04](https://github.com/dcoai/macaw_component/blob/main/spec/04-conformance.md#components-kit)).
- **Templates and layers:** the stacked-result rules ([06](06-pages.md#pages-templates)).
- **Adopters run it** in their own CI whenever `macaw_component` is present (visualize#946).
