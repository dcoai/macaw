# Releasing the Macaw family

The Macaw libraries are released to Hex together, bottom-up, and their public homes on GitHub move only at releases (dco-tek/macaw/macaw#155, #174). GitLab (`dco-tek/macaw`) stays the source of truth: CI, issues, merge requests and all work between releases.

**Publishing is the owner's.** Getting a package ready is everyone else's; `mix hex.publish` claims a name on Hex permanently and is run by the owner, package by package.

## 1. Where things stand

```bash
elixir ~/Projects/claude-tools/hex_release.exs status ~/Projects/macaw ~/Projects/macaw_*
```

It works out the publish order from the libraries' own runtime git dependencies and reports each library:

| State | Means |
|---|---|
| `published` | its version is on Hex |
| `ready` | every check passes: push its public home and publish it (§3) |
| `prepare` | its family dependencies are all on Hex: rewrite them (§2) |
| `blocked` | each block named: a family dependency not on Hex yet, missing metadata, no changelog entry, no tag or a tag behind HEAD, CI not green on the tag |

The order today: macaw_host, macaw_layers, macaw_plug (no family dependencies); macaw_data; macaw_component and macaw_auth; macaw and macaw_auth_ash.

## 2. Getting a library ready

1. **Its dependencies on Hex:** once every family library it depends on is published,
   ```bash
   elixir ~/Projects/claude-tools/hex_release.exs prepare ~/Projects/<lib> ~/Projects/macaw ~/Projects/macaw_*
   ```
   rewrites those git dependencies to `~> version`, the version each tag named.
2. **Its version:** a patch (or a minor, when the API changed) in `mix.exs`; the changelog's `Unreleased` section released as `## vX.Y.Z (date)`; the README's install snippet pinned to that version, `{:lib, "~> X.Y.Z"}`.
3. **Through CI:** a branch, a merge request, merged fast-forward with a green pipeline, then the annotated tag `vX.Y.Z` on the merged commit, pushed to GitLab.
4. `hex_release.exs status` reports it `ready`.

## 3. Releasing a ready library (the owner)

`hex_release.exs status` prints these for the next ready library:

```bash
cd ~/Projects/<lib>
elixir ~/Projects/claude-tools/publish_history.exs vX.Y.Z --remote github \
  --forbid 'BEGIN [A-Z ]*PRIVATE KEY' --forbid 'glpat-[A-Za-z0-9_-]{10}' \
  --forbid 'gh[po]_[A-Za-z0-9]{20}' --forbid 'github_p[a]t_' --dry-run
elixir ~/Projects/claude-tools/publish_history.exs vX.Y.Z --remote github \
  --forbid 'BEGIN [A-Z ]*PRIVATE KEY' --forbid 'glpat-[A-Za-z0-9_-]{10}' \
  --forbid 'gh[po]_[A-Za-z0-9]{20}' --forbid 'github_p[a]t_'
mix hex.publish
```

`publish_history.exs` fast-forwards GitHub's `main` to the release tag and pushes the tag, over your own SSH key: no mirror and no token. It refuses a tag whose pipeline isn't green, a tag GitHub already has, a push that wouldn't fast-forward, and any commit about to go public that matches a `--forbid` pattern. It runs before `mix hex.publish`, because the package's `source_url`, its links and its docs' `source_ref` point at the public home and the tag.

## 4. Once per machine and per library

- Each checkout has a `github` remote: `git remote add github git@github.com:dcoai/<lib>.git` (the core is `dcoai/macaw`).
- Each public repository exists on GitHub under `dcoai`, created **empty** (no README, license or .gitignore), so the first push fast-forwards.

## 5. Before `macaw`

The server's app (`:macaw`, in dco-tek/macaw/macaw_server) is renamed `:macaw_server` before the core is published (macaw_server#143); otherwise that app can't depend on the published core.

Every README opens with the notice that the software is a very early release, not ready for general use (#174), until the owner says otherwise.
