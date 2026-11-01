# 8. Surfaces as documents

A surface is data, so it can be saved, sent, read back, layered and moved between
machines. This chapter covers the document side of Macaw, most of it from
`macaw_layers`, the kernel every Macaw document goes through.

**What you'll learn:**

- a surface's value and its JSON form, the adapter at the edge: tags, the vocabulary and
  what JSON can't hold (`Macaw.Layers.Form`);
- the gates a document is read through;
- limits on untrusted documents;
- faults in depth: paths, ordering and formatting (`Macaw.Layers.Fault`);
- names, and why Macaw never makes an atom from a document (`Macaw.Layers.Names`);
- layering surfaces: `stack`, `compose` and `explain` (`Macaw.Layers.Fragment`);
- storing surfaces (`Macaw.Layers.Store`) and moving them as bundles
  (`Macaw.Layers.Bundle`);
- a document's digest.

The examples use this surface:

```elixir
alias Macaw.Surface

{:ok, status} =
  Surface.new(
    name: "status",
    title: "Service status",
    cells: %{
      "services" => %{
        component: "macaw.table",
        settings: %{"caption" => "Services", "sort" => "p50"},
        place: %{x: 0, y: 0, w: 12, h: 4},
        slots: %{"rows" => %{source: "services"}}
      }
    }
  )
```

## The value, and JSON at the edge

**A surface is a term, and the term is the document.** Its identity and validity are
the BEAM value's own; JSON, or any other encoding, is an adapter at the edge.
`Surface.to_map/1` is the surface's value as a versioned document,
`%{version: 1, surface: node}`, to keep in a term store or a database column of terms.
`from_map/1` judges such a value as terms (the version, then the envelope, then
`new/1`), writing and reading no encoding:

```elixir
map = Surface.to_map(status)
{map.version, map.surface.name}
#=> {1, "status"}

Surface.from_map(map) == {:ok, status}
#=> true

Surface.from_map(%{version: 2, surface: %{}})
#=> {:error, [{[], {:newer_schema, 2, 1}}]}
```

`Surface.node/1` is the surface's node alone, and `Surface.fragment/1` the node wrapped
as `%{surface: node}`, the form layers and stores use (below).

### The JSON form

`Surface.to_json/1` writes the JSON form, stamped with the document's version;
`from_json/2` reads it back to an equal surface:

```elixir
{:ok, json} = Surface.to_json(status)
IO.puts(json)

Surface.from_json(json) == {:ok, status}
#=> true
```

```json
{"$version":1,"surface":{"cells":{"services":{"component":"macaw.table","kind":{"$atom":"content"},"place":{"h":4,"w":12,"x":0,"y":0},"settings":{"caption":"Services","sort":"p50"},"slots":{"rows":{"fields":{},"params":{},"source":"services"}}}},"layout":{"$atom":"grid"},"name":"status","title":"Service status"}}
```

A surface built in the short form, or with its cells as a list (chapter 4), is written
expanded: the cells by their names, and the layout with its order, a layout with options
tagged `$layout`. A cell's `source:` shorthand stays short. A stored surface never
depends on a default that could change under it:

```elixir
short = Surface.build!("short", cells: [{"macaw.table", source: "services"}])
{:ok, short_json} = Surface.to_json(short)
IO.puts(short_json)

Surface.from_json(short_json) == {:ok, short}
#=> true
```

```json
"layout":{"$layout":["stack",{"order":["table_services"]}]}
```

JSON holds strings, numbers, booleans, `null`, lists and objects, so the adapter writes
every other term by a **tag**: an atom as `$atom`, a time as `$time`, a point as
`$point`, and a color by the colors' own tags, `$rgb` for a literal and `$color` or
`$ramp` for a theme's. A cell's settings and params are the terms they are (chapter 4),
so a map component of your own might be given these:

```elixir
import Macaw.Layers.Color, only: [sigil_RGB: 2]

{:ok, where} =
  Surface.new(
    name: "where",
    cells: %{
      "map" => %{
        component: "my_app.map",
        place: %{x: 0, y: 0, w: 6, h: 4},
        settings: %{
          "center" => {13.4, 52.5},
          "since" => ~U[2026-10-29 12:00:00Z],
          "pin" => ~RGB"#c23238",
          "water" => {:color, "info"},
          "style" => :satellite
        }
      }
    }
  )

{:ok, where_json} = Surface.to_json(where)
IO.puts(where_json)
```

```json
"settings":{"center":{"$point":[13.4,52.5]},"pin":{"$rgb":"#c23238"},"since":{"$time":"2026-10-29T12:00:00Z"},"style":{"$atom":"satellite"},"water":{"$color":"info"}}
```

**No atom is made from a document.** Words from the surface's own closed vocabulary,
such as the kind and the layout, read back as atoms **by lookup**. An atom a setting
spells is no word of the surface's, so reading it back takes the atoms you allow, in
`vocabulary:`:

```elixir
Surface.from_json(where_json)
#=> {:error, [{[:surface, :cells, "map", :settings, "style"], {:unknown_atom, "satellite"}}]}

Surface.from_json(where_json, vocabulary: %{atoms: [:satellite]}) == {:ok, where}
#=> true
```

**A value JSON can't hold is refused,** at its path: a pid, a function or a three-element
tuple is `{:type, :term}`, and a map key in a setting or param that isn't a string
`{:type, :name}`. `to_json/1` answers every one, rather than writing a document that
wouldn't read back:

```elixir
{:ok, odd} =
  Surface.new(
    name: "odd",
    cells: %{
      "a" => %{
        component: "my_app.map",
        place: %{x: 0, y: 0, w: 1, h: 1},
        settings: %{"owner" => self(), "opts" => %{zoom: 3}, "box" => {1, 2, 3}}
      }
    }
  )

Surface.to_json(odd)
#=> {:error,
#    [
#      {[:surface, :cells, "a", :settings, "box"], {:type, :term}},
#      {[:surface, :cells, "a", :settings, "opts", :zoom], {:type, :name}},
#      {[:surface, :cells, "a", :settings, "owner"], {:type, :term}}
#    ]}
```

The adapter is `Macaw.Layers.Form`, the JSON adapter of every Macaw document type.
`Form.read(json, type, opts)` runs the gates below and then reads and judges the value;
`Form.to_json(fragment, type)` writes. `Surface.from_json/2` is `Form.read/3` and then
`new/1`, and `to_json/1` is `Form.to_json/2` of the surface's fragment:

```elixir
alias Macaw.Layers.Form

{:ok, %{surface: node}} = Form.read(json, Surface)
{node.name, Form.to_json(Surface.fragment(status), Surface) == {:ok, json}}
#=> {"status", true}
```

### The gates

Everything that reads a document, from a file, a database, a request body, goes through
the same **gates**, in order:

1. **bytes**: an encoded document over the size limit is refused before it's parsed;
2. **scan**: a scan that stops at the first nesting depth or item count over its limit,
   before anything is built;
3. **version**: a document from a newer version is refused by name;
4. **migration**: an older document is migrated step by step (surfaces are at version 1,
   so there's nothing to migrate yet);
5. **the value**: the form read through the type's tags and vocabulary, then judged as
   terms, the document's own checks and then `Surface.new/1`.

Each gate's faults stop the later ones. Every fault is by path from the document you gave, so one `Surface.new/1` finds is under `:surface`:

```elixir
Surface.from_json(~s({"$version": 2, "surface": {}}))
#=> {:error, [{[], {:newer_schema, 2, 1}}]}

Surface.from_json(~s({"$version": 1, "surface": {"name": "x"}, "extra": 1}))
#=> {:error, [{["extra"], :unknown_key}]}

Surface.from_json("{not json")
#=> {:error, [{[], {:json, "unexpected byte \"n\" at byte 1"}}]}

Surface.from_json(~s({"$version": 1, "surface": {"name": "ops", "cells": {}}}))
#=> {:error, [{[:surface, :cells], :empty}]}
```

### Limits

A fetched document is untrusted input. The default limits are generous; tighten them
with `limits:` where documents come from people:

```elixir
Macaw.Layers.Limits.defaults()
#=> %{bytes: 8_000_000, depth: 64, items: 100_000}

Surface.from_json(json, limits: [bytes: 100])
#=> {:error, [{[], {:limit, :bytes, 100, 314}}]}
```

You can only tighten: a limit above its default raises `ArgumentError`, so a typo can't
open the door. `from_map/1` takes no limits: they bound what reading an encoding costs,
and a value in memory has none to read.

## Faults

Every fault in Macaw is `{path, reason}`: the path from the document's root to the value,
keys and list indexes, and a reason term. Constructors report **every** fault at once,
sorted by path (`Macaw.Layers.Fault.sort/1`), so a person fixes a document in one pass.

`Fault.format/2` words a fault as `path: words`. The kernel words its own reasons; pass
`words:` to word your own, and `root:` to name the root:

```elixir
alias Macaw.Layers.Fault

Fault.format_path([:cells, "a", :slots, "rows", 0])
#=> "cells.a.slots.rows[0]"

{Fault.format({[:name], {:type, :name}}), Fault.format({[], :required}, root: "surface")}
#=> {"name: must be a name: a non-empty string", "surface: is required"}

Fault.format({[:cells, "a", :component], {:unknown_component, "my_app.chart"}},
  words: fn {:unknown_component, name} -> "no component is named #{name}" end
)
#=> "cells.a.component: no component is named my_app.chart"
```

A formatter never fails: a reason it can't word is shown with `inspect/1`. Faults never
carry a row's values, so they're safe to log and show.

## Names

A name in a document (a cell, a slot, a source, a setting) is a **string**. Elixir code
may spell one as an atom, which is read as its spelling; a document's string is never
turned into an atom, because atoms are never garbage collected and a document could
exhaust them. `Macaw.Layers.Names` holds the rules:

```elixir
alias Macaw.Layers.Names

{Names.name(:status), Names.name("status"), Names.name(3), Names.name?(""), Names.same?(:ok, "ok")}
#=> {"status", "status", 3, false, true}
```

`Names.fetch/2` and `key/2` find a map's key by either spelling.

## Layers: stacking surfaces

A **fragment** is part of a document, a map with some of its keys. Fragments combine in
two ways, by each key's **merge rule**. For a surface, `cells` is a union by name and
every other key an override.

**`stack/2`** is the cascade: layers meant to overlap, the higher winning. A team's
layer can retitle a shared surface and add a cell, without copying it:

```elixir
alias Macaw.Layers.Fragment

base = Surface.fragment(status)

eu = %{
  surface: %{
    title: "Service status (EU)",
    cells: %{
      "errors" => %{
        component: "my_app.stat",
        settings: %{"label" => "Errors"},
        place: %{x: 0, y: 4, w: 4, h: 2},
        slots: %{"rows" => %{source: "services", fields: %{"value" => "errors"}}}
      }
    }
  }
}

stacked = Fragment.stack(Surface, [base, eu])
{:ok, eu_status} = Surface.from_map(Map.put(stacked, :version, 1))
{eu_status.title, Enum.sort(Map.keys(eu_status.cells))}
#=> {"Service status (EU)", ["errors", "services"]}
```

A cell a higher layer names replaces the lower's cell **whole**. A stack never fails and
never validates: read the result through `from_map/2`, which does.

**`compose/3`** is the union: parts meant to be disjoint. Two parts that set one cell
differently are a conflict, reported by path:

```elixir
Fragment.compose(Surface, base, %{surface: %{cells: %{"services" => %{component: "other"}}}})
#=> {:error, [{[:surface, :cells, "services"], :conflict}]}
```

**`explain/2`** says where each value of a stack came from: for every leaf, its value,
the layer that set it (by name, when layers are given as `{name, fragment}`), and the
layers it overrode:

```elixir
Surface
|> Fragment.explain([{"base", base}, {"eu", eu}])
|> Enum.find(&(&1.path == [:surface, :title]))
#=> %{layer: "eu", overrode: ["base"], path: [:surface, :title], value: "Service status (EU)"}
```

`Fragment.kind/2` says what kind of fragment a map is (`:surface`), which is how stores
file them.

## Stores

`Macaw.Layers.Store` is the behavior for where documents live: your database, files, an
object store. `Macaw.Layers.Store.Memory` is the default, an `Agent` you'd start under
your supervisor. A store holds the fragment types it's configured with, and nothing else:

```elixir
alias Macaw.Layers.Store

{:ok, memory} = Store.Memory.start_link(types: [Surface])
store = {Store.Memory, memory}

{:ok, id} = Store.put(store, %{id: nil, name: "Dashboards:status", fragment: Surface.fragment(status)})
id
#=> {:surface, 1}

{:ok, entry} = Store.get(store, id)
{:ok, ^status} = Surface.from_map(Map.put(entry.fragment, :version, 1))

Store.list(store)
#=> {:ok, [%{id: {:surface, 1}, kind: :surface, name: "Dashboards:status"}]}
```

- **Ids are typed:** `{kind, n}`, issued by the store from a sequence per kind that
  never reuses a deleted id. `Store.encode_id/1` and `decode_id/2` turn them into strings
  for URLs and forms, matching the kind by lookup:

  ```elixir
  {Store.encode_id(id), Store.decode_id(Store.kinds(store), "surface:1"), Store.decode_id(Store.kinds(store), "page:1")}
  #=> {"surface:1", {:ok, {:surface, 1}}, :error}
  ```

- **Names are attributes, never identities.** Rename freely; nothing references a name.
  `Store.group/1` reads a `"Group:Sub:name"` filing:

  ```elixir
  Store.group("Dashboards:Ops:status")
  #=> {["Dashboards", "Ops"], "status"}
  ```

- `put/2` on an entry with an id replaces it; `delete/2` removes one. A store's
  `{module, context}` pair carries who is acting, so entries are traceable.

## Bundles

A **bundle** carries documents from one store to another: `Bundle.export/3` takes the
entries and everything they reference, with provenance (which store, when, which
version). It has a JSON form that goes through the same gates as any document:

```elixir
alias Macaw.Layers.Bundle

bundle = Bundle.export(store, [id], "staging")
{:ok, bundle_json} = Bundle.to_json(bundle, [Surface])
{:ok, read_back} = Bundle.from_json(bundle_json, [Surface])

{read_back.provenance.store, length(read_back.entries)}
#=> {"staging", 1}
```

Importing into another store **relocates** the entries: the target store issues new ids,
and the answer maps old ids to new ones:

```elixir
{:ok, other} = Store.Memory.start_link(types: [Surface])
{:ok, %{ids: ids}} = Store.import({Store.Memory, other}, read_back)
ids
#=> %{{:surface, 1} => {:surface, 1}}
```

A bundle never carries credentials, source configuration or data: the importing host
maps source names to its own sources.

## Digests

`Macaw.Layers.Document.digest/1` is a SHA-256 over a canonical encoding of the value
itself, any data term, independent of map key order and of any encoding: a cheap way to
tell whether a document changed, or to cache by content. The term's types count, so `1`
and `1.0`, or `:ok` and `"ok"`, digest differently:

```elixir
alias Macaw.Layers.Document

String.length(Document.digest(Surface.to_map(status)))
#=> 64

{:ok, read_back} = Surface.from_json(json)
{Document.digest(Surface.to_map(read_back)) == Document.digest(Surface.to_map(status)), Document.digest(1) == Document.digest(1.0)}
#=> {true, false}
```

## Pitfalls

- **Reading documents with `JSON.decode!/1` and building structs yourself.** Use
  `from_json/2`: it applies the limits, the version gate, the tags and every check.
- **An atom setting that won't read back.** Give `from_json/2` the atoms you allow in
  `vocabulary: %{atoms: [...]}`, or use strings.
- **Encoding to JSON to compare or store terms.** The term is the document: compare
  values, digest them with `Document.digest/1`, and store `to_map/1` where you can.
- **Loosening limits.** You can't, by design; tighten them for user input.
- **Expecting a stack to validate.** It merges maps; validate the result with
  `from_map/2`.
- **A cell replaced whole by a layer.** A higher layer's cell is the whole cell; repeat
  every key you want to keep.
- **Treating names as identities.** Reference stored documents by id; names are labels.

## Recap

- A surface is a term; `to_map/1` and `from_map/1` are its value. JSON is the adapter:
  tags for terms, a vocabulary for atoms, a refusal for what it can't hold, and gates on
  the way in: bytes, scan, version, migration, the value.
- Faults are `{path, reason}`, all at once, sorted, worded by `Fault.format/2`.
- Names are strings; no atom is made from a document.
- `stack` layers surfaces, `compose` unites parts, `explain` traces values to layers.
- Stores hold typed fragments under typed ids; bundles move them, relocating ids.

**Further reading:** [the surface document](https://github.com/dcoai/macaw/blob/main/spec/06-pages.md#pages-surface-document) in spec/06; [names](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-names), [the vocabulary](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-vocabulary), [faults](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-faults), [the gates](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-gates), [the JSON form](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-forms) and [digests](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-digest) in `macaw_layers`' spec/01; [stacking](https://github.com/dcoai/macaw_layers/blob/main/spec/02-fragments.md#fragments-stack) in its spec/02; [stores](https://github.com/dcoai/macaw_layers/blob/main/spec/03-stores.md#stores-behavior) and [bundles](https://github.com/dcoai/macaw_layers/blob/main/spec/03-stores.md#stores-bundle) in its spec/03.

Next: [chapter 9, Themes and styles](09-themes.md).
