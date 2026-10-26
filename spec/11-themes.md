# 11 — Themes {#themes}

**One theme system styles every surface, the site included** (decided, owner, 2026-10-25). It is visualize's theme document: palettes, named whole styles and **roles** (good, warning, bad, info, neutral, selected, muted …). dcotek_web's brand tokens become a theme, and metresis maps its UI framework's roles from it.

## 1. Rules {#themes-rules}

- **Components use roles and tokens, never literal colors.** (metresis.md C3.)
- **Contrast is checked once, on the theme,** for every theme offered ([10](10-web.md#web-a11y)).
- **Themes stack** like any fragment ([07](07-documents.md#documents-fragments)).

## 2. Delivery {#themes-delivery}

- A theme compiles to **custom properties scoped by a class** (`.cx-theme-dark`), in the site's static stylesheet, served from `'self'`.
- **"Auto"** follows `prefers-color-scheme` through a media query.
- Per-mark and per-datum styles resolve on the server into SVG presentation attributes or classes.

## 3. Switching at runtime {#themes-runtime}

- A theme chooser is a component writing a viewer- or page-scoped state source, `theme`.
- A change swaps the root's theme class through an ordinary diff (classes are fine under CSP), and every component recolors.
- It persists like other state: in the user's settings when the host knows them, otherwise in the session. The server renders the right class first, so there is no flash.
- **User-defined themes:** the host generates a stylesheet for the user's theme, served as a file from `'self'` (`/themes/<hash>.css`). It must pass the same contrast check, and a theme that fails is refused.

(macaw_compose#8, question 4.)
