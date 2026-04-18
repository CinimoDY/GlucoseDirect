---
date: 2026-04-18
topic: meal-impact-overlay
linear: DMNC-688
---

# Meal Impact Overlay: Personal Glycemic Response

## Problem Frame

DOSBTS logs meals and displays glucose data, but there's no connection between the two. After logging "rice + chicken," the user has no easy way to see what happened to their glucose. The meal marker sits at the bottom of the chart; the glucose line floats above. The feedback loop is broken — food logging feels like a chore with no payoff.

Without meal impact tracking:
- Users can't learn which foods spike them and which don't
- AI food analysis (Claude) can't be validated — did estimated carbs match reality?
- The PersonalFood dictionary stores names and carbs but has no glycemic response data
- Every meal is a fresh guess instead of building on past observations

## Requirements

### Tap-to-Reveal Overlay

- R1. Tapping a meal marker on the chart reveals a 2-hour post-meal impact window. The overlay replaces the existing tap-to-edit behavior on iOS 16+ — the overlay includes an edit button (pencil icon) that opens the existing edit/detail sheet. This makes the overlay the unified entry point for both viewing impact and editing meals
- R2. The overlay highlights the 2hr window with a shaded band (subtle, behind the glucose line) spanning from meal timestamp to meal timestamp + 2hr. Note: 2hr is the ADA clinical default (matches OGTT protocol). High-fat/high-protein meals may peak later — this is an accepted V1 simplification. The stored `timeToPeakMinutes` (R12) can validate this assumption over time
- R3. The overlay displays **peak rise as a color-coded delta**: `+Xmg/dL` where X is the difference between pre-meal baseline glucose and the highest glucose reading within the 2hr window
  - Green: delta < 30 mg/dL (minimal spike)
  - Amber: delta 30–60 mg/dL (moderate spike)
  - Red: delta > 60 mg/dL (significant spike)
- R4. Pre-meal baseline is the glucose reading closest to (but not after) the meal timestamp. If no reading exists within 15 minutes before the meal, baseline is unavailable and the overlay shows the delta as `--`
- R5. If the 2hr window extends beyond the latest glucose reading (meal was recent), show "IN PROGRESS" instead of a delta, with partial shading up to the current time. Switch to final delta once 2hr of data exists
- R5a. If the 2hr window has elapsed but fewer than 4 glucose readings exist in the window (sensor dropout), show the delta from available readings with a `~` prefix (e.g., `~+38`) to indicate low confidence. No MealImpact record is stored (R13 threshold not met). If zero readings exist in the window, show `--`
- R6. Tapping outside the overlay or tapping the meal marker again dismisses it. Scroll gestures do NOT dismiss the overlay (the band tracks the meal marker position during scroll). Tapping another chart element (IOB area, exercise band) dismisses the overlay
- R7. Only one meal impact overlay is visible at a time — tapping a different meal marker switches to that meal's overlay
- R8. iOS 16+ only (requires SwiftUI Charts). iOS 15 uses `ChartViewCompatibility` which has no meal markers or tap interaction — no impact on iOS 15 users

### Confounder Detection

- R9. During the 2hr post-meal window, detect three confounder types:
  - **Correction bolus:** Any `InsulinDelivery` with `type == .correctionBolus` and `starts` within `[mealTimestamp, mealTimestamp + 2hr]`. Meal/snack boluses are NOT confounders — they are part of the normal glycemic response the user wants to learn from. Basal insulin is excluded (continuous background, not a discrete intervention)
  - **Exercise:** Any logged exercise entry overlapping the 2hr window
  - **Stacked meal:** Another meal entry within the 2hr window
- R10. When confounders are detected, show small indicator icons within the overlay (e.g., syringe for insulin, running figure for exercise, fork for stacked meal). These are informational — the overlay still shows the delta
- R11. Confounded meals are visually distinguished with **dimmed delta text** (reduced opacity, e.g., 0.5) to signal lower confidence. Note: `~` prefix is reserved for sensor dropout (R5a) — confounders use opacity reduction only, keeping the two degraded states visually distinct

### Per-Meal Impact Records (MealImpact)

- R12. Create a `MealImpact` GRDB table storing individual observations: `id`, `mealEntryId` (FK), `baselineGlucose`, `peakGlucose`, `deltaMgDL`, `timeToPeakMinutes`, `isClean` (no confounders), `timestamp`
- R13. A MealImpact record is computed and stored when the 2hr post-meal window completes AND sufficient glucose data exists (at least 4 readings in the window). Trigger: on `.setAppState(.active)` (retroactive scan for all pending meals) AND on each `.addSensorGlucose` action (incremental check). Both paths check all MealEntry records where `mealTimestamp + 2hr <= now` and no corresponding MealImpact record exists. Guard with `state.appState == .active` (following DataStore load guard pattern). The `.setAppState(.active)` trigger handles retroactive computation when the app is relaunched after being killed during a window; `.addSensorGlucose` handles real-time completion as new readings arrive
- R14. Only **clean** observations (R9 confounder-free) contribute to PersonalFood scoring (R16). Confounded observations are stored in MealImpact for history but not averaged into food scores
- R15. MealImpact is write-once per meal — enforce via UNIQUE constraint on `mealEntryId` in the table DDL, using `insertOrIgnore` to silently handle duplicate attempts. Cascade delete: when a MealEntry is deleted or edited (description/carbs changed), the linked MealImpact record is also deleted

### PersonalFood Glycemic Scoring

- R16. Extend `PersonalFood` with glycemic response fields: `avgDeltaMgDL: Double?`, `observationCount: Int`, `lastScoredDate: Date?`. Add via `DatabaseMigrator` in `createPersonalFoodTable()` (following `SensorGlucoseStore.swift` pattern) with ALTER TABLE migrations for each new column
- R17. When a clean MealImpact is recorded, update the matching PersonalFood entry's rolling average: `newAvg = ((oldAvg * oldCount) + newDelta) / (oldCount + 1)`. Linkage: add `analysisSessionId: UUID?` to both `MealEntry` and `PersonalFood` (GRDB migration). Set to a shared UUID when a meal is created via AI food analysis and PersonalFood entries are auto-created from that same session. `nil` for manual entries. Match MealImpact → PersonalFood via `MealEntry.analysisSessionId == PersonalFood.analysisSessionId`. Manual meal entries do not contribute to PersonalFood scores in V1
- R18. PersonalFood average is surfaced in the tap-to-reveal overlay when at least 2 clean observations exist (see R19): below the delta, show `avg +Xmg/dL (N obs)` in dim amber text. This gives the user historical context for the food
- R19. Minimum 2 clean observations before showing the PersonalFood average (single observation is too noisy to display as a trend)

### Chart Integration

- R20. The meal impact overlay coexists with existing chart layers (IOB AreaMark, exercise bands, heart rate line). Z-order: impact shading behind glucose line, impact annotation on top
- R21. Meal markers that have a completed MealImpact record get a subtle visual distinction from unscored meals (e.g., a dot or ring around the diamond/circle) so users can see at a glance which meals have been analyzed. Requires a `scoredMealEntryIds: Set<UUID>` state property loaded by the MealImpact middleware on `.setAppState(.active)` and updated after each MealImpact write
- R22. The overlay respects chart zoom level and scroll position — the 2hr window scales with the time axis

## Non-Goals

- **Meal suggestions or recommendations** — this is observation/feedback, not prescription
- **Adjusting delta for insulin** — confounders are flagged, not mathematically corrected. That's V2+ territory
- **Time-to-peak or return-to-baseline display** — V1 shows delta only. These metrics are stored in MealImpact for future use
- **Exporting meal impact data** — future feature (HealthKit, CSV)
- **Scoring meals with multiple foods** — the score applies to the meal entry as logged. If "rice + chicken" is one entry, the score is for that combination

## Open Questions

- Q1. Should the PersonalFood average appear in the AI food analysis prompt (Claude) to improve future carb estimates? (Likely yes, but separate from this feature.)
- Q2. Should scored meals surface in a dedicated "Meal Insights" list view, or is the chart overlay sufficient for V1?
- ~~Q3.~~ **Resolved:** Editing a MealEntry's description or carbs deletes the linked MealImpact record (cascade on edit). The meal becomes re-eligible for MealImpact computation, but since the 2hr window has already passed, the observation is effectively lost. PersonalFood rolling average is NOT retroactively corrected (accept minor drift). Deleting a MealEntry also cascade-deletes its MealImpact record

## Visual Concept

```
  180 ┤
      │          ╭──╮                    
  150 ┤         ╱    ╲          ← glucose line
      │   ┌─────────────────┐   ← 2hr shaded band (tap-revealed)
  120 ┤   │  ╱            ╲  │
      │   │╱    +42mg/dL   ╲│   ← color-coded delta (amber)
   90 ┤   │   avg +38 (4)   │   ← PersonalFood avg (dim)
      │   └─────────────────┘
   60 ┤
      │   ◆                      ← meal marker (green diamond)
      ├───┼───┼───┼───┼───┼──
     12:00  12:30  1:00  1:30  2:00
```
