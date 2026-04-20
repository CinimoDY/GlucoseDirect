---
date: 2026-04-20
topic: widget-rework
---

# Widget Rework — Phosphor Display Style with Expanded Data

## Problem Frame

The widget suite feels like an afterthought. Only a small home screen widget exists with basic data. The visual style doesn't match the app's DOS amber CGA aesthetic. Lock screen widgets are minimal. The Live Activity shows glucose and trend but nothing else actionable. Users glance at widgets dozens of times a day — they should be as information-dense and visually cohesive as the app itself.

## Requirements

### R1. Phosphor display visual style

All widgets adopt the phosphor display aesthetic: glowing amber text on pure black, monospace fonts, subtle phosphor bloom (shadow) on the glucose value, no window chrome. Alarm states use red glow instead of amber.

### R2. Home screen widgets — three sizes

**Small (2x2):** Centered glucose value with phosphor glow, trend arrow, minute change, timestamp. Same data as current but with new styling.

**Medium (4x2):** Left side: large glucose with phosphor glow + trend. Right side: TIR percentage (color-coded), IOB value (cyan), last meal (description + carbs + time ago). Right-side data uses 13-14pt font minimum for readability.

**Large (4x4):** Top: glucose + trend + TIR/IOB/meal stats. Middle: 6-hour sparkline chart (SwiftUI Path polyline, ~12 points at 30-min intervals, alarm threshold dashed lines). Bottom: timestamp + sensor remaining lifetime.

### R3. Lock screen widgets

**Circular (Glucose):** Glucose value (24pt bold) + trend arrow below. iOS tints the color.

**Rectangular (Glucose):** Glucose value (32pt bold) + trend + minute change on first line. Second line: "TIR 78% · IOB 2.4U · 2m ago" — compact one-liner with all secondary metrics.

**Circular (Sensor):** Gauge arc showing remaining lifetime fraction. Days remaining + hours label. Unchanged layout, phosphor styling applied.

**Circular (Transmitter):** Gauge arc showing battery percentage. Transmitter name label. Unchanged layout, phosphor styling applied.

### R4. Live Activity — rich banner with sparkline

**Banner:** Left: glucose value (36pt bold, phosphor glow) + trend arrow. Center: mini sparkline (last 3h, ~6 points). Right: IOB value (cyan) + timestamp. Connection-lost state: strikethrough on glucose + red dot.

**Dynamic Island Compact:** Glucose value (leading) + trend + IOB (trailing).

**Dynamic Island Expanded:** Glucose value + trend + sparkline + IOB + timestamp.

**Dynamic Island Minimal:** Glucose value only.

### R5. Shared data expansion

WidgetCenter middleware writes additional data to App Group UserDefaults on each glucose update:

- `sharedTIR: Double` — current TIR percentage
- `sharedIOB: Double` — current IOB value
- `sharedLastMealDescription: String` — last meal name
- `sharedLastMealCarbs: Double` — last meal carbs
- `sharedLastMealTimestamp: Date` — last meal time
- `sharedGlucoseSparkline: [Int]` — sampled glucose values (last 6h, ~12 points)
- `sharedGlucoseSparklineTimestamps: [Date]` — corresponding timestamps

### R6. Alarm and data states

**Glucose alarm colors:**
- Normal: amber phosphor glow
- Low/High: red phosphor glow, value in cgaRed

**Data freshness:**
- Fresh (< 5 min): normal display
- Stale (5-14 min): dim amber, prominent "X MIN AGO"
- Very stale (15+ min): red timestamp, glucose value dims

**Missing data:**
- No glucose: `---` placeholder, dim trend
- No IOB: `--` for IOB field
- No meal logged: hide meal line entirely
- No sparkline data: hide chart area, expand glucose section
- No sensor: "NO SENSOR" label, gauge shows 0%
- First install (no data): `---` with "OPEN APP"

**Live Activity specific:**
- Connection lost: strikethrough on glucose, red dot indicator
- Restart needed: "REOPEN APP" replaces timestamp

### R7. Widget design system file

New `Widgets/WidgetDesignSystem.swift` with shared phosphor glow modifiers, amber/red/cyan/green color constants (mirroring `AmberTheme` values — widget target can't import app's design system), monospace font helpers, and sparkline Path builder.

## Architecture

### Data flow

```
App (glucose update) → WidgetCenter middleware → App Group UserDefaults
                                                      ↓
Widget Timeline Provider reads UserDefaults → Widget View renders
```

### Files to modify

| File | Change |
|------|--------|
| `App/Modules/WidgetCenter/WidgetCenter.swift` | Add shared data writes (TIR, IOB, meal, sparkline) |
| `Library/Extensions/UserDefaults.swift` | Add App Group keys for new shared data |
| `Widgets/GlucoseWidget.swift` | Add medium/large families, rework all layouts |
| `Widgets/GlucoseActivityWidget.swift` | Rework Live Activity + Dynamic Island |
| `Widgets/SensorWidget.swift` | Phosphor styling pass |
| `Widgets/TransmitterWidget.swift` | Phosphor styling pass |

### Files to create

| File | Purpose |
|------|---------|
| `Widgets/WidgetDesignSystem.swift` | Shared colors, fonts, phosphor glow, sparkline builder |

### Sparkline implementation

SwiftUI `Path` polyline — no Swift Charts (requires iOS 16, deployment target is 15). The path draws ~12 points with alarm threshold dashed lines (high/low). Color: amber stroke, no fill. Points sampled at 30-min intervals from the shared sparkline array.

For the Live Activity mini sparkline: same approach but fewer points (~6, last 3h) and smaller frame.

### Timeline provider

Existing `GlucoseUpdateProvider` reloads every 15 minutes. New shared data piggybacks on the same UserDefaults — no provider changes needed beyond reading new keys in the entry struct.

## Scope Boundaries

**In scope:**
- Visual rework of all 4 widget files with phosphor display style
- New systemMedium and systemLarge home screen widgets
- Shared data expansion via App Group UserDefaults
- Sparkline via SwiftUI Path (iOS 15 compatible)
- Reworked Live Activity + Dynamic Island with sparkline + IOB
- Widget design system file
- All alarm/stale/missing data states

**Out of scope:**
- Interactive widgets (WidgetKit intents / app intent configuration)
- Widget configuration screen
- StandBy mode / iPad-specific layouts
- New widget types (digest widget, stats widget)
- WidgetCenter middleware changes beyond adding shared data keys
