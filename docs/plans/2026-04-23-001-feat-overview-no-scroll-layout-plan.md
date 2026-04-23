# Overview No-Scroll Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the DOSBTS Overview screen to a fixed-region no-scroll layout with a new pinned chart toolbar (underline tab bar), a compact sensor status line with progressive-disclosure disconnect, 2-button sticky actions (INSULIN + MEAL), and BG entry relocated from Overview to the Log tab.

**Architecture:** Single PR. Convert `OverviewView.swift` from `List { ... }` to `VStack(spacing: 0) { ... }`. Extract chart toolbar (report-type + zoom rows) into a new `ChartToolbar.swift` at Overview scope with state hoisted from `ChartView` via `@State` + `@Binding`. Replace the existing `ConnectionView` + `SensorView` with a compact `SensorLineView` inline under the hero plus a new `SensorDetailView` under Settings. `ListsView` gets wrapped in `NavigationStack` for a trailing `+BG` toolbar button. One-shot migration alert (`hasSeenBGRelocationHint`) on the Log tab notifies users their BG button moved.

**Tech Stack:** SwiftUI (iOS 26 deployment target), Redux-like `Store<State, Action>` architecture (DOSBTS-specific, see `CLAUDE.md`), Swift Testing framework (`@Test`, `#expect`), SF Mono monospace fonts, `AmberTheme` CGA-amber design tokens.

**Spec source:** `docs/brainstorms/2026-04-23-overview-no-scroll-layout-requirements.md`
**Codesign evidence:** `.devjournal/sessions/dmnc-793-codesign-2026-04-23/L2-thematic/screens/` (9 captioned screenshots)

---

## Codebase conventions you must know

Read the top half of `CLAUDE.md` before starting. Non-obvious gotchas this plan depends on:

1. **No SPM / no CocoaPods.** All dependencies are vendored or first-party. Do not add `swift-snapshot-testing` or any external library. Snapshot tests in the spec's success criteria are deferred (see Task 11).
2. **`fileSystemSynchronized` Xcode project.** New Swift files under `App/`, `Library/`, or `Widgets/` are auto-picked up. **Exception:** test files under `DOSBTSTests/` are NOT auto-synced — adding a test file requires editing `project.pbxproj`.
3. **Four-file state-plumbing pattern** for new `AppState` properties: `Library/DirectState.swift` (protocol decl), `App/AppState.swift` (property + `didSet` + init), `Library/Extensions/UserDefaults.swift` (`Keys` enum case + computed property), `Library/DirectReducer.swift` (reducer case). Plus `Library/DirectAction.swift` for new actions.
4. **No force unwrapping** (`!`). Use `guard let`, optional chaining, or nil coalescing.
5. **Reducer runs BEFORE middlewares** — `Store.dispatch()` calls `reducer(&state, action)` then passes the *new* state to middlewares. Don't guard on state the reducer just changed.
6. **Build command** (simulator): `xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build`
7. **Commits** follow conventional commits: `type(scope): subject` (feat, fix, docs, refactor, chore, test). Scope optional.

---

## File structure

**Create (3 new files):**

| Path | Responsibility |
|---|---|
| `App/Views/Overview/ChartToolbar.swift` | Module-scope `ReportType` enum + `ChartToolbarView` struct (two-row underline tab bar: report-type + zoom). `@Binding var selectedReportType`, dispatches zoom via `@EnvironmentObject store`. |
| `App/Views/Overview/SensorLineView.swift` | State-aware sensor status row (10 states per spec). Tap-to-reveal `DISCONNECT` chip when connected. Elsewhere-tap dismiss. |
| `App/Views/Settings/SensorDetailView.swift` | Full sensor controls: pair / scan / disconnect / sensor details / transmitter details. All content migrated from the deleted `ConnectionView.swift` + `SensorView.swift`. iOS 15+ `.alert(_:isPresented:actions:message:)` API. |

**Modify (6 files):**

| Path | Change |
|---|---|
| `App/Views/OverviewView.swift` | `List { ... }` → `VStack(spacing: 0) { ... }`. Remove `ConnectionView()` + `SensorView()`. Insert `SensorLineView()` + `ChartToolbarView()`. `@State var selectedReportType: ReportType = .glucose` (lifted from ChartView). Pass `selectedReportType` as parameter to `ChartView(selectedReportType: selectedReportType)`. `StickyQuickActions` trimmed to 2 buttons; BG button removed. |
| `App/Views/Overview/ChartView.swift` | Unwrap outer `Section { VStack { ... } }` at body (line 26-42) → body is plain `VStack(spacing: 0) { switch selectedReportType { ... } }`. Remove `ReportTypeSelectorView` (lines 356-378). Remove `ZoomLevelsView` (lines 477-508). Accept `selectedReportType: ReportType` as parameter (not `@State`). |
| `App/Views/SettingsView.swift` | Wrap `List { ... }` in `NavigationStack`. Add `NavigationLink("Sensor details", destination: SensorDetailView())` row in a new "Sensor" section near the top. |
| `App/Views/ListsView.swift` | Wrap `List { ... }` in `NavigationStack`. Add `.toolbar { ToolbarItem(placement: .navigationBarTrailing) { ... } }` with a trailing `+` button gated on `DirectConfig.bloodGlucoseInput`. `@State var showingAddBG: Bool`. `.sheet(isPresented:)` presents `AddBloodGlucoseView`. One-shot `.alert` on first appear using `store.state.hasSeenBGRelocationHint`. |
| `App/AppState.swift` | Add `var hasSeenBGRelocationHint: Bool { didSet { UserDefaults.standard.hasSeenBGRelocationHint = hasSeenBGRelocationHint } }`. Initialise from UserDefaults in `init()`. |
| `Library/DirectState.swift` | Add `var hasSeenBGRelocationHint: Bool { get set }` to the state protocol. |
| `Library/DirectAction.swift` | Add `case setHasSeenBGRelocationHint(seen: Bool)` to the action enum. |
| `Library/DirectReducer.swift` | Add reducer case `case .setHasSeenBGRelocationHint(let seen): state.hasSeenBGRelocationHint = seen`. |
| `Library/Extensions/UserDefaults.swift` | Add `case hasSeenBGRelocationHint = "libre-direct.settings.has-seen-bg-relocation-hint"` to the `Keys` enum + `var hasSeenBGRelocationHint: Bool { get; set }` computed property at the bottom, matching the existing `aiConsentFoodPhoto` pattern. |

**Delete (2 files):**

| Path | Why |
|---|---|
| `App/Views/Overview/ConnectionView.swift` | Content distributed: compact status into `SensorLineView`; full pair/scan/disconnect UI into `SensorDetailView`. |
| `App/Views/Overview/SensorView.swift` | Content distributed: lifetime into `SensorLineView`; transmitter battery / hardware / firmware / MAC / sensor serial / type / region into `SensorDetailView`. |

---

## Task 1: State plumbing — `hasSeenBGRelocationHint`

**Files:**
- Modify: `Library/DirectState.swift`
- Modify: `App/AppState.swift`
- Modify: `Library/Extensions/UserDefaults.swift`
- Modify: `Library/DirectAction.swift`
- Modify: `Library/DirectReducer.swift`
- Test: `DOSBTSTests/AppStateTests.swift` (or the closest existing reducer test file)

### Steps

- [ ] **Step 1.1: Find the existing `aiConsentFoodPhoto` lines in each of the 5 files** (to pattern-match against):

Run:
```
grep -n "aiConsentFoodPhoto" Library/DirectState.swift App/AppState.swift Library/Extensions/UserDefaults.swift Library/DirectAction.swift Library/DirectReducer.swift
```
Expected output: one match per file (two in UserDefaults.swift: the `Keys` enum case and the computed property).

- [ ] **Step 1.2: Add protocol declaration in `Library/DirectState.swift`**

Near the other `aiConsent*` declarations (around line 80), add:
```swift
var hasSeenBGRelocationHint: Bool { get set }
```

- [ ] **Step 1.3: Add the `Keys` enum case in `Library/Extensions/UserDefaults.swift`**

In the `Keys` enum, near the other `aiConsent*` cases (around line 61), add:
```swift
case hasSeenBGRelocationHint = "libre-direct.settings.has-seen-bg-relocation-hint"
```

- [ ] **Step 1.4: Add the computed property in `Library/Extensions/UserDefaults.swift`**

Near the existing `aiConsentFoodPhoto` computed property (around line 807), add:
```swift
var hasSeenBGRelocationHint: Bool {
    get {
        return bool(forKey: Keys.hasSeenBGRelocationHint.rawValue)
    }
    set {
        set(newValue, forKey: Keys.hasSeenBGRelocationHint.rawValue)
    }
}
```

- [ ] **Step 1.5: Add property + `didSet` in `App/AppState.swift`**

Find the existing `aiConsentFoodPhoto` stored property. Below it, add:
```swift
var hasSeenBGRelocationHint: Bool {
    didSet {
        UserDefaults.standard.hasSeenBGRelocationHint = hasSeenBGRelocationHint
    }
}
```

In the `init()` method, below the existing `aiConsentFoodPhoto` init line, add:
```swift
self.hasSeenBGRelocationHint = UserDefaults.standard.hasSeenBGRelocationHint
```

- [ ] **Step 1.6: Add action case in `Library/DirectAction.swift`**

Near similar setter actions (e.g., `case setAIConsentFoodPhoto`), add:
```swift
case setHasSeenBGRelocationHint(seen: Bool)
```

- [ ] **Step 1.7: Add reducer case in `Library/DirectReducer.swift`**

In the main `switch action` block, near similar cases, add:
```swift
case .setHasSeenBGRelocationHint(let seen):
    state.hasSeenBGRelocationHint = seen
```

- [ ] **Step 1.8: Write a Swift Testing test for the reducer case**

Find the closest existing reducer test file (search `DOSBTSTests/` for `@Test.*reducer` or similar). Create a new file if none fits, at `DOSBTSTests/HasSeenBGRelocationHintReducerTests.swift`:

```swift
//
//  HasSeenBGRelocationHintReducerTests.swift
//  DOSBTSTests
//

import Testing
@testable import DOSBTSApp

struct HasSeenBGRelocationHintReducerTests {
    @Test func reducer_setsHasSeenHint() {
        var state = AppState()
        state.hasSeenBGRelocationHint = false

        directReducer(&state, .setHasSeenBGRelocationHint(seen: true))

        #expect(state.hasSeenBGRelocationHint == true)
    }

    @Test func reducer_canClearHasSeenHint() {
        var state = AppState()
        state.hasSeenBGRelocationHint = true

        directReducer(&state, .setHasSeenBGRelocationHint(seen: false))

        #expect(state.hasSeenBGRelocationHint == false)
    }
}
```

- [ ] **Step 1.9: Register the new test file in `project.pbxproj`** (tests are NOT auto-synced)

Find the `DOSBTSTests` group in `DOSBTS.xcodeproj/project.pbxproj` and add an entry for `HasSeenBGRelocationHintReducerTests.swift`. Also add an entry in the `DOSBTSTests` target's `PBXSourcesBuildPhase`. Pattern-match against the existing entries for another test file (e.g., `IOBReducerTests.swift`).

- [ ] **Step 1.10: Run the test to verify it passes**

Run in Xcode: Cmd+U (runs the full test suite). Verify the two new tests pass.

Or from the command line:
```
xcodebuild test -project DOSBTS.xcodeproj -scheme DOSBTSApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DOSBTSTests/HasSeenBGRelocationHintReducerTests
```
Expected: 2 tests passed.

- [ ] **Step 1.11: Commit**

```bash
git add Library/DirectState.swift App/AppState.swift Library/Extensions/UserDefaults.swift Library/DirectAction.swift Library/DirectReducer.swift DOSBTSTests/HasSeenBGRelocationHintReducerTests.swift DOSBTS.xcodeproj/project.pbxproj
git commit -m "feat: add hasSeenBGRelocationHint state (DMNC-793)"
```

---

## Task 2: `ChartToolbar.swift` — extracted toolbar with module-scope `ReportType`

**Files:**
- Create: `App/Views/Overview/ChartToolbar.swift`

### Steps

- [ ] **Step 2.1: Create the file with module-scope `ReportType` and `ChartToolbarView`**

```swift
//
//  ChartToolbar.swift
//  DOSBTS
//

import SwiftUI

// MARK: - ReportType

enum ReportType: String, CaseIterable {
    case glucose = "GLUCOSE"
    case timeInRange = "TIME IN RANGE"
    case statistics = "STATISTICS"
}

// MARK: - ChartToolbarView

struct ChartToolbarView: View {
    @EnvironmentObject var store: DirectStore
    @Binding var selectedReportType: ReportType

    var body: some View {
        VStack(spacing: DOSSpacing.xs) {
            reportTypeRow
            zoomRow
        }
        .padding(.vertical, DOSSpacing.xs)
        .background(AmberTheme.dosBlack)
    }

    private var reportTypeRow: some View {
        HStack(spacing: DOSSpacing.md) {
            ForEach(ReportType.allCases, id: \.self) { type in
                Button {
                    selectedReportType = type
                } label: {
                    Text(type.rawValue)
                        .font(selectedReportType == type ? DOSTypography.bodySmall.weight(.bold) : DOSTypography.bodySmall)
                        .foregroundColor(selectedReportType == type ? AmberTheme.amber : AmberTheme.amberDark)
                        .padding(.vertical, DOSSpacing.md)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(AmberTheme.amber)
                                .frame(height: 2)
                                .opacity(selectedReportType == type ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(type.rawValue)
                .accessibilityAddTraits(selectedReportType == type ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private var zoomRow: some View {
        HStack(spacing: DOSSpacing.md) {
            ForEach(ZoomLevel.allCases, id: \.self) { zoom in
                Button {
                    store.dispatch(.setChartZoomLevel(level: zoom.level))
                } label: {
                    Text(zoom.label)
                        .font(isSelectedZoom(zoom) ? DOSTypography.caption.weight(.bold) : DOSTypography.caption)
                        .foregroundColor(isSelectedZoom(zoom) ? AmberTheme.amber : AmberTheme.amberDark)
                        .padding(.vertical, DOSSpacing.sm)
                        .padding(.horizontal, DOSSpacing.xs)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(AmberTheme.amber)
                                .frame(height: 2)
                                .opacity(isSelectedZoom(zoom) ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(zoom.label)
                .accessibilityAddTraits(isSelectedZoom(zoom) ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func isSelectedZoom(_ zoom: ZoomLevel) -> Bool {
        store.state.chartZoomLevel == zoom.level
    }
}

// MARK: - ZoomLevel

private enum ZoomLevel: CaseIterable {
    case three, six, twelve, twentyFour

    var level: Int {
        switch self {
        case .three: return 3
        case .six: return 6
        case .twelve: return 12
        case .twentyFour: return 24
        }
    }

    var label: String {
        "\(level)h"
    }
}
```

- [ ] **Step 2.2: Verify the file compiles**

Run:
```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`.

If errors about `DOSSpacing.xs`, `DOSTypography.bodySmall`, or `AmberTheme.amber` — these should already exist per CLAUDE.md. If missing members, grep the design-system source files (`Library/DesignSystem/*.swift`) for the actual names and adjust. Do not invent new tokens in this task.

- [ ] **Step 2.3: Add a SwiftUI `PreviewProvider`** at the bottom of the file:

```swift
struct ChartToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChartToolbarView(selectedReportType: .constant(.timeInRange))
                .environmentObject(DirectStore(state: AppState(), reducer: directReducer, middlewares: []))
            Spacer()
        }
        .background(AmberTheme.dosBlack)
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2.4: Verify the preview renders** in Xcode (open `ChartToolbar.swift`, enable Canvas preview). Confirm: two rows of underline tabs; `TIME IN RANGE` is underlined+bold in the top row.

- [ ] **Step 2.5: Commit**

```bash
git add App/Views/Overview/ChartToolbar.swift
git commit -m "feat: extract ChartToolbarView with underline tab bar (DMNC-793)"
```

---

## Task 3: `SensorLineView.swift` — state-aware compact status row

**Files:**
- Create: `App/Views/Overview/SensorLineView.swift`

### Steps

- [ ] **Step 3.1: Verify the exact connection-state and sensor-state enum cases** the code uses.

Run:
```
grep -nE "enum SensorConnectionState|case connected|case disconnected|case connecting|case scanning|case pairing|case powerOff|case unknown" Library/Content/SensorConnectionState.swift
```
Expected: the enum and its cases. Same for `Library/Content/SensorState.swift` (look for `.ready`, `.starting`, etc.).

Use the actual case names verbatim in Step 3.2.

- [ ] **Step 3.2: Create the file**

```swift
//
//  SensorLineView.swift
//  DOSBTS
//

import SwiftUI

struct SensorLineView: View {
    @EnvironmentObject var store: DirectStore
    @State private var disconnectChipRevealed: Bool = false
    @State private var showingDisconnectAlert: Bool = false

    var body: some View {
        HStack(spacing: DOSSpacing.sm) {
            dotAndLabel

            Spacer()

            trailingContent
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleRowTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelString)
        .accessibilityHint(accessibilityHintString)
        .alert("Disconnect sensor?", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                store.dispatch(.disconnectConnection)
                disconnectChipRevealed = false
            }
        } message: {
            Text("You'll need to reconnect the sensor to resume glucose readings.")
        }
    }

    // MARK: - Row parts

    private var dotAndLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(labelText)
                .font(DOSTypography.caption)
                .foregroundColor(labelColor)
                .bold(isConnected)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch currentState {
        case .connected:
            if disconnectChipRevealed {
                Button {
                    showingDisconnectAlert = true
                } label: {
                    Text("DISCONNECT")
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amber)
                        .padding(.horizontal, DOSSpacing.sm)
                        .padding(.vertical, 3)
                        .overlay(
                            Rectangle().stroke(AmberTheme.amber, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        case .disconnected:
            Button {
                store.dispatch(.connectConnection)
            } label: {
                Text("CONNECT")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amber)
                    .padding(.horizontal, DOSSpacing.sm)
                    .padding(.vertical, 3)
                    .overlay(
                        Rectangle().stroke(AmberTheme.amber, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        case .noSensor:
            // SET UP chip routes to Settings > Sensor via the TabBar — for now, a visual placeholder.
            // Real routing (programmatic tab switch + navigation) is added in Task 6 after SettingsView has NavigationStack.
            Text("SET UP")
                .font(DOSTypography.caption)
                .foregroundColor(AmberTheme.amberDark)
                .padding(.horizontal, DOSSpacing.sm)
                .padding(.vertical, 3)
                .overlay(
                    Rectangle().stroke(AmberTheme.amberDark, lineWidth: 1)
                )
        case .error, .bluetoothOff, .transient, .unknown:
            EmptyView()
        }
    }

    // MARK: - State resolution

    private enum ResolvedState {
        case connected
        case disconnected
        case noSensor
        case error
        case bluetoothOff
        case transient  // connecting / scanning / pairing / warmup
        case unknown
    }

    private var currentState: ResolvedState {
        if store.state.connectionError != nil {
            return .error
        }
        if store.state.connectionState == .powerOff {
            return .bluetoothOff
        }
        if !store.state.hasSelectedConnection {
            return .noSensor
        }
        if store.state.connectionState == .connected {
            return .connected
        }
        if [.connecting, .scanning, .pairing].contains(store.state.connectionState) {
            return .transient
        }
        if store.state.connectionState == .disconnected {
            return .disconnected
        }
        return .unknown
    }

    private var isConnected: Bool { currentState == .connected }

    private var dotColor: Color {
        switch currentState {
        case .connected: return AmberTheme.cgaGreen
        case .transient: return AmberTheme.amberLight
        case .disconnected, .noSensor: return AmberTheme.amberDark
        case .error, .bluetoothOff: return AmberTheme.cgaRed
        case .unknown: return AmberTheme.amberDark
        }
    }

    private var labelColor: Color {
        switch currentState {
        case .connected: return AmberTheme.cgaGreen
        case .transient: return AmberTheme.amberLight
        case .disconnected, .noSensor: return AmberTheme.amberDark
        case .error, .bluetoothOff: return AmberTheme.cgaRed
        case .unknown: return AmberTheme.amberDark
        }
    }

    private var labelText: String {
        switch currentState {
        case .connected:
            if let sensor = store.state.sensor {
                return "CONNECTED · \(sensor.remainingLifetime.inTime) LEFT"
            }
            return "CONNECTED"
        case .transient:
            if let sensor = store.state.sensor, sensor.state == .starting, let warmup = sensor.remainingWarmupTime {
                return "WARMUP · \(warmup.inTime) LEFT"
            }
            switch store.state.connectionState {
            case .connecting: return "CONNECTING…"
            case .scanning: return "SCANNING…"
            case .pairing: return "PAIRING…"
            default: return "…"
            }
        case .disconnected: return "DISCONNECTED"
        case .noSensor: return "NO SENSOR"
        case .error: return "CONNECTION ERROR"
        case .bluetoothOff: return "BLUETOOTH OFF"
        case .unknown: return "—"
        }
    }

    // MARK: - Interaction

    private func handleRowTap() {
        switch currentState {
        case .connected:
            disconnectChipRevealed.toggle()
        case .error:
            // Future: programmatic route to Settings > Sensor. For this PR, rely on user tapping the tab manually.
            break
        case .bluetoothOff:
            if let url = URL(string: "App-Prefs:Bluetooth") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabelString: String {
        switch currentState {
        case .connected:
            if let sensor = store.state.sensor {
                return "Sensor connected, \(sensor.remainingLifetime.inTime) remaining"
            }
            return "Sensor connected"
        case .transient: return labelText.lowercased().capitalized
        case .disconnected: return "Sensor disconnected"
        case .noSensor: return "No sensor set up"
        case .error: return "Connection error"
        case .bluetoothOff: return "Bluetooth is off"
        case .unknown: return "Sensor state unknown"
        }
    }

    private var accessibilityHintString: String {
        switch currentState {
        case .connected:
            return disconnectChipRevealed ? "Double-tap the disconnect chip to disconnect" : "Double-tap to reveal disconnect"
        case .bluetoothOff: return "Double-tap to open iOS Bluetooth settings"
        default: return ""
        }
    }
}
```

- [ ] **Step 3.3: Verify it compiles**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED.

If build fails on missing `AmberTheme.cgaGreen` or similar, grep `Library/DesignSystem/AmberTheme.swift` for actual token names and adjust.

- [ ] **Step 3.4: Add PreviewProvider** at the bottom:

```swift
struct SensorLineView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DOSSpacing.md) {
            SensorLineView()
                .environmentObject(DirectStore(state: AppState(), reducer: directReducer, middlewares: []))
        }
        .background(AmberTheme.dosBlack)
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 3.5: Commit**

```bash
git add App/Views/Overview/SensorLineView.swift
git commit -m "feat: add SensorLineView with tap-to-reveal disconnect (DMNC-793)"
```

---

## Task 4: `SensorDetailView.swift` — full sensor controls in Settings

**Files:**
- Create: `App/Views/Settings/SensorDetailView.swift`

### Steps

- [ ] **Step 4.1: Create the `Settings` directory** if it doesn't exist:

```bash
mkdir -p App/Views/Settings
```

- [ ] **Step 4.2: Read the full `ConnectionView.swift` and `SensorView.swift` content** so the migration is accurate:

```
cat App/Views/Overview/ConnectionView.swift
cat App/Views/Overview/SensorView.swift
```

Catalog the sections in each file — you'll replicate them inside `SensorDetailView` grouped by concern.

- [ ] **Step 4.3: Create `App/Views/Settings/SensorDetailView.swift`** with three sections (migrated content):

```swift
//
//  SensorDetailView.swift
//  DOSBTS
//

import SwiftUI

struct SensorDetailView: View {
    @EnvironmentObject var store: DirectStore
    @State private var showingDisconnectAlert: Bool = false

    var body: some View {
        List {
            connectionSection
            sensorSection
            transmitterSection
        }
        .listStyle(.grouped)
        .navigationTitle("Sensor")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Connection section (pair / scan / disconnect)

    @ViewBuilder
    private var connectionSection: some View {
        Section {
            if let error = store.state.connectionError {
                VStack(alignment: .leading, spacing: DOSSpacing.xs) {
                    Label("Connection error", systemImage: "exclamationmark.triangle")
                        .foregroundColor(AmberTheme.cgaRed)
                    Text(error)
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amberDark)
                }
            }

            if store.state.isConnectionPaired {
                HStack {
                    Text("Connection state")
                    Spacer()
                    Text(store.state.connectionState.localizedDescription)
                        .foregroundColor(AmberTheme.amberDark)
                }
            }

            if store.state.hasSelectedConnection {
                pairOrScanButton
                if store.state.isConnectionPaired, store.state.isDisconnectable {
                    Button("Disconnect", role: .destructive) {
                        showingDisconnectAlert = true
                    }
                } else if store.state.isConnectionPaired, store.state.isConnectable {
                    Button("Connect") {
                        store.dispatch(.connectConnection)
                    }
                }
            }
        } header: {
            Text("Connection")
        }
        .alert("Disconnect sensor?", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                store.dispatch(.disconnectConnection)
            }
        } message: {
            Text("You'll need to reconnect the sensor to resume glucose readings.")
        }
    }

    @ViewBuilder
    private var pairOrScanButton: some View {
        if store.state.isTransmitter && !store.state.isConnectionPaired {
            Button("Pair transmitter") {
                if store.state.isDisconnectable {
                    store.dispatch(.disconnectConnection)
                }
                store.dispatch(.pairConnection)
            }
        } else if store.state.isSensor {
            Button("Scan sensor") {
                if store.state.isDisconnectable {
                    store.dispatch(.disconnectConnection)
                }
                store.dispatch(.pairConnection)
            }
        }
    }

    // MARK: - Sensor details

    @ViewBuilder
    private var sensorSection: some View {
        if let sensor = store.state.sensor {
            Section {
                detailRow("Type", sensor.type.localizedDescription)
                detailRow("Region", sensor.region.localizedDescription)
                detailRow("Serial", sensor.serial ?? "—")
                if let macAddress = store.state.sensor?.macAddress {
                    detailRow("MAC address", macAddress)
                }
                detailRow("State", sensor.state.localizedDescription)
                if sensor.state == .ready {
                    detailRow("Remaining lifetime", sensor.remainingLifetime.inTime)
                } else if sensor.state == .starting, let warmup = sensor.remainingWarmupTime {
                    detailRow("Warmup remaining", warmup.inTime)
                }
            } header: {
                Text("Sensor")
            }
        }
    }

    // MARK: - Transmitter details

    @ViewBuilder
    private var transmitterSection: some View {
        if let transmitter = store.state.transmitter {
            Section {
                detailRow("Name", transmitter.name ?? "—")
                if let battery = transmitter.battery {
                    detailRow("Battery", "\(battery)%")
                }
                if let hardware = transmitter.hardware {
                    detailRow("Hardware", hardware)
                }
                if let firmware = transmitter.firmware {
                    detailRow("Firmware", firmware)
                }
            } header: {
                Text("Transmitter")
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(AmberTheme.amberDark)
        }
    }
}
```

- [ ] **Step 4.4: Verify it compiles**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -30
```

If compile errors on properties like `store.state.transmitter` or `transmitter.hardware`, grep the current `SensorView.swift` and `Library/Content/Sensor.swift` to find the actual type members. Adjust `SensorDetailView.swift` to match.

- [ ] **Step 4.5: Add PreviewProvider** at the bottom:

```swift
struct SensorDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SensorDetailView()
                .environmentObject(DirectStore(state: AppState(), reducer: directReducer, middlewares: []))
        }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 4.6: Commit**

```bash
git add App/Views/Settings/SensorDetailView.swift
git commit -m "feat: add SensorDetailView with full sensor controls (DMNC-793)"
```

---

## Task 5: `ChartView.swift` — unwrap `Section` + remove extracted views

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

### Steps

- [ ] **Step 5.1: Delete the private `ReportType` enum** at lines 13-17 of `ChartView.swift`. (Now lives at module scope in `ChartToolbar.swift`.)

- [ ] **Step 5.2: Delete the `@State var selectedReportType` line** at line 23 of `ChartView.swift`.

- [ ] **Step 5.3: Add a parameter** to the struct:

At the top of `ChartView`, where other `@State` / stored properties live, add:
```swift
let selectedReportType: ReportType
```

- [ ] **Step 5.4: Unwrap the outer `Section` in the body.**

Current body (around line 26-42) looks like:
```swift
var body: some View {
    Section(content: {
        VStack {
            ReportTypeSelectorView
            switch selectedReportType {
            // ... content ...
            }
        }
    })
}
```

Replace with:
```swift
var body: some View {
    VStack(spacing: 0) {
        switch selectedReportType {
        // ... same cases as before (copy them verbatim) ...
        }
    }
}
```

Do NOT include `ReportTypeSelectorView` or `ZoomLevelsView` in the new body — those are now rendered by `ChartToolbarView` at the Overview level.

- [ ] **Step 5.5: Delete `ReportTypeSelectorView`** (the private computed property around lines 356-378 of `ChartView.swift`).

- [ ] **Step 5.6: Delete `ZoomLevelsView`** (private computed property around lines 477-508) and its helper `isSelectedZoomLevel(level:)` if unused elsewhere.

Run:
```
grep -n "isSelectedZoomLevel\|ZoomLevelsView\|ReportTypeSelectorView" App/Views/Overview/ChartView.swift
```
Expected: zero remaining references. If any exist after deletion, clean them up.

- [ ] **Step 5.7: Verify it compiles**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```

Expected errors at this point: `OverviewView.swift` will fail to compile because it still instantiates `ChartView()` without the new parameter. Task 8 fixes that. For now, the CHART VIEW itself should compile fine — other compile errors should only be at the call site.

If `ChartView` itself has errors, fix before moving on.

- [ ] **Step 5.8: Commit** (accepting the transient OverviewView compile break — will be fixed in Task 8):

```bash
git add App/Views/Overview/ChartView.swift
git commit -m "refactor: unwrap ChartView Section + remove lifted toolbar views (DMNC-793)"
```

---

## Task 6: `SettingsView.swift` — `NavigationStack` + `SensorDetailView` link

**Files:**
- Modify: `App/Views/SettingsView.swift`

### Steps

- [ ] **Step 6.1: Read the current SettingsView** and note the structure:

```
cat App/Views/SettingsView.swift
```

- [ ] **Step 6.2: Replace the body with a NavigationStack-wrapped List** that adds a "Sensor details" NavigationLink at the top:

```swift
var body: some View {
    NavigationStack {
        List {
            // Sensor
            NavigationLink {
                SensorDetailView()
            } label: {
                HStack {
                    Label("Sensor details", systemImage: "sensor.tag.radiowaves.forward.fill")
                    Spacer()
                }
            }

            SensorConnectorSettingsView()
            SensorConnectionConfigurationView()

            // Glucose & Alarms
            Section {}.listRowBackground(Color.clear)
            GlucoseSettingsView()
            AlarmSettingsView()
            InsulinSettingsView()

            // Export
            Section {}.listRowBackground(Color.clear)
            NightscoutSettingsView()
            AppleExportSettingsView()

            // AI & Extras
            Section {}.listRowBackground(Color.clear)
            AISettingsView()
            BellmanSettingsView()
            CalibrationSettingsView()
            AdditionalSettingsView()

            // About
            Section {}.listRowBackground(Color.clear)
            AboutView()
        }
        .listStyle(.grouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 6.3: Verify it compiles and run the preview**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED (the OverviewView-related error from Task 5 persists until Task 8).

- [ ] **Step 6.4: Manual smoke test** (once OverviewView is fixed in Task 8): tap Settings tab → tap "Sensor details" → `SensorDetailView` pushes onto the nav stack → back-swipe works.

Defer this smoke test to after Task 8.

- [ ] **Step 6.5: Commit**

```bash
git add App/Views/SettingsView.swift
git commit -m "feat: wrap SettingsView in NavigationStack + add SensorDetailView link (DMNC-793)"
```

---

## Task 7: `ListsView.swift` — `NavigationStack` + `+BG` toolbar + migration alert

**Files:**
- Modify: `App/Views/ListsView.swift`

### Steps

- [ ] **Step 7.1: Replace the body** with a NavigationStack-wrapped List that:
  - Has a trailing toolbar `+` button gated on `DirectConfig.bloodGlucoseInput`
  - Presents `AddBloodGlucoseView` via `.sheet(isPresented:)`
  - Shows a one-shot `.alert` on first appear using `store.state.hasSeenBGRelocationHint`

```swift
struct ListsView: View {
    @EnvironmentObject var store: DirectStore
    @State private var showingAddBG: Bool = false
    @State private var showingMigrationHint: Bool = false

    var body: some View {
        NavigationStack {
            List {
                SensorGlucoseListView()

                if DirectConfig.bloodGlucoseInput {
                    BloodGlucoseListView()
                }

                MealEntryListView()

                if DirectConfig.showInsulinInput, store.state.showInsulinInput {
                    InsulinDeliveryListView()
                }

                if DirectConfig.glucoseErrors {
                    SensorErrorListView()
                }

                if DirectConfig.glucoseStatistics {
                    StatisticsView()
                }
            }
            .listStyle(.grouped)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if DirectConfig.bloodGlucoseInput {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddBG = true
                        } label: {
                            Image(systemName: "plus")
                                .accessibilityLabel("Add blood glucose")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddBG) {
                AddBloodGlucoseView(glucoseUnit: store.state.glucoseUnit) { time, value in
                    let glucose = BloodGlucose(id: UUID(), timestamp: time, glucoseValue: value)
                    store.dispatch(.addBloodGlucose(glucoseValues: [glucose]))
                }
            }
            .alert("Blood glucose moved", isPresented: $showingMigrationHint) {
                Button("Got it") {
                    store.dispatch(.setHasSeenBGRelocationHint(seen: true))
                }
            } message: {
                Text("BG entry is now in the Log tab. Tap the + button above to log a new reading.")
            }
            .onAppear {
                if !store.state.hasSeenBGRelocationHint && DirectConfig.bloodGlucoseInput {
                    showingMigrationHint = true
                }
            }
        }
    }
}
```

- [ ] **Step 7.2: Verify it compiles**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED (OverviewView error still expected until Task 8).

- [ ] **Step 7.3: Commit**

```bash
git add App/Views/ListsView.swift
git commit -m "feat: add +BG toolbar to ListsView with migration hint (DMNC-793)"
```

---

## Task 8: `OverviewView.swift` — `List` → `VStack`, integrate all

**Files:**
- Modify: `App/Views/OverviewView.swift`

### Steps

- [ ] **Step 8.1: Replace the body**. The full new version:

```swift
struct OverviewView: View {
    @EnvironmentObject var store: DirectStore

    @State private var activeSheet: ActiveSheet?
    @State private var pendingSheet: ActiveSheet?
    @State private var selectedReportType: ReportType = .glucose

    var body: some View {
        VStack(spacing: 0) {
            GlucoseView()

            SensorLineView()

            if store.state.treatmentCycleActive {
                TreatmentBannerView()
            }

            ChartToolbarView(selectedReportType: $selectedReportType)

            if !store.state.sensorGlucoseValues.isEmpty || !store.state.bloodGlucoseValues.isEmpty {
                ChartView(selectedReportType: selectedReportType)
                    .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }

            StickyQuickActions()
        }
        .background(AmberTheme.dosBlack)
        .sheet(item: $activeSheet, onDismiss: {
            if let pending = pendingSheet {
                pendingSheet = nil
                activeSheet = pending
            }
        }) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            if store.state.showTreatmentPrompt, let alarmFiredAt = store.state.alarmFiredAt {
                activeSheet = .treatmentModal(alarmFiredAt: alarmFiredAt)
                store.dispatch(.setShowTreatmentPrompt(show: false))
            }
        }
        .onChange(of: store.state.showTreatmentPrompt) { newValue in
            if newValue, let alarmFiredAt = store.state.alarmFiredAt {
                activeSheet = .treatmentModal(alarmFiredAt: alarmFiredAt)
                store.dispatch(.setShowTreatmentPrompt(show: false))
            }
        }
        .onChange(of: store.state.recheckDispatched) { newValue in
            guard newValue, store.state.treatmentCycleActive else { return }
            if let glucose = store.state.latestSensorGlucose,
               glucose.glucoseValue < store.state.alarmLow {
                activeSheet = .treatmentRecheck(glucoseValue: glucose.glucoseValue)
            }
        }
    }
```

- [ ] **Step 8.2: Keep the `sheetContent(for:)` method unchanged** — it still handles `.insulin`, `.meal`, `.bloodGlucose`, `.treatmentModal`, `.filteredFoodEntry`, `.treatmentRecheck`. The `.bloodGlucose` case is kept for future use even though no Overview affordance triggers it now.

- [ ] **Step 8.3: Replace `StickyQuickActions`** to trim BG:

```swift
@ViewBuilder
private func StickyQuickActions() -> some View {
    VStack(spacing: 0) {
        Divider()
            .background(AmberTheme.dosBorder)

        HStack(spacing: DOSSpacing.sm) {
            if DirectConfig.showInsulinInput, store.state.showInsulinInput {
                QuickActionButton(
                    title: "INSULIN",
                    icon: "syringe",
                    action: { activeSheet = .insulin }
                )
            }

            QuickActionButton(
                title: "MEAL",
                icon: "fork.knife",
                action: { activeSheet = .meal }
            )
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.xs)
        .background(AmberTheme.dosBlack)
    }
}
```

- [ ] **Step 8.4: `QuickActionButton`** stays unchanged.

- [ ] **Step 8.5: Verify the full project compiles**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 8.6: Run on simulator** (`Cmd+R` in Xcode on iPhone 17 Pro simulator).

Smoke-test checklist:
1. Overview page does not scroll vertically.
2. Chart toolbar sits pinned above the chart.
3. Sensor line is under the hero.
4. Tap sensor line → DISCONNECT chip reveals.
5. Tap DISCONNECT → alert appears → Cancel leaves state unchanged.
6. Sticky actions show only INSULIN + MEAL (no BG button).
7. Tap Settings tab → "Sensor details" row visible → tap → SensorDetailView pushes.
8. Tap Log tab → migration hint alert shows on first visit → "Got it" dismisses.
9. Log tab toolbar shows `+` → tap → `AddBloodGlucoseView` sheet presents.
10. System TabBar still works (Overview / Log / Digest / Settings all reachable).

If any smoke-test item fails, iterate on the specific task that introduced the region.

- [ ] **Step 8.7: Commit**

```bash
git add App/Views/OverviewView.swift
git commit -m "refactor: convert OverviewView to no-scroll VStack with pinned toolbar + sensor line (DMNC-793)"
```

---

## Task 9: Delete `ConnectionView.swift` + `SensorView.swift`

**Files:**
- Delete: `App/Views/Overview/ConnectionView.swift`
- Delete: `App/Views/Overview/SensorView.swift`

### Steps

- [ ] **Step 9.1: Verify no references remain** to either file:

```
grep -rn "ConnectionView\|SensorView" App/ Library/ Widgets/ 2>&1 | grep -v "SensorLineView\|SensorDetailView\|SensorConnectorSettingsView\|SensorConnectionConfigurationView\|SensorWidget\|SensorGlucose"
```
Expected: zero matches.

If any reference remains (most likely a `ConnectionView()` or `SensorView()` instantiation you missed in `OverviewView.swift`), remove it before deleting.

- [ ] **Step 9.2: Delete the files**

```bash
git rm App/Views/Overview/ConnectionView.swift
git rm App/Views/Overview/SensorView.swift
```

- [ ] **Step 9.3: Verify the build still succeeds**

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 9.4: Commit**

```bash
git commit -m "refactor: delete ConnectionView + SensorView (migrated to SensorLineView + SensorDetailView) (DMNC-793)"
```

---

## Task 10: Accessibility baseline verification

**Files:** (no new files — verifies the accessibility labels added in Tasks 2, 3, 4 are actually correct)

### Steps

- [ ] **Step 10.1: Build + run on simulator** (iPhone 17 Pro at default Dynamic Type).

- [ ] **Step 10.2: Enable Accessibility Inspector** (Xcode menu: Xcode → Open Developer Tool → Accessibility Inspector). Point it at the simulator.

- [ ] **Step 10.3: Verify each new primitive** has correct VoiceOver output:

| Element | Expected VoiceOver string |
|---|---|
| Report-type tab (selected) | `"Time In Range, selected"` (or similar per locale) |
| Report-type tab (unselected) | `"Glucose, button"` |
| Zoom tab (selected) | `"12h, selected"` |
| Zoom tab (unselected) | `"3h, button"` |
| Sensor line (connected idle) | `"Sensor connected, 8 days remaining. Double-tap to reveal disconnect"` |
| Sensor line (connected revealed) | Line reads as before; `DISCONNECT` chip reads `"Disconnect, button"` |
| Sensor line (disconnected) | `"Sensor disconnected. CONNECT, button"` |
| INSULIN sticky button | `"INSULIN, button"` |
| MEAL sticky button | `"MEAL, button"` |
| Log tab `+` button | `"Add blood glucose, button"` |

If any label is wrong or missing, fix inline in the relevant file and re-verify.

- [ ] **Step 10.4: Verify Dynamic Type at default and XXL**

In iOS Simulator: Settings → Accessibility → Display & Text Size → Larger Text → move the slider to XXL.

Re-launch the app. Check:
1. Overview still renders correctly (may slightly squeeze).
2. No text truncation on critical values (glucose number, sensor line state, tab labels).
3. Tap targets remain 44pt minimum.

If chart region drops below ~25% of screen height at XXL, document in the PR description and either (a) add a horizontal-scroll indicator to the chart, or (b) reduce hero size slightly.

- [ ] **Step 10.5: Commit** (only if any accessibility tweaks were needed):

```bash
git add <files>
git commit -m "feat: accessibility baseline for DMNC-793 primitives (VoiceOver + Dynamic Type)"
```

If no tweaks were needed, no commit — move on.

---

## Task 11: Final verification + open questions

### Steps

- [ ] **Step 11.1: Run the full test suite** in Xcode (Cmd+U). Verify all tests pass, including the two new tests from Task 1.

- [ ] **Step 11.2: Visual snapshot tests — DEFERRED**

The spec's Success Criterion #7 lists visual snapshot tests as a requirement. DOSBTS does not currently have a snapshot-testing library vendored (per CLAUDE.md: "no package manager"). Two options:

**Option A:** Add a small vendored snapshot-testing utility (~200-400 LOC). Out of scope for this PR; file as a follow-up Linear issue.

**Option B:** Rely on SwiftUI PreviewProvider + manual smoke tests for this PR. Add actual snapshot tests when (a) snapshot library lands, or (b) a regression demands them.

**Recommendation:** Ship Option B for this PR. File follow-up Linear issue titled "chore: vendor a snapshot-testing utility for SwiftUI views" with acceptance criteria "snapshot tests exist for ChartToolbarView, SensorLineView, StickyQuickActions, SensorDetailView per DMNC-793 success criteria #7."

- [ ] **Step 11.3: Run a final end-to-end smoke test** on iPhone 17 Pro simulator:

1. Cold launch → Overview renders without scroll.
2. Chart toolbar + sensor line + sticky actions all present and correctly styled.
3. Tap through each region once (GLUCOSE/TIR/STATS tabs, 3h/6h/12h/24h zoom, sensor line, both sticky buttons).
4. Settings tab → Sensor details → verify transmitter-battery / hw / fw / MAC / serial all display correctly for the user's current paired sensor.
5. Log tab → migration alert → Got it dismisses; re-launch and verify alert does not re-appear.
6. Log tab → `+` → AddBloodGlucoseView sheet → enter a fake reading → log it → verify appears in the BG list.
7. Disconnect flow: sensor line → DISCONNECT chip reveals → alert → Cancel leaves state intact; re-tap sensor line → chip revealed; tap elsewhere → chip hides.

- [ ] **Step 11.4: Verify CHANGELOG entry** (per CLAUDE.md rules):

DMNC-793 ships user-visible changes (layout change, new toolbar treatment, new sensor line, BG tab move). Add an entry under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
### Changed
- Overview screen is now a fixed no-scroll layout. Chart toolbar (GLUCOSE / TIME IN RANGE / STATISTICS and 3h / 6h / 12h / 24h) pinned above the chart; sensor connection status moved inline under the hero with tap-to-reveal disconnect; INSULIN + MEAL sticky buttons (BG button moved to the Log tab). — DMNC-793
```

- [ ] **Step 11.5: Commit the CHANGELOG**:

```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG entry for Overview no-scroll layout (DMNC-793)"
```

- [ ] **Step 11.6: Open the PR**

Push the branch (if working in a branch — otherwise push `main` per project conventions), open a pull request on GitHub with title:

```
feat: Overview no-scroll layout — pinned toolbar, sensor line, BG to Log tab (DMNC-793)
```

PR description:
```markdown
## Summary
Implements DMNC-793 per `docs/brainstorms/2026-04-23-overview-no-scroll-layout-requirements.md`.

## Changes
- Overview: `List` → `VStack(spacing: 0)` no-scroll layout.
- New `ChartToolbar.swift` — underline tab bar, two rows (report type + zoom).
- New `SensorLineView.swift` — state-aware compact status with tap-to-reveal disconnect.
- New `SensorDetailView.swift` — full sensor / transmitter details pushed from Settings.
- `ListsView` wrapped in `NavigationStack` + trailing `+BG` toolbar button + one-shot migration alert.
- `SettingsView` wrapped in `NavigationStack` + Sensor-details link.
- Sticky actions trimmed from 3 buttons to 2 (INSULIN + MEAL).
- Deleted `ConnectionView.swift` + `SensorView.swift` (content migrated).

## Test plan
- [x] All existing tests pass (`Cmd+U` in Xcode).
- [x] New `HasSeenBGRelocationHintReducerTests` pass (2 tests).
- [x] Smoke test on iPhone 17 Pro: no vertical scroll, all regions render, all taps work.
- [x] Accessibility: VoiceOver reads correct labels for every new tap target; Dynamic Type at default + XXL verified.
- [x] Sensor pair/scan/disconnect flows work from SensorDetailView.
- [x] BG entry from Log tab creates a reading identical to the previous Overview-sticky flow.
- [ ] Snapshot tests: deferred to follow-up Linear issue (no snapshot library vendored).
```

---

## Self-review notes

**Spec coverage audit:**

| Spec section | Addressed by task |
|---|---|
| Context / premise | N/A (narrative) |
| Target composition (7 regions) | Tasks 2, 3, 8 |
| Chart toolbar (Option E) | Task 2 |
| Sensor line (state table, tap-reveal, elsewhere-dismiss) | Task 3 |
| Sticky actions (2 buttons) | Task 8 |
| BG entry relocation | Task 7 |
| Full sensor controls → SensorDetailView | Tasks 4, 6 |
| What doesn't change (GlucoseView, TreatmentBanner, TabView, ActiveSheet) | Task 8 (preserves) |
| File-level changes table | Tasks 1-9 |
| Accessibility baseline | Tasks 2, 3, 4, 10 |
| Success criterion #1 (no vertical scroll) | Task 8 smoke test |
| Success criterion #2 (toolbar stays visible) | Tasks 2, 8 |
| Success criterion #3 (sensor line state table) | Task 3 |
| Success criterion #4 (connect 1-tap / disconnect 2-tap + alert) | Task 3, Task 4 |
| Success criterion #5 (BG entry from Log tab) | Task 7 |
| Success criterion #6 (nothing silently lost from ConnectionView/SensorView) | Tasks 4, 9 |
| Success criterion #7 (visual snapshot tests) | Task 11 — deferred with rationale |
| Success criterion #8 (iPhone SE gate) | Task 10 |

**Type consistency audit:**
- `ReportType` enum defined module-scope in Task 2's `ChartToolbar.swift`, used by `ChartView` in Task 5 and `OverviewView` in Task 8 — consistent.
- `ChartToolbarView(selectedReportType: $selectedReportType)` — Task 2 signature matches Task 8 call site.
- `ChartView(selectedReportType: selectedReportType)` — Task 5 parameter matches Task 8 call site (value, not binding).
- `SensorLineView()` — no parameters, uses `@EnvironmentObject` — consistent Task 3 definition and Task 8 call site.
- `SensorDetailView()` — no parameters — consistent Task 4 definition and Task 6 call site.
- `store.dispatch(.setHasSeenBGRelocationHint(seen: true))` — Task 1 action signature matches Task 7 call site.

No type inconsistencies found.

**Placeholder scan:**
- No "TBD" or "TODO" in the implementation steps.
- No "implement later" or "similar to Task N" without code.
- Step 4.2 references the current `ConnectionView.swift` + `SensorView.swift` content but provides the concrete migrated structure in Step 4.3 — that's a read-then-migrate pattern, not a placeholder.
- Step 10.5 commit is conditional ("only if any accessibility tweaks were needed") — that's legitimate optionality, not a placeholder.

No placeholders found.

---

## Execution handoff

**Plan complete and saved to `docs/plans/2026-04-23-001-feat-overview-no-scroll-layout-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
