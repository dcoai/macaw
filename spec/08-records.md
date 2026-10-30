# 08 — Records: view paths, replay and provenance {#records}

<!-- surfex: deferred #166: records -->

A **record** makes a page view reproducible. It holds what was shown, in which states, and how the visitor moved through it. **It never holds the viewer.** (macaw_compose#8, question 3.)

## 1. View paths {#records-paths}

<!-- surfex: deferred #166: records -->

A visit is a **view path**: a sequence of **views**, each a page in a particular state.

```
home ──click──▶ about ──select Elixir──▶ about [Elixir] ──select OTP──▶ about [Elixir, OTP] ──click──▶ project: exio
```

- **Steps** are visitor-initiated: navigation (a new page) and view changes (a selection, an opened tab).
- **Markers** are system-initiated changes (pushed data, a timer, another viewer's edit, a paused animation), recorded on the timeline but not counted as the visitor's actions.

Which is which comes from the event's `initiator` ([macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event)). An event on a data element resolves against the drawing it landed on, or is dropped (the drawn-token rule), so a step never records an item the visitor didn't see.

Choosing any step shows the page as it was there. The path and the replay are one view. Click paths (macaw#54) become view paths.

## 2. What is recorded {#records-content}

<!-- surfex: deferred #166: records -->

- **Base renders:** the **neutral** render of a page version **before any delivery**: every component in its initial drawn state (`loading`), and state at its initial values. It therefore holds no data and nothing per viewer, so it is content-addressed and shared by every visit.
  - It is stored **by part and assembled:** the chrome rendered by a given template stack is stored once, and a page's base render is an assembly of part hashes. The record still *means* "the whole page as seen".
  - Its assets are captured too, including generated content-addressed stylesheets ([10](10-web.md#web-csp)).

  (dcotek_web.md C7.)
- **Semantic state events,** not LiveView diffs: "selected Elixir". Each is the **recorded form** of an event (`Event.recordable/1`, [macaw_data 01](https://github.com/dcoai/macaw_data/blob/main/spec/01-sources.md#sources-event)): the component instance, the element, the name, the identity, the value, the time and the initiator. The payload data an event carries live (`row`, `point`) is delivered to the host and never recorded. Diffs are tied to template and LiveView versions, are larger, and carry everything rendered.
- **Source requests:** params, window and `as_of`. **No data is stored.**
- **Definitions by digest:** the page, its template stack and its surfaces ([07](07-documents.md)), each the kernel's digest of its value, the term ([macaw_layers 01 §7](https://github.com/dcoai/macaw_layers/blob/main/spec/01-kernel.md#kernel-digest), [00 §4.2](00-overview.md#core-terms)), never of its JSON form: a definition has one digest however it was written or read back.

**Records never embed printouts.** A **printout** is a component's prepared output with its data (a visual's design, deliveries, now, window and theme), used for print and output. Whole-page output in print mode assembles the components' printouts, and is output, never a record. Three values, three rules (macaw_compose#22, R16):

| Value | Holds | Data? |
|---|---|---|
| printout | prepared output and deliveries | carries data; never a record |
| record | digests, recorded events, requests | never |
| state snapshot ([03](03-state.md#state-snapshots)) | interaction state | never |

**Replay** starts from the base render, applies the state events up to the chosen step, and re-runs the components against requeried sources (§4). Replay runs no scripts in the frame. (dcotek_web.md C7.)

## 3. Attention {#records-attention}

<!-- surfex: deferred #166: records -->

**Attention is accounted at navigation.** A navigation closes every open interval and credits it to the page being left, and the new page starts fresh, including for persistent elements still in view. Each page view's attention therefore sums to its own time on screen, and its attention map includes its chrome as seen from that page.

## 4. Data in replay: requery, with time travel when available {#records-requery}

<!-- surfex: deferred #166: records -->

- The point of replay is the **component level:** what was shown, attention and dwell. It is not the exact rows.
- **Replay requeries sources and shows current data.**
- A source that supports `:as_of` (metresis's immutable samples, exio's object versions, a database with history) is asked for the viewing moment. Macaw supports time travel and never requires it.
- Components whose source could not time-travel are labeled **"showing current data"**.
- **The viewer for a requery** is supplied by the host; by default, the person replaying.

## 5. Two stores, one line {#records-stores}

<!-- surfex: deferred #166: records -->

| Store | Holds | Owner |
|---|---|---|
| **the Macaw record** | definition digests; state events (instance, state, value, time, initiator); source requests; steps and markers | Macaw, neutral and portable |
| **the host's records** | the visit (visitor, session, token, site, address); the access at the time (capabilities, gate states); the link from each page view to its Macaw record | the host, under its own privacy rules |

- **Identity never enters Macaw.** The same record format works in any app, and a record can be shared without identifying anyone.
- **Deletion and retention have one owner:** the host deletes the visit and the records linked to it.
- **Replay gets its viewer from the host.**
- **State values can themselves be personal** (a typed search, picked skills). So recording is declared per state source with the lowest capture level allowed ([01](01-vocabulary.md#vocab-records)), and is **closed by default**: a source or state source is recorded only when it declares it and the host enables it. Collpa's D6 (nothing finer than page level for anonymous visitors) applies to state values too.
