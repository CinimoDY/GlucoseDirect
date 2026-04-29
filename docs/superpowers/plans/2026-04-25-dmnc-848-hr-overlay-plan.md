# DMNC-848 HR Overlay Plan (D6, v2 — post doc-review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Gate the existing always-on HR overlay behind a `showHeartRateOverlay` setting, add an end-of-line numeric readout, and place the toggle alongside the Apple Health import switch.

**Architecture (after doc-review):** The HR `LineMark` already exists in `ChartView.swift:699-710` (cgaMagenta dashed, opacity 0.3, unit-aware scaling via existing `chartMinimum`/`alarmHigh` formula). `cgaMagenta` already in `AmberTheme.swift:43`. `setHeartRateSeries` action + `heartRateSeries` state already exist. **Nothing new to build for the line itself** — only gate the existing rendering, add a readout, add the toggle.

**Tech Stack:** SwiftUI Charts, Redux-like Store, UserDefaults persistence.

**Spec:** `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` D6.

**Doc-review revisions from v1:**
- Acknowledge HR rendering already exists; do not add a new `HRChartOverlay`.
- Drop adding `cgaMagenta` (already defined).
- Toggle home is `AppleExportSettingsView.swift`, not the non-existent `HealthKitSettingsView.swift`.
- Reuse the existing unit-aware scaling formula; do not invent `40...300` hardcode.
- Handle empty/single-point/stale HR series.
- Default `false` (per brainstorm); document the visible-behavior change in CHANGELOG.
- Use existing `firstTimestamp`/`lastTimestamp` for time bounds; no `chartStartDate`/`chartEndDate` invention.

**Out of scope:** HR-resting calibration to glucose-100 line — separate follow-up.

---

## File Structure

| Path | Change |
|---|---|
| `Library/DirectState.swift` | Add `var showHeartRateOverlay: Bool { get set }`. |
| `App/AppState.swift` | Backing storage + UserDefaults `didSet`. |
| `Library/Extensions/UserDefaults.swift` | `Keys.showHeartRateOverlay` + computed property. |
| `Library/DirectAction.swift` | `case setShowHeartRateOverlay(enabled: Bool)`. |
| `Library/DirectReducer.swift` | Reducer case. |
| `App/Views/Overview/ChartView.swift` | Wrap existing HR `LineMark` (lines 699-710) and HR legend chip (lines 70-79) and HR tooltip/selection logic (lines 134, 181-193) in `if store.state.showHeartRateOverlay`. Add end-of-line `PointMark` + readout when enabled. |
| `App/Views/Settings/AppleExportSettingsView.swift` | Add toggle row inside the existing `if store.state.appleHealthImport { … }` block. |
| `DOSBTSTests/DirectReducerTests.swift` | Cover `setShowHeartRateOverlay`. |
| `CHANGELOG.md` | "Changed: HR overlay is now toggleable; default off (was always on for users on build ≤ 62)." |

---

## Task 1: Add toggle state + reducer test

**Files:**
- Modify: `Library/DirectState.swift`, `App/AppState.swift`, `Library/Extensions/UserDefaults.swift`, `Library/DirectAction.swift`, `Library/DirectReducer.swift`, `DOSBTSTests/DirectReducerTests.swift`

- [ ] **Step 1: Failing reducer test (use `directReducer(state:action:)` and `AppState()` no-arg per existing pattern in DirectReducerTests.swift)**

```swift
@Test("setShowHeartRateOverlay toggles the flag")
func toggleHROverlay() {
    var state = AppState()
    state.showHeartRateOverlay = false
    directReducer(state: &state, action: .setShowHeartRateOverlay(enabled: true))
    #expect(state.showHeartRateOverlay == true)
    directReducer(state: &state, action: .setShowHeartRateOverlay(enabled: false))
    #expect(state.showHeartRateOverlay == false)
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Wire the property + action + reducer + UserDefaults**

```swift
// Library/DirectState.swift
var showHeartRateOverlay: Bool { get set }
```

```swift
// App/AppState.swift
var showHeartRateOverlay: Bool {
    didSet { UserDefaults.standard.showHeartRateOverlay = showHeartRateOverlay }
}
// In init(): self.showHeartRateOverlay = UserDefaults.standard.showHeartRateOverlay
```

```swift
// Library/Extensions/UserDefaults.swift — add to Keys enum:
case showHeartRateOverlay

// Computed property:
var showHeartRateOverlay: Bool {
    get { bool(forKey: Keys.showHeartRateOverlay.rawValue) }  // defaults to false (per brainstorm)
    set { set(newValue, forKey: Keys.showHeartRateOverlay.rawValue) }
}
```

```swift
// Library/DirectAction.swift — alphabetical
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
git commit -m "feat: add showHeartRateOverlay state + toggle action (default off)"
```

---

## Task 2: Gate the existing HR rendering + add end-of-line readout

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

- [ ] **Step 1: Wrap the existing HR rendering in `if store.state.showHeartRateOverlay`**

In `ChartView.swift`:
1. Lines 70-79 (HR legend chip): wrap in `if store.state.showHeartRateOverlay && !store.state.heartRateSeries.isEmpty`.
2. Lines 134, 181-193 (HR tooltip/selection): wrap in `if store.state.showHeartRateOverlay`.
3. Lines 699-710 (the HR `LineMark` `ForEach`): wrap in `if store.state.showHeartRateOverlay`. Keep the existing scaling formula `((point.1 - 40) / (200 - 40)) * (chartMinimum - alarmHigh) + alarmHigh` — it's unit-aware (mg/dL vs mmol/L) via `chartMinimum`. Keep `cgaMagenta.opacity(0.3)` line styling.

- [ ] **Step 2: Add end-of-line `PointMark` + readout**

Inside the same `if store.state.showHeartRateOverlay` block as the LineMark, append:

```swift
if let last = store.state.heartRateSeries.last {
    PointMark(
        x: .value("Time", last.0),
        y: .value("HR", scaledHR(last.1))   // reuse the same scaling formula as the LineMark
    )
    .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.7))
    .symbol(.circle)
    .symbolSize(30)
    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
        Text("\(Int(last.1))")
            .font(DOSTypography.caption)
            .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.7))
    }
}
```

Helper (extract the shared scaling expression to avoid duplicating it):

```swift
private func scaledHR(_ bpm: Double) -> Double {
    ((bpm - 40) / (200 - 40)) * (chartMinimum - alarmHigh) + alarmHigh
}
```

(Use existing `chartMinimum`, `alarmHigh` references that ChartView already has.)

- [ ] **Step 3: Stale-data guard for the readout**

Above the PointMark, gate the readout when the latest HR sample is older than 10 minutes (HealthKit can lag):

```swift
if let last = store.state.heartRateSeries.last,
   Date().timeIntervalSince(last.0) < 10 * 60 {
    // PointMark + annotation as above
}
```

- [ ] **Step 4: Build app**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 5: Run on simulator with HealthKit Import on + HR samples available. Toggle `showHeartRateOverlay` via Settings (next task) → magenta dashed line + readout appear/disappear.**

- [ ] **Step 6: Commit**

```bash
git add App/Views/Overview/ChartView.swift
git commit -m "feat: gate HR overlay behind showHeartRateOverlay + add end-of-line readout"
```

---

## Task 3: Settings toggle in AppleExportSettingsView

**Files:**
- Modify: `App/Views/Settings/AppleExportSettingsView.swift`

- [ ] **Step 1: Add toggle row inside the existing import section (lines 40-57)**

Place the new `Toggle` inside the existing `if store.state.appleHealthImport { … }` block so it only appears when import is active and HR data actually flows:

```swift
// AppleExportSettingsView.swift — inside the import section
Toggle(isOn: Binding(
    get: { store.state.showHeartRateOverlay },
    set: { store.dispatch(.setShowHeartRateOverlay(enabled: $0)) }
)) {
    VStack(alignment: .leading, spacing: 2) {
        Text("HR overlay on chart")
            .font(DOSTypography.body)
        Text("Magenta dashed line + current bpm")
            .font(DOSTypography.caption)
            .foregroundStyle(AmberTheme.amberDark)
    }
}
```

- [ ] **Step 2: Build, run on simulator, navigate to Settings → Apple Health import → toggle on/off → confirm chart overlay tracks the toggle.**

- [ ] **Step 3: Commit**

```bash
git add App/Views/Settings/AppleExportSettingsView.swift
git commit -m "feat: HR overlay settings toggle in AppleExportSettingsView"
```

---

## Task 4: CHANGELOG entry

- [ ] **Step 1: Append to `[Unreleased]`**

```markdown
### Changed
- Heart rate overlay on the glucose chart is now toggleable (Settings → Apple Health import → "HR overlay on chart"). Default is **off** to give users explicit control. If you saw the magenta HR line on prior builds and want it back, enable the toggle. (DMNC-848 D6)

### Added
- End-of-line numeric BPM readout on the HR overlay (when enabled and HR data is fresh within the last 10 minutes).
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — HR overlay toggle (D6)"
```

---

## Self-review

- [ ] **Spec coverage:** D6 covered. The LineMark already shipped; the spec's "ship HR as relative-scaled magenta dashed line" is satisfied by the existing rendering. The new work is the toggle + readout. Calibration to glucose-100 stays a follow-up.
- [ ] **No phantom symbols:** plan does not reference `HealthKitSettingsView`, `HRChartOverlay`, `chartStartDate`/`chartEndDate`, hardcoded `40...300` y-range, or duplicate `cgaMagenta` definition.
- [ ] **No GRDB changes.**
- [ ] **Behavior-regression call-out:** users on build 62 saw HR always-on; this build defaults it off. Documented in CHANGELOG.
