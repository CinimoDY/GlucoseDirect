# DOSBTS (formerly GlucoseDirect)

Continuous glucose monitoring (CGM) app for iOS with a DOS amber CGA aesthetic. Connects to Libre sensors via Bluetooth/NFC and displays real-time glucose data.

## Build Commands

```bash
# Build the app
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build

# Build the widget
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSWidget -sdk iphonesimulator -configuration Debug build
```

No package manager (SPM/CocoaPods) - all dependencies are vendored or first-party.

## Architecture: Redux-like (Store/Action/Reducer/Middleware)

Based on [Daniel Bernal's Redux-like SwiftUI architecture](https://danielbernal.co/redux-like-architecture-with-swiftui-basics/).

**Core types** (all in `Library/`):
- `Store<State, Action>` — `Library/Extensions/State.swift` — Observable store, dispatches actions through reducer then middlewares
- `DirectState` protocol — `Library/DirectState.swift` — All app state properties
- `DirectAction` enum — `Library/DirectAction.swift` — All possible actions
- `DirectReducer` — `Library/DirectReducer.swift` — Pure state mutations
- `DirectStore` typealias — `Library/DirectStore.swift` — `Store<DirectState, DirectAction>`

**Data flow:**
```
View dispatches Action -> Store.dispatch() -> Reducer mutates State
                                           -> Middlewares receive (State, Action)
                                           -> Middlewares emit new Actions via Combine publishers
```

**Middlewares** are defined in `App/Modules/` — each module file contains middleware functions (not classes). They return `AnyPublisher<DirectAction, DirectError>?`. There is no `Middleware` folder; look for `func ...Middleware` or `func ...Middelware` (note: typo is in the codebase) patterns.

**State persistence:** `AppState` (`App/AppState.swift`) implements `DirectState` and persists most properties to `UserDefaults`.

**Architecture gotchas:**
- **Reducer runs BEFORE middlewares** — `Store.dispatch()` calls `reducer(&state, action)` first, then passes the *new* state to middlewares. Don't guard on state that the reducer just changed for the same action flow.
- **`fileSystemSynchronized` Xcode project** — new Swift files under `App/`, `Library/`, or `Widgets/` are auto-picked up; no manual pbxproj edits needed. Per-target exclusions live in `PBXFileSystemSynchronizedBuildFileExceptionSet` (currently excludes widget resources + `Extensions/Float.swift` from the widget target, and `Info.plist` from both app/widget auto-inclusion). Adding a new test file requires an explicit entry in `DOSBTSTests` group + `PBXSourcesBuildPhase` — the tests are NOT auto-synced.
- **Two middleware arrays** in `App.swift` (device + simulator) — both must be updated when adding middleware
- **Deployment target is iOS 26.0** — bumped from 15.0 in DMNC-769 to match DOOMBTS and adopt iOS 17+ APIs (new `onChange(of:_:)` two-arg form, etc.). Existing `if #available(iOS 15.x/16.x/17.x, *)` guards are now dead branches and can be cleaned up incrementally.
- **Deploy to TestFlight:** `./deploy.sh` (uses ASC API key). `ExportOptions.plist` uses automatic signing. Bump `CURRENT_PROJECT_VERSION` in pbxproj before each deploy. If a connected iPhone is passcode-locked, archive will fail — unlock or disconnect it. Provisioning profiles are per-macOS-account; if deploying from a new account, archive once from Xcode first to generate them.
- **SwiftUI nested sheets are unreliable** — never present a `.sheet` from within a view that is itself presented as a `.sheet`. Use `NavigationLink` (push) instead. This applies to all iOS versions, not just iOS 15. See `docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`.
- **Cross-middleware listening** — multiple middlewares can handle the same action (e.g., `.addMealEntry` triggers both `mealEntryStoreMiddleware` and `favoriteFoodStoreMiddleware`). Comment these cross-dependencies for maintainability.
- **Data load guards** — all DataStore middlewares guard `state.appState == .active` before loading. The `.active` state is set in `ContentView.onAppear`. If adding new data store middlewares, follow this pattern: handle `.setAppState(.active)` to trigger initial load, and guard `.active` in the load action handler. See `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`.
- **OverviewView uses ActiveSheet enum** — all sheets (insulin, meal, blood glucose, treatment modal, filtered food entry, treatment recheck) are consolidated into a single `.sheet(item:)` with an `ActiveSheet` enum discriminator. This prevents iOS 15 sibling sheet collisions. Use `pendingSheet` + `onDismiss` for dismiss-then-present sequencing (not `asyncAfter`).
- **Overview layout order** — hero glucose → treatment banner (if active) → chart (with report type selector) → action buttons → connection → sensor. Matches Libre-style flow. ChartView has a `@State selectedReportType` enum switching between GLUCOSE (chart), TIME IN RANGE (TAR/TIR/TBR bars), and STATISTICS (AVG/SD/CV/GMI). The chart content is extracted into a `GlucoseChartContent` computed property.
- **Food analysis has three input paths** — `analyzeFood(imageData:)` for photos, `analyzeFoodText(query:history:)` for NL text (with optional multi-turn follow-up), and `analyzeFoodBarcode(code:)` for barcode scanning (Open Food Facts). All three share `foodAnalysisResult/Loading/Error` state and reuse `FoodPhotoAnalysisView` as the staging plate. Photo and text paths require `aiConsentFoodPhoto` consent gate; barcode path does NOT (OFF is free). Text path supports conversational follow-up (up to 3 rounds) when confidence is low — follow-up state lives in `@State` (not Redux), staging plate stays visible during follow-up loading.
- **Treatment workflow (Rule of 15)** — `TreatmentCycleMiddleware` orchestrates guided hypo treatment: alarm fires → `.showTreatmentPrompt` → user logs treatment → 15-min countdown → recheck glucose → stabilised or treat again. Two UI surfaces: UNNotificationAction buttons (background/lock screen) and TreatmentModalView (foreground). Alarm suppression during countdown (sound-only, banners continue) with critical-low safety floor (`alarmLow - 15 mg/dL` breaks through). Treatment cycle state persists to UserDefaults (survives app kill). TreatmentEvent stored in GRDB (write-only V1) for future absorption analysis. `treatmentCycleSnoozeUntil` is separate from `alarmSnoozeUntil` — GlucoseNotification checks both. Configurable wait time via `hypoTreatmentWaitMinutes` (default 15). TreatmentBannerView has 4 states: countdown, rechecking, stale data, recovered (auto-dismiss 5s).
- **Predictive low alarm** — GlucoseNotification middleware extrapolates glucose trajectory using smoothed `minuteChange` (avg of 3 readings) projected 20 min forward. Fires "Trending Low" notification with `predictiveLowAlarm` UNNotificationCategory ("EAT NOW" button) when predicted to cross `alarmLow`. CRITICAL: does NOT trigger autosnooze — actual low alarm fires independently. Does NOT fire when `treatmentCycleActive` (prevents snooze cascade). Once-per-episode dedup via `predictiveLowAlarmFired` flag, cleared at `alarmLow + 10` or on actual low. Chart shows dashed projection line (iOS 16+ only) with red cross marker at predicted threshold crossing. Toggle: `showPredictiveLowAlarm` (default on).
- **Chart markers** — Meal/insulin entries grouped by 15-min `timegroup`. Single entries show diamond, groups show circle with count + total carbs (e.g. "3x 45g"). Tapping a group opens detail sheet with individual items (swipe-to-delete, tap-to-edit). Meal edit sheet has Delete button (`deleteCallback`). Insulin tap shows `confirmationDialog` with Delete option.
- **Stale data indicator** — GlucoseView shows "X MIN AGO" warning when latest reading is >5 min old. Amber text for 5-14 min, red for 15+. Prevents dosing decisions on silently stale data.
- **Insulin-on-Board (IOB)** — `IOBCalculator.swift` implements OpenAPS oref0 Maksimovic exponential decay model. `InsulinPreset` enum (rapidActing peak 75m/DIA 6h, ultraRapid peak 55m/DIA 6h) with separate basal DIA (2-24h). IOB computed on-read from `iobDeliveries` (DIA-window filtered, loaded by `IOBMiddleware`). Hero display (GlucoseView) with 60s refresh timer, split display toggle (M=meal/snack, B=basal+corr). Chart AreaMark overlay (iOS 16+ only, cgaCyan/amberDark). Stacking warning in AddInsulinView (amber, correction bolus only, reactive to picker). IOB on TreatmentBannerView (countdown/rechecking states, second line). `InsulinSettingsView` with preset picker, basal DIA stepper, split toggle. Future deliveries excluded from IOB (not yet delivered). Zero threshold: 0.05U.
- **Meal impact overlay** — Tap single meal markers to see 2-hour post-meal glucose delta (color-coded green/amber/red), confounder detection (correction bolus, exercise, stacked meal), and PersonalFood rolling glycemic average. `MealImpactStore` middleware computes impacts on dual triggers (retroactive on app activation + real-time on new glucose readings). `analysisSessionId` links AI-analyzed meals to PersonalFood glycemic scores.
- **Event marker lane** — Dedicated 32px lane above the glucose chart replacing in-chart meal/insulin annotations. SF Symbol icons per type (`fork.knife` meals, `syringe.fill` insulin, `figure.run` exercise). Zoom-dependent consolidation groups nearby markers at wider zoom levels. `EventMarkerLaneView` is a self-contained view receiving pre-computed `ConsolidatedMarkerGroup` data and tap callbacks. Tap meal → meal impact overlay; tap insulin → confirmation dialog; tap group → expanded panel.
- **Daily Digest tab** — Fourth tab (Overview > Lists > Settings > Digest) showing daily glucose summary. `DailyDigestMiddleware` computes stats from raw GRDB data (glucose, meals, insulin, exercise) and generates AI insight via Claude Haiku with full context + 7-day cross-day history. `DailyDigest` model persisted to GRDB for history browsing. Date navigation for past days. Today always recomputes (no stale cache). Separate `aiConsentDailyDigest` consent toggle. Events loaded into `dailyDigestEvents` state for timeline display. `DigestView` has date nav bar, 2x3 stats grid (color-coded), AI insight card (cyan border), and chronological event timeline.
- **GRDB deadlock: never write inside asyncRead** — `DatabaseQueue` serializes all access. Calling `dbQueue.write` from inside a `dbQueue.asyncRead` callback deadlocks (read holds queue, write waits for queue). Always return data via the Future promise and do writes separately. See `docs/solutions/logic-errors/grdb-write-inside-asyncread-deadlock-20260420.md`.
- **Combine Future-to-async bridge: guard double-resume** — When bridging a `Future` to async/await via `withCheckedThrowingContinuation`, the `receiveValue` and `receiveCompletion` callbacks both fire (Future emits one value then completes). Must use a `resumed` flag to call `continuation.resume` exactly once. See `docs/solutions/logic-errors/combine-future-async-bridge-double-resume-20260420.md`.
- **Widget target has separate design system** — `Widgets/WidgetDesignSystem.swift` mirrors AmberTheme/DOSTypography colors and fonts for the widget extension (can't import app module). Pure logic types (`SparklineBuilder`, `DataStaleness`) live in `Library/Content/SparklineBuilder.swift` (both targets) for testability. Widget-specific color properties are extensions in the widget file.
- **Widget shared data via App Group** — `AppGroupSharing` middleware writes TIR, IOB, last meal, and sparkline to `UserDefaults.shared` (App Group suite) on each glucose update. IOB is pre-computed (read from `sharedIOB`), not recomputed in the sharing middleware. Widget data writes dispatch to background queue.
- **Live Activity data flows through ContentState** — never read `UserDefaults.shared` directly in Live Activity views. All data (glucose, IOB, sparkline) must pass through `SensorGlucoseActivityAttributes.ContentState` via `ActivityGlucoseService.getStatus()`. Direct UserDefaults reads bypass ActivityKit's sync mechanism and serve stale data on lock screen/rehydration.
- **Snapshot testing** — XCTest target `DOSBTSTests` with 138 tests covering IOB calculation engine, IOB reducer state, treatment cycle lifecycle, predictive alarm flags, alarm snooze auto-clear, treatment prompt state, MealImpact model, MealImpact reducer, delta thresholds, rolling average math, analysisSessionId linkage, PersonalFood glycemic fields, DailyDigest model/reducer, GlucoseStatistics computed properties, SensorGlucose clamping/minuteChange, SensorTrend slope classification, CustomCalibration regression, Sensor lifecycle, alarm thresholds, connection state, and glucose unit switching. Swift Testing framework (`@Test`, `#expect`). Run with Cmd+U on simulator.

## Project Structure

```
App/
  App.swift                    # @main DOSBTSApp entry point
  AppState.swift               # DirectState implementation (UserDefaults-backed)
  DesignSystem/
    Components/DOSButtonStyle.swift  # App-only button styles
    Modifiers/DOSModifiers.swift     # App-only view modifiers
  Modules/                     # Feature middlewares
    SensorConnector/           # BLE/NFC sensor connections
      SensorConnector.swift    # Main middleware + glucose filtering
      SensorBluetoothConnection.swift
      LibreConnection/         # Libre 2, LibreLink, LibreLinkUp
      BubbleConnection/        # Bubble transmitter
      VirtualConnection/       # Simulator testing
    DataStore/                 # GRDB-based persistence
    Nightscout/                # Nightscout upload
    AppleExport/               # HealthKit & Calendar export
    GlucoseNotification/       # Glucose alerts
    ConnectionNotification/
    ExpiringNotification/
    BellmanAlarm/
    ReadAloud/
    WidgetCenter/
    ScreenLock/
    TreatmentCycle/            # Hypo treatment workflow (Rule of 15)
    Claude/                    # AI food photo analysis (Claude Haiku)
    IOB/                       # Insulin-on-Board decay model middleware
    MealImpact/                # Meal impact overlay computation middleware
    DailyDigest/               # Daily digest stats + AI insight middleware
    Log/
    Debug/
  Views/
    OverviewView.swift         # Main glucose display
    DigestView.swift           # Daily digest tab (stats grid, AI card, timeline)
    SettingsView.swift
    CalibrationsView.swift
    ListsView.swift
    Overview/                  # Chart, sensor, connection subviews
    Settings/                  # Individual settings screens
    SharedViews/               # Reusable components
    AddViews/                  # Meal entry, photo analysis, insulin, blood glucose, calibration
Widgets/
  Widgets.swift                  # @main WidgetBundle
  WidgetDesignSystem.swift       # Widget-local colors, fonts, phosphor glow
  GlucoseWidget.swift            # Home screen (small/medium/large) + lock screen widgets
  GlucoseActivityWidget.swift    # Live Activity + Dynamic Island
  SensorWidget.swift             # Lock screen sensor lifetime gauge
  TransmitterWidget.swift        # Lock screen transmitter battery gauge
Library/
  Extensions/State.swift       # Store class, Reducer/Middleware typealiases
  DirectState.swift            # State protocol
  DirectAction.swift           # Action enum
  DirectReducer.swift          # Reducer function
  DirectStore.swift            # DirectStore typealias
  DirectNotifications.swift
  Content/                     # Domain models (Sensor, SensorGlucose, BloodGlucose, etc.)
  DesignSystem/                # Shared design tokens (both targets)
    AmberTheme.swift           # CGA amber color tokens
    DOSTypography.swift        # SF Mono font styles
    DOSSpacing.swift           # 8px grid spacing
  Extensions/                  # Swift type extensions
```

## Sensor Connection Protocol

All sensor connections implement `SensorConnectionProtocol` (`Library/Content/SensorConnection.swift`):
```swift
protocol SensorConnectionProtocol {
    var subject: PassthroughSubject<DirectAction, DirectError>? { get }
    func pairConnection()
    func connectConnection(sensor: Sensor, sensorInterval: Int)
    func disconnectConnection()
    func getConfiguration(sensor: Sensor) -> [SensorConnectionConfigurationOption]
}
```

Connections emit `DirectAction`s through a `PassthroughSubject`. Available connections:
- `Libre2Connection` — Direct Libre 2 via NFC+BLE
- `LibreLinkConnection` — LibreLink companion
- `LibreLinkUpConnection` — LibreLinkUp cloud API
- `BubbleConnection` — Bubble transmitter via BLE
- `VirtualConnection` — Simulated data for testing

## Design System: DOS Amber CGA

Source: eiDotter design system. Shared tokens in `Library/DesignSystem/` (`AmberTheme.swift`, `DOSTypography.swift`, `DOSSpacing.swift`). App-only components in `App/DesignSystem/` (`Components/DOSButtonStyle.swift`, `Modifiers/DOSModifiers.swift`).

Key colors:
- **Primary amber:** `#ffb000` (P3 phosphor 602nm)
- **Dim amber:** `#9a5700` (secondary text) → `AmberTheme.amberDark`
- **Bright amber:** `#fdca9f` (highlights) → `AmberTheme.amberLight` (NOT amberBright)
- **Background:** `#000000` (pure black)
- **Success/Low:** `#55ff55` (CGA green) → `AmberTheme.cgaGreen`
- **Error/High:** `#ff5555` (CGA red) → `AmberTheme.cgaRed`
- **Warning:** `#ffff55` (CGA yellow) — no dedicated property yet
- **Info:** `#55ffff` (CGA cyan) → `AmberTheme.cgaCyan`

Typography API (`DOSTypography`): `displayMedium` (28pt bold), `bodyLarge` (20pt), `body` (17pt), `bodySmall` (15pt), `caption` (12pt), `button` (17pt semibold), `tabBar` (10pt), `glucoseHero` (60pt bold), `mono(size:weight:)`. No `headline` or `title` members.

Rules:
- All text uses monospace fonts (`DOSTypography`)
- Sharp corners preferred (DOS aesthetic)
- Dark theme only (`.preferredColorScheme(.dark)`)
- 8px grid spacing
- SF Symbols have inconsistent intrinsic sizes — use `.frame(height:)` on icons when pixel-perfect alignment matters
- Fast, snappy animations (linear, short duration)

## Adding New State Properties

**For UserDefaults-backed settings** (toggles, preferences), add in 4 files:
1. `Library/DirectState.swift` — protocol declaration
2. `App/AppState.swift` — property with `didSet` + init from UserDefaults
3. `Library/Extensions/UserDefaults.swift` — `Keys` enum case + computed property
4. `Library/DirectReducer.swift` — reducer case

**For GRDB-backed data** (arrays loaded from database like `mealEntryValues`, `favoriteFoodValues`), add in 3 files — skip UserDefaults:
1. `Library/DirectState.swift` — protocol declaration
2. `App/AppState.swift` — property with default `= []` (no `didSet`, no UserDefaults)
3. `Library/DirectReducer.swift` — reducer case for the `set` action

Don't forget `Library/DirectAction.swift` if a new action is needed.

## Adding New Files to Xcode Project

The project uses Xcode's `fileSystemSynchronized` build system (DMNC-768). New `.swift` files placed anywhere under `App/`, `Library/`, or `Widgets/` are picked up automatically — no pbxproj edits needed.

Exceptions:
- **Tests** are NOT auto-synced. New files under `DOSBTSTests/` must be added to the `DOSBTSTests` group and `PBXSourcesBuildPhase` in `project.pbxproj` manually.
- **Widget-only exclusions.** The `DOSBTSWidget` target excludes `Library/Extensions/Float.swift` and all files in `Library/Resources/` (audio + `sensor.png`). If you add a new file under `Library/Resources/` that the widget should NOT include, add it to `E8217F012F97F9B800ACCE52 /* PBXFileSystemSynchronizedBuildFileExceptionSet */` in `project.pbxproj`.
- **Info.plist** is excluded from auto-inclusion (uses explicit `INFOPLIST_FILE` build setting).

## Adding GRDB Table Columns

Use `DatabaseMigrator` in the store's `create...Table()` method (see `SensorGlucoseStore.swift` for pattern):
```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("description") { db in
    try db.alter(table: MyModel.Table) { t in
        t.add(column: MyModel.Columns.newColumn.name, .double)
    }
}
try migrator.migrate(dbQueue)
```
Also add the column to the `Columns` enum in `DataStore.swift`.

## Development Rules

Key constraints from `docs/development-rules.md`:
- **No force unwrapping** (`!`) — use guard/let, optional chaining, nil coalescing
- **Async/await** for new code, no completion handlers
- **HealthKit is source of truth** for health data
- **Privacy by design** — no PII in logs/metadata
- **Offline-first** — core functionality works without network
- **No secrets in Redux actions** — never put API keys or tokens in action associated values; use Keychain as a side channel
- Conventional commits: `type(scope): subject` (feat, fix, docs, style, refactor, test, chore)

## CHANGELOG

- Every user-visible change goes under `## [Unreleased]` in `CHANGELOG.md` as part of the same PR that ships the change.
- When bumping `CURRENT_PROJECT_VERSION` for TestFlight, promote the `[Unreleased]` block to `## [Build N] — YYYY-MM-DD` and add a new empty `[Unreleased]` above it.
- Date is the TestFlight upload date, not the commit date. Use `git log` or App Store Connect to verify if in doubt.
- Group entries under `Added` / `Changed` / `Fixed` / `Removed` per [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
- Internal-only changes (refactors, tooling, CI) don't need a CHANGELOG entry unless a user can feel the effect.

## Docs

Additional documentation in `docs/`:
- `architecture.md` — System architecture
- `design-system.md` — Full design system spec
- `requirements.md` — Feature requirements
- `technology-stack.md` — Tech stack details
- `project-structure.md` — Directory layout
- `ui-mockups.md` — UI mockups
- `apple-watch-architecture.md` — Watch extension plans
- `solutions/` — Documented solutions to past problems (bugs, best practices, workflow patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in documented areas.
