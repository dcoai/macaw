# 07 — Documents {#documents}

Every declarative value composex reads is a **document**: pages, surfaces, templates, layers, themes, visualize designs, component settings and records. One kernel validates them all. It starts from visualize's planned `Visualize.Document` (visualize#912), which moves to composex.

## 1. The kernel {#documents-kernel}

- **One version line per document kind,** stamped as `"$version"`.
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
  - keys are decoded against the kind's tables;
  - closed vocabularies are looked up;
  - `String.to_existing_atom/1` is never used on document data.

  (visualize.md C6, D-195.)
- **Map and JSON forms are exact inverses** for valid values. Values JSON can't express use one table of `$` tags. (visualize.md C6.)
- **A canonical digest** (`Document.digest/1`) fingerprints any document independently of key order. Records and snapshots cite it. (visualize#912; metresis.md C6.)
- **Documents hold no functions, bindings or credentials.** (visualize.md C6.)
- **Untrusted strings** are sanitized where read and escaped where written, and URLs are checked by a host policy. (visualize.md C6.)
- **Fetched documents** (from exio or a database) are untrusted input: the same gates apply, and nothing is evaluated. (dcotek_web.md C6.)

## 2. Fragments and stacking {#documents-fragments}

visualize's fragment machinery moves into composex and is used by every stackable document: templates and layers, styles, themes and designs. It comprises:
- **fragments** and **composites;**
- **use sites,** resolved `ref → local → mask → bind → stack`;
- **`stack/1`,** a cascade, and **`compose/2`,** a union, each under **per-key merge rules** (`:concat`, `:union`, `:deep`, `:override`);
- **masks,** which explicitly drop keys from below;
- **`explain/1`,** provenance for any value: which layer or fragment set it.

(visualize.md C4, C7; composex#8.)

## 3. Validation time {#documents-validation-time}

Validation runs **whenever a document is loaded**, through pure functions. In v1 that is at build or boot. A broken shipped document fails the build, and a broken fetched document is refused, keeping the last good version. (metresis.md C6; dcotek_web.md C13.)
