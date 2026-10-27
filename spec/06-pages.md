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

A **template** is a registered, named arrangement of regions, with its options declared as parameters ([05](05-components.md#components-parameters)), a landmark role per region and, per region, a default collapse behavior and a breakpoint. **Layers** stack on it, using visualize's fragment machinery (reused in Macaw, [07](07-documents.md#documents-fragments)):

```elixir
template :site do
  region :header,  role: :banner
  region :sidebar, role: :navigation, persistent: true, fillable: true,
                   collapse: :drawer, content: [surface: :site_menu]
  region :main,    role: :main, fillable: true
  region :footer,  role: :contentinfo
  param :sidebar, values: [:shown, :collapsed, :hidden], default: :shown
end

layer :full_width,  on: :site, do: hide(:sidebar)
layer :project_toc, on: :site, do: fill(:sidebar, surface: :table_of_contents)
```

- **Merge rules per key:**
  - regions: `:deep` by name;
  - a region's content: `:override`;
  - params: `:override`;
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
  - **a page's own last layer** may only set declared params and fill regions declared fillable.
- **Print** is an automatic layer, stacked by the print mode and for output: it hides every region but `main` and opens disclosures. A template may declare its own `print:` layer in its place.
- **One stack per page** replaces nested page and site templates.

(macaw_compose#8, question 2.)

## 3. Regions and surfaces {#pages-regions}

- **A region holds surfaces in a flow.** A surface lays out its cells as a **flow** (sections, for prose) or a **12-column grid** (`x, y, w, h` in integer units, no overlaps, reading order by `y`, then `x`, then name), metresis's and visualize's grid. A grid stacks into reading order below its container breakpoint. (visualize.md C4; metresis.md C4.)
- **A surface is reusable:** the same surface can appear on several pages, in a tab or in a drawer.
- **A cell's settings are inline or referenced** ([07](07-documents.md#documents-everything)).
- **Its title** takes the next heading level from context ([10](10-web.md#web-a11y)).

## 4. Persistent regions {#pages-persistent}

A region marked `persistent: true` survives live navigation between pages that share it (LiveView's sticky nested LiveView). Its components keep their processes and state, and focus inside it is kept. When a layer fills it with different content, the old content's state follows its scope ([03](03-state.md#state-scopes)).

## 5. Steps and navigation {#pages-steps}

- **Navigation** changes the page (live, or a full load when the plans differ; macaw#130).
- **A view change** stays on the page: a selection, an opened tab or drawer, a sorted table.
- Both are steps on a view path ([08](08-records.md)).

### Cell actions {#pages-actions}

**A component emits events and never decides what they mean.** Its **placement** decides, by declaring **actions**: each maps one of the component's declared events to one of two effects (macaw_compose#22, R9).

```yaml
cells:
  latency:
    component: visual
    settings: {ref: service_latency}
    actions:
      - on: pick
        set: {state: focus, value: {event: identity}}
      - on: pick
        navigate: {to: {page: service}, params: {service: {event: [identity, service]}}}
```

- **`set`** writes a state source from the event's fields: a view change, applied by the runtime as an event on that state source.
- **`navigate`** goes to a typed reference ([09](09-stores.md#stores-references)) with params taken from the event's fields: a navigation step, performed by the host's navigation behavior. The library never navigates.
- **Event fields** are named as paths into the event ([macaw_data 01](https://gitlab.conet.yarina.org/dco-tek/macaw_data/-/blob/main/spec/01-sources.md#sources-event)): `{event: identity}`, `{event: [identity, service]}`, `{event: value}`, or `{event: [row, field]}`. Only the named field is read: the row itself is never recorded. A field written by `set` becomes that state source's value, recorded under its capture level like any other ([08](08-records.md#records-stores)); one used by `navigate` is recorded as the step's params.
- **Several actions on one event run in their declared order,** so one pick may select and then navigate.
- **Validated with the page:** the event must be one the component declares, the state must accept the value's type, and a `navigate` action's params are checked against the target page's declared params, by type and legal values.

visualize's `drill` is an action table: `{:datum, field}` becomes `{event: [row, field]}` or `{event: identity}`, a drill to the same board with variables becomes `set`, and a drill to another board becomes `navigate` (visualize#947).

### Page params {#pages-params}

A page declares the **params** it accepts, as parameters ([05](05-components.md#components-parameters)): typed, with a default and legal values, read from the URL path or query by the host's router.

```yaml
page: "/service/:service"
params:
  service: {type: category, values_from: "services.name"}
```

- Params are validated before anything renders; an illegal value is a `404`-class refusal, never a fault inside a component. A `values_from` param is checked against the source's current values at that moment ([07](07-documents.md#documents-validation-time)).
- State sources read them with `initial: {:param, "service"}`, and source requests bind them like state (`params: %{service: {:param, "service"}}`, [03](03-state.md#state-sources)).
- A `navigate` action's params are validated against them (§5).

## 6. A runtime page builder (out of scope for v1) {#pages-runtime}

It is out of scope, but not precluded:
1. validation and the page DAG are pure library functions over documents;
2. pages are data, with names resolved through the registry and no atoms;
3. activation is an atomic swap of a validated definition;
4. template CSS is compiled ahead. A runtime template would generate a stylesheet file served from `'self'`, as user themes do.

Out of scope for v1: the builder UI, editing a page while viewers are on it, and runtime CSS generation for new templates.
