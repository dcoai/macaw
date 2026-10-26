# 08 — Records: view paths, replay and provenance {#records}

A **record** makes a page view reproducible. It holds what was shown, in which states, and how the visitor moved through it. **It never holds the viewer.** (macaw_compose#8, question 3.)

## 1. View paths {#records-paths}

A visit is a **view path**: a sequence of **views**, each a page in a particular state.

```
home ──click──▶ about ──select Elixir──▶ about [Elixir] ──select OTP──▶ about [Elixir, OTP] ──click──▶ project: exio
```

- **Steps** are visitor-initiated: navigation (a new page) and view changes (a selection, an opened tab).
- **Markers** are system-initiated changes (pushed data, a timer, another viewer's edit), recorded on the timeline but not counted as the visitor's actions.

Choosing any step shows the page as it was there. The path and the replay are one view. Click paths (dcotek_web#54) become view paths.

## 2. What is recorded {#records-content}

- **Base snapshots:** the **neutral** render of a page version, content-addressed and shared by every visit.
  - It is stored **by part and assembled:** the chrome rendered by a given template stack is stored once, and a page's snapshot is an assembly of part hashes. The record still *means* "the whole page as seen".
  - Its assets are captured too.

  (dcotek_web.md C7.)
- **Semantic state events,** not LiveView diffs: "selected Elixir". Each names the component instance, the state, the value, the time, and the initiator. Diffs are tied to template and LiveView versions, are larger, and carry everything rendered.
- **Source requests:** params, window and `as_of`. **No data is stored.**
- **Definitions by digest:** the page, its template stack and its surfaces ([07](07-documents.md)).

**Replay** re-renders the base snapshot, applies the state events up to the chosen step, and re-runs the components. Replay runs no scripts in the frame. (dcotek_web.md C7.)

## 3. Attention {#records-attention}

**Attention is accounted at navigation.** A navigation closes every open interval and credits it to the page being left, and the new page starts fresh, including for persistent elements still in view. Each page view's attention therefore sums to its own time on screen, and its attention map includes its chrome as seen from that page.

## 4. Data in replay: requery, with time travel when available {#records-requery}

- The point of replay is the **component level:** what was shown, attention and dwell. It is not the exact rows.
- **Replay requeries sources and shows current data.**
- A source that supports `:as_of` (metresis's immutable samples, exio's object versions, a database with history) is asked for the viewing moment. Macaw supports time travel and never requires it.
- Components whose source could not time-travel are labeled **"showing current data"**.
- **The viewer for a requery** is supplied by the host; by default, the person replaying.

## 5. Two stores, one line {#records-stores}

| Store | Holds | Owner |
|---|---|---|
| **the Macaw record** | definition digests; state events (instance, state, value, time, initiator); source requests; steps and markers | Macaw, neutral and portable |
| **the host's records** | the visit (visitor, session, token, site, address); the access at the time (capabilities, gate states); the link from each page view to its Macaw record | the host, under its own privacy rules |

- **Identity never enters Macaw.** The same record format works in any app, and a record can be shared without identifying anyone.
- **Deletion and retention have one owner:** the host deletes the visit and the records linked to it.
- **Replay gets its viewer from the host.**
- **State values can themselves be personal** (a typed search, picked skills). So recording is declared per state source with the lowest capture level allowed, and is **closed by default**: a source or state source is recorded only when it declares it and the host enables it. dcotek_web's D6 (nothing finer than page level for anonymous visitors) applies to state values too.
