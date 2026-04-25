# DMNC-848 HR Overlay Plan (D6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the user's HealthKit heart-rate series as a magenta dashed line overlaid on the glucose chart, with an end-of-line numeric readout and a settings toggle. Relative-scaled (no separate y-axis).

**Architecture:** New `showHeartRateOverlay` Bool in state (UserDefaults-backed). `setHeartRateSeries` action already exists (`Library/DirectAction.swift:79`). Add chart `LineMark` + end-of-line `PointMark` overlay in `ChartView`, gated by the new toggle. Settings switch alongside the existing HealthKit integration toggle.

**Tech Stack:** SwiftUI Charts, Combine, Redux-like Store, UserDefaults persistence.

**Spec:** `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` D6.

**Out of scope:** HR-resting-rate calibrated to glucose-100 line. Stays as a follow-up Linear issue. v1 is relative-scaled only.

**Depends on:** None — D6 is orthogonal to the core unified-entry plan. Can ship independently.

---

## File Structure

### Modified files

| Path | Change |
|---|---|
| `Library/DirectState.swift` | Add `var showHeartRateOverlay: Bool { get set }`. |
| `App/AppState.swift` | Add backing property + `didSet` UserDefaults persistence. |
| `Library/Extensions/UserDefaults.swift` | Add `Keys.showHeartRateOverlay` + computed property. |
| `Library/DirectAction.swift` | Add `case setShowHeartRateOverlay(enabled: Bool)`. |
| `Library/DirectReducer.swift` | Handle the new action. |
| `App/Views/Overview/ChartView.swift` | Add `LineMark` for HR series + end-of-line `PointMark` + readout text, gated by `showHeartRateOverlay`. |
| `App/Views/Settings/HealthKitSettingsView.swift` | Add toggle row for `showHeartRateOverlay`. |
| `DOSBTSTests/DirectReducerTests.swift` | Cover the new action. |

### New files

| Path | Responsibility |
|---|---|
| `App/Views/Overview/HRChartOverlay.swift` | Optional helper view containing the HR `LineMark` + readout (extracted to keep ChartView body manageable). |

---

## Task 1: Add toggle state

**Files:**
- Modify: `Library/DirectState.swift` (add protocol property)
- Modify: `App/AppState.swift` (add storage + didSet)
- Modify: `Library/Extensions/UserDefaults.swift` (add Keys + computed property)
- Modify: `Library/DirectAction.swift` (add action case)
- Modify: `Library/DirectReducer.swift` (add reducer case)
- Modify: `DOSBTSTests/DirectReducerTests.swift` (test the reducer case)

- [ ] **Step 1: Write failing reducer test**

```swift
// DOSBTSTests/DirectReducerTests.swift — add to existing suite
@Test("setShowHeartRateOverlay toggles the flag")
func toggleHROverlay() {
    var state = AppState()
    state.showHeartRateOverlay = false
    DirectReducer.reducer(state: &state, action: .setShowHeartRateOverlay(enabled: true))
    #expect(state.showHeartRateOverlay == true)
    DirectReducer.reducer(state: &state, action: .setShowHeartRateOverlay(enabled: false))
    #expect(state.showHeartRateOverlay == false)
}
```

- [ ] **Step 2: Run test, expect FAIL.**

- [ ] **Step 3: Add the protocol property, storage, UserDefaults, action, reducer**

```swift
// Library/DirectState.swift — alongside other booleans
var showHeartRateOverlay: Bool { get set }
```

```swift
// App/AppState.swift
var showHeartRateOverlay: Bool {
    didSet {
        UserDefaults.standard.showHeartRateOverlay = showHeartRateOverlay
    }
}

// In init:
self.showHeartRateOverlay = UserDefaults.standard.showHeartRateOverlay
```

```swift
// Library/Extensions/UserDefaults.swift — Keys enum
case showHeartRateOverlay

// computed property
var showHeartRateOverlay: Bool {
    get { bool(forKey: Keys.showHeartRateOverlay.rawValue) }
    set { set(newValue, forKey: Keys.showHeartRateOverlay.rawValue) }
}
```

```swift
// Library/DirectAction.swift — alphabetical position
case setShowHeartRateOverlay(enabled: Bool)
```

```swift
// Library/DirectReducer.swift — inside switch
case .setShowHeartRateOverlay(let enabled):
    state.showHeartRateOverlay = enabled
```

- [ ] **Step 4: Run test, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/DirectState.swift App/AppState.swift Library/Extensions/UserDefaults.swift Library/DirectAction.swift Library/DirectReducer.swift DOSBTSTests/DirectReducerTests.swift
git commit -m "feat: add showHeartRateOverlay state + toggle action"
```

---

## Task 2: HR overlay rendering on the chart

**Files:**
- Create: `App/Views/Overview/HRChartOverlay.swift`
- Modify: `App/Views/Overview/ChartView.swift` (compose the overlay into the chart body)

- [ ] **Step 1: Implement `HRChartOverlay`**

```swift
// App/Views/Overview/HRChartOverlay.swift
import SwiftUI
import Charts

struct HRChartOverlay: ChartContent {
    let series: [(Date, Double)]
    let yRange: ClosedRange<Double>          // chart's current glucose y-extent
    let hrRange: ClosedRange<Double>         // user's HR range (e.g., 50–180 bpm)

    var body: some ChartContent {
        ForEach(series, id: \.0) { (timestamp, bpm) in
            LineMark(
                x: .value("Time", timestamp),
                y: .value("HR (scaled)", scaledY(for: bpm))
            )
            .foregroundStyle(AmberTheme.cgaMagenta)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .interpolationMethod(.linear)
        }
        if let last = series.last {
            PointMark(
                x: .value("Time", last.0),
                y: .value("HR", scaledY(for: last.1))
            )
            .foregroundStyle(AmberTheme.cgaMagenta)
            .symbol(.circle)
            .symbolSize(30)
            .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                Text("\(Int(last.1))")
                    .font(DOSTypography.caption)
                    .foregroundStyle(AmberTheme.cgaMagenta)
            }
        }
    }

    /// Maps HR value into the chart's vertical extent, proportional to user's range.
    private func scaledY(for bpm: Double) -> Double {
        let normalised = (bpm - hrRange.lowerBound) / (hrRange.upperBound - hrRange.lowerBound)
        return yRange.lowerBound + normalised * (yRange.upperBound - yRange.lowerBound)
    }
}
```

Add `cgaMagenta` to `AmberTheme`:

```swift
// Library/DesignSystem/AmberTheme.swift
public static let cgaMagenta = Color(red: 1.0, green: 85.0 / 255.0, blue: 1.0)  // #ff55ff
```

- [ ] **Step 2: Compose into the chart**

```swift
// ChartView.swift — inside the Chart {} body, after existing sensor LineMark
if store.state.showHeartRateOverlay && !store.state.heartRateSeries.isEmpty {
    HRChartOverlay(
        series: store.state.heartRateSeries.filter { $0.0 >= chartStartDate && $0.0 <= chartEndDate },
        yRange: 40...300,    // glucose chart y-extent
        hrRange: hrRangeForUser()
    )
}
```

Compute `hrRangeForUser()`:

```swift
// ChartView.swift — helper
private func hrRangeForUser() -> ClosedRange<Double> {
    let bpms = store.state.heartRateSeries.map(\.1)
    let lo = max(40, bpms.min() ?? 50)
    let hi = min(220, bpms.max() ?? 180)
    return lo...hi
}
```

- [ ] **Step 3: Build app, expect success**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 4: Run on simulator with HealthKit Import enabled and HR data present. Toggle `showHeartRateOverlay` → magenta dashed line + end-of-line readout appear/disappear.**

- [ ] **Step 5: Commit**

```bash
git add App/Views/Overview/HRChartOverlay.swift App/Views/Overview/ChartView.swift Library/DesignSystem/AmberTheme.swift
git commit -m "feat: HR overlay on glucose chart (relative-scaled, magenta dashed)"
```

---

## Task 3: Settings toggle

**Files:**
- Modify: `App/Views/Settings/HealthKitSettingsView.swift` (add the toggle row)

- [ ] **Step 1: Add a toggle row near the existing HealthKit Import toggle**

```swift
// HealthKitSettingsView.swift — inside the settings Form
Toggle(isOn: Binding(
    get: { store.state.showHeartRateOverlay },
    set: { store.dispatch(.setShowHeartRateOverlay(enabled: $0)) }
)) {
    VStack(alignment: .leading) {
        Text("HR overlay")
        Text("Show heart rate on the chart")
            .font(DOSTypography.caption)
            .foregroundStyle(AmberTheme.amberDark)
    }
}
```

- [ ] **Step 2: Build app, expect success.**

- [ ] **Step 3: Run on simulator, navigate to Settings → HealthKit. Toggle on/off. Confirm chart overlay tracks the toggle.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/Settings/HealthKitSettingsView.swift
git commit -m "feat: HR overlay settings toggle"
```

---

## Task 4: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Append to `[Unreleased]`**

```markdown
### Added
- Heart rate overlay on glucose chart (magenta dashed line, relative-scaled). Toggle in Settings → HealthKit. (DMNC-848 D6)
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — HR overlay (D6)"
```

---

## Self-review

- [ ] Spec coverage: D6 fully covered (toggle, rendering, settings, no calibration). Calibration stays out.
- [ ] No GRDB changes — `setHeartRateSeries` action already populated by HealthKit middleware.
- [ ] No new sheet presentations.
- [ ] Type consistency: `cgaMagenta` defined once in `AmberTheme`.
