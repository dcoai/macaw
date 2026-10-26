# 05 — Components, cells and containers {#components}

A **component** is a registered implementation of one public contract. Built-in and third-party components use the same contract ([00](00-overview.md) goal 8). A **cell** places a component in a surface.

## 1. What a component declares {#components-declares}

Each declaration buys a composition effect ([00](00-overview.md) goal 1, rule 1).

| Declares | Buys |
|---|---|
| **settings schema**, which may depend on bound slot schemas (`legal_for`) | validated pages; type-legal options (metresis.md C3) |
| **slots**: typed inputs with `requires` contracts, checkable before data flows | any source works; faults found at validation (visualize.md C1) |
| **kinds** it renders as | correct placement and landmarks (§2) |
| **state** it writes, and **exports** | interaction without wiring ([03](03-state.md)) |
| **events** it emits, each marked visitor- or system-initiated | accurate view paths ([08](08-records.md)) |
| **announcements** it may request | one coordinated announcer ([10](10-web.md#web-a11y)) |
| **observation**, in the host's closed vocabulary | disclosure that matches (dcotek_web.md C3, C12) |
| **element ids**, stable and derived from content structure | attention that aggregates across builds (dcotek_web.md C3) |
| **reading load** of its sections | reading vs skimming (dcotek_web.md C3) |
| **client hooks**, as static files from `'self'` | strict CSP ([10](10-web.md#web-csp)) |
| **assets** (CSS, images) | self-contained base snapshots ([08](08-records.md)) |
| **renders** in each mode: live, socketless, neutral, print | complete without a socket; replay; output |
| **drawn states** | never blank; failures shown (§4) |
| **required access**, if any | consistent gating |

## 2. Kinds {#components-kinds}

A component offers one or more **kinds**, one `render/2` clause per kind:

```elixir
kinds [:navigation, :content]

def render(:navigation, assigns), do: ~H"<nav aria-label={@label}><ul>…</ul></nav>"
def render(:content, assigns),    do: ~H"<ul class=\"cards\">…</ul>"
```

- **The region or container selects the clause.** A cell is valid only where its placement's kind is one of the component's kinds. That is checked at validation, so a missing clause never fails at runtime.
- **Declared kinds are checked against the clauses at compile time,** and the registry reads them without calling the component.
- **Each kind carries rules the output is checked against:**
  - `:navigation` renders a labeled `<nav>` of links;
  - `:control` renders real form controls;
  - `:container` renders an accessible pattern (a tab list, a disclosure, a dialog).
- **Kind and mode are separate axes.** Kind is the argument; mode comes in the context. Most components render the same markup in every mode, and the runtime changes what it wraps around it.

(macaw_compose#8, question 2.)

## 3. Rendering rules {#components-rendering}

- **Server first, complete without a socket.** Native HTML wherever it gives behavior: `<details>`, `popover`, `<dialog>`. (dcotek_web.md C3.)
- **Size by container queries, never by viewport,** so one component works in any region ([10](10-web.md#web-responsive)).
- **Colors through theme roles only,** never literals ([11](11-themes.md)).
- **Headings at the level given by context,** never hard-coded ([10](10-web.md#web-a11y)).
- **Links and navigation as events or host link helpers.** A component never navigates by itself.
- **No inline `style` or `<style>`, no inline script, nothing from another origin** ([10](10-web.md#web-csp)).

## 4. Drawn states and isolation {#components-states}

- **Every component is always in exactly one drawn state:** `crashed`, `down`, `invalid`, `over_budget`, `loading`, `no_data`, `stale`, `capped` or `live`, in that precedence. Each has a theme role, a glyph and words, and is never blank. (visualize.md C3.)
- **Pure components** (Markdown, cards) render in the page's process.
- **Components with server work** run as **contained cells**: a heap-limited process each, restarted by its surface with a backoff (100 ms doubling to 10 s, reset after 30 s alive), shown as `crashed` meanwhile. A component's crash never takes down the page that carries the visitor's observation. (visualize.md C13; dcotek_web.md C13.)
- **Embedded applications** (dcotek_web#9's demos) are a container kind running a nested LiveView with its own limits.

## 5. Containers {#components-containers}

A **container** is a component of kind `:container` whose content is surfaces: tabs, drawer, accordion, split.
- Each pane is a surface, with its own state.
- Panes **render** lazily, but **compute** whatever other nodes depend on ([03](03-state.md#state-dag)).
- **Opening a pane is a view change** (a step), never navigation.
- Each container type follows its accessibility pattern ([10](10-web.md#web-a11y)).
- **Nesting** is only through containers, to a **depth of 3** (surface → container → surface …). A surface's grid never directly contains a grid.

## 6. Packaging {#components-packaging}

Components ship in packages, which bring their own dependencies (Macaw never imports them) and register through the registry ([12](12-registry.md)). Some expected packages:
- **`macaw_visualize`:** visualize's visuals (charts, maps, scenes) as components. visualize itself depends only on `macaw_layers` and `macaw_data`;
- **metresis:** dashboard and panel components, plus its shaping functions, so remote hosts can draw them (metresis#556);
- **a records library:** data-editing components ([13](13-writes.md));
- **components built on ryutronic:** wizards, durable jobs, an assistant.
