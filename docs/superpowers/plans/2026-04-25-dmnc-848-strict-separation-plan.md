# DMNC-848 Marker-Lane Position Plan (D7, v2 — post doc-review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow the user to choose whether the marker lane sits **above** or **below** the glucose chart. Default `.top` (matches today's placement — no behavior change for existing users unless they opt into bottom).

**Architecture (after doc-review):** Today's `EventMarkerLaneView` is the first child of an inner `VStack(spacing: 0)` (above the inner SwiftUI `Chart`). The IOB curve is rendered as `AreaMark` **inside** the same `Chart {}` block as glucose — it shares the chart canvas, not a separate stack child. Therefore the **"IOB sandwich" rule from the original brainstorm is dropped**: there is no separate IOB lane to sandwich. The toggle simply moves `EventMarkerLaneView` between two positions inside the existing `VStack`. No view extraction, no new `ChartSettingsView`, no new chart-area refactor.

**Tech Stack:** SwiftUI, Redux-like Store, UserDefaults persistence.

**Spec:** `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` D7. Note: D7's "cluster rule" (markers never sandwich IOB) is removed from this plan because the structural premise doesn't hold — IOB is in the chart canvas, not a sibling lane. The spec should be updated separately if the user wants to re-introduce IOB-related layout rules later.

**Doc-review revisions from v1:**
- Drop "IOB lane sandwich" framing — no such lane exists.
- Default `.top` (current placement) — no regression for existing users.
- Position toggle lives inside the existing inner `VStack(spacing: 0)`, not a refactored `chartArea`/`iobLane`/`markerLane` extraction.
- Use established settings inline-toggle pattern (like `showSmoothedGlucose` in `AdditionalSettingsView`) — no new `ChartSettingsView` file.
- Reducer test follows existing `directReducer(state:action:)` + `AppState()` pattern.

**Depends on:** Core plan's adapted `EventMarkerLaneView` (Phase 6 Task 10) — bare-icon visual + `onTapGroup` callback. The view name and prop surface stay; only visual changes. This plan can either ship before or after Core; if before, the toggle works against today's chip-bordered markers and adopts the bare icons when Core lands.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `Library/Content/MarkerLanePosition.swift` | Enum (`.top`, `.bottom`) with `rawValue: String`. |

### Modified files

| Path | Change |
|---|---|
| `Library/DirectState.swift` | `var markerLanePosition: MarkerLanePosition { get set }`. |
| `App/AppState.swift` | Backing storage + UserDefaults `didSet`. |
| `Library/Extensions/UserDefaults.swift` | `Keys.markerLanePosition` + computed property (default `.top`). |
| `Library/DirectAction.swift` | `case setMarkerLanePosition(position: MarkerLanePosition)`. |
| `Library/DirectReducer.swift` | Reducer case. |
| `App/Views/Overview/ChartView.swift` | Conditional ordering of the existing inner `VStack(spacing: 0)` children at lines 85-130. |
| `App/Views/Settings/AdditionalSettingsView.swift` | Add a `Picker` for the position (segmented style) inline — same pattern as existing `showSmoothedGlucose` toggle. |
| `DOSBTSTests/DirectReducerTests.swift` | Cover `setMarkerLanePosition`. |

---

## Task 1: MarkerLanePosition enum

**Files:**
- Create: `Library/Content/MarkerLanePosition.swift`

- [ ] **Step 1: Implement**

```swift
// Library/Content/MarkerLanePosition.swift
import Foundation

enum MarkerLanePosition: String, CaseIterable, Identifiable {
    case top
    case bottom

    var id: String { rawValue }
    var displayLabel: String {
        switch self {
        case .top: return "Above chart (default)"
        case .bottom: return "Below chart"
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

## Task 2: State + action + reducer + UserDefaults

**Files:**
- Modify: `Library/DirectState.swift`, `App/AppState.swift`, `Library/Extensions/UserDefaults.swift`, `Library/DirectAction.swift`, `Library/DirectReducer.swift`, `DOSBTSTests/DirectReducerTests.swift`

- [ ] **Step 1: Failing reducer test**

```swift
@Test("setMarkerLanePosition updates the preference")
func markerLanePosition() {
    var state = AppState()
    state.markerLanePosition = .top
    directReducer(state: &state, action: .setMarkerLanePosition(position: .bottom))
    #expect(state.markerLanePosition == .bottom)
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Wire**

```swift
// Library/DirectState.swift
var markerLanePosition: MarkerLanePosition { get set }
```

```swift
// App/AppState.swift
var markerLanePosition: MarkerLanePosition {
    didSet { UserDefaults.standard.markerLanePosition = markerLanePosition }
}
// init(): self.markerLanePosition = UserDefaults.standard.markerLanePosition
```

```swift
// Library/Extensions/UserDefaults.swift — Keys
case markerLanePosition

// Computed property — default .top so existing users see no change
var markerLanePosition: MarkerLanePosition {
    get { MarkerLanePosition(rawValue: string(forKey: Keys.markerLanePosition.rawValue) ?? "") ?? .top }
    set { set(newValue.rawValue, forKey: Keys.markerLanePosition.rawValue) }
}
```

```swift
// Library/DirectAction.swift
case setMarkerLanePosition(position: MarkerLanePosition)
```

```swift
// Library/DirectReducer.swift — inside switch
case .setMarkerLanePosition(let pos):
    state.markerLanePosition = pos
```

- [ ] **Step 4: Run test, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/DirectState.swift App/AppState.swift Library/Extensions/UserDefaults.swift Library/DirectAction.swift Library/DirectReducer.swift DOSBTSTests/DirectReducerTests.swift
git commit -m "feat: markerLanePosition state + action + persistence (default .top)"
```

---

## Task 3: ChartView reorders the inner VStack children based on position

**Files:**
- Modify: `App/Views/Overview/ChartView.swift` (the inner `VStack(spacing: 0)` at lines 85-130)

**Critical:** the conditional reorder must happen **inside** the existing inner `VStack(spacing: 0)` (where `EventMarkerLaneView` and the inner `Chart` are siblings). Reordering at an outer level would break the shared horizontal-scroll container and desync marker tap coordinates from the chart x-axis.

- [ ] **Step 1: Wrap the two children in a conditional ordering**

Today (paraphrased lines 85-130):
```swift
VStack(spacing: 0) {
    EventMarkerLaneView(markerGroups: ..., totalWidth: ..., ...)
    Chart {
        // glucose LineMarks, IOB AreaMark, HR LineMark (gated by D6 toggle), etc.
    }
    .chartXScale(...)
    .frame(height: ...)
}
```

After:
```swift
VStack(spacing: 0) {
    if store.state.markerLanePosition == .top {
        EventMarkerLaneView(markerGroups: ..., totalWidth: ..., ...)
    }
    Chart {
        // unchanged
    }
    .chartXScale(...)
    .frame(height: ...)
    if store.state.markerLanePosition == .bottom {
        EventMarkerLaneView(markerGroups: ..., totalWidth: ..., ...)
    }
}
```

Both invocations of `EventMarkerLaneView` pass identical props. `ScrollViewReader` and the outer `ScrollView` enclose the entire `VStack` so both positions remain inside the same horizontal scroll container — marker x-coordinates stay synced with the chart.

- [ ] **Step 2: Build**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 3: Run on simulator. Toggle position via Settings (Task 4). Confirm visual reorder; tap a marker in both positions and confirm the list overlay opens (taps stay aligned with chart x-axis).**

- [ ] **Step 4: Commit**

```bash
git add App/Views/Overview/ChartView.swift
git commit -m "feat: ChartView honours markerLanePosition (top | bottom)"
```

---

## Task 4: Inline picker in AdditionalSettingsView

**Files:**
- Modify: `App/Views/Settings/AdditionalSettingsView.swift`

- [ ] **Step 1: Add a Picker row near the existing chart-related toggles (e.g., near `showSmoothedGlucose`)**

```swift
// AdditionalSettingsView.swift — inside the existing chart-related Section
Picker("Marker lane", selection: Binding(
    get: { store.state.markerLanePosition },
    set: { store.dispatch(.setMarkerLanePosition(position: $0)) }
)) {
    ForEach(MarkerLanePosition.allCases) { position in
        Text(position.displayLabel).tag(position)
    }
}
.pickerStyle(.segmented)
```

- [ ] **Step 2: Build, run, navigate to Settings → Additional → toggle position. Confirm chart layout updates immediately.**

- [ ] **Step 3: Commit**

```bash
git add App/Views/Settings/AdditionalSettingsView.swift
git commit -m "feat: marker lane position picker in additional settings"
```

---

## Task 5: CHANGELOG entry

- [ ] **Step 1: Append to `[Unreleased]`**

```markdown
### Added
- Chart customisation: marker lane position toggle (above or below the glucose chart). Default is "above" — no change for existing users unless they opt into below. (DMNC-848 D7)
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — marker lane position toggle (D7)"
```

---

## Self-review

- [ ] **Spec coverage:** D7 toggle covered. The "IOB never sandwiched" rule is dropped from this plan because IOB is part of the glucose `Chart {}` canvas, not a separate lane — there is nothing to sandwich. If the spec wants a future cluster rule, a follow-up plan would extract the IOB AreaMark out of the glucose chart into its own view, which is a larger architectural move.
- [ ] **No GRDB changes.**
- [ ] **No new sheet presentations.**
- [ ] **Default `.top` — no regression** for existing users.
- [ ] **No phantom symbols:** plan does not reference non-existent `chartArea`, `iobLane`, `markerLane`, or `ChartSettingsView`.
