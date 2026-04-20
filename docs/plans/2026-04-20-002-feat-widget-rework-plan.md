---
title: "feat: Widget Rework — Phosphor Display Style with Expanded Data"
type: feat
status: active
date: 2026-04-20
origin: docs/brainstorms/2026-04-20-widget-rework-requirements.md
---

# feat: Widget Rework — Phosphor Display Style with Expanded Data

## Overview

Full visual rework of all widget surfaces (home screen, lock screen, Live Activity, Dynamic Island) with phosphor display aesthetic and expanded data. Add medium and large home screen widgets with TIR, IOB, last meal, and sparkline chart. Rework Live Activity banner with mini sparkline and IOB.

## Problem Frame

The widget suite looks like an afterthought — the small home screen widget has basic data, lock screen widgets are minimal, and none match the app's DOS amber CGA aesthetic. Users glance at widgets dozens of times a day; they should be as information-dense and visually cohesive as the app. (see origin: `docs/brainstorms/2026-04-20-widget-rework-requirements.md`)

## Requirements Trace

- R1. Phosphor display visual style — glowing amber on black, monospace, no window chrome
- R2. Home screen widgets — small, medium (TIR + IOB + meal), large (+ sparkline chart)
- R3. Lock screen widgets — circular glucose, rectangular glucose (TIR + IOB), sensor, transmitter
- R4. Live Activity — rich banner with sparkline + IOB, Dynamic Island with IOB
- R5. Shared data expansion — TIR, IOB, last meal, sparkline via App Group UserDefaults
- R6. Alarm and data states — color coding, staleness, missing data, connection loss
- R7. Widget design system file — shared phosphor modifiers, colors, fonts, sparkline builder

## Scope Boundaries

- Visual rework of all 4 widget files with phosphor display style
- New systemMedium and systemLarge home screen families
- Shared data expansion via App Group UserDefaults
- Sparkline via SwiftUI Path (iOS 15 compat — no Swift Charts)
- Reworked Live Activity + Dynamic Island
- Widget design system file
- All alarm/stale/missing data states

### Out of Scope

- Interactive widgets / app intent configuration
- Widget configuration screen
- StandBy mode / iPad layouts
- New widget types (digest, stats)
- WidgetCenter middleware changes beyond adding shared data writes

## Context & Research

### Relevant Code and Patterns

- Widget entry + timeline provider: `Widgets/GlucoseWidget.swift` — `GlucoseEntry` struct, `GlucoseUpdateProvider`, `StaticConfiguration`, family switching via `@Environment(\.widgetFamily)`
- Live Activity: `Widgets/GlucoseActivityWidget.swift` — `ActivityConfiguration`, `DynamicIsland` with 4 regions, `GlucoseStatusContext` protocol
- Data sharing: `App/Modules/WidgetCenter/WidgetCenter.swift` — middleware writes to `UserDefaults.shared` on glucose updates; `Library/Extensions/UserDefaults.swift` has shared keys pattern (`sharedGlucose`, `sharedSensor`, etc.) and generic `setObject`/`getObject` helpers
- Live Activity attributes: `Library/Content/SensorGlucoseActivityAttributes.swift` — `ContentState` with alarm thresholds, sensor/connection state, glucose, unit
- Widget bundle: `Widgets/Widgets.swift` — `@main WidgetBundle` with iOS 16.1+ availability check

### Institutional Learnings

- **iOS 15 deployment target** — Swift Charts requires iOS 16. Sparkline must use `Path` or `Shape`.
- **App Group UserDefaults** — widgets read from `UserDefaults.shared` (App Group suite). New shared keys follow existing pattern in `UserDefaults.swift`.
- **Live Activity 8-hour limit** — activities auto-expire; restart logic in `ActivityGlucoseService`.

## Key Technical Decisions

- **SwiftUI Path for sparkline, not Swift Charts** — deployment target iOS 15. Path draws a polyline from sampled points. Simple, no dependencies.
- **WidgetDesignSystem.swift mirrors AmberTheme** — widget extension can't import app's design system module. Mirror the color/font constants in a widget-local file. Keep values identical to `AmberTheme`.
- **Expand GlucoseEntry to carry all new data** — rather than reading 7+ keys from UserDefaults in the view, expand `GlucoseEntry` to include TIR, IOB, meal, sparkline. Timeline provider populates everything upfront.
- **Live Activity ContentState gets IOB field** — add `iob: Double?` to `SensorGlucoseActivityAttributes.GlucoseStatus`. Sparkline data is too large for ContentState; render from shared UserDefaults in the view.

## Open Questions

### Resolved During Planning

- **How to share sparkline data?** — Encode as `[Int]` + `[Date]` arrays in App Group UserDefaults. Sampled at 30-min intervals (~12 points for 6h).
- **Where does IOB come from for the widget?** — WidgetCenter middleware reads `state.iobDeliveries` and computes IOB via `IOBCalculator`, then writes the scalar `Double` to shared UserDefaults.

### Deferred to Implementation

- **Exact phosphor glow shadow parameters** — tune `shadow(color:radius:)` values during visual iteration.
- **Sparkline Path smoothing** — start with straight segments, consider quadratic curves if it looks too jagged.

## Implementation Units

- [ ] **Unit 1: WidgetDesignSystem.swift — shared design tokens**

**Goal:** Create widget-local design system file mirroring AmberTheme colors, DOSTypography fonts, and phosphor glow modifiers.

**Requirements:** R1, R7

**Dependencies:** None

**Files:**
- Create: `Widgets/WidgetDesignSystem.swift`

**Approach:**
- Mirror `AmberTheme` color constants: amber, amberDark, amberLight, cgaRed, cgaGreen, cgaCyan
- Monospace font helpers matching `DOSTypography` sizes (but local to widget target)
- Phosphor glow view modifier: `.phosphorGlow(color:)` applying double shadow (tight + diffuse)
- Sparkline `Path` builder: takes `[Int]` points, `CGRect` frame, optional alarm threshold lines → returns `Path`
- Staleness helper: given timestamp, return `.fresh`, `.stale`, `.veryStale` enum

**Patterns to follow:**
- `Library/DesignSystem/AmberTheme.swift` for color values
- `Library/DesignSystem/DOSTypography.swift` for font sizes

**Test scenarios:**
- Test expectation: none — pure styling constants and view modifiers

**Verification:**
- Widget target builds with new file imported
- Colors match AmberTheme values

---

- [ ] **Unit 2: Shared data expansion — UserDefaults keys + WidgetCenter writes**

**Goal:** Add new App Group UserDefaults keys for TIR, IOB, last meal, and sparkline. Write them from WidgetCenter middleware.

**Requirements:** R5

**Dependencies:** Unit 1

**Files:**
- Modify: `Library/Extensions/UserDefaults.swift` (add shared keys + properties)
- Modify: `App/Modules/WidgetCenter/WidgetCenter.swift` (write new data on glucose updates)

**Approach:**
- New keys in `UserDefaults.Keys`: `sharedTIR`, `sharedIOB`, `sharedLastMealDescription`, `sharedLastMealCarbs`, `sharedLastMealTimestamp`, `sharedGlucoseSparkline`, `sharedGlucoseSparklineTimestamps`
- Computed properties on `UserDefaults` for each (Double, String, Date, [Int], [Date])
- In WidgetCenter middleware's `.addSensorGlucose` handler, after existing writes:
  - Write `state.glucoseStatistics?.tir` as `sharedTIR`
  - Compute IOB from `state.iobDeliveries` via `IOBCalculator.computeIOB()`, write as `sharedIOB`
  - Write `state.mealEntryValues.last` fields as `sharedLastMeal*`
  - Sample `state.sensorGlucoseValues` at 30-min intervals (last 6h), write as `sharedGlucoseSparkline`

**Patterns to follow:**
- Existing `sharedGlucose` key pattern in `UserDefaults.swift`
- Existing middleware writes in `WidgetCenter.swift`

**Test scenarios:**
- Test expectation: none — UserDefaults writes are side effects in middleware. Verify by reading values in widget at runtime.

**Verification:**
- Widget reads non-nil values for TIR, IOB, sparkline after app has been running with sensor data

---

- [ ] **Unit 3: GlucoseWidget rework — all three home screen sizes**

**Goal:** Rework the small widget and add medium/large with phosphor display style and expanded data.

**Requirements:** R1, R2, R3, R6

**Dependencies:** Unit 1, Unit 2

**Files:**
- Modify: `Widgets/GlucoseWidget.swift`

**Approach:**
- Expand `GlucoseEntry` with: `tir: Double?`, `iob: Double?`, `lastMealDescription: String?`, `lastMealCarbs: Double?`, `lastMealTimestamp: Date?`, `sparkline: [Int]?`
- `GlucoseUpdateProvider.getTimeline` reads all new keys from `UserDefaults.shared`
- Add `.systemMedium` and `.systemLarge` to `supportedFamilies`
- **Small:** Centered glucose (44pt bold, phosphor glow) + trend + minute change + timestamp. Pure black background.
- **Medium:** Left: glucose (52pt, phosphor glow) + trend, border separator. Right: TIR (color-coded, 14pt), IOB (cyan, 14pt), last meal (amber, 13pt), timestamp. Right-side labels minimum 13-14pt.
- **Large:** Top row: glucose + trend + TIR/IOB/meal. Middle: 6h sparkline Path with alarm threshold dashed lines. Bottom: timestamp + sensor remaining.
- **Lock screen rectangular:** Glucose (32pt bold) + trend + change. Second line: "TIR 78% · IOB 2.4U · 2m ago"
- **Lock screen circular:** Glucose (24pt bold) + trend arrow
- Alarm states: red glow when glucose crosses alarm thresholds
- Staleness: dim amber for 5-14 min, red timestamp for 15+ min
- Missing data: `---` placeholder, hide missing optional fields

**Patterns to follow:**
- Existing `GlucoseView` family switching pattern
- `WidgetDesignSystem` phosphor glow modifier from Unit 1

**Test scenarios:**
- Test expectation: none — pure UI widget views. Verify visually on simulator.

**Verification:**
- All 5 families render correctly in widget gallery preview
- Alarm state shows red glow
- Stale data shows dim/red styling
- Missing data shows `---` gracefully
- Medium right-side text is readable (13-14pt minimum)

---

- [ ] **Unit 4: Live Activity + Dynamic Island rework**

**Goal:** Rework Live Activity banner with sparkline + IOB and Dynamic Island with IOB.

**Requirements:** R1, R4, R6

**Dependencies:** Unit 1, Unit 2

**Files:**
- Modify: `Widgets/GlucoseActivityWidget.swift`
- Modify: `Library/Content/SensorGlucoseActivityAttributes.swift` (add `iob: Double?` to ContentState)
- Modify: `App/Modules/WidgetCenter/WidgetCenter.swift` (pass IOB in activity updates)

**Approach:**
- Add `iob: Double?` to `SensorGlucoseActivityAttributes.GlucoseStatus`
- Update `ActivityGlucoseService.getStatus()` to include IOB
- **Banner:** Left: glucose (36pt, phosphor glow) + trend. Center: mini sparkline (3h, ~6 points, read from UserDefaults.shared). Right: IOB (cyan) + timestamp.
- **Dynamic Island Compact Leading:** glucose value (bold amber)
- **Dynamic Island Compact Trailing:** trend + IOB (cyan)
- **Dynamic Island Expanded Center:** glucose + trend + sparkline + IOB + timestamp
- **Dynamic Island Minimal:** glucose value only
- Connection lost: strikethrough + red dot (keep existing pattern)
- Phosphor amber styling on all surfaces

**Patterns to follow:**
- Existing `GlucoseActivityView` and `DynamicIslandCenterView` structure
- `GlucoseStatusContext` protocol for alarm/warning logic

**Test scenarios:**
- Test expectation: none — Live Activity views. Verify on device (simulator has limited LA support).

**Verification:**
- Live Activity banner shows sparkline + IOB
- Dynamic Island compact shows glucose + IOB
- Connection-lost state still works (strikethrough)

---

- [ ] **Unit 5: SensorWidget + TransmitterWidget phosphor styling**

**Goal:** Apply phosphor display styling to the two circular lock screen widgets.

**Requirements:** R1, R3

**Dependencies:** Unit 1

**Files:**
- Modify: `Widgets/SensorWidget.swift`
- Modify: `Widgets/TransmitterWidget.swift`

**Approach:**
- Replace existing gauge styling with phosphor-styled circular gauge (amber fill arc on black)
- Monospace font for labels
- Sensor: days remaining + hours, gauge arc proportional to remaining/total lifetime
- Transmitter: battery percentage, gauge arc proportional to battery level
- No data state: `?` with dashed circle (keep existing pattern, apply phosphor styling)

**Patterns to follow:**
- Existing gauge layout in both files
- `WidgetDesignSystem` colors from Unit 1

**Test scenarios:**
- Test expectation: none — pure styling pass on existing widgets

**Verification:**
- Both circular widgets render with amber phosphor styling in widget gallery
- No-data state shows correctly

---

- [ ] **Unit 6: Xcode project + build verification**

**Goal:** Add WidgetDesignSystem.swift to pbxproj and verify full build.

**Requirements:** All

**Dependencies:** Units 1-5

**Files:**
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- Add `Widgets/WidgetDesignSystem.swift` to PBXBuildFile (widget target only), PBXFileReference, PBXGroup (Widgets group), PBXSourcesBuildPhase (widget sources)
- Verify both app and widget targets build successfully

**Test scenarios:**
- Test expectation: none — build infrastructure

**Verification:**
- `xcodebuild build` succeeds for both DOSBTSApp and DOSBTSWidget schemes

## System-Wide Impact

- **Interaction graph:** WidgetCenter middleware gains additional writes to App Group UserDefaults. Widgets read more keys. Live Activity ContentState gains `iob` field. No other middleware affected.
- **Error propagation:** Missing data in UserDefaults → widgets show graceful fallbacks (`---`, hidden fields). No crashes from nil data.
- **State lifecycle risks:** UserDefaults writes happen on every glucose update (~every 5 min). Sparkline array is small (~12 ints). No storage growth concern.
- **API surface parity:** `SensorGlucoseActivityAttributes.GlucoseStatus` gains `iob` field — this is a Codable struct, but Live Activities are ephemeral (8h max), so versioning is not a concern.
- **Unchanged invariants:** All existing widget functionality preserved. Small widget still works. Live Activity still has same lifecycle. Sensor/transmitter widgets unchanged functionally.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Sparkline looks too jagged with 12 straight-line segments | Defer to implementation: try quadratic curves if needed |
| Medium widget right-side text too cramped | 13-14pt minimum font requirement in spec; test on smallest iPhone screen |
| IOB computation in WidgetCenter adds latency to glucose update | IOBCalculator is fast (<1ms for typical delivery count); acceptable |
| Live Activity ContentState change breaks existing activities | Activities are ephemeral (8h); old activities expire naturally |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-20-widget-rework-requirements.md](docs/brainstorms/2026-04-20-widget-rework-requirements.md)
- Related code: `Widgets/GlucoseWidget.swift`, `Widgets/GlucoseActivityWidget.swift`, `App/Modules/WidgetCenter/WidgetCenter.swift`
- Related issue: DMNC-579
