---
title: "feat: Libre-style event marker lane above glucose chart"
type: feat
status: active
date: 2026-04-18
origin: docs/brainstorms/2026-04-18-event-marker-lane-requirements.md
---

# feat: Libre-style Event Marker Lane Above Glucose Chart

## Overview

Replace in-chart meal/insulin/exercise annotations with a dedicated marker lane above the glucose chart. Backported from DOOMBTS (commit `4a5a5be0`) with DOSBTS amber CGA theming. Meal markers in the lane trigger the existing meal impact overlay on the chart below.

## Problem Frame

DOSBTS renders meal diamonds, insulin labels, and exercise bars as overlapping annotations inside the glucose chart. At dense data periods or wider zoom levels, these markers crowd the chart bottom and obscure the glucose line. The Freestyle Libre app solves this with a dedicated marker row above the chart. DOOMBTS already implements this pattern. (see origin: `docs/brainstorms/2026-04-18-event-marker-lane-requirements.md`)

## Requirements Trace

- R1: Dedicated 32px marker lane above chart, scrolling in sync
- R2: SF Symbol icons per type — `fork.knife` (meals/cgaGreen), `syringe.fill` (insulin/amberDark), `figure.run` (exercise/cgaCyan)
- R3: Scored meal visual distinction (larger `fork.knife` or border)
- R4: Zoom-dependent consolidation (3h=individual, 6h+=grouped with badge count)
- R5: Tap behavior — single meal toggles impact overlay, single insulin shows confirm dialog, group expands panel
- R6: Exercise markers show activity type + duration
- R7: Remove in-chart meal/insulin PointMark annotations (keep exercise RectangleMark shading, IOB AreaMark, meal impact overlay)
- R8: Disable BG button from front action bar (already done)

## Scope Boundaries

- No new marker types
- iOS 15 unaffected (ChartViewCompatibility has no markers)
- Exercise `RectangleMark` background shading stays on chart
- Meal impact overlay (2hr band + delta) stays on chart, unchanged

### Deferred to Separate Tasks

- HealthKit deep-link from exercise markers (DMNC-715)
- Alternative visualization styles (DMNC-715)

## Context & Research

### Relevant Code and Patterns

- **DOOMBTS reference:** `EventMarkerLaneView.swift` (159 lines), `ChartView.swift` marker types + consolidation logic at commit `4a5a5be0`
- **Current meal markers:** `ChartView.swift` lines 668-697 — `ForEach(mealGroups)` with `PointMark` diamonds + annotation
- **Current insulin markers:** `ChartView.swift` lines 600-633 — `ForEach(insulinSeries)` with `PointMark` + annotation
- **Tap handling:** `ChartView.swift` lines 1050-1085 — `.onEnded` gesture handler finding nearest meal/insulin groups
- **Meal impact overlay:** `ChartView.swift` lines 699-810 — triggered by `activeMealOverlay` state, renders RectangleMark band + annotation
- **Data preparation:** `updateMealSeries()`, `updateInsulinSeries()`, `updateExerciseSeries()` — existing `@State` arrays
- **Sheet routing:** `OverviewView.swift` `ActiveSheet` enum + single `.sheet(item:)` — all tap-to-sheet interactions must route through this

### Institutional Learnings

- **Nested sheets unreliable** (`docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`): EventMarkerLaneView must not present sheets directly. Route tap callbacks to ChartView/OverviewView
- **Sibling sheet collision** (`docs/solutions/ui-bugs/swiftui-sheet-collision-ios15-sibling-views-20260315.md`): All sheet presentation must use the existing `ActiveSheet` enum
- **Reducer-first** (`docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`): No new middleware needed for this feature — purely view-layer

## Key Technical Decisions

- **EventMarkerLaneView is a passive view:** Receives pre-computed `[ConsolidatedMarkerGroup]` data and tap callbacks. No store dependency, no middleware, no Redux state. All data prep happens in ChartView via `updateMarkerGroups()`
- **Marker types defined in ChartView:** `MarkerType` enum, `EventMarker` struct, `ConsolidatedMarkerGroup` struct live at the bottom of ChartView.swift (matching DOOMBTS pattern). They're tightly coupled to chart data prep
- **Lane scrolls with chart:** Both are inside the same `ScrollView(.horizontal)` in a `VStack(spacing: 0)`. The lane uses `GeometryReader`-free positioning — markers are absolutely positioned using timestamp-to-x conversion matching the chart's time axis
- **Meal tap in lane triggers overlay:** `onTapMeal` callback sets `activeMealOverlay` in ChartView — same state that the current in-chart diamond tap uses. No new state needed
- **Theme adaptation:** DoomTheme → AmberTheme, DoomTypography → DOSTypography, DoomSpacing → DOSSpacing throughout

## Open Questions

### Resolved During Planning

- **How does the lane sync scroll position with the chart?** Both are in the same ScrollView, same total width. Lane uses the same `startMarker`/`endMarker` time range for x-positioning
- **What happens to the chartOverlay tap gesture?** The `.chartOverlay` DragGesture stays on the Chart for glucose point selection (drag) and meal impact overlay dismissal (tap outside). The meal/insulin group detection in `.onEnded` is removed — those taps now happen in the marker lane above
- **Do we keep `mealGroups` and `insulinGroups` state?** Yes — they feed the lane via `updateMarkerGroups()`. The grouping logic is adapted to produce `ConsolidatedMarkerGroup` instead

### Deferred to Implementation

- Exact clamping logic for expanded panel positioning near scroll edges — determine empirically
- Whether `consolidationWindows` time thresholds need tuning for DOSBTS's chart widths

## Implementation Units

- [ ] **Unit 1: Marker type definitions and consolidation logic**

**Goal:** Add the shared types (`MarkerType`, `EventMarker`, `ConsolidatedMarkerGroup`) and the `updateMarkerGroups()` function to ChartView.

**Requirements:** R4

**Dependencies:** None

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

**Approach:**
- Add `MarkerType` enum with cases `.meal`, `.bolus`, `.exercise`, each with `icon` (SF Symbol name) and `color` (AmberTheme token) computed properties
- Add `EventMarker` struct (id, time, type, label, rawValue, sourceID)
- Add `ConsolidatedMarkerGroup` struct (id, time, markers, computed properties: isSingle, dominantType, summaryLabel, totalCarbs)
- Add `@State private var markerGroups: [ConsolidatedMarkerGroup] = []` and `@State private var expandedGroupID: String? = nil`
- Add `Config.consolidationWindows` dictionary and `Config.markerLaneHeight`
- Add `updateMarkerGroups()` that builds `EventMarker` array from `mealEntryValues`, `insulinDeliveryValues`, `exerciseEntryValues`, sorts by time, consolidates based on zoom-level window, produces `ConsolidatedMarkerGroup` array
- Call `updateMarkerGroups()` from `onAppear` and from existing `onChange` handlers where `updateMealSeries()` / `updateInsulinSeries()` are called

**Patterns to follow:**
- DOOMBTS `ChartView.swift` lines 1480-1560 (MarkerType, EventMarker, ConsolidatedMarkerGroup)
- DOOMBTS `ChartView.swift` lines 1096-1165 (updateMarkerGroups)

**Test expectation:** none — view-layer data preparation, verified by visual inspection in Unit 4

**Verification:**
- `markerGroups` populates correctly (debug print in updateMarkerGroups)
- Types compile with correct SF Symbol names and AmberTheme colors

---

- [ ] **Unit 2: EventMarkerLaneView**

**Goal:** Create the self-contained marker lane SwiftUI view.

**Requirements:** R1, R2, R3, R5, R6

**Dependencies:** Unit 1 (marker types)

**Files:**
- Create: `App/Views/Overview/EventMarkerLaneView.swift`
- Modify: `DOSBTS.xcodeproj/project.pbxproj` (4 sections: PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase — app target only)

**Approach:**
- Adapt from DOOMBTS `EventMarkerLaneView.swift` (159 lines) with theme token swaps
- View takes: `markerGroups: [ConsolidatedMarkerGroup]`, `totalWidth: CGFloat`, `timeRange: ClosedRange<Date>`, `scoredMealEntryIds: Set<UUID>`, `onTapMeal: (UUID) -> Void`, `onTapInsulin: (UUID) -> Void`, `expandedGroupID: Binding<String?>`
- `markerView(for:)` renders single markers with SF Symbol icon + label, and consolidated groups with dominant icon + summary + badge count
- Scored meals: check `scoredMealEntryIds.contains(marker.sourceID)` — apply slightly larger icon or subtle amber border
- `expandedPanel(for:)` shows individual items in a dropdown, tap routes to single-marker action
- `xPosition(for:)` converts timestamp to x coordinate using `timeRange` and `totalWidth`
- `tapSingleMarker()` routes to `onTapMeal` / `onTapInsulin` callbacks
- Exercise tap: no action (future DMNC-715)
- Exercise label: activity type + duration (e.g. "Run 30m")
- Use AmberTheme colors, DOSTypography fonts, DOSSpacing for padding

**Patterns to follow:**
- DOOMBTS `EventMarkerLaneView.swift` — direct adaptation

**Test expectation:** none — pure view component, verified visually in Unit 4

**Verification:**
- File compiles and is registered in pbxproj
- Lane renders markers with correct icons and colors

---

- [ ] **Unit 3: Integrate lane into chart layout and rewire tap handling**

**Goal:** Place EventMarkerLaneView above the chart in the ScrollView, remove in-chart meal/insulin PointMark annotations, and rewire tap handling.

**Requirements:** R1, R5, R7

**Dependencies:** Unit 1 (types), Unit 2 (lane view)

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

**Approach:**
- In `GlucoseChartContent`, find the `ScrollView(.horizontal)` that wraps the chart. Insert `EventMarkerLaneView(...)` in a `VStack(spacing: 0)` above the chart `GlucoseChart.frame(...)`. Pass `markerGroups`, `totalWidth: max(0, screenWidth, seriesWidth)`, `timeRange: (startMarker ?? Date())...(endMarker ?? Date())`, `scoredMealEntryIds: store.state.scoredMealEntryIds`, callbacks, and `$expandedGroupID`
- Set lane frame width to match chart: `.frame(width: max(0, screenWidth, seriesWidth), height: Config.markerLaneHeight)`
- `onTapMeal` callback: find the `MealEntry` by ID from `store.state.mealEntryValues`, toggle `activeMealOverlay` (same as current diamond tap logic). For grouped meals (tapped from expanded panel), check if the group has count > 1 — if so, set `tappedMealGroup` instead
- `onTapInsulin` callback: find the `InsulinDelivery` by ID from `store.state.insulinDeliveryValues`, set `tappedInsulinEntry` + `showInsulinDetail = true`
- Remove the `ForEach(mealGroups.enumerated())` PointMark block (lines ~668-697) — meal markers now in lane
- Remove the insulin PointMark annotations (non-basal) — insulin markers now in lane. Keep basal `AreaMark`/`RectangleMark` rendering on chart
- Keep exercise `RectangleMark` background shading on chart (R7)
- Remove meal/insulin group detection from `.onEnded` tap gesture handler — those taps now happen in the lane. Keep the overlay dismissal (`activeMealOverlay = nil`) on tap-outside
- Dismiss `expandedGroupID` when tapping outside the lane (add to the `.onEnded` handler)

**Patterns to follow:**
- DOOMBTS `ChartView.swift` lines 99-122 (VStack with EventMarkerLaneView + chart in ScrollView)

**Test expectation:** none — view integration, verified visually

**Verification:**
- Marker lane appears above chart, scrolls in sync
- Meal markers no longer render as in-chart diamonds
- Insulin markers no longer render as in-chart points (basal area remains)
- Tapping meal in lane shows meal impact overlay on chart
- Tapping insulin in lane shows confirmation dialog
- Tapping outside dismisses overlay and expanded panel
- Exercise shading still visible on chart

---

- [ ] **Unit 4: Build verification and visual QA**

**Goal:** Verify the full feature builds, existing tests pass, and visual behavior is correct.

**Requirements:** All (R1-R8)

**Dependencies:** Units 1-3

**Files:**
- Modify: `DOSBTS.xcodeproj/project.pbxproj` (if any registration was missed)

**Test scenarios:**
- Happy path: Build succeeds for both DOSBTSApp and DOSBTSWidget schemes
- Happy path: All existing tests pass (61 tests)
- Happy path: Marker lane visible above chart with meal (fork.knife green), insulin (syringe amber), exercise (runner cyan) markers
- Happy path: Tap single meal marker in lane → meal impact overlay appears on chart with 2hr band + delta
- Happy path: Tap pencil in overlay → edit sheet opens
- Happy path: Tap single insulin marker in lane → confirmation dialog appears
- Happy path: Tap consolidated group → expanded panel shows individual items
- Happy path: Tap item in expanded panel → triggers single-marker action, panel closes
- Edge case: 3h zoom → all markers individual, no consolidation
- Edge case: 24h zoom → nearby markers consolidated with badge count
- Edge case: No meals/insulin/exercise → empty lane (32px of blank space)
- Edge case: Scored meal marker → visually distinct from unscored
- Integration: Tap meal in lane → overlay appears → tap pencil → edit sheet opens → save → overlay updates
- Integration: Delete meal from edit sheet → marker disappears from lane, impact overlay dismissed

**Verification:**
- Build succeeds
- Tests pass
- All tap flows work end-to-end
- Chart is clean (no overlapping in-chart annotations)

## System-Wide Impact

- **Interaction graph:** Meal tap in lane → sets `activeMealOverlay` → renders meal impact overlay on chart → edit button sets `tappedMealEntry` → `ActiveSheet.meal` sheet opens. Insulin tap in lane → sets `tappedInsulinEntry` + `showInsulinDetail` → confirmation dialog. All existing sheet routing through `ActiveSheet` enum is preserved
- **Unchanged invariants:** Meal impact overlay behavior is unchanged — only the trigger point moves from in-chart diamond to marker lane. IOB AreaMark, heart rate LineMark, predictive low projection line, exercise RectangleMark shading all remain on the chart untouched. All middleware (MealImpactStore, IOB, etc.) is unaffected — this is purely a view-layer change
- **State lifecycle risks:** `expandedGroupID` is `@State` in ChartView — ephemeral, no persistence needed. `markerGroups` is recomputed on data change — no stale state risk

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| ChartView is already 1800+ lines — adding marker types + consolidation adds ~200 more | EventMarkerLaneView is extracted to its own file. Marker types could be extracted to a separate file in future (DMNC-715) |
| Lane x-positioning may drift from chart x-axis at wide zoom levels | Both use the same `totalWidth` and `timeRange` — positioning is derived from identical inputs |
| Removing in-chart meal markers breaks the `symbolSize` scored-meal distinction added in PR #14 | Scored meal distinction moves to the lane (R3) — `scoredMealEntryIds` passed to EventMarkerLaneView |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-18-event-marker-lane-requirements.md](docs/brainstorms/2026-04-18-event-marker-lane-requirements.md)
- **DOOMBTS reference:** commit `4a5a5be0` — `EventMarkerLaneView.swift`, `ChartView.swift`
- Related issues: DMNC-635, DMNC-714 (backport audit), DMNC-715 (future exploration)
- Related PR: CinimoDY/DOSBTS#14 (meal impact overlay — now merged)
- Learnings: `docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`, `docs/solutions/ui-bugs/swiftui-sheet-collision-ios15-sibling-views-20260315.md`
