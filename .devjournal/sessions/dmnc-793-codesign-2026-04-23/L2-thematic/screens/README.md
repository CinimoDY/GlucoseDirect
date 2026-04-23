# Visual-companion screens — DMNC-793 codesign session

Nine screens captured from the brainstorming companion as the codesign conversation unfolded. In order, they document the decision journey from first chip-style options to final approved composition.

## 01 · toolbar-chip-style.png

**First push.** Chart toolbar visual vocabulary candidates: CURRENT baseline (11-12pt amber pills inside scrolling List) · **A** same idiom bigger · **B** AmberChip from DMNC-798 · **C** unified segmented container. Lean: B.

## 02 · toolbar-compose-plus-option-d.png

**User's follow-up.** Explains the "doesn't compose with marker-lane" phrase with side-by-side (C+marker-lane has two idioms vs B+marker-lane has one). Shows B's three state swatches (UNSELECTED / SELECTED / DISABLED) with explicit token names. Adds the user's proposed **Option D** (border-only selected, no border unselected — the mixture of A's layout and B's outlined selected state).

## 03 · toolbar-loudness-ladder.png

**User proposed another variant** ("underline and default amber"). Added as **Option E**. Screen presents a loudness ladder — B (fill-on-selected, loudest) → D (outline, medium) → E (underline, quietest). Includes a context check strip showing each variant next to the marker lane. **Decision: E locked in** — toolbar recedes as ambient metadata while marker lane carries chip-prominence.

## 04 · sensor-line-options.png

**Sensor line candidates** — what info shows + what tap does. **A** DOOMBTS literal (status-only, controls in Settings) · **B** status + tappable DISCONNECT chip with destructive alert · **C** whole line is one toggle button (no alert). Medical-safety note: silent disconnect during a shaky-hands hypo event is a real failure mode.

## 05 · sensor-line-option-d.png

**User's refinement of B**: "can we have it only appear when you click on connected?" Sequence mockup of the connected flow (IDLE → REVEALED → ALERT) + asymmetric disconnected flow (CONNECT chip always visible since connect is non-destructive). Implementation sketch: `@State var disconnectChipVisible` + `Task.sleep(5s)` auto-hide.

## 06 · full-overview-target.png

**First full Overview assembly.** All settled decisions stacked into one mockup — hero + sensor line (D) + treatment banner slot + toolbar (E) + chart + sticky actions + annotated regions table. User response: "I have some comments for that."

## 07 · sensor-line-symmetric-vs-asymmetric.png

**Follow-up comparison requested.** Side-by-side asymmetric D (CONNECT chip always visible when disconnected) vs symmetric D (both states hide the action chip until tap). Asymmetric: 1-tap reconnect, two idle shapes. Symmetric: 2-tap reconnect, identical idle shapes. **User confirmed asymmetric.**

## 08 · full-overview-v2.png

**User's comments incorporated.** Bottom row trimmed to 2 buttons (INSULIN + MEAL, BG removed). Added top-right ⚙ menu button on the hero. Added system tab bar (Overview · Log · Digest · Settings) pinned below sticky actions.

## 09 · full-overview-v3.png

**⚙ menu button removed** — Settings is already reachable via the bottom tab bar, so a duplicate access point at the top was redundant. Final approved Overview composition. BG entry decision: moves to Log tab (the home it fits with).

---

## Captured state

Each screen was pushed to the companion (http://localhost:56570, then http://localhost:50932 after a server timeout), then captured with Playwright `browser_take_screenshot` at 1280×1000 full-page. PNG files are the durable record — the companion's HTML content is gitignored under `.superpowers/brainstorm/*/content/`.

## Outcome

Spec written at `docs/brainstorms/2026-04-23-overview-no-scroll-layout-requirements.md` capturing the six locked decisions. Next: user review → commit → `writing-plans` for PR 1 implementation plan.
