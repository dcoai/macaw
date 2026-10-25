# Requirements: dcotek_web

- **Project:** dcotek_web (`~/Projects/dcotek_web`), the Phoenix/LiveView public sites dco-tek.com and myfield.dev, with token attribution, share codes, capability-gated content, server-observed tracking, page snapshots, scanner defense and a separate admin console.
- **Date:** 2026-10-25 (main at `b3845e0`, "Closes #129").
- **Sources read:**
  - `spec/README.md` (goals, non-goals, decisions D1–D17, platform); `spec/01-architecture.md` (§1 listeners, §1.1 sites, §2 supervision, §3 contexts, §4 request flow); `spec/02-content.md` (§1 catalog, §2 page format and `track`, §2.1 link rule, §2.2 components, §2.3 content sets, §3 routes, §3.1 access, §3.2 gated links, §4 layout, §5 snapshots); `spec/03-tokens.md` (§1–§7, especially §1.1 public links, §6 share codes, §6.5 scanner defense, §7.5 capabilities); `spec/04-tracking.md` (§1 levels, §3 page view, §4, §4a Attention, §4b Signals, §4c latency, §5 retention, §6 bots, §9 matching); `spec/05-notifications.md` (grep only, §3 content); `spec/06-admin.md` (§2 views, §2.0 sites, §3 replay, §4 attention map, §4.1 threshold, §5 export); `spec/07-operations.md` (§1 settings, §2 edge, §4 CI).
  - `design/interactive_design_guide.md` (source material, not spec: §1A tiers, §1B friction and PDF résumé, §2 color, §3 interactions, §4 motion, §5 constraints, §6 checklist).
  - Code: `lib/dcotek_web/content.ex`, `content/{compiled,compiler (head),context,page,track,gate,snapshots}.ex`, `lib/dcotek_web_web/{public_live,page_context,page_scripts}.ex`, `priv/content/*` and `priv/static/js/*` (listings), `priv/content/myfield/resume.md`.
  - Issues: #2 (Research: A/B content variants for token visits), #9 (Research: live app demos, with its two comments). No open issue on composable pages exists yet. The composable-pages direction below comes from the owner's brief to this study.
- **Tag legend:** **MUST**/**SHOULD**. Status: (current) is built; (planned: #n) is in an issue; (planned: composable pages) is the owner's stated direction, not yet in the spec or an issue; (implied) is my inference.
- **Note on status:** `spec/README.md` still says "Status: Draft. Nothing here is implemented", but the code implements most of it (#76, #95 and later). I mark something (current) only where I saw it in code.

---

## C1 Sources

dcotek_web has no general "source" concept today. Its data inputs are compile-time content (Markdown with front matter) and per-request context: visitor, session level, caps, site, share prefix and page view. Query parts are planned.

### Requirements

- **MUST** keep content as data compiled at build time, with every error reported at once and failing the build. *Rationale:* a broken page never ships; one build lists every problem. [02 §2 "Front matter is validated at compile time"; §2.3 "an error in any fails the build"] (current: `Content.Compiled` raises `CompileError` listing every error)
- **MUST** let a source be parameterized by the **per-request context**: site, visitor, session capture level (`basic`/`full`), effective capabilities per resource, share prefix, page-view id, bot flag, preview. *Rationale:* every rendering in dcotek_web is per visitor; the same page differs by gate state and plan. [01 §4; 02 §3.2; 04 §1; `Content.Context`, `PageContext.prepare/4`] (current for content; planned: composable pages for query sources)
- **MUST** let a source's result depend on the visitor's **capabilities**. A source must be able to refuse, filter or tease by the effective level for a resource (`none` < `listed` < `view` < `interact` < `write`). It must never amplify a level. *Rationale:* D16 invariant; hidden content must hold no href, text or id of the gated thing. [D16, D17; 03 §7.5.4; 02 §3.2 "hidden ... holds no href, text or id"] (implied for sources; current for links)
- **MUST** resolve source data on the server for the first render. No browser-side fetch to another origin, and `connect-src 'self'` only. *Rationale:* no third party sees the visit, and the CSP forbids it. [02 §4 "the site loads nothing from another origin"; `PageScripts.csp/1`] (current)
- **MUST** make a query part's result reproducible for replay: either store the result as shown, or make it a pure function of versioned inputs that the page view records. *Rationale:* replay shows what the visitor saw, not today's data (D11). A query table whose rows change would otherwise replay wrongly. [D11; 02 §5; 06 §3] (implied; planned: composable pages)
- **SHOULD** allow content data to live outside git, in object storage (S3 via exio), as manifests and Markdown fragments, while templates and parts stay compiled code. *Rationale:* owner direction, "code in git, content as data". [owner brief] (planned: composable pages). *Conflict:* README §2 non-goal "A CMS. Content is Markdown in the repository, changed by commit", and design guide §5 "Content is Markdown in the repository ... no CMS". A spec amendment is needed.
- **MUST**, if content moves to object storage, keep the compile-time guarantees: front-matter validation, link resolution against the access table, gated-unit derivation, stable component ids, and reading-load counts. Fetching from a store then needs its own validation gate with the same all-errors report before content is served. *Rationale:* gating and tracking depend on compile-time analysis. [02 §2, §2.2, §3.2 "Tracked at compile time"] (implied; planned: composable pages)
- **SHOULD** let a source carry per-token data such as the emphasis skill set. *Rationale:* the token carries the emphasis ("a set of skill tags the page highlights on arrival"); a query parameter must not. [design guide §3.3] (planned: composable pages)
- **MUST NOT** take any source's parameters from the URL query for visitor-specific behavior. *Rationale:* emphasis is not "`?role=backend` ... that anyone can copy or edit"; the token and share code are the only carriers. Query strings are also stripped by messengers. [design guide §3.3; 03 §6.2] (planned: composable pages)
- **SHOULD** support per-token or per-share-branch content variants: a source that picks variant A or B for a token, inherited down the share tree. *Rationale:* A/B research. Owner-assigned per-token variants are the likely form, and handoffs probably inherit the parent's variant. [#2 items 1–3] (planned: #2)
- **MUST** have a page view record which variant or version of every source result it rendered. *Rationale:* "page views need to record their variant" for replay. [#2 item 6] (planned: #2)

### Current mechanism

`DcotekWeb.Content.Compiled` compiles every `priv/content/<set>/` directory at build time into `%Page{segments: …}`. Segments are binaries interleaved with `{:slot, name}`, `{:href, path, frag}`, `{:asset, path}`, `{:abs, path}` and `{:gate, resource, forms}`, held as module attributes. Per-request data comes from `%Content.Context{}`, built by `PageContext.context/5`.

### Constraints a unified model must not break

- The first render is complete from server data. No source may require the socket.
- Source access is capability-filtered, with hidden meaning absent from the HTML.
- No outbound request per visit (D10 makes the same point for GeoIP).
- Every result shown must be replayable (C7).

---

## C2 Virtual / derived sources

### Requirements

- **MUST**, if a part's interactive state is exposed as a source (the skill picker's selection consumed by a project list), let the server alone own and derive that state. Consuming parts re-render on the server over the page's LiveView. *Rationale:* pages are LiveViews observed by the server. The CSP allows only the page's own hashed script, which is built from the tracking plan. No arbitrary client-side wiring. [D2; 02 §2 CSP; `PageScripts`] (planned: composable pages)
- **MUST** work for no-socket visitors: bots, black holes, plain-HTML errors and no-JS browsers. Derived state then has a default value, and the first render shows that default. *Rationale:* plain HTML must be fully readable. The design guide requires that matching projects highlight while "the rest stay fully readable". [D2; 01 §4 step 3; 03 §6.5 black holes; design guide §3.1] (planned: composable pages)
- **SHOULD** allow the initial value of a virtual source to come from the token (the token's emphasis set seeds the skill selection). *Rationale:* emphasis carried by the token. [design guide §3.3] (planned: composable pages)
- **MUST** record the derived state that changed what was shown, so replay can reproduce it: the selection, its timing, and which projects were highlighted. This works like `gate_states`, which records per-visitor rendering decisions, and it must respect the capture level. *Rationale:* replay shows the page "as it was served" and highlights components. A state-dependent rendering not recorded cannot be replayed. [D11, D17 "each page view records the gate states"; 04 §3 `gate_states`; 06 §3] (implied; planned: composable pages)
- **MUST NOT** record interaction state for an anonymous (`basic`) session beyond page-level data. Selection events are fine-grained interaction, captured only at `full`. *Rationale:* D6. "New interactive elements fit that model rather than adding new tracking." [D6; 04 §1; design guide §5] (implied; planned: composable pages)
- **MUST** make toggles of a derived-state input real controls (`aria-pressed` buttons, keyboard and touch, never hover-only). *Rationale:* accessibility. [design guide §3.1] (planned: composable pages)
- **SHOULD** allow a derived source to be computed across parts from different packages, so visualize and metresis parts can consume page state. *Rationale:* shared parts, with interaction as data. [owner brief] (planned: composable pages)

### Current mechanism

There is none for content. The nearest analogue is `gate_states`: a per-visitor value derived from caps (`PageContext.gate_states_for/3`) that changes rendering and is recorded on the page view. On the tracking side, `LiveAttention` rebuilds intervals on the server from browser state changes. That is a derived stream with server ownership.

### Constraints

- Server-owned state.
- A no-socket default.
- Recorded where it changes the output, and capture-level-capped.
- No unrecorded per-visitor rendering fork (see C7: a snapshot is a function of content and layout only).

---

## C3 Parts / components

Two existing terms matter here. In dcotek_web, a **component** is a trackable element (`data-dw`). A tracking **part** is an optional JS module (hover, focus, copy …). The composable-pages "part" is a third meaning; see Vocabulary.

### Requirements

- **MUST** support static content parts: Markdown blocks rendered at compile time by MDEx, raw HTML disabled, with headings that get ids. *Rationale:* safety, stable ids, and no raw-HTML injection. [02 §2.1 "MDEx with raw HTML disabled"; `markdown.ex` moduledoc] (current, as a whole page; planned: composable pages per part)
- **MUST** support interactive LiveView parts with state (skill picker) and query parts that show a table. *Rationale:* owner direction. [owner brief; design guide §3.1, §3.2] (planned: composable pages)
- **MUST** make every part emit trackable component ids (`data-dw`) that are **stable across builds**, derived from content structure, never from render order or randomness. Part ids must also be unique on the page (`#2`, `#3` suffix rule) and namespaced so two parts cannot collide. *Rationale:* attention aggregates across snapshots by element id. The attention map, replay and notifications key on these ids. [D12; 02 §2.2; 06 §4 "aggregates across snapshots"] (current for Markdown; planned: composable pages for parts)
- **MUST** let a part contribute to the page's **component index**: id → gate resource, teaser-only, and for sections `words`, `code_blocks`, `order`. *Rationale:* the server drops events for ids not in the snapshot's index. Reading-vs-skimming needs reading load. [02 §2.2 "reading load"; 04 §4 "Only components the visitor saw"; `Content.component_index/1`] (current; planned: composable pages)
- **MUST** let a part declare the tracking it needs (hover, focus, copy …), so the page's plan, script, CSP hash and privacy note are the union of its declared parts. A part must not ship JS outside that mechanism. *Rationale:* "a part a page doesn't declare isn't on it"; the code, the server's acceptance and the note are generated from one plan and "can't drift apart". [02 §2 `track`; `Track` moduledoc; `PageScripts`] (current per page; planned: composable pages per part)
- **MUST** let a part that needs a client hook (a chart's hover, a visualize brush) supply its JS either as a file served from `'self'` or as source folded into the page's single hashed inline script. Never inline `<script>` of its own, never `eval`, never inline `style` attributes or `<style>` (the CSP is `style-src 'self'`). *Rationale:* CSP `script-src 'self' 'sha256-…'`, `style-src 'self'`, no `unsafe-inline` or `unsafe-eval`. [02 §2; `PageScripts.csp/1`] (current CSP; planned: composable pages)
- **MUST** render every part fully on the server for the first render, and degrade to static HTML with no socket. The degraded form must be meaningful: expanders are native `<details>`, toggles show the default. *Rationale:* D2. Bots, black holes and errors get plain HTML. "Native `<details>`/`<summary>`: it works without JavaScript." [D2; 01 §4 step 3; design guide §3.2] (current for pages; planned: composable pages)
- **MUST** let a part render in a **neutral** mode (no hooks, scripts or click attributes, no share prefix, every gated unit shown and marked, with its teaser in a template) for snapshots. *Rationale:* snapshots are content-and-layout-only. [02 §5; `Context.neutral/1`; `Content.segment/2` snapshot clause] (current; planned: composable pages)
- **MUST** route every internal link a part emits through the link machinery: `{:href, …}` segments that get the share prefix, live-patch attributes, preview query and canonical id. Links to invited routes must be resolved against the access table at compile time, so they become gated units. *Rationale:* forwarding is traced by the share prefix in every copied URL. Gating is compile-time. [03 §6.2; 02 §3.2; `Content.segment({:href, …})`] (current; planned: composable pages)
- **MUST** fail the build when a part links to an internal route that does not exist, puts two gated resources in one unit, or links to a private host. *Rationale:* gating and link integrity. [02 §2, §3.2 build failures] (current; planned: composable pages)
- **MUST** use only local assets: images must be local paths, no web fonts and no third-party embeds. *Rationale:* no third-party loads. [02 §2 "Images must be local paths"; 02 §4; design guide §5] (current)
- **MUST** have parts meet accessibility: 4.5:1 contrast (3:1 large) in both themes, including muted text; lightness difference not hue alone; real buttons and links; labeled icons; visible focus; honor reduced motion. *Rationale:* design guide. [design guide §2, §3.1, §4, §5] (planned: composable pages; partly current in CSS)
- **MUST** keep one `<h1>` per page, the page title. Part headings start at `##`. *Rationale:* outline and screen readers. [02 §2 "A level-1 heading in a body fails the build"; 02 §4 (#107)] (current)
- **MUST** let third-party and sibling-project parts (visualize, metresis) use the same public contract as built-ins, with the same guarantees (stable ids, declared tracking, CSP compliance, neutral render, a11y). *Rationale:* open-source extensibility; shared parts. [owner brief] (planned: composable pages)
- **SHOULD** support per-section or per-part settings, e.g. bullet style. Today one bullet style applies everywhere, "per section once pages are split". *Rationale:* owner direction. [02 §4 (#109, #111)] (planned: composable pages)
- **SHOULD** support the three-tier structure (glance / scan / deep dive) as a part shape: one section per project or role with its three layers, the deep tier in an expander. *Rationale:* attention tracking then shows which tier a visitor reached. [design guide §1A, §3.2, §6] (planned: composable pages)
- **SHOULD** let parts render to a print/PDF target from the same content (print stylesheet expands everything; a generated PDF résumé). *Rationale:* "A PDF is generated from the same content, so it can't drift, and served through a tracked link." [design guide §1B.4, §3.2, §6] (planned: composable pages)
- **MUST** keep outcomes and figures in parts real. This is a content rule, not a code rule. [design guide §1A] (planned: composable pages; editorial)

### Current mechanism

A page is one compiled segment list (`%Page{segments}`), layout included. `Content.render/2` and `render_parts/2` (head/body/tail split at `{:mark, …}`) fill it from the context. `PublicLive.render/1` emits two hidden hook elements (`#dw-a` Attention, `#dw-s` Signals) and `raw(@body)`, with `temporary_assigns: [body: nil]`. There are no LiveComponents and no per-part state today.

### Constraints

- Part identity equals stable `data-dw` ids.
- Parts declare their tracking. No undeclared JS.
- CSP with `script-src 'self'` plus one hash and `style-src 'self'`.
- A neutral render must exist.
- Links go through the share-prefix and gating machinery.
- The first render is complete without a socket.

---

## C4 Composition / layout

### Requirements

- **MUST** keep one site layout per site: a header (wordmark or logo, nav), a content column and a footer. Nav comes from the content set (the catalog's three categories plus About, or a page set's `nav: n` pages). *Rationale:* consistency. [02 §2.3, §4] (current)
- **MUST** use plain vertical flow: no horizontal scroll down to 360 px, and no hidden menus. *Rationale:* responsive, predictable navigation. [02 §4 "Responsive down to 360 px"; design guide §1B.2] (current)
- **MUST** nest sections as headings nest (an h3 section inside its h2's `<section>`), with `s:<heading-id>` ids. Composition must keep this nesting where parts carry headings, because nested intervals are not double-counted and reading load rolls up. *Rationale:* attention semantics. [02 §2.2; 06 §4] (current; planned: composable pages)
- **MUST** keep a defined **reading order** across parts: each section's `order` on the page and the end-of-page marker `end`, so `deepest_heading` and `max_scroll_pct` are meaningful. *Rationale:* scroll depth is computed from a section's place among the page's sections. [04 §4a "Rebuilding"; `PublicLive.sections/1`] (current; planned: composable pages)
- **MUST** derive gated units from the composed structure. The smallest enclosing block (paragraph, list item, table row, card, nav item) is shown, teased or hidden together, so sentences stay whole. *Rationale:* D17. [02 §3.2] (current; planned: composable pages)
- **MUST** have the composed document split into head / body / tail at layout marks: the root layout writes head and tail once, and the LiveView renders the body. *Rationale:* `PublicLive` architecture. [01 §4 step 4; `Content.render_parts/2`] (current)
- **SHOULD** let a page manifest (data) place compiled parts and Markdown fragments into the layout, with per-section settings. *Rationale:* composable pages. [owner brief] (planned: composable pages)
- **MUST** keep sites separate: each site has its own content set, its own `/`, its own snapshots and its own nav. A manifest belongs to exactly one content set. *Rationale:* multi-site. [01 §1.1; 02 §2.3] (current)
- **SHOULD** allow print layout (everything expanded) as a layout mode. [design guide §3.2] (planned: composable pages)

### Current mechanism

`Content.Layout` builds the layout segments around the compiled Markdown body. Catalog and page-set compilers differ (`Compiler.compile_catalog/1` and `compile_pages/1`). Cards are generated for category and home pages.

### Constraints

- The section tree and reading order must survive composition.
- Gated units are block-level.
- Layout is per site.
- 360 px with no horizontal scroll.

---

## C5 Shared state, events and interaction

### Requirements

- **MUST** own state per viewer (per LiveView process, per visitor), never shared across visitors, for content interaction (skill picker). *Rationale:* pages are per visitor (`Cache-Control: private, no-cache`). [01 §4 step 4] (implied; planned: composable pages)
- **MUST** carry the per-visitor, per-token context (site, visitor, session level, effective caps, share prefix, page view, token emphasis) to every part and source, both on first render and after connect. Today it travels in the **encrypted** LiveView session (`PublicPage.decrypt/2`) and is checked against the socket's site. *Rationale:* rendering and acceptance decisions depend on it; a decoy's session must be indistinguishable from a page's. [01 §4 step 3 "encrypted"; 01 §1.1 "A page's LiveView session records the site"] (current)
- **MUST** re-check capabilities on every request and every live navigation, so a revocation takes effect on the next request. *Rationale:* "Access is checked on every request against the grants table." [03 §7.1; `PublicLive.navigate/2` `allowed/2`] (current)
- **MUST** keep live navigation only between pages under the same share prefix, that the visitor may open, **and with the same tracking plan**. Otherwise do a full page load, so the next page gets its own code and CSP. *Rationale:* the inline script and CSP header are per page; a socket can't change its CSP. [01 §4 step 6; 02 §2 "Live navigation stays live only between pages with the same plan"; `PublicLive.navigate/2`] (current). With composable pages the plan is the union of the parts' declarations, so pages with different parts may not live-navigate. *Composable pages MUST preserve this rule* (planned: composable pages).
- **MUST** accept only events the page's plan allows, only for a page view this socket shows (attention) or of its session (signals, clicks), and drop anything else silently. *Rationale:* forged events can't add data. [04 §4 Rules] (current). Parts' own events MUST be held to the same rule. (planned: composable pages)
- **MUST** rate-limit events per session (10 clicks/s, 5 attention or signal batches/s, at most 500 events per list). *Rationale:* abuse. [04 §4 Rules] (current); parts' events need equivalent limits (implied).
- **MUST** use the event vocabulary already fixed for observation: `in`/`out`, `hidden`/`visible`, `idle`/`active`, `hover`/`unhover`, `focus`/`blur` (Attention); `copy`, `print`, `timing`, `errors` (Signals); `dw` click with `{dw: id, pv}`; `dw:ping`/`dw:pong`. Times are in tenths of a second on the page clock, anchored by `pn` at connect. *Rationale:* existing wire protocol. [04 §4a, §4b, §4c; `PublicLive.handle_event/3`] (current). New part interaction events (toggle, expand) SHOULD be expressible as component events on `data-dw` ids, e.g. a new `component_events` kind. [design guide §3.2 "Opening one is an interaction the tracking can count"] (planned: composable pages)
- **MUST** record clicks for `full` only: `phx-click` on every component of a `full` page, and the level re-checked server-side. *Rationale:* D6. "Anyone can send the event." [04 §4; `PublicLive` "dw" handler] (current)
- **MUST**, for a decoy, behave identically (same plan, hooks, socket and pings) and record nothing. Part interactions on a decoy MUST also record nothing yet look the same. *Rationale:* scanners must not tell a hit from a miss. [03 §6.5 Decoys] (current; planned: composable pages)
- **MUST**, for a preview with lag, record nothing, delay every reply by the recorded round trips, and carry the preview token on internal links. *Rationale:* owner tool. [04 §4c Preview with lag] (current); parts must not record in preview (implied).
- **SHOULD** let the token seed initial interaction state (emphasis set). [design guide §3.3] (planned: composable pages)

### Current mechanism

`PublicLive` is the single LiveView for all public pages. Assigns: prefix, site, decoy, session_id, visitor_id, preview, level, plan (hook), attention state per page view, viewport, latency. The heartbeat runs every 10 s, the ping every 45 s, and presence is tracked via `DcotekWeb.Presence`.

### Constraints

- Per-visitor state only.
- Capability re-check on every navigation.
- Plan equality gates live navigation.
- Server-side acceptance of only planned events.
- Decoy and preview must record nothing yet behave alike.

---

## C6 Documents

The nearest dcotek_web has to a "document" is a page file: YAML front matter plus CommonMark. A page manifest is planned.

### Requirements

- **MUST** validate the declarative form strictly at build: an unknown key fails, required keys (`slug`, `name`, `category`, `tagline` for projects; `title` for site pages), a slug matching its file name, `related` and `featured` slugs that exist, a catalog entry with a file, and no stray files. Report every error at once. *Rationale:* fail loudly. [02 §2, §2.3; `Content.FrontMatter`, `Track.parse/1`] (current)
- **MUST** validate the `track` declaration (`observe` ∈ {sections, page}, `parts` ⊆ {hover, focus}, `signals` ⊆ {copy, print, timing, errors}) and `latency_log` ∈ {off, aggregate, full}. *Rationale:* the plan is derived from it. [02 §2; `Track.parse/1`] (current). A manifest of parts MUST be checked the same way: unknown part, unknown setting or bad value fails (planned: composable pages).
- **MUST** validate `access: public|invited`. Catalog pages are expected to stay public. [02 §2, §3.1] (current)
- **MUST** allow logo and icon keys only on a content set's home page. [02 §4 (#105)] (current)
- **MUST** keep strings as strings: front-matter values are validated against allow-lists rather than turned into atoms from untrusted data. *Rationale:* atom safety (house memory: `to_existing_atom` fails in release eval). [`Track.parse/1` keeps strings; memory "Release eval and existing atoms"] (current; implied for manifests from S3)
- **MUST** treat a manifest fetched from object storage as untrusted input: the same validation, size bounds and no evaluation (cf. `data/config.exs` "a literal map that is never evaluated"). *Rationale:* house config pattern; content outside git. [07 §1] (implied; planned: composable pages)
- **SHOULD** let variants be expressed in the document form: variant files (`about@b.md`) or variant blocks in one file. Decide what happens when a base page changes, and how the catalog check treats variants. [#2 item 3] (planned: #2)
- **SHOULD** make a manifest name its content set or site, its access, its track declaration (or let it be derived from its parts), its parts with their settings, and its section settings. (planned: composable pages; implied shape)

### Current mechanism

`DcotekWeb.Content.FrontMatter` and `Track` parse YAML front matter. The Markdown body is compiled by `Content.Markdown` (MDEx). Content lives in `priv/content/<set>/*.md` (catalog: plus `projects/*.md`) and compiles into module attributes, so a content change is a rebuild and release (README §2 non-goal "A CMS").

### Constraints

- Build-time (or load-time) validation with all errors listed.
- No evaluation of data.
- No atoms from data.
- An unknown key is an error.
- The tracking declaration is part of the document and drives code, CSP and note.

---

## C7 Snapshots / replay / provenance

### Requirements

- **MUST** snapshot every served page, content-addressed (SHA-256 of the neutral HTML), deduplicated by hash, at boot, per content set. *Rationale:* the page changes between builds; replay must show what was served. [D11; 02 §5; `Content.Snapshots`] (current)
- **MUST** make a snapshot a function of content and layout only: neutral render, no per-request markup. Per-visitor rendering decisions (gate states) are recorded on the page view and **applied** to the snapshot at replay, never forked into separate snapshots. *Rationale:* dedup; "per-request markup (gate states included) never forks a snapshot". [02 §5] (current). **Any new per-visitor rendering dimension (part state, token emphasis, variant, query result) MUST follow the same pattern: neutral snapshot plus recorded per-view state that replay can apply, or else a recorded data snapshot.** (implied; planned: composable pages, #2)
- **MUST** store every gated unit in its shown form marked `data-gate="<resource>"`, with its teaser in `<template data-gate-teaser>`. Replay swaps or removes units by the page view's `gate_states`. [02 §5; 06 §3] (current)
- **MUST** snapshot every asset a page references (CSS, images, CSS `url()` references), content-hashed, with references rewritten to `/frame-asset/<hash>`, so a snapshot is self-contained. [02 §5; `Snapshots.asset_url/3`, `css_urls/4`] (current). Parts' assets (chart SVGs, part CSS) MUST be captured the same way (planned: composable pages).
- **MUST** have every page view record `snapshot_hash`, `gate_states` and `build_sha`. [04 §3; 01 §4 step 2] (current). It must also record the variant (planned: #2) and any part state needed to reproduce (implied).
- **MUST** store each snapshot's **component index** (ids, gate, teaser-only, reading load) with it, so stored `element_id`s resolve against the snapshot they were recorded on. [02 §2.2; `PageSnapshot.components`] (current)
- **MUST** have replay render in `<iframe sandbox="allow-same-origin">`, scripts off, served by the admin endpoint only, and never appear as a visit. Highlights come from `attention_intervals` keyed by `[data-dw]` ids, so **the snapshot must be meaningful with no JS**. An interactive part's replay must be reproducible by the console from the static snapshot plus recorded state, with no part code running in the frame. [06 §3] (current; constraint on planned parts)
- **MUST** aggregate the attention map across snapshots by stable component id. A component missing from the shown snapshot is listed beside it, not dropped. [06 §4] (current)
- **MUST** keep retention: snapshots pruned only when no retained page view references them, and never the current build's. [04 §5] (current)
- **MUST** mark in replay when the snapshot differs from the current build's page for that path. [06 §3] (current)
- **MUST** be able to snapshot every catalog route and the 404 page. System pages (`/invite`, `/403`) are not snapshotted. [02 §5; `Content.system_page/2` doc] (current). Pages assembled from data in S3 (planned) MUST still be snapshotted at the moment that content becomes servable, not only at boot (implied: today snapshots are recorded at boot because content only changes with a release).

### Current mechanism

`DcotekWeb.Content.Snapshots.record!/3` runs from the supervision tree before the endpoints. It renders each page with `Context.neutral(&asset_url/…)` and inserts `page_snapshots(hash, path, html, components, inserted_at)` and `asset_snapshots(hash, path, body, content_type)`. The route → hash map and the components live in `:persistent_term`.

### Constraints

- Content-addressed, deduplicated, self-contained.
- Neutral, with per-view state applied at replay.
- Replay runs no scripts.
- Ids are stable across builds.
- A snapshot exists before any page view can reference it.

---

## C8 Stores

### Requirements

- **MUST** keep everything the host holds in one data directory (SQLite with ecto_sqlite3, `config.exs`, `secret_key_base`, `geoip/`, `demo_keys/`), backed up by copying it. [D8; 07 §1, §5; house `<app>-ctl` pattern] (current)
- **MUST** keep snapshots in the database (`page_snapshots`, `asset_snapshots`) keyed by content hash. [02 §5] (current)
- **MUST** identify content by (content set, route path). Each site's `content` names a directory, and each site has its own `/`. [02 §2.3; `Snapshots.hash_for/2`] (current)
- **SHOULD** allow manifests and Markdown fragments in object storage (exio S3), referenced by name and version, with templates and parts compiled from git. [owner brief] (planned: composable pages). This conflicts with the README §2 non-goal "A CMS"; a spec change is required.
- **MUST**, if content lives in object storage, be able to name exactly which version of every fragment and manifest a page view used (directly, or via the snapshot hash). *Rationale:* replay and provenance. [D11] (implied; planned: composable pages)
- **MUST NOT** require a per-visit outbound request to a store on the public request path if that would expose visitor data. A local fetch to the owner's own exio is a deployment choice, but a per-visit fetch also adds latency to first render. *Rationale:* D10's principle, "No request leaves the host per visit". [D10; 04 §8] (implied)
- **SHOULD** keep a registry of demo apps (resources `demo:<app>`), registered by the demos design. [03 §7.5.1; #9] (planned: #9)

### Current mechanism

Content: `priv/content/<set>/` compiled into the release. State: SQLite under `<data_dir>/data`. Hot lookups: `:persistent_term` (snapshot hashes, components, page scripts).

### Constraints

- One data directory.
- Content addressed by (site content set, path).
- Snapshots content-hashed in the DB.
- No per-visit third-party request.

---

## C9 Registries / extension

### Requirements

- **MUST** keep the tracking-code registry closed and declarative: parts `hover`, `focus` and signals `copy`, `print`, `timing`, `errors`, each a source file under `priv/static/js`, assembled in a fixed order (`attention`, `attention_<part>`…, `signals`, `signals_<sig>`…). *Rationale:* reading the page shows everything it can do. [02 §2; `PageScripts.sources/1`] (current)
- **MUST** have the router's access table be "one declaration that both the plug and a test read". Every route is in exactly one row, and every invited route belongs to one resource. [02 §3.1; `DcotekWeb.Access.Routes`] (current). Parts that add routes (a résumé PDF link, demo routes) MUST register through it (implied).
- **MUST** derive the reserved-code set from the access table, so no share code is minted that a route would shadow. Shadowed codes are reported in `/healthz`. [03 §6.1] (current). Page-set page names are reserved likewise. [02 §2.3] (current)
- **MUST** let third parties and sibling projects ship parts as packages, registered at compile time (parts are compiled Elixir), with built-in parts using the same public contract. [owner brief] (planned: composable pages)
- **MUST** have a registered part declare: its settings schema, its tracking needs (so the plan and note are derivable), its client code (for the CSP hash), its assets (for snapshots), its component ids and reading load (for the index), its neutral render, and its no-socket render. (implied from C3, C7, C12; planned: composable pages)
- **MUST** let a third-party part never add tracking the site's model doesn't have, nor a privacy-note line the generator doesn't know. Either part tracking needs map onto the existing plan vocabulary, or the vocabulary is extended in dcotek_web with a note line. *Rationale:* "New interactive elements fit that model rather than adding new tracking"; the note is generated from the plan. [design guide §5; `Track.note/2`] (planned: composable pages)
- **SHOULD** register demo apps as resources, each with its key in `data/demo_keys/<app>`. [03 §7.5.1, §7.5.6; #9 comments] (planned: #9)

### Current mechanism

These are fixed module attributes: `@parts ~w(hover focus)` and `@signals …` in `Track`, `Access.Routes`, and `Compiler @site_pages`. Nothing is open for extension today.

### Constraints

- Registration is compile-time.
- The tracking vocabulary is a closed set tied to note text.
- The access table is the single route declaration.

---

## C10 Rendering targets and web constraints

### Requirements

- **MUST** do the first render on the server as full HTML. Pages work without JS. *Rationale:* D2. [D2; 01 §4] (current)
- **MUST** serve bots, redirects, error pages, black-holed requests and probes as plain HTML **with no socket**. Black holes get the bare plain page, with no prefix and no socket. [01 §4 step 3; 02 §3; 03 §6.5] (current). Parts MUST have a correct socketless form (planned: composable pages).
- **MUST** run the public LiveView over its own public socket (`/live`), separate from the console's, with different salts, an origin check limited to the site's own pages, `421` for an unclaimed host and `403` for a cross-site origin. [01 §1, §1.1] (current)
- **MUST** set CSP: `default-src 'self'; script-src 'self' 'sha256-<page script>'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'`. No `unsafe-inline` and no `unsafe-eval`. The LiveView client is served from `/vendor`. [02 §2; `PageScripts.csp/1`, `external/0`] (current). Consequences for parts: no inline `<style>` or `style=""` attributes; no inline event handlers; chart libraries that inject inline styles are incompatible; SVG rendered on the server is fine (implied).
- **MUST** compute the inline script and hash from the plan, cached per plan in `:persistent_term`. [`PageScripts.inline/1`] (current). With parts, the hash input becomes the union of declared parts' code. Live navigation between different unions must be a full load (C5).
- **MUST** load nothing from another origin: no CDN, no third-party fonts, analytics, embeds or CAPTCHA. The wordmark letters are SVG outlines for this reason. [02 §4; 03 §7.3 "no third-party CAPTCHA"; design guide §5] (current)
- **MUST** provide light and dark themes via `prefers-color-scheme` (no toggle), with brand tokens `--ink`, `--paper`, `--accent` (light `#15171A`/`#F4F5F3`/`#0B6E69`, dark swapped with accent `#3CC4B8`). Whether myfield.dev shares them is open. [02 §4; design guide §2] (current for theming; tokens are guide-level)
- **MUST** meet contrast 4.5:1 (3:1 large) in both themes, including muted text; distinguish by lightness, not hue alone. [design guide §2] (planned: composable pages; applies to all parts)
- **MUST** honor `prefers-reduced-motion`. Motion: 100–150 ms for feedback, 200–250 ms for layout changes. [design guide §4] (planned: composable pages)
- **MUST** emit internal links as live patches (`data-phx-link="patch"`) on a LiveView page and as ordinary links on plain HTML. [01 §4 step 6] (current)
- **MUST** send `Cache-Control: private, no-cache` (the page is per visitor). [01 §4 step 4] (current)
- **MUST** render `<title>`, a meta description and Open Graph tags (generated `/og.png`) and a canonical link to the bare path on the request's own site. [02 §4; 03 §6.2; 01 §1.1] (current)
- **MUST** show the slow-connection notice when the median of the last three round trips exceeds 300 ms, and "Reconnecting…" via `phx-disconnected` CSS. [04 §4c] (current)
- **SHOULD** produce a print/PDF target from the same content (the résumé PDF, served through a tracked link). [design guide §1B.4, §6] (planned: composable pages)
- **SHOULD** allow demo apps (proxied LiveViews) at `/demo/<app>/*` under a path prefix or a subdomain, with tracking either at the proxy or via an opt-in component-attention hook in each app. [#9 items 3, 5] (planned: #9)

### Current mechanism

`PublicLive` with a root layout that writes the document head and tail from compiled segments. The body is a raw binary. Hooks are registered by the inline script before `live.js` starts the LiveView client.

### Constraints

- Server first render.
- A socketless plain-HTML path.
- Strict hash-based CSP with `style-src 'self'`.
- Zero third-party origins.
- Themes by media query.
- WCAG-level contrast in both themes.

---

## C11 Identity, auth and capabilities

### Requirements

- **MUST** keep two public access levels: static pages are public; invited routes need a grant (from a token, a share-code handoff or a magic link). [D14; 02 §3.1; 03 §7] (current)
- **MUST** scope capabilities per resource (`pages`, `demo:<app>`), totally ordered `none` < `listed` < `view` < `interact` < `write`. For `pages`, only `none`/`listed`/`view` are meaningful. [D16; 03 §7.5.1] (current)
- **MUST** compute effective caps **live along the share chain**: token caps → forward rule applied per hop (`inherit`, `step_down`, `cap:<level>`, `none`) → per-grant `restrict` (lower only); a visitor's level is the max over active grants. **Invariant:** a child's level ≤ its parent's at every node, for every resource. It can only be attenuated, never amplified (property-tested). [D16; 03 §7.5.3, §7.5.4] (current)
- **MUST** render gated content per visitor: `view`+ shown, `listed` teaser with a Request access button, otherwise hidden with no href, text or id. Bots are always hidden, and anonymous visitors see no gated units. [D17; 02 §3.2] (current). Parts MUST honor the same states for any content they gate (planned: composable pages).
- **MUST** respond to invited routes as follows: bot → 404; no grant → 302 `/invite?next=`; `listed` → 302 `/invite?next=` with the listed message; grants but `none` → 403 naming the resource and level. [02 §3.1] (current)
- **MUST** let demo apps enforce `view`/`interact`/`write` from a signed `X-Dcotek-Cap` assertion (visitor_id, resource, level, exp ≤ 5 min, HMAC-SHA256 with a per-app key), sent on every proxied request and WebSocket (re)connect. [03 §7.5.6] (current for the assertion; planned: #9 for the per-app meaning)
- **MUST** have the session capture level come from attribution: `full` for a personal token's sessions, the token's `capture` for a public link, `basic` for anonymous. Matching never changes it. [04 §1; 03 §1.1; D15; 04 §9.4] (current)
- **MUST** resolve a token or share code only on its own site's host; elsewhere it is a miss. Visitor cookies are per site. [01 §1.1] (current)
- **MUST** answer misses with decoys indistinguishable from hits, and black-hole scanning addresses (50 misses/IP/hour, 100/subnet, probe run weight 8), serving them plain HTML after a 100 ± 25 ms delay. `never_block` exempts listed addresses. [03 §6.5] (current). A part MUST NOT leak hit/miss through its behavior (e.g. a query part showing token-specific data on a decoy) (implied).
- **MUST** carry token emphasis (skill tags) on the token, untamperable, not in the URL. [design guide §3.3] (planned: composable pages)
- **MUST** keep the admin console on a separate listener (private bind, Host check, sign-in). No admin route on the public endpoint. [D4; 01 §1; 06 §1] (current). Shared parts used in the console (attention maps, replay) are a separate rendering context and must not make the public endpoint serve admin assets (implied).

### Current mechanism

`DcotekWeb.Access` (`visitor_caps/1`, `level/2`), `Access.{Grant, Levels, Routes, Assertion}`, `AccessGate`, and `PageContext.gate_states_for/3`. The page's decided context is sealed into the LiveView session.

### Constraints

- Capabilities only attenuate.
- Re-checked on every request and navigation.
- Hidden means absent from the HTML.
- Per-site resolution.
- Decoy indistinguishability.
- Bots get nothing gated.

---

## C12 Privacy, tracking and observation

### Requirements

- **MUST** cap anonymous (`basic`) visitors at page views, dwell, scroll depth and deepest heading, coarse browser traits, truncated IP and coarse location. No component intervals, clicks, copies or viewport. *Rationale:* D6 (amended by D15). [D6; 04 §1, §9.1] (current)
- **MUST** decide the plan per page and per capture level (`Track.plan/2`): `full` gets the declaration; `basic` gets `observe: depth` (or `page`), no parts, and signals ∩ {print, timing, errors}. **An anonymous visitor's page carries no code for `full` data, and the server MUST also drop any `full` event for a `basic` session.** [02 §2; 04 §1; `Track.plan/2`] (current)
- **MUST** generate from the **same plan**: the page's assembled script, its CSP hash, what the server accepts, and the plain-language privacy note (`<p class="privacy">`). "So the three can't drift apart." [02 §2; `Track` moduledoc; `PageContext.note/2`] (current). **With composable pages, the plan, and so the script, hash and note, MUST be generated from the declared parts.** [owner brief] (planned: composable pages)
- **MUST** show the note only while the owner's page-notices switch is on (stored in the DB, applies without restart). No banner, no privacy page. DNT/GPC are not honored. [D3 (#116); 06 §2 Settings; 04 §4] (current)
- **MUST** record attention as in-view, hover and focus **intervals on components**, never pointer coordinates, keystrokes or DOM mutations. Hover and focus only on pages declaring them. Intervals have a fixed 250 ms server floor; the owner's display threshold is separate (default 1 s, per browser). [D12; README §2 non-goals; 04 §4, §4a; 06 §4.1] (current)
- **MUST** accept element ids only if they are in the page view's snapshot index, not inside a `hidden` gated unit, and a `gate-req:` only if its unit was a teaser. [04 §4 Rules] (current). Part ids are subject to the same check (planned: composable pages).
- **MUST** never record copied text, only its length and enclosing component; and for errors, never page text (at most 5). [04 §4b] (current)
- **MUST** confirm a session human only after an interaction through the socket (D7); a token session unconfirmed after the idle window is a prefetch. [D7; 04 §6] (current). Part interactions count as interactions (implied).
- **MUST** resolve latency logging token > page > site default, recorded per page view. [04 §4c] (current)
- **MUST** apply retention: events 730 days, anonymous sessions 365 days, known sessions kept. [04 §5] (current)
- **SHOULD** let the attention data answer which **tier** of a project a visitor reached (glance / scan / deep), which needs tiers to be components or sections with stable ids. [design guide §1A] (planned: composable pages)
- **MUST**, for planned A/B variants, settle whether anonymous visitors get variants, given D6. [#2 item 4] (planned: #2)
- **MUST** support tracking inside demos only via proxy-level logging or an opt-in component-attention hook in each app, raised cross-project. [#9 item 5] (planned: #9). A shared visualize or metresis part placed on a dcotek_web page is not a proxied demo, so it MUST use dcotek_web's own tracking contract (component ids and declared plan), not its own telemetry (implied).
- **MUST** keep geolocation local (DB-IP Lite MMDB), with no per-visit outbound request. [D10; 04 §8] (current)

### Current mechanism

`DcotekWeb.Content.Track` (declaration, plan, note), `DcotekWebWeb.PageScripts` (code and CSP), `PublicLive` (acceptance, rate limits, `LiveAttention` rebuild, signals, ping), and `PageContext` (page view, `gate_states`, note slot).

### Constraints

- One plan generates code, CSP, acceptance and note.
- The anonymous cap holds both in the code shipped and on the server.
- Components, not coordinates.
- Ids are validated against the snapshot.
- Nothing is recorded for decoys, previews or bots without cookies.

---

## C13 Isolation, limits and failure

### Requirements

- **MUST** fail the build on any content error, listing every one. A broken page never serves. [02 §2; `Compiled`] (current). For content loaded from a store, a bad manifest MUST be refused (keep the previous version) rather than serve a broken page (implied; planned: composable pages).
- **MUST** refuse boot on malformed `sites` config (naming the key) or on a site whose `content` names no directory. [01 §1.1; 02 §2.3] (current)
- **MUST** have a LiveView session that fails to decrypt, or belongs to another site, reload the page afresh (redirect), never error. [`PublicLive.mount/3` `:error` clause] (current)
- **MUST** limit event rates per session and batch sizes (see C5), dropping silently. [04 §4] (current)
- **MUST** cost a dropped connection at most 10 s of attention (heartbeat checkpoint). [04 §3, §4a] (current)
- **MUST** sandbox demos, if hosted, because every demo assumes a hostile user: no network, read-only base, CPU/memory/pids and wall-clock limits, or excluded. Decide the instance model (shared-reset, ephemeral or pool) and behavior when resources are exhausted. [#9 items 1, 2, 7] (planned: #9)
- **SHOULD** contain a failing interactive or query part: show a plain fallback for that part, without crashing the page's LiveView (which carries the visitor's observation, heartbeat and presence for the whole page). This must be done without `try/rescue` (house rule), e.g. by running the part in its own process or LiveComponent boundary. (implied; planned: composable pages)
- **SHOULD** bound query parts in time and size, since a first render blocks on them (implied; planned: composable pages).
- **MUST** keep the scanner-defense thresholds as constants that fail loudly in the console, not settings. [03 §6.5] (current)

### Current mechanism

Compile-time failure for content. Rate limits via `DcotekWeb.RateLimit`. The per-page LiveView process holds all observation state. CI fails a test when a LiveView or tracking task outlives it (07 §4).

### Constraints

- Errors are surfaced, never hidden (no try/rescue).
- One LiveView per page carries tracking, so a part crash must not take observation down.
- Hostile-user assumption for anything interactive and invited.

---

## Vocabulary

| Term | Exact meaning in dcotek_web |
|------|------------------------------|
| **site** | One public host on the public listener (dco-tek.com, myfield.dev), chosen by `Host`, with `id`, `host`, `name` and `content` (01 §1.1). |
| **content set** | A directory `priv/content/<content>/` that one site serves. Kinds: **catalog** (has `projects/`), **page set** (`index.md` plus `<name>.md`), and the one-page `dco-tek-intro` (02 §2.3). |
| **catalog** | (1) The spec table of projects that must each have a page (02 §1). (2) dco-tek's content-set kind. Also "the compiled page catalog" in `persistent_term` (01 §2). |
| **page** | A compiled `%Page{}`: path, kind (`home`, `about`, `category`, `project`, `page`, `not_found`, `invite`, `forbidden`), access, track, segments, sections, components. |
| **system page** | `/invite` and `/403`, whose body fills the `:main` slot per request. Not snapshotted and not in the sitemap. |
| **front matter** | YAML at the top of a page file, strictly validated (02 §2). |
| **segment** | An element of a compiled page: a binary, or `{:slot, name}`, `{:href, path, frag}`, `{:asset, path}`, `{:abs, path}`, `{:mark, :body\|:tail}`, `{:gate, resource, forms}` (`Content.Page`, `Content.render/2`). |
| **slot** | A per-request hole in a compiled page, `{:slot, name}`: `:head`, `:body_end`, `:privacy`, `:live`, `:main` (`Layout`, `Context.slots`). Spec 02 §3.2 also says **gate slot** for a gated unit's segment. |
| **layout** | The one site layout: header, content column, footer (02 §4). `Content.Layout` builds its segments. "Layout parts" in `Compiler.compile_site/1` are the site's nav and footer pieces. |
| **context** | `%Content.Context{}`: what varies per request (prefix, query, base_url, asset fn, gates, snapshot?, clicks?, page_view, live?, slots). **Neutral context:** a snapshot's, with no prefix, hooks or scripts, and gates shown and marked. |
| **component** | A trackable element marked `data-dw="<id>"`: section `s:`, card `card:`, link `a:`, nav `nav:`, code `code:`, image `img:`, request button `gate-req:` (02 §2.2). The unit attention is recorded on (D12). *Not* a Phoenix component. |
| **component index** | Per page and snapshot: id → gate resource, teaser_only, and for sections words, code_blocks, order (02 §2.2; `Content.component_index/1`). |
| **section** | A heading plus content up to the next heading of the same or higher level, wrapped in `<section>`, id `s:<heading-id>`, nested. |
| **reading load** | A section's `words`, `code_blocks` and `order`, counted at compile time (02 §2.2). |
| **gated link / gated unit** | A link to an invited route; the smallest enclosing block (p, li, tr, card, nav item) shown, teased or hidden together (02 §3.2). |
| **gate state** | `shown` \| `teaser` \| `hidden`, per resource and per page view (`gate_states`). |
| **resource** | What capabilities are about: `pages` or `demo:<app>` (03 §7.5.1). |
| **level** | Overloaded. (1) **Capture level:** a session's `basic` \| `full` (04 §1). (2) **Capability level:** `none` < `listed` < `view` < `interact` < `write` (03 §7.5.1). |
| **caps / effective caps** | A token's resource → level map; computed live along the share chain with forward rules and `restrict` (03 §7.5). |
| **forward rule** | `inherit` \| `step_down` \| `cap:<level>` \| `none` (03 §7.5.3). |
| **grant** | A visitor's access row from a token, share or magic link (03 §7.1). |
| **token / share code / handoff / code reuse / decoy / black hole / probe** | 03 §1, §6, §6.4, §6.5. A **decoy** is a fake share code answering a miss exactly as a hit would, recording nothing. |
| **prefix** | The share code path prefix `/<share>` put on every internal link (03 §6.2). |
| **known / anonymous visitor** | Has (or doesn't have) a `visitor_tokens` row. Public-link arrivals stay anonymous (03 §1.1, §3). |
| **track (declaration)** | Front matter `track: {observe, parts, signals}` (02 §2). |
| **observe** | `sections` \| `page`, and in a plan also `depth` (the anonymous form) (04 §4a; `Track.plan/2`). |
| **parts (tracking)** | Optional Attention modules `hover`, `focus`, each a JS file included only when declared (02 §2, 04 §4a). Signals also has "parts": `copy`, `print`, `timing`, `errors` (04 §4b). **This collides with the composable-pages "part".** |
| **signals** | Discrete reports: copy, print, timing, errors (04 §4b). |
| **plan** | What a page observes at a capture level: `Track.plan(track, level)`. It generates the script, CSP hash, accepted events and privacy note. |
| **privacy note / page notice** | The generated `<p class="privacy">` sentence; shown while the owner's page-notices switch is on (D3, #116). |
| **render_parts** | `Content.render_parts/2`: head / body / tail of the document (not composable parts). |
| **hook** | A LiveView JS hook: `Attention` (`#dw-a`) and `Signals` (`#dw-s`). |
| **page view** | One served page per session, with snapshot_hash, gate_states, build_sha, dwell, latency, timing (04 §3). |
| **attention interval** | `(page_view_id, element_id, kind w\|h\|f, start_ms, duration_ms)` (04 §4). |
| **component event** | `c` click, `y` copy, `p` print (04 §4). |
| **attention threshold / floor** | The owner's display filter (default 1 s, per browser) / the fixed 250 ms server drop (06 §4.1, 04 §4). |
| **snapshot** | Neutral page HTML, content-addressed (`page_snapshots`); **asset snapshot** (`asset_snapshots`); served at `/frame/:hash` and `/frame-asset/:hash` on the admin endpoint (02 §5, 06 §3). |
| **replay** | The admin view of a `full` page view over its snapshot, with highlights from intervals and gate states applied (06 §3). |
| **attention map** | Per-path aggregation of component attention across snapshots, drawn on a snapshot frame (06 §4). |
| **preview (with lag)** | A signed console link opening a public page that records nothing, delayed by a fixed or recorded round trip (04 §4c). |
| **source** | Overloaded and *not* a data concept. `Compiler.sources/1` means the Markdown files read. Token `source` is `manual` \| `magic_link`. Grant `source` is `token` \| `share` \| `magic_link`. "Source drafted from" in 02 §1 means a project README. |
| **registered** | Demo apps "registered by the demos design" (03 §7.5.1); no general registry exists. |
| **store, manifest, binding, board, dashboard, feed, cell, panel, schema** | Not used in dcotek_web today. "Manifest" appears only in the owner's composable-pages direction. |
| **variant** | A planned alternative version of a page for A/B (#2). |
| **tier** | Glance / scan / deep dive content depth (design guide §1A). |
| **emphasis** | A token-carried set of skill tags a page highlights on arrival (design guide §3.3). |

---

## Open questions found

1. **"Code in git, content as data in S3" vs the spec's non-goal "A CMS. Content is Markdown in the repository, changed by commit"** (README §2; design guide §5). This needs a spec amendment. It also needs a decision on when snapshots are recorded for content that changes without a release (today only at boot, 02 §5), and on how compile-time guarantees (link resolution against the access table, gated-unit derivation, id stability, reading load) run for fetched content.
2. **Neutral snapshot vs stateful parts.** A snapshot is "a function of content and layout only" and replay runs no scripts. How are an interactive part's state (skill selection, highlights), a token's emphasis, an A/B variant and a query part's rows reproduced in replay? Is it the gate-state pattern (recorded per-view state applied by the console), or a per-view data snapshot? Which recorded state is allowed at `basic` level?
3. **Plan as a union of parts.** If each part declares tracking, pages with different parts have different scripts and CSP hashes, so live navigation between them becomes a full load (02 §2). Does the owner accept fewer live navigations, or should part JS be served from `'self'` files (allowed by `'self'`) so the plan, and with it the hash, stays page-level?
4. **Third-party part tracking.** The privacy note is generated from a closed vocabulary (`Track.note/2`). Can a package part introduce new observation (a "selected skill" event)? If yes, who writes its note line, and how is D6 enforced for it on the server?
5. **"parts" naming collision.** The tracking "parts" (hover, focus, copy …) and the "render_parts" head/body/tail split already use the word. The unified model needs a different term, or a rename here.
6. **`level` overloading** (capture level vs capability level) will collide with any unified "level" concept.
7. **Token emphasis.** Where does it live (a new token field?), does it pass down the share tree like caps (attenuate? inherit?), and is it recorded on the page view? This is not yet in spec 03.
8. **PDF résumé.** Generated from the same content and "served through a tracked link". Is it a rendering target of the same parts (print layout), is it snapshotted, and is a PDF download a page view or a component event? This is not in the spec.
9. **Shared visualize/metresis parts vs `/demo/*` proxies (#9).** An embedded part runs inside dcotek_web's LiveView, under dcotek_web's CSP and tracking. A demo is a proxied app with its own process and the `X-Dcotek-Cap` assertion. The boundary between the two needs stating.
10. **Bullet style per section** (02 §4: "One style everywhere for now; per section once pages are split"). How is a per-section setting expressed in Markdown fragments, given raw HTML is disabled?
11. **myfield.dev brand tokens.** Shared with dco-tek or its own identity is "an open decision for the owner" (design guide §2).
12. **Spec status drift.** README says "Nothing here is implemented" and §5 Platform says "Phoenix LiveView 1.2 (admin only)", both stale since #76 and #95.
