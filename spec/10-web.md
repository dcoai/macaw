# 10 — The web: security, responsive layout, accessibility {#web}

## 1. Content Security Policy {#web-csp}

Every page must work under the strictest policy of the three adopters (dcotek_web's):

```
script-src 'self' 'sha256-…'; style-src 'self'; connect-src 'self'; img-src 'self' data:;
object-src 'none'; base-uri 'none'; frame-ancestors 'none'
```

- **No inline `style=` and no `<style>` elements.** LiveView applies diffs with `setAttribute`, so a nonce would not help either.
- **No inline script and no `eval`/`new Function`.**
- **Hooks are static files from `'self'`.** Only a host's own small inline script (dcotek_web's tracking plan) is hashed.
- **Nothing from another origin.**
- **The delivery rule:** a finite set of values becomes a class; a per-datum value becomes an SVG presentation attribute (not governed by CSP); a dynamic value is set by a trusted hook through CSSOM, which CSP allows.

What this asks of visualize (visualize#938):
- grid and cell placement by class;
- theme and motion rules in static stylesheets;
- blend modes and animations as classes;
- no `:js` canvas path;
- a board drawn in the first render.

(visualize.md C10; dcotek_web.md C10.)

## 2. Rendering modes {#web-modes}

| Mode | Use | Notes |
|---|---|---|
| live | a connected LiveView | hooks attached |
| socketless | bots, black holes, no JS, the first render | complete HTML; native behaviors only |
| neutral | base snapshots for records | no hooks, scripts, prefixes or per-viewer markup |
| print | print and PDF export | the automatic print layer |

## 3. Responsive layout {#web-responsive}

- **Templates compile to static CSS at build time,** like themes. The markup carries classes and landmark elements only, and layers change classes, never CSS. There is one stylesheet per site, generated from the stacks in use, served from `'self'` and snapshotted.
- **The template responds to the viewport** (media queries). **Components respond to their region** (container queries; each region is a CSS container). **Components never size by viewport.**
- **Breakpoints are in `rem`,** following the visitor's font size, with a shared default set (narrow, wide) that templates use or extend.
- **Collapse behaviors per region on narrow screens.** The template sets the default, and a layer can override it per region:

  | `collapse:` | Becomes | How |
  |---|---|---|
  | `:stack` | above or below main | grid order; DOM order unchanged |
  | `:inline` | a disclosure in place | `<details>`/`<summary>`, no JS |
  | `:drawer` | slides over the page; light dismiss | `popover` with `popovertarget`, no JS |
  | `:modal` | a drawer that traps focus; background inert | `<dialog>` with `showModal()`, one static hook |
  | `:hide` | not shown | a class |

- **Grid rows:** DOM order plus column classes, with `grid-auto-flow: dense`. It is accepted if it renders every visualize and metresis board fixture identically (composex#5).
- **Motion:** named animations in the stylesheet, removed under `prefers-reduced-motion`.
- **Print:** the print layer compiles to `@media print`: chrome hidden, disclosures open, regions stacked.

(composex#8, question 4.)

## 4. Accessibility {#web-a11y}

**The target is WCAG 2.2 AA.** Most of it is about how components fit together, so composex owns it. (composex#8, question 5.)

**Structure**, guaranteed by composex:
- a landmark element per region role, exactly one `main`, and labeled navs;
- **heading levels come from context:** the page has the `<h1>`, and each surface and component renders its headings at the level it is given. Components never hard-code a level, so the outline is right for any arrangement;
- skip links: to main, and to navigation when there is a sidebar;
- DOM order equal to visual order.

**Keyboard:**
- tab order is DOM order, with no positive `tabindex`;
- **composite widgets are one tab stop** with arrows inside (charts, grids, tree menus, tab sets);
- Escape closes or leaves, and Enter or Space activates;
- no traps, except `:modal`, which releases on Escape.

**Focus after changes**, owned by composex:

| Change | Focus | Announcement |
|---|---|---|
| navigation | to the new `<h1>` | the page title |
| view change | stays | the result ("12 projects match") |
| system update | never moves | only if declared important; rate-limited |
| error | to the error summary or first invalid field | the error |
| within a persistent region | kept | — |

**One announcer per surface:** one polite and one assertive live region. Components request announcements as declared events, and the surface queues, merges and rate-limits them.

**Every component:**
- real elements;
- states exposed (`aria-pressed`, `aria-expanded`, `aria-current`, `aria-busy`);
- every control and image named. Charts are `role="img"` with a description and a data table beside them;
- never color alone;
- kinds carry checks ([05](05-components.md#components-kinds)).

The menu pattern is a **disclosure navigation** (buttons with `aria-expanded` and `aria-controls`, nested lists, `aria-current="page"`), never `role="menu"`.

**Visual:**
- contrast checked once per theme: 4.5:1 for text; 3:1 for large text, UI parts and focus indicators;
- a visible focus indicator;
- usable at 200% zoom and reflowing at 320 px;
- targets at least 24×24 px;
- no autoplay, and reduced motion honored.

**Testing:**
- a conformance kit shipped in the library ([12](12-registry.md#registry-kit));
- surface and template validation;
- theme contrast checks;
- **axe-core and keyboard scripts in CI** for the example app.
