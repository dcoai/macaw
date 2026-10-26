# 09 — Stores and references {#stores}

Documents live in **stores**: the host's database, files in git, or an object store (exio). composex reaches them through one behavior. (visualize.md C8; metresis.md C8.)

## 1. The store behavior {#stores-behavior}

```elixir
@callback list(context)            :: {:ok, [entry]} | {:error, reason}
@callback get(id, context)         :: {:ok, entry} | {:error, :not_found | reason}
@callback put(entry, context)      :: {:ok, id} | {:error, reason}
@callback delete(id, context)      :: :ok | {:error, reason}
@callback import(bundle, context)  :: {:ok, %{old_id => new_id}} | {:error, [fault]}
```

The **context** says who is acting and from where, so entries are traceable. The default store is in memory ([00](00-overview.md) goal 3).

## 2. References {#stores-references}

- **References are typed ids:** `{kind, id}`. A reference of the wrong kind is refused before resolution.
- **Names are attributes, never identities:** a route path, a slug, a title. dcotek_web's route path becomes an attribute of a page id.
- **Versions are digests,** or the store's own object versions.
- **A missing reference masks its own site** and is reported. Rendering never fails because of it.
- **An import is a relocation:**
  - every check runs before anything is written;
  - new ids are issued, and references are rewritten through one table;
  - it commits whole or not at all.
- **An export takes the transitive closure.**
- **A bundle carries definitions** (re-keyed on import), **never bindings, credentials or data.**

## 3. Ids on object storage {#stores-object}

Open (composex#4). visualize's per-kind sequences, which are never reused, are awkward on S3. The options are:
- ids derived from object keys;
- a manifest object that issues ids by conditional write;
- content-addressed ids for immutable fragments.

This is deferred until an exio-backed store is built.
