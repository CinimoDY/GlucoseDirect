---
title: "feat: Insulin-on-Board (IOB) decay model with stacking warnings"
type: feat
status: active
date: 2026-04-17
origin: docs/brainstorms/2026-04-17-iob-decay-model-requirements.md
---

# feat: Insulin-on-Board (IOB) decay model with stacking warnings

## Overview

Add IOB tracking to DOSBTS using the OpenAPS oref0 exponential decay model. IOB is computed on-demand from stored insulin deliveries, displayed on the hero screen and chart, and warns about insulin stacking when adding correction boluses. Presets for bolus insulin type (rapid-acting vs ultra-rapid) replace raw DIA configuration.

## Problem Frame

DOSBTS tracks insulin deliveries but has no concept of active insulin over time. Without IOB, correction boluses get stacked on still-active insulin (risking hypoglycemia), dosing decisions lack critical context, and the treatment workflow can't factor in active insulin. IOB is the highest-leverage addition — it makes the hero display, chart, stacking decisions, and future features all smarter. (see origin: `docs/brainstorms/2026-04-17-iob-decay-model-requirements.md`)

## Requirements Trace

- R1. Exponential decay curve (oref0 Maksimovic formula, peak ~60-90 min)
- R2. Bolus insulin presets (rapid-acting: peak 75m/DIA 6h, ultra-rapid: peak 55m/DIA 6h) + separate basal DIA (default 6h, range 2-24h, step 30min)
- R3. Include ALL insulin types: meal, snack, correction bolus, and basal
- R4. IOB computed on-read from delivery timestamps + current time (always fresh)
- R4a. Separate DIA-window query for IOB deliveries (independent of day-scoped insulinDeliveryValues)
- R5. IOB on hero: beside unit label normally, separate row below warning when warning active, below "No Data" when sensor disconnected, own row below "HIGH" when glucose is high
- R6. Split display toggle: total IOB vs meal/snack + correction/basal breakdown
- R7. Hide IOB when < 0.05U (practical zero threshold for exponential tail)
- R8. IOB decay curve on chart as filled AreaMark, iOS 16+ only
- R9. Split chart: two colored areas when split toggle enabled
- R10. Chart IOB shares time window with glucose (scrolls together)
- R11. Stacking warning: inline in AddInsulinView when correctionBolus selected and IOB > 0, reactive to picker
- R12. Warning is informational only, no blocking
- R13. IOB passed to AddInsulinView as `currentIOB: Double?` parameter (static at open time, V1 limitation)
- R14. IOB displayed on TreatmentBannerView during active treatment cycle

## Scope Boundaries

- No dose calculator or dose suggestions
- No IOB notifications or alarms
- No pump integration — manual logging only
- iOS 15: no IOB chart visualization (hero display only)
- Stacking warning for correction bolus only in V1
- Widget/Live Activity IOB display explicitly deferred to V2
- HealthKit IOB export deferred to V2
- No deep treatment workflow integration beyond banner display

### Deferred to Separate Tasks

- Widget IOB display: future iteration
- Treatment workflow IOB-aware alarm logic: future iteration
- AI food analysis IOB integration: future iteration

## Context & Research

### Relevant Code and Patterns

- `Library/Content/InsulinDelivery.swift` — Model with `starts`, `ends`, `units`, `type` (mealBolus/snackBolus/correctionBolus/basal), `timegroup`
- `App/Modules/DataStore/InsulinDeliveryStore.swift` — GRDB middleware, `getInsulinDeliveryValues(selectedDate:)` queries by day or last 24h
- `App/Modules/GlucoseNotification/GlucoseNotification.swift` — Pattern for computing derived values on `.addSensorGlucose`
- `App/Views/Overview/GlucoseView.swift` — Hero layout with conditional warning/unit-label slot
- `App/Views/Overview/ChartView.swift` — `@available(iOS 16.0, *)`, existing insulin series + prediction line overlay
- `App/Views/AddViews/AddInsulinView.swift` — Callback-only contract, `@State var insulinType: InsulinType = .snackBolus`
- `App/Views/Overview/TreatmentBannerView.swift` — 4-state banner between hero and chart
- `App/Views/Settings/AlarmSettingsView.swift` — Settings UI patterns (Toggle, Picker, Binding)
- `DOSBTSTests/DirectReducerTests.swift` — Swift Testing framework, `makeState()` + `reduce()` helpers

### Institutional Learnings

- **appState guard pattern** — IOB data loading middleware must handle `.setAppState(.active)` and guard `state.appState == .active` (see `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`)
- **Reducer-first execution** — Never guard on state that a prior dispatch just changed; reducer runs before middlewares (see `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`)
- **GRDB Future nil dbQueue** — Every early-exit path in a Future closure must call `promise(...)` or the Combine chain hangs (see `docs/solutions/logic-errors/grdb-future-nil-dbqueue-hangs-subscriber-20260318.md`)
- **ActiveSheet enum** — Any new IOB-related sheets must use OverviewView's consolidated `ActiveSheet` pattern (see `docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`)

### External References

- OpenAPS oref0 exponential formula: [oref0/lib/iob/calculate.js](https://github.com/openaps/oref0/blob/master/lib/iob/calculate.js)
- LoopKit ExponentialInsulinModel: [LoopKit/InsulinKit/ExponentialInsulinModel.swift](https://github.com/LoopKit/LoopKit/blob/main/LoopKit/InsulinKit/ExponentialInsulinModel.swift)
- Original derivation by Dragan Maksimovic: [Loop#388](https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473)
- LoopKit basal segmentation: [LoopKit/InsulinKit/InsulinMath.swift](https://github.com/LoopKit/LoopKit/blob/main/LoopKit/InsulinKit/InsulinMath.swift)

## Key Technical Decisions

- **oref0 exponential model (Maksimovic formula)**: Industry consensus, used by Loop + OpenAPS + all major forks. Parametric (peak time + DIA), closed-form solution, no numerical integration needed for boluses
- **Insulin presets over raw DIA**: Rapid-acting (Humalog/NovoRapid, peak 75min, DIA 6h) and Ultra-rapid (Fiasp/Lyumjev, peak 55min, DIA 6h). Simpler UX, medically appropriate, matches LoopKit presets
- **6-hour DIA default**: Loop's evidence-based approach. Old 3-4h DIA was a major source of stacking incidents. User can lower in settings (min 2h)
- **No discrete onset delay**: The Maksimovic exponential formula naturally models slow onset via curve shape (IOB at t=0 is 1.0, decaying from there). No separate onset parameter needed — matches oref0 reference implementation
- **Compute on-read, not cached in Redux state**: IOB = pure function of (deliveries, current time, model params). Fresh on every access. Only the delivery list and settings are stored in state
- **Separate IOB middleware**: Own middleware for DIA-window queries, separate from day-scoped `insulinDeliveryStoreMiddleware`. Clean separation of concerns
- **Basal: continuous infusion model**: Segment basal entries into 5-min chunks, each decayed independently (Loop pattern). More accurate than midpoint-bolus for multi-hour entries
- **Zero threshold: 0.05U**: Below this, IOB displays as zero and is hidden. Prevents exponential tail noise
- **Static IOB in AddInsulinView**: Pass `currentIOB: Double?` at sheet-open time. Accept V1 staleness (sheets are typically open for seconds). Avoids breaking the callback-only contract
- **Chart colors**: Total IOB: `AmberTheme.cgaCyan` (0.3 opacity). Split: meal/snack `AmberTheme.cgaCyan`, correction/basal `AmberTheme.amberDark` (both 0.3 opacity). Avoids collision with glucose colors (amber/red/green) and heart rate overlay (cgaMagenta)

## Open Questions

### Resolved During Planning

- **Decay formula**: oref0 exponential (Maksimovic). Industry standard with parametric flexibility
- **Basal decay model**: Continuous infusion with 5-min segmentation (Loop pattern)
- **IOB computation location**: Pure function called from views/middleware; delivery list loaded by separate middleware
- **iOS 15 chart fallback**: No chart IOB on iOS 15; hero display is sufficient
- **Chart colors**: cgaCyan for total/meal, cgaMagenta for correction/basal
- **DIA settings control**: Picker with .menu style for bolus preset; Stepper for basal DIA (matching existing settings patterns)
- **"HIGH" glucose IOB placement**: IOB on own row below "HIGH", consistent with warning-active fallback
- **IOB after add/delete**: Reload immediately on `.addInsulinDelivery` and `.deleteInsulinDelivery`, not just on sensor readings
- **DIA change with active IOB**: Silently recompute (natural consequence of compute-on-read). Settings footnote explains retroactive effect

### Deferred to Implementation

- Exact visual weight/font size of IOB on treatment banner second line

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
Data Flow:

  GRDB (InsulinDelivery table)
       |
       v
  IOBMiddleware  ──listens──>  .addSensorGlucose
       |                       .addInsulinDelivery
       |                       .deleteInsulinDelivery
       |                       .setAppState(.active)
       |
       v
  Query: deliveries where starts > (now - maxDIA)
       |
       v
  .setIOBDeliveries([InsulinDelivery])  ──reducer──>  state.iobDeliveries
       
  
  IOB Computation (pure function, called on-read):
  
  computeIOB(deliveries, bolusModel, basalModel, at: Date()) -> IOBResult
       |
       +── For each bolus: units * model.percentEffectRemaining(elapsed)
       +── For each basal: segment into 5-min chunks, sum decay per chunk
       |
       v
  IOBResult { total: Double, mealSnack: Double, correctionBasal: Double }


  View Layer:

  GlucoseView reads state.iobDeliveries
       |
       v
  computeIOB(...) on each render
       |
       v
  Display: "mg/dL · IOB 2.4U" or split or hidden
```

## Implementation Units

- [x] **Unit 1: IOB Calculation Engine**

**Goal:** Create the core exponential decay model and IOB computation functions as pure, testable code.

**Requirements:** R1, R3, R7

**Dependencies:** None

**Files:**
- Create: `Library/Content/IOBCalculator.swift`
- Test: `DOSBTSTests/IOBCalculatorTests.swift`
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- `ExponentialInsulinModel` struct with precomputed `tau`, `a`, `S` constants from DIA and peak time
- `percentEffectRemaining(at:)` method implementing Maksimovic formula (no discrete onset delay — the formula naturally ramps up slowly via the exponential curve shape; IOB at t=0 is 1.0 by definition)
- `InsulinPreset` enum: `.rapidActing` (peak 75m, DIA 6h), `.ultraRapid` (peak 55m, DIA 6h). Must conform to `Codable` and `CaseIterable` (UserDefaults persistence + Picker iteration)
- `computeIOB(deliveries:bolusModel:basalModel:at:)` function returning `IOBResult` struct with `total`, `mealSnackIOB`, `correctionBasalIOB`
- Bolus entries (`type != .basal`): simple `units * percentEffectRemaining(elapsed)`. Use the `type` field as discriminator, not `starts == ends` comparison
- Basal entries (`type == .basal`): segment into 5-min chunks, each chunk's dose = `units * chunkDuration / totalDuration`, sum decay per chunk. Guard against zero-duration basal entries (treat as bolus)
- IOB < 0.05U treated as zero

**Patterns to follow:**
- Pure functions in `Library/Content/` following `SensorGlucose.swift` pattern (model + extensions)
- `InsulinDelivery.swift` for the insulin type enum usage

**Test scenarios:**
- Happy path: 1U bolus at t=0, IOB should be 1.0U (full dose, no insulin absorbed yet)
- Happy path: 1U bolus at t=DIA (6h), IOB should be 0.0
- Happy path: 1U bolus at t=DIA/2 (~3h), IOB should be roughly 0.3-0.5U (exponential midpoint)
- Edge case: IOB below 0.05U threshold returns 0.0
- Edge case: Empty delivery list returns IOBResult with all zeros
- Edge case: Delivery with `starts` in the future returns full dose as IOB
- Happy path: Basal entry (2U over 2 hours) decays correctly via segmented integration
- Happy path: Split IOB correctly separates meal+snack from correction+basal
- Integration: Multiple overlapping boluses sum IOB correctly
- Edge case: Rapid-acting vs ultra-rapid presets produce different IOB at same elapsed time (faster decay for ultra-rapid)

**Verification:**
- All test scenarios pass
- IOB for a 1U rapid-acting bolus at DIA (6h) is effectively zero
- Split IOB components sum to total IOB

---

- [x] **Unit 2: State, Actions, and Reducer**

**Goal:** Add IOB-related state properties, actions, and reducer cases following the established 4-file/3-file patterns.

**Requirements:** R2, R4a, R6

**Dependencies:** Unit 1 (InsulinPreset enum)

**Files:**
- Modify: `Library/DirectState.swift`
- Modify: `Library/DirectAction.swift`
- Modify: `Library/DirectReducer.swift`
- Modify: `App/AppState.swift`
- Modify: `Library/Extensions/UserDefaults.swift`
- Test: `DOSBTSTests/DirectReducerTests.swift`

**Approach:**
- **UserDefaults-backed settings (4-file pattern):**
  - `bolusInsulinPreset: InsulinPreset` (default `.rapidActing`)
  - `basalDIAMinutes: Int` (default 360 = 6 hours, range 120-1440, step 30)
  - `showSplitIOB: Bool` (default `false`)
- **GRDB-backed computed data (3-file pattern, no UserDefaults):**
  - `iobDeliveries: [InsulinDelivery]` (DIA-window filtered, loaded by middleware)
- **Actions:**
  - `.setBolusInsulinPreset(preset: InsulinPreset)`
  - `.setBasalDIAMinutes(minutes: Int)`
  - `.setShowSplitIOB(enabled: Bool)`
  - `.setIOBDeliveries(deliveries: [InsulinDelivery])`
  - `.loadIOBDeliveries`

**Patterns to follow:**
- `showPredictiveLowAlarm` for UserDefaults-backed Bool toggle
- `hypoTreatmentWaitMinutes` for UserDefaults-backed Int setting
- `insulinDeliveryValues` for GRDB-backed array (3-file, no UserDefaults)

**Test scenarios:**
- Happy path: `.setBolusInsulinPreset(.ultraRapid)` updates state correctly
- Happy path: `.setBasalDIAMinutes(240)` updates state correctly
- Happy path: `.setShowSplitIOB(enabled: true)` toggles flag
- Happy path: `.setIOBDeliveries` sets the array
- Edge case: `.setBasalDIAMinutes` with out-of-range value (reducer should clamp or the UI should prevent)

**Verification:**
- All new state properties have matching actions, reducer cases, and persistence
- Settings survive app restart (UserDefaults round-trip)
- `iobDeliveries` does NOT persist to UserDefaults (transient, loaded from GRDB)

---

- [x] **Unit 3: IOB Data Loading Middleware**

**Goal:** Create a middleware that loads DIA-window insulin deliveries from GRDB on relevant triggers.

**Requirements:** R4, R4a

**Dependencies:** Unit 2 (state properties and actions)

**Files:**
- Create: `App/Modules/IOB/IOBMiddleware.swift`
- Modify: `App/Modules/DataStore/InsulinDeliveryStore.swift` (add DIA-window query method)
- Modify: `App/App.swift` (register middleware in BOTH arrays)
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- Add `getIOBDeliveries(diaMinutes:)` method to `InsulinDeliveryStore` — queries deliveries where `starts > now - diaMinutes`. DIA window size = max(bolusInsulinPreset.DIA, basalDIAMinutes) to capture all potentially active deliveries. CRITICAL: the new Future MUST include an `else` branch calling `promise(.success([]))` when `dbQueue` is nil — do NOT copy the existing `getInsulinDeliveryValues` pattern which has the nil-dbQueue hang bug
- IOBMiddleware must be registered AFTER `insulinDeliveryStoreMiddleware` in both App.swift middleware arrays, since it depends on the InsulinDelivery table being created on `.startup`
- `iobMiddleware` handles:
  - `.addSensorGlucose` → dispatch `.loadIOBDeliveries`
  - `.addInsulinDelivery` → dispatch `.loadIOBDeliveries` (immediate refresh)
  - `.deleteInsulinDelivery` → dispatch `.loadIOBDeliveries` (immediate refresh)
  - `.setAppState(.active)` → dispatch `.loadIOBDeliveries` (initial load, with `.active` guard)
  - `.loadIOBDeliveries` → query GRDB, dispatch `.setIOBDeliveries`
  - `.setBolusInsulinPreset` / `.setBasalDIAMinutes` → dispatch `.loadIOBDeliveries` (DIA window changed)
- Follow `insulinDeliveryStoreMiddleware` pattern for GRDB query + Combine publisher
- Guard `state.appState == .active` on `.loadIOBDeliveries` (institutional learning)
- Every Future early-exit must call `promise(...)` (institutional learning)

**Patterns to follow:**
- `insulinDeliveryStoreMiddleware` in `InsulinDeliveryStore.swift` for GRDB query pattern
- `treatmentCycleMiddleware` for cross-middleware listening on `.addSensorGlucose`
- Both middleware arrays in `App.swift` (lines ~194 and ~242)

**Test scenarios:**
Test expectation: none — middleware has side effects (GRDB queries). IOB computation is tested in Unit 1. Middleware wiring is verified through integration (Unit 9 verification).

**Verification:**
- IOB deliveries load on app launch
- Adding insulin immediately updates `iobDeliveries`
- Deleting insulin immediately updates `iobDeliveries`
- Changing DIA settings reloads with new window size

---

- [x] **Unit 4: Hero Display**

**Goal:** Show IOB on the hero glucose screen in all layout states.

**Requirements:** R5, R6, R7

**Dependencies:** Unit 1 (computeIOB), Unit 2 (state properties)

**Files:**
- Modify: `App/Views/Overview/GlucoseView.swift`

**Approach:**
- Compute IOB from `store.state.iobDeliveries` using `computeIOB()`. Cache result in `@State` and recompute via `.onChange(of: store.state.iobDeliveries)` and a 60-second timer (prevents staleness during sensor disconnection when no `.addSensorGlucose` triggers re-render)
- Build bolus model from `store.state.bolusInsulinPreset`, basal model from `store.state.basalDIAMinutes`
- **Single insertion point**: Add one unconditional IOB row after the `if let warning / else { unitLabel }` block. This row renders in ALL states (normal, warning, HIGH, No Data) — no per-state conditional layout needed. The row is simply hidden when IOB < 0.05U
- Total display: `"IOB 2.4U"`
- Split display: `"IOB 1.8M · 0.6B"` (abbreviated to fit small screens — M=meal/snack, B=basal+corr)
- Hide entirely when total IOB < 0.05U (R7)
- Use `DOSTypography.caption` and `AmberTheme.amber` at 0.5 opacity (matching unit label style)

**Patterns to follow:**
- Stale data indicator in `GlucoseView.swift` (conditional row below glucose)
- Unit label opacity and font styling

**Test scenarios:**
Test expectation: none — pure UI rendering. IOB computation tested in Unit 1. Visual verification in simulator.

**Verification:**
- IOB visible beside unit label when glucose is normal and IOB > 0
- IOB appears below warning banner when sensor disconnected
- IOB appears below "No Data" when sensor has no reading
- IOB appears below "HIGH" text
- IOB hidden when < 0.05U
- Split display shows meal/correction breakdown when toggle enabled

---

- [x] **Unit 5: Chart Visualization**

**Goal:** Add IOB decay curve as a filled area on the chart with split display support.

**Requirements:** R8, R9, R10

**Dependencies:** Unit 1 (computeIOB), Unit 2 (state properties), Unit 3 (iobDeliveries loaded)

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

**Approach:**
- iOS 16+ only (inside existing `@available(iOS 16.0, *)` guard)
- Generate IOB time series: for each 5-min interval in the chart time window, compute IOB at that point
- `AreaMark` with `y` mapped to a secondary range below the glucose line (similar to how insulin series maps to `0...alarmLow`)
- Total IOB: single `AreaMark` in `cgaCyan` at 0.3 opacity
- Split mode: two `AreaMark` series — `cgaCyan` for meal/snack IOB, `amberDark` for correction/basal IOB
- IOB series regenerated in `updateInsulinSeries()` (already called on `.onChange(of: insulinDeliveryValues)` and `.onAppear`). Add `.onChange(of: store.state.iobDeliveries)`, `.onChange(of: store.state.bolusInsulinPreset)`, and `.onChange(of: store.state.basalDIAMinutes)` to also trigger regeneration. IOB series generation MUST occur inside `updateInsulinSeries()` on the background `calculationQueue`, not in a computed property or body
- Add `iobSeries: [(date: Date, total: Double, mealSnack: Double, corrBasal: Double)]` state
- Y-axis range for IOB: `0...maxIOB` mapped to chart pixel range below glucose area

**Patterns to follow:**
- Existing insulin series update pattern (`updateInsulinSeries()`)
- Prediction projection line (lines 522-566) for secondary overlay
- Basal `RectangleMark` for filled area styling

**Test scenarios:**
Test expectation: none — pure chart rendering. IOB computation tested in Unit 1. Visual verification on iOS 16+ simulator.

**Verification:**
- IOB area visible below glucose line on iOS 16+ simulator
- Area decays over time matching the exponential curve shape
- Split mode shows two distinct colored areas
- Chart scrolls with IOB area in sync
- No IOB area on iOS 15 (fallback view unaffected)

---

- [x] **Unit 6: Stacking Warning**

**Goal:** Show inline IOB warning in AddInsulinView when correction bolus is selected with active insulin.

**Requirements:** R11, R12, R13

**Dependencies:** Unit 1 (computeIOB), Unit 2 (state properties)

**Files:**
- Modify: `App/Views/AddViews/AddInsulinView.swift`
- Modify: `App/Views/OverviewView.swift` (pass currentIOB to AddInsulinView)

**Approach:**
- Add `currentIOB: Double?` parameter to `AddInsulinView` (default nil, preserves existing callers)
- In OverviewView's `.insulin` sheet case, compute IOB from `store.state.iobDeliveries` and pass as `currentIOB`
- Inside AddInsulinView, show warning when `insulinType == .correctionBolus && (currentIOB ?? 0) > 0.05`
- Warning appears/disappears reactively as picker changes (SwiftUI conditional rendering)
- Warning UI: `HStack` with exclamation triangle icon + "ACTIVE IOB: X.XU" in `AmberTheme.amber` + `DOSTypography.caption` (amber = informational awareness, not cgaRed which is reserved for alarms/danger)
- Placed above the existing footer VStack in the Form section

**Patterns to follow:**
- `deleteCallback` parameter pattern on `AddMealView` (optional parameter, nil default)
- Warning banner styling from `TreatmentBannerView`

**Test scenarios:**
Test expectation: none — pure UI rendering with static IOB value. Visual verification in simulator.

**Verification:**
- Warning visible when correctionBolus selected and IOB > 0
- Warning disappears when switching to mealBolus/snackBolus/basal
- Warning reappears when switching back to correctionBolus
- No warning when IOB is 0 or nil
- User can still tap Add despite warning

---

- [x] **Unit 7: Treatment Banner IOB**

**Goal:** Display current IOB on TreatmentBannerView during active treatment cycle.

**Requirements:** R14

**Dependencies:** Unit 1 (computeIOB), Unit 2 (state properties)

**Files:**
- Modify: `App/Views/Overview/TreatmentBannerView.swift`

**Approach:**
- Use existing `@EnvironmentObject var store: DirectStore` (already declared in TreatmentBannerView)
- Compute IOB from `store.state.iobDeliveries` on render
- Show IOB only during `.countdown` and `.rechecking` banner states (clinically relevant during active treatment). Omit during `.staleData` (sensor unreliable) and `.recovered` (auto-dismissing in 5s)
- Display IOB on a **second line** within the banner VStack, not appended inline (prevents text overflow on small screens)
- Only show when IOB > 0.05U
- Use existing `DOSTypography.caption` and `AmberTheme.amber` styling

**Patterns to follow:**
- Existing banner content layout (HStack with text + spacer + dismiss button)

**Test scenarios:**
Test expectation: none — pure UI rendering. Visual verification during active treatment cycle.

**Verification:**
- IOB visible on treatment banner during active countdown
- IOB updates as time passes (recomputed on each render)
- IOB hidden on banner when < 0.05U

---

- [x] **Unit 8: Settings UI**

**Goal:** Add IOB settings screen for insulin preset selection, basal DIA, and split display toggle.

**Requirements:** R2, R6

**Dependencies:** Unit 2 (state properties and actions)

**Files:**
- Create: `App/Views/Settings/InsulinSettingsView.swift`
- Modify: `App/Views/SettingsView.swift` (add navigation link to InsulinSettingsView)
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- Create standalone `InsulinSettingsView` — insulin pharmacokinetic settings are a separate concern from alarm notification sounds
- Add a "INSULIN" row in `SettingsView` linking to the new view (follow existing settings navigation pattern)
- **Bolus insulin preset**: `Picker` with `.menu` style, options: "Rapid-acting (Humalog/NovoRapid)" and "Ultra-rapid (Fiasp/Lyumjev)"
- **Basal DIA**: `Stepper` showing hours:minutes, step 30 min, range 2h-24h. Label: "Basal Duration"
- **Split display toggle**: `Toggle` for "Show split IOB (meal vs correction)"
- Footer text explaining DIA: "Duration of Insulin Action — how long insulin remains active after injection. Changes apply to all active insulin. For long-acting basal (Lantus/Tresiba), set to the manufacturer-specified duration."
- All use `Binding(get:, set:)` pattern dispatching actions to store

**Patterns to follow:**
- `AlarmSettingsView.swift` Section/Toggle/Picker/Binding patterns
- `hypoTreatmentWaitMinutes` Stepper in treatment settings
- Existing `SettingsView` navigation link pattern

**Test scenarios:**
Test expectation: none — pure settings UI. Settings persistence tested via reducer tests in Unit 2.

**Verification:**
- InsulinSettingsView accessible from SettingsView
- Preset picker shows two options and persists selection
- Basal DIA stepper increments/decrements by 30 min within range (2h-24h)
- Split toggle persists across app restarts
- Footer text is readable and informative

---

- [x] **Unit 9: Reducer Tests**

**Goal:** Add snapshot tests for IOB-related reducer cases.

**Requirements:** R1, R2, R4a, R6

**Dependencies:** Unit 2 (reducer cases exist)

**Files:**
- Modify: `DOSBTSTests/DirectReducerTests.swift`

**Approach:**
- Add `@Suite("IOB State")` test suite
- Follow existing `makeState()` + `reduce()` helper pattern
- Test IOB-specific reducer behavior

**Patterns to follow:**
- `TreatmentCycleTests`, `PredictiveLowAlarmTests` in `DirectReducerTests.swift`

**Test scenarios:**
- Happy path: `.setBolusInsulinPreset(.ultraRapid)` updates `bolusInsulinPreset`
- Happy path: `.setBasalDIAMinutes(240)` updates `basalDIAMinutes` to 240
- Happy path: `.setShowSplitIOB(enabled: true)` sets flag to true
- Happy path: `.setIOBDeliveries` populates `iobDeliveries` array
- Edge case: `.setIOBDeliveries` with empty array clears the list
- Happy path: Default state has `.rapidActing` preset, 360 basalDIAMinutes, `showSplitIOB == false`

**Verification:**
- All tests pass with `Cmd+U`
- Tests follow existing suite naming and helper patterns

## System-Wide Impact

- **Interaction graph:** IOBMiddleware listens to `.addSensorGlucose` (same as GlucoseNotification, TreatmentCycle — documented cross-middleware listener), `.addInsulinDelivery` and `.deleteInsulinDelivery` (same as InsulinDeliveryStore — documented cross-middleware listener), `.setAppState(.active)` (same as all DataStore middlewares)
- **Error propagation:** GRDB query failures in IOBMiddleware should log and return `Empty()` (non-critical — IOB display simply shows no data). Never block the glucose pipeline
- **State lifecycle risks:** `iobDeliveries` is transient (not persisted). On app restart, middleware reloads from GRDB on `.setAppState(.active)`. No stale state risk
- **API surface parity:** No external API changes. Widget does not show IOB (explicit V1 scope boundary)
- **Integration coverage:** IOBMiddleware + InsulinDeliveryStore both handle `.addInsulinDelivery` — verify both fire and don't conflict. IOBMiddleware + GlucoseNotification both handle `.addSensorGlucose` — verify IOB recalculates alongside notification logic
- **Unchanged invariants:** Existing insulin delivery CRUD, chart marker display, treatment cycle workflow, predictive alarm — all unchanged. IOB is purely additive

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Exponential formula produces unexpected IOB values at edge DIA/peak combinations | Unit 1 tests validate against known oref0 reference values |
| Chart AreaMark for IOB conflicts with existing glucose/insulin chart rendering | IOB area uses separate Y range (below glucose) and distinct colors |
| Basal segmentation performance with many 5-min chunks | Max chunks per entry: 8h / 5min = 96. With < 10 basal entries, ~960 iterations — trivial |
| `insulinDeliveryValues` and `iobDeliveries` refresh timing confusion | Separate middleware, separate state properties, separate GRDB query methods. Document the separation |
| pbxproj merge conflicts from new files | Only 2 new Swift files (IOBCalculator, IOBMiddleware). Add sequentially in Unit 1 and Unit 3 |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-17-iob-decay-model-requirements.md](docs/brainstorms/2026-04-17-iob-decay-model-requirements.md)
- **Linear issue:** [DMNC-687](https://linear.app/lizomorf/issue/DMNC-687)
- Related code: `Library/Content/InsulinDelivery.swift`, `App/Modules/DataStore/InsulinDeliveryStore.swift`
- External: [oref0 exponential model](https://github.com/openaps/oref0/blob/master/lib/iob/calculate.js), [LoopKit ExponentialInsulinModel](https://github.com/LoopKit/LoopKit/blob/main/LoopKit/InsulinKit/ExponentialInsulinModel.swift)
