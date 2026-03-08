---
title: "Food Logging, HealthKit Import & AI-Powered Health Analysis"
type: feat
status: active
date: 2026-03-08
linear_issues:
  - DMNC-389  # Food Logging MVP
  - DMNC-422  # Food Logging Idea (broader vision)
  - DMNC-425  # Phase 1 Food Logging MVP (High)
  - DMNC-426  # Phase 2 HealthKit Import (Medium, blocked by 425)
  - DMNC-427  # Phase 3 AI-Powered Food Analysis (Low, blocked by 425)
---

## Enhancement Summary

**Deepened on:** 2026-03-08
**Sections enhanced:** All 3 phases + technical considerations
**Research agents used:** architecture-strategist, security-sentinel, performance-oracle, pattern-recognition-specialist, code-simplicity-reviewer, UX researcher, GRDB/HealthKit framework researcher

### Key Improvements
1. **Simplified Phase 1 model** — Cut `MealSource` enum, `notes` field from MVP; 5-field model only
2. **Fixed `description` naming conflict** — Rename to `mealDescription` to avoid `CustomStringConvertible` collision with GRDB
3. **Security pre-work identified** — LibreLinkUp/Nightscout credentials stored in plaintext UserDefaults (existing vulnerability)
4. **Chart positioning corrected** — Meals at TOP of chart (above `alarmHigh`), insulin at BOTTOM, to avoid overlap
5. **Action naming aligned** — Use plural `mealEntryValues:` parameter style matching `addInsulinDelivery(insulinDeliveryValues:)` pattern
6. **Middleware return pattern** — Always return `Empty().eraseToAnyPublisher()` never `nil`/`break` to avoid stopping dispatch chain
7. **Post-meal glucose metrics** — Future UX: peak delta, time-to-peak, 2hr average, recovery time

# Food Logging, HealthKit Import & AI-Powered Health Analysis

## Overview

Add food/meal logging to DOSBTS, import health data from HealthKit (nutrition, exercise, heart rate), and lay groundwork for AI-powered glucose-food-exercise correlation analysis. This builds on the existing Redux-like architecture and extends the current HealthKit export to support bidirectional sync.

**Key insight:** HealthKit can serve as a universal bridge — other apps (MyFitnessPal, Carb Manager) write nutrition data to HealthKit, and DOSBTS reads it. Combined with manual meal logging, this gives users a complete picture of food impact on glucose.

**Note:** Claude iOS can read from Apple Health (beta, Pro/Max plan) but **cannot write** to HealthKit. So using Claude iOS as a food-photo bridge is not viable — we need to integrate the Claude API directly into DOSBTS.

## Problem Statement

DOSBTS currently shows glucose and insulin data but has no food/meal context. Users can't see how meals affect their glucose levels — the most fundamental question for anyone managing diabetes or metabolic health. Without food context, the glucose chart tells only half the story.

## Proposed Solution

Three-phase approach, each independently shippable:

1. **Phase 1 (MVP — DMNC-425):** Manual meal logging with GRDB storage and chart markers
2. **Phase 2 (DMNC-426):** HealthKit import of nutrition, exercise, and heart rate data from other apps
3. **Phase 3 (DMNC-427):** Claude API integration for food photo analysis and glucose correlation insights

---

## Pre-Phase 1: Security Fixes (Separate Work — Not Blocking)

> **Security sentinel finding:** LibreLinkUp credentials and Nightscout API secret are stored in plaintext `UserDefaults`. This is an existing vulnerability unrelated to food logging. Tracked separately — does not block Phase 1. The `KeychainService` wrapper is required before Phase 3 (API key storage).

- [ ] Create `KeychainService` utility for secure credential storage (needed for Phase 3 API key)
- ~~Nightscout/LibreLinkUp credential migration~~ — not relevant (Nightscout not in use)
- [ ] Fix `deleteGlucose` bug in `AppleHealthExport.swift:220` (uses `insulinType` instead of `glucoseType`)
- [ ] Ensure CSV export escapes `mealDescription` to prevent formula injection

---

## Phase 1: Food Logging MVP (DMNC-425)

### Data Model

#### MealEntry (`Library/Content/MealEntry.swift`)

```swift
struct MealEntry: Codable, Identifiable, CustomStringConvertible {
    let id: UUID
    let timestamp: Date
    let mealDescription: String   // "Chicken salad with rice"
    let carbsGrams: Double?       // Estimated carbs in grams (optional)
    let timegroup: Date           // Rounded for grouping (matches existing pattern)

    var description: String {
        "MealEntry(id: \(id), timestamp: \(timestamp), mealDescription: \(mealDescription), carbsGrams: \(carbsGrams ?? 0))"
    }
}
```

**Design decisions:**
- **`mealDescription` not `description`** — avoids conflict with `CustomStringConvertible.description` which GRDB uses for column mapping. Using `description` would cause the computed property to be stored instead of the meal name.
- `carbsGrams` is `Double?` (not Int) — matches insulin `units` pattern and HealthKit's `HKQuantity` precision (supports 22.5g)
- `carbsGrams` is optional — users may not always know the carb count
- `mealDescription` is required — every meal should have at least a name
- **No `MealSource` enum in MVP** — only manual entry exists in Phase 1. Add when HealthKit import arrives in Phase 2 (simple migration: add column with default "manual")
- **No `notes` field in MVP** — `mealDescription` is free-text and serves both purposes. Add later if distinct use case emerges
- `timegroup` stored (not computed) — matches existing BloodGlucose/InsulinDelivery pattern for indexed date-range queries
- Single `timestamp` (not starts/ends like InsulinDelivery) — meals are point-in-time events
- No separate `MealType` enum yet (breakfast/lunch/dinner) — keep it simple for MVP

#### GRDB Table (`App/Modules/DataStore/MealStore.swift`)

Follow the InsulinDeliveryStore pattern exactly:

```swift
// In DataStore.swift — add FetchableRecord + PersistableRecord extension
extension MealEntry: FetchableRecord, PersistableRecord {
    static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
    static var Table: String { "MealEntry" }

    enum Columns: String, ColumnExpression {
        case id, timestamp, mealDescription, carbsGrams, timegroup
    }
}
```

Table schema:
- `id` TEXT PRIMARY KEY
- `timestamp` DATE NOT NULL, INDEXED
- `mealDescription` TEXT NOT NULL
- `carbsGrams` DOUBLE (nullable)
- `timegroup` DATE NOT NULL, INDEXED

### Actions (`Library/DirectAction.swift`)

```swift
// Add to DirectAction enum (naming matches addInsulinDelivery pattern):
case addMealEntry(mealEntryValues: [MealEntry])
case deleteMealEntry(mealEntry: MealEntry)
case loadMealEntryValues
case setMealEntryValues(mealEntryValues: [MealEntry])
```

> **Note:** `addMealEntry` takes an array `mealEntryValues` matching the `addInsulinDelivery(insulinDeliveryValues:)` pattern, even though MVP only adds one at a time. This avoids a future signature change when batch import arrives in Phase 2.

### State (`Library/DirectState.swift` + `App/AppState.swift`)

```swift
// Add to DirectState protocol:
var mealEntryValues: [MealEntry] { get }

// Add to AppState:
var mealEntryValues: [MealEntry] = []
```

### Reducer (`Library/DirectReducer.swift`)

```swift
case .setMealEntryValues(mealEntryValues: let values):
    state.mealEntryValues = values
```

### Middleware (`App/Modules/DataStore/MealStore.swift`)

Follow `insulinDeliveryStoreMiddleware()` pattern:
- `.startup` → create table with `ifNotExists: true`, get first meal date
- `.addMealEntry` → insert into GRDB, dispatch `.loadMealEntryValues`
- `.deleteMealEntry` → delete from GRDB, dispatch `.loadMealEntryValues`
- `.setSelectedDate` → reload for selected date
- `.loadMealEntryValues` → query GRDB for current date range

> **⚠️ Middleware return pattern:** For handled actions with no follow-up dispatch, return `Empty().eraseToAnyPublisher()` — never `nil` or use `break`. The dispatch chain uses `break` which stops ALL subsequent middlewares from processing the action. This is a latent bug in the existing codebase; don't replicate it.

### UI: Add Meal View (`App/Views/AddViews/AddMealView.swift`)

Follow `AddInsulinView` pattern:
- Modal sheet with NavigationView
- Fields: description (TextField), carbs grams (NumberField, optional), timestamp (DatePicker)
- "Add" button in toolbar calls callback
- Cancel button dismisses
- **Apply DOS theme:** Use `.dosTextField()` modifier on inputs, `AmberTheme.dosBlack` background, amber text. Match the existing `AddInsulinView` styling exactly — the code below is structural reference, not final styled code.

```swift
struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var descriptionFocus: Bool

    @State var timestamp: Date = .init()
    @State var mealDescription: String = ""
    @State var carbsGrams: Double?

    var addCallback: (_ timestamp: Date, _ mealDescription: String, _ carbsGrams: Double?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Description", text: $mealDescription)
                        .focused($descriptionFocus)

                    HStack {
                        Text("Carbs (g)")
                        TextField("", value: $carbsGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Time", selection: $timestamp,
                               displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Meal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard !mealDescription.isEmpty else { return }
                        addCallback(timestamp, mealDescription, carbsGrams)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    self.descriptionFocus = true
                }
            }
        }
    }
}
```

### UI: Chart Markers (`App/Views/Overview/ChartView.swift`)

Add meal entries as PointMark with diamond symbol and carb annotation, positioned in the **upper** chart area (above `alarmHigh`) to avoid collision with insulin markers at the bottom:

```swift
// Add to Chart { } body, after insulin series:
ForEach(mealSeries) { value in
    PointMark(
        x: .value("Time", value.time),
        y: .value("Meal", Double(alarmHigh) + 20)  // Position above high alarm line
    )
    .symbolSize(value.carbsValue.map(from: 0...100, to: 30...120))
    .symbol(.diamond)
    .annotation(position: .top) {
        Text(value.carbsLabel)  // "45g" — concise, matches insulin annotation style
            .foregroundStyle(AmberTheme.cgaGreen)
            .padding(.horizontal, 2.5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(2)
            .font(DOSTypography.caption)
    }
    .foregroundStyle(AmberTheme.cgaGreen)
}
```

**Positioning:** Meals at TOP of chart, insulin at BOTTOM — clear visual separation. Annotations show carb grams only ("45g") not full description, matching the concise insulin annotation style.

**Color choice:** CGA green (`#55ff55`) for meals — distinct from cyan (glucose), amber-dark (insulin), red (blood glucose/alarms).

### UI: Meal List

Add meals to the existing ListsView, either as a new section or a new tab segment. Follow the pattern of how insulin deliveries are listed — grouped by date with swipe-to-delete.

### HealthKit Carb Export (Deferred to Phase 2)

> **Decision:** HealthKit carb export is deferred to Phase 2, keeping Phase 1 purely local (GRDB + UI). This reduces scope and avoids touching the HealthKit permission flow in MVP. The code below is reference for Phase 2 implementation.

Extend `AppleHealthExportService` to write `HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)` when meals with carb values are logged:

```swift
// Add to requiredPermissions:
var carbsType: HKQuantityType {
    HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!
}

// Add case to middleware (use Empty() not break!):
case .addMealEntry(mealEntryValues: let values):
    guard state.appleHealthExport else {
        return Empty().eraseToAnyPublisher()
    }
    for mealEntry in values {
        if let carbs = mealEntry.carbsGrams {
            service.value.addCarbs(mealEntry: mealEntry)
        }
    }
    return Empty().eraseToAnyPublisher()
```

### Files to Create/Modify (Phase 1)

| Action | File | Description |
|--------|------|-------------|
| CREATE | `Library/Content/MealEntry.swift` | Data model |
| CREATE | `App/Modules/DataStore/MealStore.swift` | GRDB store + middleware |
| MODIFY | `App/Modules/DataStore/DataStore.swift` | Add FetchableRecord extension |
| MODIFY | `Library/DirectAction.swift` | Add meal actions |
| MODIFY | `Library/DirectState.swift` | Add mealEntryValues property |
| MODIFY | `App/AppState.swift` | Implement mealEntryValues |
| MODIFY | `Library/DirectReducer.swift` | Handle setMealEntryValues |
| MODIFY | `Library/DirectStore.swift` | Register mealStoreMiddleware |
| CREATE | `App/Views/AddViews/AddMealView.swift` | Add meal form |
| MODIFY | `App/Views/Overview/ChartView.swift` | Meal chart markers |
| MODIFY | `App/Views/Lists/` | Meal list section |
| MODIFY | `App/App.swift` | Register mealStoreMiddleware in BOTH store creators |
| MODIFY | `DOSBTS.xcodeproj/project.pbxproj` | Add new files to project |

### Acceptance Criteria (Phase 1)

- [ ] MealEntry model with id, timestamp, mealDescription, carbsGrams?, timegroup
- [ ] GRDB table created with `ifNotExists: true` on startup
- [ ] FetchableRecord/PersistableRecord extension in DataStore.swift
- [ ] Add meal modal form (mealDescription required, carbs optional, timestamp)
- [ ] Meals appear as green diamond markers at TOP of glucose chart
- [ ] Meal list view with date grouping and swipe-to-delete
- [ ] Actions, reducer, state follow existing Redux patterns exactly
- [ ] MealStore middleware registered in BOTH store creators in App.swift
- [ ] Middleware returns `Empty().eraseToAnyPublisher()` (not nil/break)
- [ ] DOS amber theme applied to all new UI (monospace, dark, amber accents)

---

## Phase 2: HealthKit Import (DMNC-426)

### Overview

Create a new `AppleHealthImport` module (separate from existing export) that reads nutrition, exercise, and heart rate data from HealthKit into DOSBTS.

### HealthKit Data Types to Import

| Category | HKQuantityType / HKWorkoutType | Display |
|----------|-------------------------------|---------|
| **Carbohydrates** | `.dietaryCarbohydrates` | Meal markers on chart |
| **Energy** | `.dietaryEnergyConsumed` | Info in meal detail view |
| **Protein** | `.dietaryProtein` | Info in meal detail view |
| **Fat** | `.dietaryFatTotal` | Info in meal detail view |
| **Exercise** | `HKWorkout` (all activity types) | Activity markers on chart |
| **Heart Rate** | `.heartRate` | Overlay line on chart |
| **Active Energy** | `.activeEnergyBurned` | Exercise detail |

### Architecture

#### New Module: `App/Modules/AppleImport/AppleHealthImport.swift`

```swift
func appleHealthImportMiddleware() -> Middleware<DirectState, DirectAction> {
    // Handles:
    // .requestAppleHealthImportAccess(enabled:)
    // .setAppleHealthImport(enabled:)
    // .importHealthKitNutrition
    // .importHealthKitExercise
    // .importHealthKitHeartRate
    // .setSelectedDate → re-import for date range
}
```

#### Import Strategy

**Anchored queries** (`HKAnchoredObjectQuery`) for incremental sync:
- Store last anchor per data type in UserDefaults
- On app foreground or date change, query for new samples since last anchor
- Convert HK samples to local models (MealEntry from carb samples, new ExerciseEntry, HeartRateEntry)

**Background delivery** (`HKObserverQuery` + `enableBackgroundDelivery`):
- Register for dietaryCarbohydrates, workout, heartRate updates
- Wake app to sync new data
- Requires `UIBackgroundModes: processing` in Info.plist

#### HealthKit Read Permissions

Extend `requiredPermissions` in health service:

```swift
var readPermissions: Set<HKObjectType> {
    Set([
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType(),
    ])
}
```

**Privacy strings update** (Info.plist):
- `NSHealthShareUsageDescription`: "DOSBTS reads nutrition, exercise, and heart rate data from Apple Health to show how food and activity affect your glucose levels."
- `NSHealthUpdateUsageDescription`: "DOSBTS writes glucose, insulin, and nutrition data to Apple Health."

#### Source Filtering

HealthKit samples include source metadata. Users should be able to:
- See which app wrote each nutrition sample (MyFitnessPal, Carb Manager, etc.)
- Filter imports by source app if desired
- Distinguish manually-logged meals (DOSBTS) from imported ones

#### New Data Models

**ExerciseEntry** (`Library/Content/ExerciseEntry.swift`):
```swift
struct ExerciseEntry: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let activityType: String      // HKWorkoutActivityType description
    let durationMinutes: Double
    let activeCalories: Double?
    let source: String?           // Source app name
    let timegroup: Date
}
```

**HeartRateEntry** — Consider NOT persisting to GRDB (too much data). Instead, query HealthKit on-demand for the visible chart date range and display as an overlay.

### Chart Overlays

| Data | Chart Mark | Color | Position |
|------|-----------|-------|----------|
| Meals (manual + imported) | PointMark diamond | CGA green | Upper area (above alarmHigh) |
| Exercise | RectangleMark (duration) | CGA cyan light | Bottom band |
| Heart rate | LineMark | CGA white (dimmed) | Secondary Y-axis |

### Acceptance Criteria (Phase 2)

- [ ] HealthKit import middleware with anchored queries
- [ ] Import nutrition samples (carbs, calories, protein, fat)
- [ ] Import workout/exercise sessions
- [ ] Heart rate overlay on chart (queried on-demand, not persisted)
- [ ] Background delivery for new HealthKit samples
- [ ] Source app attribution on imported entries
- [ ] Settings toggle for HealthKit import (separate from export)
- [ ] Updated privacy strings in Info.plist
- [ ] Imported meals shown alongside manual meals on chart

---

## Phase 3: AI-Powered Analysis (DMNC-427)

### Claude API Integration

#### Architecture: BYOK (Bring Your Own Key)

**Recommended approach** for an independent/free app:
- User enters their own Anthropic API key in Settings
- Key stored in Keychain (not UserDefaults — UserDefaults is not encrypted)
- No backend proxy needed — direct `URLSession` API calls from device (no Swift SDK needed, matches vendored approach)
- Zero ongoing cost for the developer
- Cost to user: ~$0.003/call with Haiku 4.5 → ~$0.42-0.75/month for moderate use

```swift
// Settings: API Key entry
// Store in Keychain via Security framework
// Pass to AnthropicService for API calls
```

#### Feature 1: Food Photo → Carb Estimation

User flow:
1. User taps "Add Meal" → option to take photo
2. Photo sent to Claude Vision API with prompt: "Estimate the nutritional content of this meal. Return: description, estimated carbs (g), protein (g), fat (g), calories."
3. Claude returns structured estimate
4. User confirms/adjusts values → saves as MealEntry
5. Entry exported to HealthKit

**API cost estimate**: ~$0.01-0.03 per food photo analysis (Haiku 4.5 with vision). At 3-5 meals/day = ~$1-4/month per user. With BYOK, user pays directly.

#### Feature 2: Glucose-Food Correlation Analysis

User flow:
1. User taps "Analyze" on a time period
2. App sends glucose readings + meal entries + exercise data to Claude
3. Claude identifies patterns: "Your glucose spikes ~45 min after rice-based meals. Exercise within 30 min of eating reduces the spike by ~30%."
4. Results displayed in a dedicated analysis view

**Privacy consideration**: Glucose data + food logs sent to Anthropic API. Require explicit user consent. Consider on-device summarization first to minimize data sent.

#### Feature 3: Substance/Supplement Tracking

Add a `SubstanceEntry` model for tracking:
- Medications (metformin, etc.)
- Supplements (vitamins, mushroom supplements)
- Caffeine, alcohol
- Other substances that affect glucose

Simple model: name, dose, timestamp. Display as chart markers. HealthKit doesn't have great support for supplements (no standard type), so this would be local-only.

### Acceptance Criteria (Phase 3)

- [ ] BYOK API key entry in Settings (Keychain storage)
- [ ] Food photo → carb estimation via Claude Vision
- [ ] Structured response parsing (description, carbs, protein, fat, calories)
- [ ] User confirmation step before saving AI estimates
- [ ] Glucose correlation analysis view
- [ ] Explicit privacy consent for sending health data to API
- [ ] Substance/supplement tracking model and UI

---

## Findings from Research

### HealthKit Read Permissions Are Opaque

HealthKit deliberately hides whether the user granted read access. `authorizationStatus(for:)` always returns `.notDetermined` for read types, even if denied. The UI must gracefully handle empty query results without distinguishing "no data" from "access denied."

### HealthKit Food Correlations vs Flat Samples

`HKCorrelationType.food` groups nutrition samples into a logical meal. However, many apps (including MyFitnessPal) write flat `HKQuantitySample` objects WITHOUT correlations. Phase 2 import must handle **both** patterns — query for food correlations AND standalone nutrition samples, then merge by time window (~30 min grouping).

### Background Delivery Entitlement Required

Phase 2 background HealthKit delivery requires adding `com.apple.developer.healthkit.background-delivery` to `App.entitlements`. Not currently present.

### Research Insights: Performance

- **Heart rate (Phase 2)**: Hourly or daily granularity is sufficient — no need to handle 1-sample-per-second workout data. Query HealthKit for the visible date range with hourly averages (or daily resting HR). This eliminates the performance concern entirely.
- **Photo analysis (Phase 3)**: Resize food photos to max 1024px before base64 encoding for Claude Vision. Full-res photos bloat the request (5-10MB → 200KB).
- **Phase 1 has no performance concerns** — meal data is sparse (3-5 entries/day).

### Research Insights: UX

- **Target: under 10 seconds** to log a meal (description + carbs + save)
- **Auto-focus description field** on sheet appear (already in plan)
- **Future: vertical RuleMark** connecting meal marker to glucose curve for visual causation
- **Future: post-meal metrics** — peak glucose delta, time-to-peak, 2hr average, recovery time
- **Swipe-to-delete** on meal list (matches insulin pattern)

### Research Insights: Architecture

- **Extract shared middleware array** — `App.swift` duplicates middleware list for device/simulator. Consider extracting to a shared function. (Not blocking for Phase 1, but reduces error risk.)
- **HealthKit feedback loop risk (Phase 2)**: When both import and export are active, writing a meal → exports to HealthKit → import detects "new" sample → creates duplicate. Use `HKMetadataKeySyncIdentifier` + bundle ID filtering to break the loop.

---

## Technical Considerations

### iOS 15 Compatibility

- Swift Charts requires iOS 16+ — the app already uses Charts, so this is already the effective minimum
- `HKAnchoredObjectQuery` available since iOS 8 — no issues
- Background delivery available since iOS 8
- Keychain APIs available since iOS 2

### HealthKit Entitlements

Already configured in `App/App.entitlements`:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array><string>health-records</string></array>
```

Need to add to capabilities: background delivery requires no additional entitlement, just `enableBackgroundDelivery` call.

### Data Deduplication

When both manual logging and HealthKit import are active:
- Use `HKMetadataKeySyncIdentifier` on exported meals to prevent re-importing our own data
- Filter imported samples to exclude source = our own bundle ID
- Match by timestamp + carbs value to detect duplicates from manual entry vs import

### Performance

- Heart rate: hourly or daily granularity is sufficient. Query for visible chart range with hourly averages — no need for per-second data
- Meal/exercise data is sparse — no performance concerns
- Background HealthKit queries should be lightweight — use date predicates

### Middleware Registration

**Critical:** `App.swift` has TWO middleware arrays — `createAppStore()` (device) and `createSimulatorAppStore()` (simulator). Both must include new middlewares. Also note that middleware ordering matters: returning `nil` from a middleware **stops all subsequent middlewares** from processing that action. Always return `Empty().eraseToAnyPublisher()` when handling an action with no follow-up.

### Database Migration

No migration needed — new tables created with `ifNotExists: true` on startup, following existing pattern. Old databases simply get the new table added.

---

## Implementation Order

```
Pre-Phase 1 (Optional) — ~1 session
├── 0.1 Fix deleteGlucose bug in AppleHealthExport.swift:220
├── 0.2 Create KeychainService wrapper
└── 0.3 Migrate credentials from UserDefaults to Keychain

Phase 1 (MVP) — ~2-3 sessions
├── 1.1 MealEntry model (Library/Content/MealEntry.swift)
├── 1.2 GRDB extension in DataStore.swift
├── 1.3 Actions in DirectAction.swift, state in DirectState/AppState
├── 1.4 Reducer in DirectReducer.swift
├── 1.5 MealStore middleware (App/Modules/DataStore/MealStore.swift)
├── 1.6 AddMealView (App/Views/AddViews/AddMealView.swift)
├── 1.7 Chart meal markers in ChartView.swift
├── 1.8 Meal list section in ListsView
├── 1.9 Register middleware in App.swift (BOTH arrays!)
└── 1.10 Add files to DOSBTS.xcodeproj/project.pbxproj

Phase 2 (HealthKit Import) — ~2-3 sessions
├── 2.1 AppleHealthImport middleware
├── 2.2 HealthKit read permissions + privacy strings
├── 2.3 Nutrition import (anchored queries)
├── 2.4 Exercise/workout import
├── 2.5 Heart rate chart overlay
├── 2.6 Background delivery
├── 2.7 Source filtering
└── 2.8 Settings toggle for import

Phase 3 (AI) — ~3-4 sessions
├── 3.1 BYOK API key settings + Keychain
├── 3.2 Claude Vision food photo analysis
├── 3.3 Structured response parsing
├── 3.4 Correlation analysis view
└── 3.5 Substance tracking
```

## Dependencies & Risks

| Risk | Mitigation |
|------|-----------|
| HealthKit read permissions rejected by user | Graceful fallback — manual logging still works |
| HealthKit background delivery unreliable | Foreground refresh on app open as primary, background as bonus |
| Claude API costs too high for users | BYOK model — user controls their own spend; start with Haiku for cheapest option |
| App Store review for health claims | Don't make medical claims — "informational" framing. AI analysis should include disclaimers |
| Heart rate data too dense for chart | Hourly or daily aggregation is sufficient — no per-second data needed |
| Duplicate entries from import + manual | Sync identifier filtering + bundle ID exclusion |

## Sources & References

### Internal References
- Existing HealthKit export: `App/Modules/AppleExport/AppleHealthExport.swift`
- Existing GRDB patterns: `App/Modules/DataStore/InsulinDeliveryStore.swift`
- GRDB extensions centralized: `App/Modules/DataStore/DataStore.swift`
- Existing chart marks: `App/Views/Overview/ChartView.swift:170-258`
- Existing add view template: `App/Views/AddViews/AddInsulinView.swift`
- InsulinDelivery model template: `Library/Content/InsulinDelivery.swift`
- Middleware registration: `App/App.swift` (TWO arrays: device + simulator)

### Linear Issues
- DMNC-389: Food Logging MVP (original)
- DMNC-422: Food Logging Idea (broader vision, original)
- DMNC-425: Phase 1 Food Logging MVP (implementation, High)
- DMNC-426: Phase 2 HealthKit Import (implementation, Medium, blocked by 425)
- DMNC-427: Phase 3 AI-Powered Food Analysis (implementation, Low, blocked by 425)

### External References
- Apple HealthKit docs: [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- Apple HealthKit docs: [Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)

### Known Bugs to Fix
- `AppleHealthExport.swift:220` — `deleteGlucose` uses `self.insulinType` instead of `self.glucoseType`
- LibreLinkUp/Nightscout credentials in plaintext UserDefaults (security vulnerability)
