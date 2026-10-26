# 11 — Themes {#themes}

**One theme system styles every surface, the site included** (decided, owner, 2026-10-25). It is visualize's theme document: palettes, named whole styles and **roles** (good, warning, bad, info, neutral, selected, muted …). dcotek_web's brand tokens become a theme, and metresis maps its UI framework's roles from it.

## 1. Rules {#themes-rules}

- **Drawing colors are theme roles and tokens,** and values derived from them (`lighten(:warning)`), so contrast is checked on the theme. (metresis.md C3.)
- **Data colors are typed content.** A `:color` column or a schema's value color (a team's color) may be shown only with a non-color cue (a glyph, a label or a dash) and under a contrast guard against the surface; it is never the sole carrier of meaning ([02](02-sources.md#sources-data); macaw_compose#22, decision 7).
- **Literal colors are refused** under the **`:roles` profile**, which every Macaw page validates against. An adopter may offer a permissive profile standalone (visualize's `colors: :open`); on a Macaw page its documents validate as `:roles`.
- **One theme per page.** A component's own theme setting (a visualize design's `theme`) is an override slot the page masks; standalone, it applies.
- **Adopters register their theme slots** (visualize's mark roles) into the shared theme document, so one theme styles them.
- **Contrast is checked once, on the theme,** for every theme offered ([10](10-web.md#web-a11y)).
- **Themes stack** like any fragment ([07](07-documents.md#documents-fragments)).

## 2. Delivery {#themes-delivery}

- A theme compiles to **custom properties scoped by a class**, `.mw-theme-<name>` (`.mw-theme-dark`), in the site's static stylesheet, served from `'self'`. Adopters emit the same class, so a visualize chart standalone and on a page reads the same properties.
- **"Auto"** follows `prefers-color-scheme` through a media query in that stylesheet; there is never a `<style>` element per component.
- Per-mark and per-datum styles resolve on the server into SVG presentation attributes or classes.

## 3. Switching at runtime {#themes-runtime}

- A theme chooser is a component writing a viewer- or page-scoped state source, `theme`.
- A change swaps the root's theme class through an ordinary diff (classes are fine under CSP), and every component recolors.
- It persists like other state: in the user's settings when the host knows them, otherwise in the session. The server renders the right class first, so there is no flash.
- **User-defined themes:** the host generates a stylesheet for the user's theme, served as a file from `'self'` (`/themes/<hash>.css`), by the same mechanism as every document-defined stylesheet ([10](10-web.md#web-csp), rule 3). It must pass the same contrast check, and a theme that fails is refused.

(macaw_compose#8, question 4.)
