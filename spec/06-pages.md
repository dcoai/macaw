# 06 — Pages, templates and surfaces {#pages}

```
page          the final browser document at one URL
 └ template stack       base template + layers (with masks)
    └ region            a named, landmarked area; holds surfaces in a flow
       └ surface        a reusable composed unit: cells in a grid or a flow
          └ cell        a component placed in the surface
             └ (container cell → surfaces → …, to depth 3)
```

## 1. The page {#pages-page}

The **page** owns what exists once per browser document:
- the title and the one `<h1>`;
- exactly one `main`;
- the template stack;
- the CSP and the host's observation plan (the union of its components' declarations);
- navigation;
- the page view and its record ([08](08-records.md)).

A page document picks a template stack and fills its regions with surfaces:

```yaml
page: "/p/exio"
template: [site, project_toc]
regions:
  main:
    - surface: project_overview
    - surface: project_status
```

## 2. Templates and layers {#pages-templates}

A **template** is a registered, named arrangement of regions, with a landmark role per region and, per region, a default collapse behavior and a breakpoint. **Layers** stack on it, using visualize's fragment machinery (reused in composex, [07](07-documents.md#documents-fragments)):

```elixir
template :site do
  region :header,  role: :banner
  region :sidebar, role: :navigation, persistent: true, fillable: true,
                   collapse: :drawer, content: [surface: :site_menu]
  region :main,    role: :main
  region :footer,  role: :contentinfo
  setting :sidebar, values: [:shown, :collapsed, :hidden], default: :shown
end

layer :full_width,  on: :site, do: hide(:sidebar)
layer :project_toc, on: :site, do: fill(:sidebar, surface: :table_of_contents)
layer :print,       on: :site, do: [hide(:header), hide(:sidebar), hide(:footer)]
```

- **Merge rules per key:**
  - regions: `:deep` by name;
  - a region's content: `:override`;
  - settings: `:override`;
  - responsive rules and collapse: `:deep` (a layer can override one region's collapse).
- **Masks** explicitly drop keys from below. A masked override is intended, so it raises no error, and `explain` names the mask. An unmasked collision on a conflicting key is an error, or a warning when a later layer silently undoes an earlier one.
- **The stacked result is validated as a whole,** never layer by layer. It must have:
  - exactly one `main`;
  - a landmark per region role, and labeled navs;
  - DOM order equal to visual order;
  - CSP-safe classes;
  - every kind placed where it is allowed.

  A failing stack fails validation, naming the layer at fault. A mask can redesign a page but never bypasses validation.
- **Where layers come from:**
  - **registered layers**, authored with the template and tested, may be stacked by any page;
  - **a page's own last layer** may only set declared settings and fill regions declared fillable.
- **Print** is an automatic layer, stacked by the print and export mode.
- **One stack per page** replaces nested page and site templates.

(composex#8, question 2.)

## 3. Regions and surfaces {#pages-regions}

- **A region holds surfaces in a flow.** A surface lays out its cells as a **flow** (sections, for prose) or a **12-column grid** (`x, y, w, h` in integer units, no overlaps, reading order by `y`, then `x`, then name), metresis's and visualize's grid. A grid stacks into reading order below its container breakpoint. (visualize.md C4; metresis.md C4.)
- **A surface is reusable:** the same surface can appear on several pages, in a tab or in a drawer.
- **Its title** takes the next heading level from context ([10](10-web.md#web-a11y)).

## 4. Persistent regions {#pages-persistent}

A region marked `persistent: true` survives live navigation between pages that share it (LiveView's sticky nested LiveView). Its components keep their processes and state, and focus inside it is kept. When a layer fills it with different content, the old content's state follows its scope ([03](03-state.md#state-scopes)).

## 5. Steps and navigation {#pages-steps}

- **Navigation** changes the page (live, or a full load when the plans differ; dcotek_web#130).
- **A view change** stays on the page: a selection, an opened tab or drawer, a sorted table.
- Both are steps on a view path ([08](08-records.md)).

## 6. A runtime page builder (out of scope for v1) {#pages-runtime}

It is out of scope, but not precluded:
1. validation and the page DAG are pure library functions over documents;
2. pages are data, with names resolved through the registry and no atoms;
3. activation is an atomic swap of a validated definition;
4. template CSS is compiled ahead. A runtime template would generate a stylesheet file served from `'self'`, as user themes do.

Out of scope for v1: the builder UI, editing a page while viewers are on it, and runtime CSS generation for new templates.
