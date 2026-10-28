# 11 — Themes {#themes}

<!-- surfex: deferred #167: the web plans and runtime themes -->

**One theme system styles every surface, the site included** (decided, owner, 2026-10-25). It is visualize's theme document: palettes, named whole styles and **roles** (good, warning, bad, info, neutral, selected, muted …). macaw_server's brand tokens become a theme, and metresis maps its UI framework's roles from it.

The theme document's **rules** and **delivery** are specified in [macaw_layers 04](https://gitlab.conet.yarina.org/dco-tek/macaw_layers/-/blob/main/spec/04-themes.md), which moved with `macaw_layers`' repository (#95). What stays here is switching themes on a running page.

## 1. Switching at runtime {#themes-runtime}

<!-- surfex: deferred #167: the web plans and runtime themes -->

- A theme chooser is a control whose cell action sets the `theme` preference, a state source at `:viewer` scope, or `:session` for an anonymous visitor ([03](03-state.md#state-sources)).
- A change swaps the root's theme class through an ordinary diff (classes are fine under CSP), and every component recolors.
- It persists like other state: in the host's user store when the host knows the viewer, otherwise in the session. The server renders the right class first, so there is no flash.
- **User-defined themes:** the host generates a stylesheet for the user's theme, served as a file from `'self'` (`/themes/<hash>.css`), by the same mechanism as every document-defined stylesheet ([10](10-web.md#web-csp), rule 3). It must pass the same contrast check, and a theme that fails is refused.

(macaw_compose#8, question 4.)
