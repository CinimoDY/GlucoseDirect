# Event Marker Lane — Requirements

Created: 2026-04-18
Linear: DMNC-635, DMNC-714 (backport), DMNC-715 (future exploration)

## Problem

DOSBTS displays meal, insulin, and exercise markers as in-chart annotations (PointMark diamonds + text labels at the bottom of the glucose chart). At dense data periods or wider zoom levels, these markers overlap each other and obscure the glucose line. The Freestyle Libre app solves this with a dedicated marker row above the chart — DOOMBTS has already implemented this pattern (commit `4a5a5be0`).

## Requirements

### R1. Dedicated marker lane above the glucose chart

A fixed-height (32px) horizontal lane rendered above the glucose chart, inside the same ScrollView so it scrolls in sync with the chart. Contains all event markers (meals, insulin, exercise) that currently render as in-chart annotations.

### R2. Marker types with SF Symbol icons

Each marker type has a distinct icon and color:
- **Meals:** `fork.knife` in `AmberTheme.cgaGreen`
- **Insulin (bolus/correction):** `syringe.fill` in `AmberTheme.amberDark`
- **Exercise:** `figure.run` in `AmberTheme.cgaCyan`

Basal insulin stays on the chart as an AreaMark (not a marker lane item).

### R3. Scored meal visual distinction

Meals that have been glycemically scored (present in `scoredMealEntryIds`) display the `fork.knife` icon with a visual cue — slightly larger or with a subtle border — to indicate glycemic impact data is available.

### R4. Zoom-dependent consolidation

At narrow zoom levels (3h), all markers show individually. At wider zoom levels (6h, 12h, 24h), markers within a configurable time window merge into a consolidated group showing:
- The dominant type's icon
- A summary label (e.g. total carbs for meal groups)
- A badge count circle

Consolidation windows per zoom level (matching DOOMBTS):
- 3h: 0 (no consolidation)
- 6h: 10 minutes
- 12h: 20 minutes
- 24h: 30 minutes

### R5. Tap behavior

- **Single meal marker:** Toggle the meal impact overlay on the chart below (2hr band + delta + edit pencil). Same toggle behavior as the current in-chart meal diamond tap.
- **Single insulin marker:** Show confirmation dialog with delete option (existing behavior).
- **Single exercise marker:** No action for now (future: HealthKit deep-link, DMNC-715).
- **Consolidated group:** Expand an inline panel showing individual items. Tapping an item in the panel triggers the single-marker action and closes the panel.

### R6. Exercise marker display

Exercise markers show:
- Activity type (from HealthKit)
- Duration (e.g. "30m")

Future enhancements (deferred to DMNC-715):
- Intensity level
- External factors/activities
- HealthKit deep-link to the specific workout

### R7. Remove in-chart meal/insulin markers

The current meal `PointMark` diamonds with carb/description annotations and insulin `PointMark` with unit annotations move to the marker lane. Remove them from the Chart body.

Keep on chart:
- Exercise `RectangleMark` background shading (visual context for glucose correlation)
- Meal impact overlay (2hr band + delta annotation)
- IOB AreaMark
- Heart rate LineMark
- Predictive low projection line

### R8. Remove BG button from front action bar

Set `DirectConfig.bloodGlucoseInput = false` to hide the blood glucose quick action button from the overview action bar and lists view. Already done.

## Scope Boundaries

- No new marker types (heart rate, calibrations, etc.)
- No HealthKit deep-linking from exercise markers (DMNC-715)
- No alternative visualization styles (DMNC-715)
- No changes to the meal impact overlay behavior (already shipped)
- iOS 15 unaffected (ChartViewCompatibility has no markers)

## Key Decisions

- **Backport from DOOMBTS:** The implementation is adapted from DOOMBTS commit `4a5a5be0` with theme tokens swapped (DoomTheme → AmberTheme, DoomTypography → DOSTypography)
- **EventMarkerLaneView is a separate SwiftUI view:** Self-contained, receives data and callbacks, no store dependency. ChartView owns the data preparation and passes it down.
- **Marker types defined in ChartView:** `MarkerType`, `EventMarker`, and `ConsolidatedMarkerGroup` structs live at the bottom of ChartView.swift (same as DOOMBTS) since they're tightly coupled to chart data
- **Consolidation is recalculated on data change:** `updateMarkerGroups()` called alongside existing `updateMealSeries()` / `updateInsulinSeries()`

## Open Questions

- Q1: Should the marker lane have a subtle bottom border/separator, or just use spacing? **Decision: subtle 1px border in `AmberTheme.amberDark` opacity 0.3, matching DOOMBTS**
- Q2: Should tapping outside the expanded group panel dismiss it? **Decision: yes, same as DOOMBTS behavior**
