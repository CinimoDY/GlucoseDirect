# Dev Journal: DOSBTS UI Overhaul — Libre-Inspired Layout

**Session:** dosbts-ui-overhaul
**Date:** 2026-03-22
**Build shipped:** 46
**Commit:** 81a0e255

---

## Overview

Libre-inspired layout overhaul: hero glucose display flows directly into the chart (no interrupting buttons or redundant headers), report type selector adds Time In Range and Statistics views alongside the glucose chart, and a new sensor disc app icon replaces the old pen+blood drop.

## Changes

### 1. Layout Reorder (OverviewView.swift)

Previous order: hero → buttons → chart → connection → sensor. The MEAL/INSULIN buttons between the hero and chart broke the visual flow — the most important data (current glucose → recent trend) was split by action controls.

New order: hero → chart → buttons → connection → sensor. Matches FreeStyle Libre 3 layout where the glucose reading flows directly into the chart. Button order swapped to INSULIN | MEAL (insulin is the more time-sensitive action for CGM users).

### 2. Timestamp Removal (GlucoseView.swift)

Removed `Text(latestGlucose.timestamp, style: .time)` and `Text(Date(), style: .time)` from the hero display. The OS already shows time in the status bar — duplicating it wastes vertical space in the most valuable screen area. Kept the glucose unit label (mg/dL) since that context isn't shown elsewhere.

### 3. Chart Section Header Removal (ChartView.swift)

Removed `Label("Chart", systemImage: "chart.xyaxis.line")` section header. The chart is self-explanatory — the header was just noise.

### 4. Report Type Selector (ChartView.swift)

Added horizontal pill selector above the chart: GLUCOSE (default) | TIME IN RANGE | STATISTICS. Styled to match the existing zoom level selector (small monospace text + circle indicators).

- **GLUCOSE**: existing chart view, unchanged
- **TIME IN RANGE**: horizontal TAR/TIR/TBR bars using `GlucoseStatistics` data, with percentage labels
- **STATISTICS**: AVG, SD, CV, GMI, readings summary table

All three views pull from `store.state.glucoseStatistics` — no new state or middleware needed.

### 5. New App Icon (generate_icon.py)

Replaced pen + blood drop + chart icon with a CGM sensor disc:
- Concentric circles (outer ring with adhesive tick marks, inner housing ring, center filament dot)
- Chart line below (glucose trace zigzag)
- Small fork+knife accent (food logging)
- Amber (#FFB000) on black, matching DOS theme

The sensor disc shape is recognizable to CGM users and matches competitor icons (Libre, GlucoseDirect).

### Architecture Decisions

- **Report type selector uses @State, not Redux** — purely UI-local state, no need to persist tab selection across app restarts
- **GlucoseChartContent extracted to computed property** — the switch on report type required pulling the chart content out of the inline Section closure
- **TimeInRangeBar uses GeometryReader** — proportional bar widths relative to container, not fixed pixel widths
- **StatRow as function returning View** — simple helper, no separate struct needed

---

## Session Summary

**Date:** 2026-03-22
**Build shipped:** 46
**Files changed:** 25 (3 Swift views + pbxproj + 19 icon PNGs + icon generator)
