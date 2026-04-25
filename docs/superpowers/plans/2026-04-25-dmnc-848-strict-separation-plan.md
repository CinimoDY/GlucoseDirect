# DMNC-848 Strict-Separation Customisation Plan (D7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the user to choose whether the chart marker lane sits at the top or bottom of the chart stack. Marker groups never sandwich the IOB lane (cluster rule).

**Architecture:** New `markerLanePosition` enum in state (UserDefaults-backed, default `.bottom`). `ChartView` reads the preference and reorders its vertical layout accordingly. The IOB lane stays adjacent to the chart on the opposite side from the marker lane.

**Tech Stack:** SwiftUI, Redux-like Store, UserDefaults persistence.

**Spec:** `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` D7.

**Depends on:** Core unified-entry plan (Task 12 `MarkerLaneView`) — needs to land first so `MarkerLaneView` exists to be repositioned.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `Library/Content/MarkerLanePosition.swift` | Enum (`.bottom`, `.top`) with `rawValue: String` for UserDefaults storage. |

### Modified files

| Path | Change |
|---|---|
| `Library/DirectState.swift` | Add `var markerLanePosition: MarkerLanePosition { get set }`. |
| `App/AppState.swift` | Backing storage + UserDefaults `didSet`. |
| `Library/Extensions/UserDefaults.swift` | `Keys.markerLanePosition` + computed property. |
| `Library/DirectAction.swift` | `case setMarkerLanePosition(position: MarkerLanePosition)`. |
| `Library/DirectReducer.swift` | Handle the new action. |
| `App/Views/Overview/ChartView.swift` | Honour `markerLanePosition` when laying out chart + IOB + marker lane. |
| `App/Views/Settings/ChartSettingsView.swift` (or new file if absent) | Picker for the position. |
| `DOSBTSTests/DirectReducerTests.swift` | Cover the new action. |

---

## Task 1: MarkerLanePosition enum

**Files:**
- Create: `Library/Content/MarkerLanePosition.swift`

- [ ] **Step 1: Implement the enum**

```swift
// Library/Content/MarkerLanePosition.swift
import Foundation

enum MarkerLanePosition: String, CaseIterable, Identifiable {
    case bottom
    case top

    var id: String { rawValue }
    var displayLabel: String {
        switch self {
        case .bottom: return "Bottom (default)"
        case .top: return "Top"
        }
    }
}
```

- [ ] **Step 2: Build, expect success.**

- [ ] **Step 3: Commit**

```bash
git add Library/Content/MarkerLanePosition.swift
git commit -m "feat: MarkerLanePosition enum"
```

---

## Task 2: State + action + reducer

**Files:**
- Modify: `Library/DirectState.swift`
- Modify: `App/AppState.swift`
- Modify: `Library/Extensions/UserDefaults.swift`
- Modify: `Library/DirectAction.swift`
- Modify: `Library/DirectReducer.swift`
- Modify: `DOSBTSTests/DirectReducerTests.swift`

- [ ] **Step 1: Write failing reducer test**

```swift
// DOSBTSTests/DirectReducerTests.swift
@Test("setMarkerLanePosition updates the preference")
func markerLanePosition() {
    var state = AppState()
    state.markerLanePosition = .bottom
    DirectReducer.reducer(state: &state, action: .setMarkerLanePosition(position: .top))
    #expect(state.markerLanePosition == .top)
}
```

- [ ] **Step 2: Run test, expect FAIL.**

- [ ] **Step 3: Wire the property + action + reducer + UserDefaults**

```swift
// Library/DirectState.swift
var markerLanePosition: MarkerLanePosition { get set }
```

```swift
// App/AppState.swift
var markerLanePosition: MarkerLanePosition {
    didSet { UserDefaults.standard.markerLanePosition = markerLanePosition }
}

// init:
self.markerLanePosition = UserDefaults.standard.markerLanePosition
```

```swift
// Library/Extensions/UserDefaults.swift — Keys
case markerLanePosition

// computed property
var markerLanePosition: MarkerLanePosition {
    get { MarkerLanePosition(rawValue: string(forKey: Keys.markerLanePosition.rawValue) ?? "") ?? .bottom }
    set { set(newValue.rawValue, forKey: Keys.markerLanePosition.rawValue) }
}
```

```swift
// Library/DirectAction.swift
case setMarkerLanePosition(position: MarkerLanePosition)
```

```swift
// Library/DirectReducer.swift
case .setMarkerLanePosition(let pos):
    state.markerLanePosition = pos
```

- [ ] **Step 4: Run test, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/DirectState.swift App/AppState.swift Library/Extensions/UserDefaults.swift Library/DirectAction.swift Library/DirectReducer.swift DOSBTSTests/DirectReducerTests.swift
git commit -m "feat: markerLanePosition state + action + persistence"
```

---

## Task 3: ChartView honours marker-lane position

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

- [ ] **Step 1: Refactor the chart layout to a `Group` driven by `markerLanePosition`**

In ChartView's body, replace the existing fixed vertical order (chart → IOB → MarkerLane) with:

```swift
// ChartView.swift — body
VStack(spacing: 0) {
    if store.state.markerLanePosition == .top {
        markerLane
    }
    chartArea           // existing chart + axes
    iobLane             // existing IOB AreaMark wrapper
    if store.state.markerLanePosition == .bottom {
        markerLane
    }
}
```

The cluster rule is enforced structurally: marker lane is either at the very top or very bottom; IOB lane sits adjacent to the chart on the opposite side. There is no path where IOB is sandwiched between marker lane and chart.

- [ ] **Step 2: Build, expect success.**

- [ ] **Step 3: Run on simulator. Toggle `markerLanePosition` via Settings (Task 4). Confirm visual reorder. Confirm IOB stays adjacent to chart. Confirm marker tap still routes to list overlay (Core plan Task 17).**

- [ ] **Step 4: Commit**

```bash
git add App/Views/Overview/ChartView.swift
git commit -m "feat: ChartView honours markerLanePosition (top | bottom)"
```

---

## Task 4: Settings picker

**Files:**
- Modify: `App/Views/Settings/ChartSettingsView.swift` (or wherever chart-customisation settings live; create the file if absent)

- [ ] **Step 1: Add a Picker for the position**

```swift
// ChartSettingsView.swift — inside the chart-customisation section
Section("Marker lane position") {
    Picker("Position", selection: Binding(
        get: { store.state.markerLanePosition },
        set: { store.dispatch(.setMarkerLanePosition(position: $0)) }
    )) {
        ForEach(MarkerLanePosition.allCases) { position in
            Text(position.displayLabel).tag(position)
        }
    }
    .pickerStyle(.segmented)
}
```

If `ChartSettingsView` doesn't exist yet, create it as a sibling of `HealthKitSettingsView` and add it to the main `SettingsView` navigation.

- [ ] **Step 2: Build, expect success.**

- [ ] **Step 3: Run on simulator. Settings → Chart → toggle position. Confirm chart layout updates immediately.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/Settings/ChartSettingsView.swift App/Views/SettingsView.swift
git commit -m "feat: marker lane position picker in chart settings"
```

---

## Task 5: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Append to `[Unreleased]`**

```markdown
### Added
- Chart customisation: marker lane position (top or bottom). IOB lane never sandwiched between marker lane and chart. (DMNC-848 D7)
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — marker lane position toggle (D7)"
```

---

## Self-review

- [ ] Spec coverage: D7 fully covered. Cluster rule is enforced by structure (vertical layout never places marker lane between chart and IOB lane).
- [ ] No GRDB changes.
- [ ] No new sheet presentations.
- [ ] Default is `.bottom` — no behavioural change for users who never toggle.
- [ ] Depends on Core plan Task 12 (`MarkerLaneView`) — must land first.
