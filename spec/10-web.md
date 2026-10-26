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
- **The delivery rule,** for everything a component styles or loads (macaw_compose#22, R12):
  1. a finite set of values becomes a **class** in a static stylesheet;
  2. a per-datum value becomes an **SVG presentation attribute** (not governed by CSP);
  3. a finite set **defined at runtime by a document** (a design's motion: transitions and keyframes; a user's theme, [11](11-themes.md#themes-runtime)) becomes a **generated stylesheet**, content-addressed (`/assets/<hash>.css`), generated on demand and served from `'self'`. Its content is a pure function of the document, so the same document always yields the same file, and base snapshots capture it ([08](08-records.md#records-content));
  4. a dynamic value is set by a trusted hook through the CSSOM, which CSP allows;
  5. **no script evaluation,** anywhere;
  6. **media from another origin is proxied** through a same-origin route (§1.1).

What this asks of visualize (visualize#944): inline styles become classes, per-design motion becomes generated stylesheets, dark mode is the theme class, the `:js` canvas path is removed, map tiles come through the proxy, and every chart is complete SVG in the first render.

### 1.1 The asset proxy {#web-proxy}

Macaw provides **one generic same-origin asset proxy** for media a component needs from elsewhere: map tiles, remote images, a site's images on object storage (macaw_compose#22, decision 12).
- **A component declares its proxy routes:** a name, the URL template it fetches, and the content types it accepts. The host mounts the proxy once.
- **Closed by default:** the host enables each origin explicitly; an undeclared route or an origin not enabled is refused.
- **It never forwards the viewer:** no cookies, credentials or identifying headers go upstream; the host may add its own credentials by configuration, never from a document.
- **Bounded:** each response is checked for its declared content type and capped in size, and cached by URL with the upstream's freshness.
- Pages then hold same-origin URLs only, so `img-src 'self'` holds.

(visualize.md C10; dcotek_web.md C10.)

## 2. Rendering modes {#web-modes}

| Mode | Use | Notes |
|---|---|---|
| live | a connected LiveView | hooks attached; a visual may draw marks on a canvas |
| socketless | bots, black holes, no JS, the first render | complete HTML and SVG, never canvas; native behaviors only; the first render from the deliveries |
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

- **Grid rows:** DOM order plus column classes, with `grid-auto-flow: dense`. It is accepted if it renders every visualize and metresis board fixture identically (macaw_compose#5).
- **Motion:** named animations in the static stylesheet, or in a document's generated stylesheet (§1), removed under `prefers-reduced-motion`.
- **Print:** the print layer compiles to `@media print`: chrome hidden, disclosures open, regions stacked.

(macaw_compose#8, question 4.)

## 4. Accessibility {#web-a11y}

**The target is WCAG 2.2 AA.** Most of it is about how components fit together, so Macaw owns it. (macaw_compose#8, question 5.)

**Structure**, guaranteed by Macaw:
- a landmark element per region role, exactly one `main`, and labeled navs;
- **heading levels come from context:** the page has the `<h1>`, and each surface and component renders its headings at the level it is given. Components never hard-code a level, so the outline is right for any arrangement;
- skip links: to main, and to navigation when there is a sidebar;
- DOM order equal to visual order.

**Keyboard:**
- tab order is DOM order, with no positive `tabindex`;
- **composite widgets are one tab stop** with arrows inside (charts, grids, tree menus, tab sets);
- Escape closes or leaves, and Enter or Space activates;
- no traps, except `:modal`, which releases on Escape.
- **Key bindings are focus-scoped.** A component handles keys while focus is inside it. **Page-wide shortcuts** go only through the **page-shortcut layer**, which the composition owns (macaw_compose#22, decision 13):
  - a component declares the shortcuts it offers (a key, an action name, a description); the page accepts or drops each, and validation refuses two on one key;
  - every single-character shortcut can be turned off or remapped by the viewer, through a `shortcuts` preference state source ([03](03-state.md#state-sources)), as WCAG 2.1.4 requires;
  - the layer lists the active shortcuts for assistive technology and in a help dialog.

  A visualize scene's `capture: :page` (visualize#620) declares its keys to this layer.

**Focus after changes**, owned by Macaw:

| Change | Focus | Announcement |
|---|---|---|
| navigation | to the new `<h1>` | the page title |
| view change | stays | the result ("12 projects match") |
| system update | never moves | only if declared important; rate-limited |
| error | to the error summary or first invalid field | the error |
| within a persistent region | kept | — |

**One announcer per composition** (a surface, or an adopter's standalone component, such as a visualize chart outside Macaw): one polite and one assertive live region. Components never render a live region of their own. They request announcements by a name they declare (`announces`, [05](05-components.md#components-declares)):
- **from the server,** as an event;
- **from a hook,** as a DOM event, `macaw:announce`, with `{name, text, politeness}`, which the announcer hook (`macaw_live`) receives.

The announcer queues, merges and rate-limits requests, and drops undeclared names. A visual's keyboard readout is such a request (visualize#945).

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

## 5. Observation {#web-observation}

Observation reports what a viewer did with a component, never what data they saw (macaw_compose#22, R14).
- **One closed vocabulary:** `view`, `dwell`, `hover_item`, `focus_item`, `activate`, `select`, `brush`, `copy` and `scroll_into_view`.
- **Each observation is an event in its recorded form** ([02](02-sources.md#sources-event)): the element and identity, never data values.
- **A component declares** which it can emit (`observes`). **The host enables** a subset per page. **Nothing is emitted otherwise**, so an adopter used without a host plan reports nothing.
- **Hover and focus are reported on enter and leave,** never on pointer motion; raw movement never reaches the server.
- The host's disclosure is generated from the enabled declarations, so it matches exactly what the page can report ([00](00-overview.md#overview-goals)).

## 6. The client bus {#web-bus}

The **client bus** carries the `:local` scope ([03](03-state.md#state-scopes)) between components in one browser page. It is a static module in `macaw_live`, served from `'self'`.
- **Keyed by local scope name;** each component's hook publishes and subscribes only to the keys its component declares (`local`, [05](05-components.md#components-state)). Undeclared keys are refused.
- **Domain values only** (a time, an identity, a window), never pixels, so components of different authors share a hover.
- **It never reaches the server,** and nothing on it is recorded or persisted. A value that must count is turned into an event by the component.
- visualize's `VisualizeSync` becomes this bus; standalone, visualize ships a compatible bus of its own (visualize#906).
