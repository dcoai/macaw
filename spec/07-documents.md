# 07 — Documents {#documents}

Every declarative value Macaw reads is a **document**: pages, surfaces, templates, layers, themes, visualize designs, component settings and records. One kernel validates them all. It starts from visualize's `Visualize.Document`, which moves to Macaw ([00](00-overview.md#overview-order) step 2).

## 1. The kernel {#documents-kernel}

- **One version line per document type,** stamped as `"$version"`.
- **Gate order:**
  1. refuse a newer version by name (`{:newer_schema, needs, this}`) before anything else is read;
  2. check size limits before decoding;
  3. migrate step by step, purely;
  4. validate.

  A document with no stamp reads as current. (visualize.md C6; metresis.md C6.)
- **Size limits:** `depth` and `items` are checked before decoding, and the counts after migration. A host may tighten them. (visualize.md C6.)
- **Every fault is reported, never just the first,** as `{path, reason}`, ordered by path, worded by one formatter. (All three projects.)
- **Unknown keys are refused by name** at their own spelling. (metresis.md C6.)
- **Atom safety:**
  - names a document declares are strings;
  - keys are decoded against the document type's tables;
  - closed vocabularies are looked up;
  - `String.to_existing_atom/1` is never used on document data.

  (visualize.md C6, D-195.)
- **Map and JSON forms are exact inverses** for valid values. Values JSON can't express use one table of `$` tags. (visualize.md C6.)
- **A canonical digest** (`Document.digest/1`) fingerprints any document independently of key order. Records, base renders and bundles cite it. (metresis.md C6.)
- **Documents hold no functions, bindings or credentials.** (visualize.md C6.)
- **Untrusted strings** are sanitized where read and escaped where written, and URLs are checked by a host policy. (visualize.md C6.)
- **Fetched documents** (from exio or a database) are untrusted input: the same gates apply, and nothing is evaluated. (dcotek_web.md C6.)

## 2. Fragments and stacking {#documents-fragments}

visualize's fragment machinery moves into Macaw and is used by every stackable document: templates and layers, styles, themes and designs. It comprises:
- **fragments** and **composites;**
- **use sites,** resolved `ref → local → mask → bind → stack`;
- **`stack/1`,** a cascade, and **`compose/2`,** a union, each under **per-key merge rules** (`:concat`, `:union`, `:deep`, `:override`);
- **masks,** which explicitly drop keys from below;
- **`explain/1`,** provenance for any value: which layer or fragment set it.

(visualize.md C4, C7; macaw_compose#8.)

## 3. Everything is composable data {#documents-everything}

**Every configurable thing is a document of the fragment shape,** and there is no second configuration format (owner, 2026-10-26). That covers:
- pages, surfaces and cells;
- **component settings;**
- templates, layers, themes and styles;
- source declarations.

Each stacks, masks, validates and explains the same way (§2). A configured component is a stack: its defaults, then a **preset** (a fragment), then the cell's local settings. So "why is this table sorted by date?" answers through `explain`, like any other value.

**A component's settings schema is made of parameters** ([05](05-components.md#components-parameters)): typed, with a default, legal values and documentation. One shape describes every component's options, so validation, builder forms and an AI author read the same thing.

**A cell's settings may be inline or referenced.** A cell may carry a component's whole settings inline (a complete visualize design, for instance), or a reference to a preset plus local overrides. Both are the same stack and validate the same way. Inline settings keep a page in one document, which suits AI authoring; a reference keeps a shared design in the library, where every page using it follows its changes (macaw_compose#22, decision 3). This uniformity is what makes portability possible ([09](09-stores.md#stores-portable)), and what lets an AI author anything through one format.

## 4. Validation time {#documents-validation-time}

Validation runs **whenever a document is loaded**, through pure functions. It includes each placed component's configured declarations ([05](05-components.md#components-declares)): `declarations(settings)` is called here, so slots, events, state writes, budget functions and observation are known before anything renders. (A budget's value depends on the measured size, so it is computed at render, clamped to the host ceiling.) In v1 that is at build or boot. A broken shipped document fails the build, and a broken fetched document is refused, keeping the last good version. (metresis.md C6; dcotek_web.md C13.)
