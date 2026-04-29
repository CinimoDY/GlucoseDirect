# Unified entry experience + chart markers — DMNC-848 (and the bridge)

**Issue:** [DMNC-848](https://linear.app/lizomorf/issue/DMNC-848) — chart-marker tap parity (insulin impact overlay)
**Bridges:** DMNC-715 (marker-lane visualizations), DMNC-796 (unified entry interactions), DMNC-798 (AmberChip primitive), DMNC-799 (insulin entry redesign), DMNC-800 (FoodPhotoAnalysisView decomposition), DMNC-805 (food log: tap = staging, hold = insta-log)
**Scope:** One coherent design spec for the Overview chart marker layer (visual treatment + tap parity) and the entry surfaces (food, insulin) it leads to. Replaces the bare insulin `confirmationDialog` with a unified read overlay, swaps the food/insulin entry views for a shared single-modal edit pattern, and locks the marker visual style.
**Codesign source:** `.devjournal/sessions/dmnc-848-unified-entry-2026-04-25/L2-thematic/screens/` — screens 04 through 24 walk the journey, ending at the v5 stress-test against the actual `FoodPhotoAnalysisView` plate.

---

## Context

Three threads landed at the same point and the user wanted them solved together rather than one at a time:

1. **Chart marker overlap.** Meal + insulin markers at the same timestamp visually collide — the existing `ConsolidatedMarkerGroup` consolidates within each type but doesn't handle cross-type stacking. Touch targets are also fragile when icons land within a few pixels of each other.
2. **Insulin marker tap parity (DMNC-848).** Today: tap meal marker → rich `MealImpact` overlay (delta, peak, confounders, PersonalFood avg, edit/close). Tap insulin marker → bare `confirmationDialog` with Delete + Cancel. No impact info, no edit affordance, easy to fat-finger Delete. The asymmetry has bothered the user since `MealImpact` shipped.
3. **Entry surfaces are due.** `AddInsulinView` still uses the legacy `Picker("Type", selection: $insulinType)` (124 LOC, DMNC-799 marked Done in Linear but never actually shipped). `FoodPhotoAnalysisView` is an 882-LOC God View. `AddMealView` and `AddInsulinView` are separate modals with unrelated visual languages. Logging a meal+bolus pair = two opens, two saves.

This spec packages all three so the **chart-tap → impact-card → edit** flow has consistent visual + interaction language end to end, and so the entry surfaces share primitives instead of competing.

**Out of scope (deliberately):**
- HealthKit heart-rate calibration to the glucose-100 line — design is locked but engineering is deferred. Spec ships HR as a **relative-scaled magenta dashed line** with end-of-line readout. Calibration becomes a follow-up.
- DOS / demoscene flair (text scramble, glow halos, etc.) — locked as a future polish pass, not in this spec.
- BloodGlucose entry view rework — already lives in `AddBloodGlucoseView` and is fine.
- DailyDigest, calibration, treatment-cycle UI — untouched.

---

## Locked decisions

### D1 — Marker style: bare type-coloured icons (Q5 v3)

Replace the flag-chip-with-border markers (Q2 v15 lock candidate) with **bare SF Symbol icons** on a single shared baseline below the chart:

- 🍴 `fork.knife` — meals (`AmberTheme.amber` `#FFB000`)
- 💉 `syringe.fill` — insulin (`AmberTheme.amberLight` for gold/dose, `#FFD97A`)
- 🏃 `figure.run` — exercise (`AmberTheme.cgaCyan` `#55ffff`)

No border, no chip background, no per-marker text (count or grams). All numeric data moves into the list overlay on tap. Icon size 22pt, baseline-aligned, type-coloured.

**Group consolidation rule** (cross-type, replaces today's same-type-only `ConsolidatedMarkerGroup`): markers within 4 pt of each other on the chart's x-axis collapse into a stacked-icon group with a small numeric badge for the count. Stacking order top-to-bottom = insulin → food → exercise (consistent with Q2 v15 baseline order).

**Touch target:** every marker (single or group) has an invisible 88 × 48 hit area centred on the icon, regardless of icon visual size. Min 4 pt visible gap between adjacent groups so two cluster taps never resolve the wrong group.

### D2 — Read surface: Libre-style list overlay (Q5 v3)

Single read surface for any marker tap (single or group, single-type or mixed). Replaces both today's:
- Inline `MealImpact` card on meal-marker tap
- Bare `confirmationDialog` on insulin-marker tap

**Anatomy:**

```
┌──────────────────────────────────────────┐
│  14:32 · Logged                  Edit ✎ │  ← header: shared timestamp + Edit
├──────────────────────────────────────────┤
│  🍴  Pasta carbonara              45g   │  ← entry row
│      3 items · 14:32 · +72 mg/dL  2h     │     icon · name · sub-line · value
├──────────────────────────────────────────┤
│  💉  Meal bolus                  4.5U   │
│      14:30 · 2m before meal · IOB 1.2U   │
├──────────────────────────────────────────┤
│              [   OK   ]                  │  ← single dismiss button
└──────────────────────────────────────────┘
```

- **Header:** shared timestamp (group's earliest entry, rounded to minute), single `Edit ✎` affordance top-right.
- **Body:** one row per entry. Type-coloured icon, primary name, **sub-line** showing per-entry timestamp + impact/IOB context, value (right-aligned, type-coloured).
  - Meal sub-line: `<n> items · <hh:mm> · <delta> mg/dL` (delta from `MealImpact` if available, else "computing…")
  - Insulin sub-line: `<hh:mm> · <Δ-from-meal> · IOB <units>` (Δ-from-meal only if a paired meal exists in the same group)
  - Exercise sub-line: `<hh:mm> · <duration> · <type>` (HealthKit-imported)
- **Footer:** single OK button. No Delete, no Cancel — there's nothing to commit at the read surface.
- **Row ordering:** chronological by per-entry timestamp (earliest first). Insulin given 5 min before a meal lands above the meal in the list; reflects the actual sequence of events.

Single-entry tap collapses to one row + OK — same component, no special-case UI.

### D3 — Edit route: single Edit → combined modal (Q5 v4 Option C, refined v5)

The `Edit ✎` button in the list-overlay header opens **one combined modal** with stacked sections. This modal is for **editing already-logged entries**; the new-AI-entry flow keeps using `FoodPhotoAnalysisView` from the sticky `[MEAL]` button (untouched).

```
┌──────────────────────────────────────────┐
│  Cancel       Meal + Insulin    Save     │
├──────────────────────────────────────────┤
│  🍴 FOOD                  3 items · 45g  │
│  ─────────────────────────────────────   │
│  Description: Pasta carbonara, espresso  │
│                                          │
│  • Pasta            120g · 38g C   ▸    │  ← collapsed: name + amount + carbs
│  • Bacon                    2g C   ▸    │  ← collapsed (no amount): name + carbs
│  • Parmesan                 5g C   ▸    │
│  + Add item                              │
├──────────────────────────────────────────┤
│  💉 INSULIN              meal · 4.5U    │
│  ─────────────────────────────────────   │
│  [MEAL] [SNACK] [CORR] [BASAL]           │  ← Q3 chip row
│  [−]  4.5 U  [+]                         │  ← Q3 stepper
├──────────────────────────────────────────┤
│  ⏱ TIME (shared)                         │
│  ─────────────────────────────────────   │
│  [Apr 25, 2026]  [14:30]                 │  ← compact DatePicker (date + hour)
└──────────────────────────────────────────┘
```

When the user taps a plate row, that row expands **and any other expanded row collapses**:

```
│  • Pasta            120g · 38g C   ▾    │
│    ┌─────────────────────────────────┐  │
│    │ Name    [Pasta]            [▦] │  │  ← barcode-rescan icon
│    │ Amount  [    120 ] g            │  │
│    │ Carbs   [     38 ] g            │  │
│    └─────────────────────────────────┘  │
│  • Bacon                    2g C   ▸    │
```

- **Sections** are independent and editable in place; both visible, no tabs, no reveal.
- **Shared TIME** at the bottom — meal and bolus paired in a group share a single timestamp. If the user wants to detach (rare), the Edit screen for a single-entry tap still uses this layout but TIME edits only the visible entry.
- **Time control: compact `DatePicker`** (`displayedComponents: [.date, .hourAndMinute]`). Chart-marker Edit is most often retroactive ("fix that meal I logged earlier") — chip-row presets don't reach. The standalone `AddInsulinView` (sticky-action path) still uses Q3 chip row + `⋯` for new entries.
- **Plate-row accordion (Q-D lock):** at most one item expanded at a time. Tapping a second row collapses the first. Today's `FoodPhotoAnalysisView` allows multiple rows expanded simultaneously inside a scrolling `Form` — the combined modal trades that for no-scroll.
- **Collapsed-row summary (Q-D refinement):** `<name>  <amountG>g · <carbsG>g C` when `currentAmountG != nil`, else `<name>  <carbsG>g C`. So users keep an overview at a glance even when only one row is expanded.
- **No portion picker** in the combined modal (Q-C lock). The picker is barcode-creation chrome that bakes the multiplier into `currentAmountG` at log time. Editing operates on the resulting grams. Picker stays in `FoodPhotoAnalysisView` for new-AI-entry only.
- **No AI Clarify, Confidence indicator, or AI disclaimer** (Q-E lock). The combined modal opens against an existing logged entry — no re-analysis happens. These remain in `FoodPhotoAnalysisView`.
- **Save semantics:** one Save commits all dirty sections in a single store dispatch. If only one section is dirty, only that entry is updated.
- **No-scroll constraint:** the modal as a whole does not scroll at default Dynamic Type with 5 plate items + one expanded + bolus chip row + stepper + DatePicker. Plate row count cap = 5 visible; 6+ scrolls inside the plate only. Verified at densities A (all collapsed) and B (one expanded).
- **Empty companion:** if the tapped marker is insulin-only, the FOOD section shows a `+ add meal` placeholder row instead of the plate. Symmetric for meal-only.

This is **Option C** from Q5 v4 — beat out Tabs (B, save semantics fragile across two drafts) and Primary+Reveal (D, engineering scope blew past milestone). v5 adds the staging-plate audit refinements (compact DatePicker, accordion, summary collapsed rows, no portion picker, no AI chrome).

### D4 — Insulin entry primitives (Q3)

The combined modal's INSULIN section uses three new primitives that also become the standalone `AddInsulinView` (when entered from the sticky action button):

**`AmberChip`** — a single-tap chip. Variants:
- `.type` (segmented): MEAL / SNACK / CORR / BASAL — selection state with type colour
- `.preset` (single-tap): NOW / −15m / −30m / −1h / ⋯ — last is "custom time"

Visual: 1 pt amber border, 28 pt min height, monospace label, sharp corners. Selected state fills with type colour at 8% opacity, border + label at 100%. SF Symbol prefix optional.

**`StepperField`** — `[−] value [+]` numeric stepper with tap-to-type. Visual: gold (`amberLight` `#FFD97A`) buttons (22 × 22 pt), monospace value, 0.5 U step, range 0–50 U. Tapping the value opens the numeric keypad.

**`QuickTimeChips`** — chip row of `AmberChip(.preset)`. The `⋯` chip opens the native compact `DatePicker` in a popover.

These three primitives also retire the legacy `Picker("Type", selection: $insulinType)` in `AddInsulinView`.

### D5 — Food entry primitives (Q4 + DMNC-805)

The combined modal's FOOD section reuses the **plate-row pattern** from `FoodPhotoAnalysisView` (882 LOC, scheduled for decomposition under DMNC-800). The audit (Q5 v5) confirmed plate rows are richer than first assumed:

**Per-item full edit affordances (Q-B lock):**

- **Collapsed row:** name + summary (`<amountG>g · <carbsG>g C` when amount available, else `<carbsG>g C`) + chevron. Tap to expand.
- **Expanded row** (one at a time, accordion per D3):
  - **Name** TextField + **barcode-rescan** icon (NavigationLink → `ItemBarcodeScannerView`, replaces the item's data on success while preserving its `id` so SwiftUI doesn't re-render the whole list)
  - **Amount** field in grams (only present when `currentAmountG != nil` — i.e., a parseable serving size exists)
  - **Carbs** field in grams. When `carbsPerG` (auto-scale ratio) is non-nil and `currentAmountG` changes, carbs auto-scale proportionally. Manual edit of carbs that breaks the ratio link sets `carbsPerG = nil` and shows a `manual` indicator in the row. Auto-scale clamps amount to ≤ 10000 g to avoid overflow.
- **Swipe to delete** on any row.
- **`+ Add item`** row at the bottom (creates an empty `EditableFoodItem` and auto-expands it).
- **Cap:** 5 visible items in the combined modal; 6+ scrolls inside the plate only (never the modal as a whole).

**Description field (Q-D refinement):** the combined modal carries the meal-level Description TextField from today's plate, sitting between the FOOD section header and the row list. It's a free-form caption ("Pasta carbonara, espresso") — independent of item names.

**Sections that DO NOT live in the combined modal** (per Q-C, Q-E):

- Portion picker (barcode preset chips + custom multiplier) — stays in `FoodPhotoAnalysisView` only
- AI Clarify (multi-turn follow-up) — stays in `FoodPhotoAnalysisView` only
- Confidence indicator — stays in `FoodPhotoAnalysisView` only
- AI safety disclaimer — stays in `FoodPhotoAnalysisView` only

**Sticky `[MEAL]` action button** path is unchanged: opens `FoodPhotoAnalysisView` (or `UnifiedFoodEntryView`) with the full AI flow + portion picker + Clarify + Confidence + disclaimer. The combined modal is reached only via chart-marker tap → list overlay → Edit, and operates on already-logged entries.

**Multi-source population** (creation paths, all in `FoodPhotoAnalysisView`, untouched): AI photo analysis, NL text query, barcode (Open Food Facts), favourites.

**DMNC-805 reaffirmed:** **tap a favourite = direct log** (today's speed kept). **Long-press a favourite = open in staging plate** for edit before commit. Direct log path skips both the analysis modal and the combined modal entirely.

**Shared row component:** the plate-row view (collapsed summary + expanded edit fields) is extracted into a reusable component (`StagingPlateRowView`) used by both `FoodPhotoAnalysisView` (full plate) and `CombinedEntryEditView` (subset plate). This is the only piece of plate code shared across the two surfaces — the wrapping `Form` / `VStack`, section ordering, and conditional sections differ.

### D6 — HR overlay (Q2 v14, simplified)

Single dashed magenta line on the glucose chart. End-of-line numeric readout in magenta. **No separate y-axis.** v1 ships with relative scaling (HR mapped into the chart's vertical extent proportionally to the user's resting-rate-aware range). The intended "HR-resting calibrated to glucose 100" treatment is locked as a follow-up — too much engineering for this milestone.

Toggle: `showHeartRateOverlay` — default off. Settings live alongside the existing `HealthKit` integration toggle.

### D7 — Strict-separation customisation (Q2b v3)

Opt-in chart customisation: **markers always at the very top OR very bottom** of the chart stack, never sandwiching the IOB lane. Cluster rule: a marker group never appears between the chart and the IOB lane.

Setting: `markerLanePosition` (`.bottom` default | `.top`). Lives in chart-customisation settings, alongside report-type defaults.

### D8 — Insulin marker delete moves into Edit (DMNC-848 closeout)

Today's `confirmationDialog` with Delete-only on insulin tap goes away. Delete affordances live in the Edit surfaces only:

- **Combined modal (`CombinedEntryEditView`):** each section's primary row supports swipe-to-delete. Swiping clears that section to its `+ add ...` placeholder; Save commits the deletion as a `.deleteMealEntry` / `.deleteInsulinDelivery` dispatch.
- **Standalone `AddInsulinView` (sticky-action entry path):** a small destructive Delete button sits below the Save area, requiring a confirmation tap. Used when editing an existing dose without a paired meal.

The read surface (list overlay) stays destruction-free. Delete always requires entering Edit first — fixes today's fat-finger risk.

---

## Architecture

### New Swift types (Library/Content)

- `EntryGroup` — value type wrapping a list of `MarkerEntry` items at the same `timegroup`. Replaces today's separate `ConsolidatedMealMarkerGroup` / `ConsolidatedInsulinMarkerGroup` with a cross-type model.
- `MarkerEntry` — protocol or sum type covering Meal, Insulin, Exercise. Each conforms to a minimal `markerIcon`, `markerColor`, `markerSubline()`, `markerValue()` API.
- `EntryGroupOverlayState` — observable state for the list-overlay sheet (group, dismissal, edit handoff).
- `InsulinImpact` — view-layer computed type (no GRDB persistence). Mirrors `MealImpact`'s shape but computed on tap from existing `iobDeliveries` + `SensorGlucose`. Fields: `dose`, `glucoseAtDose`, `glucoseAtPeak`, `peakOffsetMinutes`, `iobAtDose`, `confounders: [InsulinConfounder]`.

### New SwiftUI views (App/Views/Overview)

- `MarkerLaneView` — replaces today's in-chart marker annotations. Owns the cross-type consolidation, hit testing, and group-tap delegation.
- `EntryGroupListOverlay` — the Libre-style list read surface (D2). Sheet-presented from the chart.
- `CombinedEntryEditView` — the stacked-sections combined modal (D3). Owns FOOD section, INSULIN section, shared TIME section. Cancel + Save in nav bar.

### New SwiftUI views (App/Views/AddViews + DesignSystem)

- `AmberChip` (Library/DesignSystem/Components — both targets) — chip primitive (D4).
- `StepperField` (App/DesignSystem/Components) — numeric stepper (D4).
- `QuickTimeChips` (App/DesignSystem/Components) — chip row + custom-time popover (D4).
- `StagingPlateRowView` (App/Views/AddViews/Components) — collapsed-summary + expanded-edit row used by both `FoodPhotoAnalysisView` and `CombinedEntryEditView` (D5). Owns its own expand/collapse state, name + amount + carbs fields, ratio-link auto-scaling, manual-override indicator, barcode-rescan affordance, and swipe-to-delete plumbing.

### Modified views

- `ChartView.swift` (currently 1855 LOC) — drops in-chart marker annotations, drops `tappedInsulinEntry` confirmDialog, drops `activeMealOverlay` inline card. Marker layer delegates to `MarkerLaneView`. Tap delegates to `EntryGroupListOverlay`. Edit delegates to `CombinedEntryEditView`. Estimated −150 LOC.
- `AddInsulinView.swift` (currently 124 LOC) — rewritten to use `AmberChip` + `StepperField` + `QuickTimeChips`. Estimated −20 LOC. Standalone path (sticky action button) only — chart-tap edits route through `CombinedEntryEditView`.
- `FoodPhotoAnalysisView.swift` (currently 882 LOC) — extracts only the per-item plate row into the reusable `StagingPlateRowView`. Section structure (nutrition banner, portion picker, description, items list, clarify, confidence, disclaimer, log) stays as-is. Estimated −80 LOC for the row extraction. Full decomposition into separate analysis / picker / item-list views remains DMNC-800's job.

### Data flow

1. User taps chart marker → `MarkerLaneView` resolves the hit to an `EntryGroup`.
2. `EntryGroup` published → `EntryGroupListOverlay` presented as sheet.
3. User taps `Edit ✎` → sheet dismisses, `CombinedEntryEditView` presents (per CLAUDE.md "no nested sheets" rule, this is a sequential sheet swap via `pendingSheet` + `onDismiss`, **not** a nested presentation).
4. User edits, taps Save → modal computes the diff against the original `EntryGroup` and dispatches one or more of `.updateMealEntry`, `.updateInsulinDelivery`, `.deleteMealEntry`, `.deleteInsulinDelivery` in sequence.
5. Reducer + middleware fan-out (existing) updates GRDB and triggers `MealImpact` recomputation.

### Sheet presentation

Reuses Overview's existing `ActiveSheet` enum pattern (CLAUDE.md). Two new cases:
- `.entryGroupReadOverlay(EntryGroup)` — list overlay sheet
- `.combinedEntryEdit(EntryGroup)` — edit modal

Edit-from-overlay = `pendingSheet = .combinedEntryEdit(group); dismiss()` then present in the existing `onDismiss` chain.

---

## Per-entry-point routing

| Entry point | Today's view | New routing |
|---|---|---|
| Chart marker tap (single, meal) | `activeMealOverlay` inline card | `EntryGroupListOverlay` (1 row + OK) |
| Chart marker tap (single, insulin) | `confirmationDialog` Delete-only | `EntryGroupListOverlay` (1 row + OK) |
| Chart marker tap (group, same-type) | Inline detail sheet | `EntryGroupListOverlay` (N rows + OK) |
| Chart marker tap (group, cross-type) | (today: visually colliding markers) | `EntryGroupListOverlay` (N rows + OK) |
| List-overlay → Edit | n/a | `CombinedEntryEditView` |
| Sticky `[INSULIN]` action button | `AddInsulinView` (Picker) | `AddInsulinView` (Q3 chip + stepper + chips) |
| Sticky `[MEAL]` action button | `AddMealView` / `UnifiedFoodEntryView` / `FoodPhotoAnalysisView` | unchanged section structure; per-item rows replaced with extracted `StagingPlateRowView` (D5) |
| Favourite tap | direct log (DMNC-805) | unchanged direct log |
| Favourite long-press | n/a | open in staging plate (DMNC-805) |

---

## Theming + accessibility

- All colours from `AmberTheme` — no new hex literals.
- All typography from `DOSTypography` — `bodySmall` for sub-lines, `body` for primary names, `displayMedium` for delta values.
- VoiceOver labels for every entry row include type, name, value, and time (e.g., "Meal, pasta carbonara, 45 grams, 14:32, impact plus 72").
- **Dynamic Type policy:** default size fits no-scroll on iPhone 17 Pro at 5 staging-plate items (success criterion #4). `xLarge` should still fit; sizes ≥ `xxxLarge` are permitted to scroll the modal as a whole. Verified manually on iPhone SE + Dynamic Type slider before PR ship.
- `AmberChip` selected-state contrast verified at all type colours against `#000` background.
- 44 pt minimum touch target on every interactive element (88 × 48 is the marker target).

---

## Migration

No GRDB migrations. `MealImpact` schema unchanged. `InsulinImpact` is view-layer-only.

`AddInsulinView` rewrite is a pure UI change — the dispatched action (`.addInsulinDelivery(starts, ends, units, type)`) is unchanged, so middleware + persistence are untouched.

---

## Success criteria

The spec is ready for `writing-plans` when all of:

1. Every chart marker tap (single, group, cross-type) lands on the same read surface (D2).
2. The list overlay shows correct sub-lines for meal, insulin, and exercise rows; impact / IOB / exercise data sourced from the right places.
3. Edit from any list-overlay row opens the **same** `CombinedEntryEditView` with the corresponding section pre-focused.
4. The combined modal does not vertically scroll on iPhone 17 Pro at default Dynamic Type with description + 5 plate items (one expanded) + bolus chip row + stepper + compact DatePicker.
5. `AddInsulinView` (standalone path) uses `AmberChip` + `StepperField` + `QuickTimeChips` — no `Picker` remains. Note: combined modal's TIME control is a compact DatePicker, not chip row, by design (Q-A lock).
6. Combined modal's plate uses accordion behaviour — at most one row expanded at a time. Tapping a second row collapses the first.
7. Collapsed plate rows show summary text (`<name>  <amountG>g · <carbsG>g C` when amount available, else `<name>  <carbsG>g C`).
8. Combined modal omits portion picker, AI Clarify, Confidence indicator, and AI disclaimer — those remain in `FoodPhotoAnalysisView` only.
9. Favourite tap still 1-tap-logs (no regression of DMNC-805); long-press opens the staging plate.
10. Marker layer renders single icons, group icons with badge, and cross-type stacks correctly. Touch target 88 × 48 confirmed.
11. HR overlay toggle on/off; line + end-of-line readout render at relative scale.
12. Strict-separation toggle moves marker lane top↔bottom; IOB never sandwiched.
13. VoiceOver readout for every list-overlay row is meaningful and complete.

---

## Plan decomposition note

This spec covers the unified marker → read overlay → edit flow as one coherent story (D1, D2, D3, D4, D5, D8) plus two orthogonal chart-layer enhancements (D6 HR overlay, D7 strict-separation customisation). `writing-plans` should evaluate whether to ship as:

- **One plan, one PR** — full sweep, larger review surface but single coordinated change
- **One plan, multiple PRs** — core unified-entry PR (D1, D2, D3, D4, D5, D8) + HR PR (D6) + customisation-toggle PR (D7); core can land first and the others stack independently

The locked decisions don't depend on each other across the D6/D7 boundary — splitting is safe. Recommend the multi-PR route to keep review pressure manageable; the core flow is already a meaningful change in isolation.

---

## Out-of-scope follow-ups (suggested Linear issues)

- **HR-resting calibrated to glucose-100 line** — full calibration pass with documented anchor.
- **DMNC-800** — `FoodPhotoAnalysisView` decomposition. This spec uses but does not require the decomposition; deferral acceptable.
- **DOS / demoscene effects** on the read overlay (text scramble, phosphor halo, scan flicker) — locked as future polish.
- **BloodGlucose** marker tap parity — out of scope (no impact card concept yet); revisit when calibration UX is reworked.
- **Combined edit modal — multiple meals or multiple bolus doses** at the same group — current spec assumes 1 meal + 1 bolus per group. If a group contains 2+ of the same type, the FOOD or INSULIN section shows the union but Save semantics need extension. Revisit if real-world data shows this is common.

---

## Session artifacts

- Brainstorm session dir: `.superpowers/brainstorm/35252-1777068283/content/`
- Companion URL (during the session): http://localhost:54128
- Key screens (saved to `.devjournal/sessions/dmnc-848-unified-entry-2026-04-25/L2-thematic/screens/`):
  - `15-q2-v15-final-lock.png` — initial flag-chip marker treatment (superseded by D1)
  - `16-q3-insulin-entry.png` — D4 chip + stepper + chips
  - `18-q2b-v2-iob-lane-bottom.png` — D7 strict-separation reference
  - `19-q4-food-entry-hybrid.png` — D5 tap/hold logging
  - `20-q5-chart-marker-tap-parity.png` — original DMNC-848 InsulinImpact overlay (superseded by D2)
  - `22-q5-v3-libre-list-overlay.png` — D1 + D2 lock
  - `23-q5-v4-final-edit-modal.png` — D3 lock (Option C)
  - `24-q5-v5-staging-plate-stress-test.png` — D3 + D5 refinements (compact DatePicker, accordion, summary collapsed rows, no portion picker / AI chrome in combined modal)
