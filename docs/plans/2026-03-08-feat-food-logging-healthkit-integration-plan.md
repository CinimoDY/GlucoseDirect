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

**Deepened on:** 2026-03-08 (second pass — 9 parallel research agents)
**Sections enhanced:** Phase 2 (HealthKit Import), Phase 3 (Claude API), Security, Performance, Architecture
**Research agents used:** HealthKit best-practices-researcher, Claude Vision API researcher, iOS Keychain researcher, Swift Charts framework-docs-researcher, architecture-strategist, security-sentinel, performance-oracle, Context7 HealthKit docs, Context7 Anthropic API docs

### Key Improvements (Second Pass)
1. **Modern HealthKit API** — Use `HKAnchoredObjectQueryDescriptor` (iOS 15.4+ async/await) instead of callback-based API
2. **Anchor persistence** — Store `HKQueryAnchor` as NSSecureCoding Data in UserDefaults (invalidated anchors gracefully return full dataset)
3. **Heart rate via HKStatisticsCollectionQuery** — Hourly `.discreteAverage` aggregation, 24 data points max per day, query once per date change
4. **Food correlation + flat sample handling** — Query both `HKCorrelationType.food` and standalone `HKQuantitySample`, merge by 30-min time window
5. **Claude Vision API** — Base64 JPEG, `output_config.format.json_schema` for structured nutrition response, Haiku 4.5 at ~$0.003/call
6. **App Store compliance** — Guideline 5.1.2(i) requires naming Anthropic explicitly, per-feature opt-in consent, no bundled permissions
7. **CRITICAL security findings** — Full API response bodies (including auth tokens) logged to disk in LibreLinkUpConnection.swift; log middleware dispatches action descriptions containing credentials
8. **Chart overlay strategy** — Normalize heart rate into glucose Y-axis using existing `.map(from:to:)` pattern (no dual Y-axis needed)
9. **Performance debounce needed** — Multiple `onChange` handlers trigger parallel `updateSeriesMetadata()` calls; debounce before adding more data series
10. **Background delivery entitlement** — Must add `com.apple.developer.healthkit.background-delivery` to App.entitlements (confirmed required since iOS 15+)

### Previous Key Improvements (First Pass)
1. Simplified Phase 1 model — Cut `MealSource` enum, `notes` field from MVP; 5-field model only
2. Fixed `description` naming conflict — Rename to `mealDescription` to avoid `CustomStringConvertible` collision with GRDB
3. Chart positioning — Meals at TOP (`chartMinimum * 0.85`), insulin at BOTTOM
4. Action naming aligned — `mealEntryValues:` parameter style matching `addInsulinDelivery(insulinDeliveryValues:)`
5. Middleware return pattern — Always return `Empty().eraseToAnyPublisher()` never `nil`/`break`

---

# Food Logging, HealthKit Import & AI-Powered Health Analysis

## Overview

Add food/meal logging to DOSBTS, import health data from HealthKit (nutrition, exercise, heart rate), and lay groundwork for AI-powered glucose-food-exercise correlation analysis. This builds on the existing Redux-like architecture and extends the current HealthKit export to support bidirectional sync.

**Key insight:** HealthKit can serve as a universal bridge — other apps (MyFitnessPal, Carb Manager) write nutrition data to HealthKit, and DOSBTS reads it. Combined with manual meal logging, this gives users a complete picture of food impact on glucose.

**Note:** Claude iOS can read from Apple Health (beta, Pro/Max plan) but **cannot write** to HealthKit. So using Claude iOS as a food-photo bridge is not viable — we need to integrate the Claude API directly into DOSBTS.

## Problem Statement

DOSBTS currently shows glucose and insulin data but has no food/meal context. Users can't see how meals affect their glucose levels — the most fundamental question for anyone managing diabetes or metabolic health. Without food context, the glucose chart tells only half the story.

## Proposed Solution

Three-phase approach, each independently shippable:

1. **Phase 1 (MVP — DMNC-425):** ✅ COMPLETE — Manual meal logging with GRDB storage and chart markers
2. **Phase 2 (DMNC-426):** HealthKit import of nutrition, exercise, and heart rate data from other apps
3. **Phase 3 (DMNC-427):** Claude API integration for food photo analysis and glucose correlation insights

---

## Pre-Phase 2: Security Fixes (Should Do Before Phase 2)

> **Security audit findings (CRITICAL):** Multiple pre-existing vulnerabilities identified. The KeychainService is required before Phase 3, but the logging vulnerabilities should be fixed immediately.

### CRITICAL: Fix Credential/Token Logging

- [x] **C-2: API response bodies logged to disk** — `LibreLinkUpConnection.swift` lines 311, 366, 399, 436 log FULL response bodies including auth tokens (`authTicket.token`), user IDs, and patient IDs to file-based logs. These are exportable via the "Send Logs" feature. **Fix:** Never log full response bodies. Log only status codes and sanitized error messages.
- [x] **C-3: Action descriptions in logs may contain credentials** — The log middleware at `Log.swift:53` logs action descriptions. Already handled: `setNightscoutURL` and `setNightscoutSecret` are excluded from logging at lines 27-31.
- [x] Ensure log files are excluded from iCloud/iTunes backups via `isExcludedFromBackup`

### KeychainService (Required for Phase 3)

- [ ] Create `KeychainService` utility for secure credential storage

```swift
// Minimal KeychainService — use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
// for API keys (accessible in background after first device unlock, not in backups)
enum KeychainService {
    private static let serviceName = "com.dosbts.credentials"

    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.encodingFailed }
        // Try update first (cheaper than delete-then-add, no race condition)
        let updateQuery = baseQuery(key: key)
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary,
                                         [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw keychainError(for: updateStatus) }
        // Add new item
        var addQuery = baseQuery(key: key)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw keychainError(for: addStatus) }
    }

    static func read(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) { SecItemDelete(baseQuery(key: key) as CFDictionary) }

    private static func baseQuery(key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: serviceName,
         kSecAttrAccount as String: key]
    }
}
```

> **Access control choice:** `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — accessible in background (needed for HealthKit background delivery), excluded from backups, device-only. Better than `WhenUnlockedThisDeviceOnly` which blocks background access.

- [x] Fix `deleteGlucose` bug in `AppleHealthExport.swift:220` (uses `self.insulinType` instead of `self.glucoseType`)
- [ ] Ensure CSV export escapes `mealDescription` to prevent formula injection

---

## Phase 1: Food Logging MVP (DMNC-425) — ✅ COMPLETE

Phase 1 has been implemented and shipped to TestFlight. See commit `9024274e` (feat: add Phase 1 food logging MVP) and `82f7dbbd` (refactor: address code review findings).

**What shipped:**
- [x] MealEntry model with id, timestamp, mealDescription, carbsGrams?, timegroup
- [x] GRDB table created with `ifNotExists: true` on startup
- [x] FetchableRecord/PersistableRecord extension in DataStore.swift
- [x] Add meal modal form (mealDescription required, carbs optional, timestamp)
- [x] Input validation: trim whitespace, 200 char cap, carbs 0-1000 range
- [x] Meals appear as green diamond markers at TOP of glucose chart (`chartMinimum * 0.85`)
- [x] Meal list view with date grouping and swipe-to-delete
- [x] Actions, reducer, state follow existing Redux patterns exactly
- [x] MealStore middleware registered in BOTH store creators in App.swift
- [x] Middleware returns `Empty().eraseToAnyPublisher()` (not nil/break)

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

#### Decision: ONE Middleware, Internal Service Decomposition

> **Architecture review finding:** Use a single `appleHealthImportMiddleware()` following the established pattern. The existing export handles glucose + insulin in one middleware; Nightscout handles blood glucose + sensor glucose + insulin in one middleware. Splitting into multiple middlewares adds more entries to the dual middleware arrays in App.swift, increasing sync error risk. However, the internal service class should be decomposed into `NutritionImporter`, `ExerciseImporter`, `HeartRateQuerier` for clarity.

#### New Module: `App/Modules/AppleImport/AppleHealthImport.swift`

```swift
func appleHealthImportMiddleware() -> Middleware<DirectState, DirectAction> {
    return appleHealthImportMiddleware(service: LazyService<AppleHealthImportService>(initialization: {
        AppleHealthImportService()
    }))
}

private func appleHealthImportMiddleware(service: LazyService<AppleHealthImportService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .requestAppleHealthImportAccess(enabled: let enabled):
            // Request read permissions, dispatch .setAppleHealthImport(enabled:)
        case .setSelectedDate, .loadMealEntryValues:
            // Re-query HealthKit for visible date range
        case .setAppState(appState: let appState) where appState == .active:
            // Foreground refresh — query anchored queries for new data
        default:
            break
        }
        return Empty().eraseToAnyPublisher()
    }
}
```

#### Import Strategy: Anchored Queries (Modern API)

Use `HKAnchoredObjectQueryDescriptor` (iOS 15.4+ async/await API) for incremental sync:

```swift
actor NutritionSyncManager {
    private let healthStore = HKHealthStore()

    /// Anchor persistence — store as NSSecureCoding Data in UserDefaults
    private func saveAnchor(_ anchor: HKQueryAnchor, for key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "com.dosbts.hkAnchor.\(key)")
        }
    }

    private func loadAnchor(for key: String) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: "com.dosbts.hkAnchor.\(key)") else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    /// Fetch new nutrition samples since last anchor
    func fetchNewSamples(type: HKQuantityTypeIdentifier) async throws -> [HKQuantitySample] {
        let quantityType = HKQuantityType(type)
        let anchor = loadAnchor(for: type.rawValue)
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: quantityType)],
            anchor: anchor
        )
        let result = try await descriptor.result(for: healthStore)
        saveAnchor(result.newAnchor, for: type.rawValue)
        return result.addedSamples.compactMap { $0 as? HKQuantitySample }
    }
}
```

> **Anchor invalidation:** When HealthKit's database is reset (device restore, etc.), an invalid anchor behaves like `nil` — returns ALL samples from scratch. No error thrown. Handle gracefully by deduplicating against existing GRDB entries.

#### Food Correlations vs Flat Samples

> **Research finding:** `HKCorrelationType.food` groups nutrition samples into a logical meal. But many apps (MyFitnessPal, Cronometer) write **flat** `HKQuantitySample` objects WITHOUT correlations. Must handle both patterns.

**Strategy — query both, merge by time window:**

```swift
func fetchMealsFromHealthKit(dateRange: DateInterval) async throws -> [ImportedMeal] {
    // 1. Query food correlations (grouped meals)
    let correlationDescriptor = HKSampleQueryDescriptor(
        predicates: [.correlation(type: HKCorrelationType(.food),
                                  samplePredicates: [.quantitySample(type: HKQuantityType(.dietaryCarbohydrates))])],
        sortDescriptors: [SortDescriptor(\.startDate)]
    )
    let correlations = try await correlationDescriptor.result(for: healthStore)

    // 2. Query standalone carb samples (flat samples from apps that don't use correlations)
    let flatDescriptor = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: HKQuantityType(.dietaryCarbohydrates),
                                     predicate: HKQuery.predicateForSamples(withStart: dateRange.start,
                                                                            end: dateRange.end))],
        sortDescriptors: [SortDescriptor(\.startDate)]
    )
    let flatSamples = try await flatDescriptor.result(for: healthStore)

    // 3. Filter out samples already in correlations
    let correlatedSampleUUIDs = Set(correlations.flatMap { ($0 as! HKCorrelation).objects }.map(\.uuid))
    let standaloneSamples = flatSamples.filter { !correlatedSampleUUIDs.contains($0.uuid) }

    // 4. Group standalone samples by 30-min time window into logical meals
    return mergeIntoMeals(correlations: correlations, standaloneSamples: standaloneSamples)
}
```

#### Deduplication: Import/Export Feedback Loop Prevention

> **Research finding:** The existing export code already uses `HKMetadataKeySyncIdentifier` (see `AppleHealthExport.swift:190`). Use the same pattern on import.

**Three-layer dedup strategy:**

1. **Bundle ID filtering** — Exclude samples where `sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier` (our own exports)
2. **Sync identifier check** — Skip samples with `HKMetadataKeySyncIdentifier` matching any UUID in our GRDB MealEntry table
3. **Timestamp + carbs fuzzy match** — For manually-logged meals also imported from another app, match within 5-minute window + same carb value

#### Heart Rate: On-Demand Query with HKStatisticsCollectionQuery

> **Performance finding:** 24 data points per day (hourly averages). Trivially small. Query once per date change, cache in memory.

```swift
func fetchHourlyHeartRate(for date: Date) async throws -> [(Date, Double)] {
    let heartRateType = HKQuantityType(.heartRate)
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = startOfDay.addingTimeInterval(86400)

    let query = HKStatisticsCollectionQuery(
        quantityType: heartRateType,
        quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay),
        options: .discreteAverage,
        anchorDate: startOfDay,
        intervalComponents: DateComponents(hour: 1)
    )

    return try await withCheckedThrowingContinuation { continuation in
        query.initialResultsHandler = { _, results, error in
            if let error { continuation.resume(throwing: error); return }
            var hourlyRates: [(Date, Double)] = []
            results?.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                if let avg = statistics.averageQuantity() {
                    hourlyRates.append((statistics.startDate,
                                        avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))))
                }
            }
            continuation.resume(returning: hourlyRates)
        }
        healthStore.execute(query)
    }
}
```

> **Do NOT use `statisticsUpdateHandler`** for the chart — it fires on every new heart rate sample (every few seconds during workouts), causing excessive re-renders. Use one-shot queries triggered by date changes.

#### Background Delivery

> **Entitlement required (iOS 15+):** Must add `com.apple.developer.healthkit.background-delivery` to `App.entitlements`. Without it, `enableBackgroundDelivery` fails with `HKError.errorAuthorizationDenied`.

```swift
// In AppleHealthImportService.init() or on first enable:
let types: [(HKSampleType, HKUpdateFrequency)] = [
    (HKQuantityType(.dietaryCarbohydrates), .immediate),
    (HKObjectType.workoutType(), .immediate),
    (HKQuantityType(.heartRate), .hourly),  // hourly is sufficient
]
for (type, frequency) in types {
    try await healthStore.enableBackgroundDelivery(for: type, frequency: frequency)
}
```

> **Reliability note:** Background delivery is best-effort. iOS may coalesce or delay notifications. Always do a full foreground refresh on `.active` app state as the primary sync mechanism; background delivery is bonus.

#### HealthKit Read Permissions

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

```swift
// Get all source apps that have written nutrition data
func availableNutritionSources() async throws -> [HKSource] {
    let carbType = HKQuantityType(.dietaryCarbohydrates)
    return try await withCheckedThrowingContinuation { continuation in
        let query = HKSourceQuery(sampleType: carbType, samplePredicate: nil) { _, sources, error in
            if let error { continuation.resume(throwing: error); return }
            continuation.resume(returning: Array(sources ?? []))
        }
        healthStore.execute(query)
    }
}
// Display source.name in a list; let user toggle which sources to import from
```

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

**HeartRateEntry** — NOT persisted to GRDB. Query HealthKit on-demand for the visible chart date range. Cache in memory as `@State var heartRateSeries: [(Date, Double)]` in ChartView.

### Chart Overlays

| Data | Chart Mark | Color | Position |
|------|-----------|-------|----------|
| Meals (manual + imported) | PointMark diamond | CGA green `#55ff55` | Upper area (`chartMinimum * 0.85`) |
| Exercise | RectangleMark (duration bar) | CGA cyan `#55ffff` | Bottom band (below `alarmLow`) |
| Heart rate | LineMark (dashed) | CGA magenta dimmed | Normalized into glucose Y-axis via `.map(from:to:)` |

#### Heart Rate Chart Overlay Strategy

> **Research finding:** Swift Charts has no native dual Y-axis. Best approach: normalize heart rate (40-200 bpm) into the glucose Y-axis range using the existing `.map(from:to:)` extension, matching the pattern already used for insulin at `ChartView.swift:206`.

```swift
ForEach(heartRateSeries, id: \.0) { (time, bpm) in
    LineMark(
        x: .value("Time", time),
        y: .value("HR", bpm.map(from: 40...200, to: Double(alarmHigh)...chartMinimum)),
        series: .value("Series", "HeartRate")
    )
    .interpolationMethod(.monotone)
    .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.4))
    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
}
```

Optionally add trailing axis labels that map back to BPM values for the heart rate range.

#### Exercise as RectangleMark

```swift
ForEach(exerciseSeries) { exercise in
    RectangleMark(
        xStart: .value("Start", exercise.startTime),
        xEnd: .value("End", exercise.endTime),
        yStart: .value("Bottom", chartMinimum),
        yEnd: .value("Top", chartMinimum * 0.95)
    )
    .foregroundStyle(AmberTheme.cgaCyan.opacity(0.3))
    .annotation(position: .top) {
        Text(exercise.activityType)
            .foregroundStyle(AmberTheme.cgaCyan)
            .font(DOSTypography.caption)
    }
}
```

### Performance: Chart Rendering

> **Performance finding:** Current chart renders ~288 glucose + meals + insulin marks. Phase 2 adds ~24 heart rate points + ~5 exercise rectangles + ~10 imported nutrition points = ~330 total marks. Swift Charts handles up to ~2,000-3,000 marks before frame drops. **Ample headroom.**

> **Action required:** Debounce `updateSeriesMetadata()` calls in ChartView before adding more data series. Currently each `onChange` handler triggers it independently. With 6-7 series, parallel loads cause redundant recalculations.

### Acceptance Criteria (Phase 2)

- [ ] HealthKit import middleware with anchored queries (`HKAnchoredObjectQueryDescriptor`)
- [ ] Import nutrition samples (carbs, calories, protein, fat)
- [ ] Handle both food correlations AND standalone flat samples
- [ ] Import workout/exercise sessions as ExerciseEntry in GRDB
- [ ] Heart rate overlay on chart (on-demand query, not persisted, hourly `HKStatisticsCollectionQuery`)
- [ ] Background delivery with `com.apple.developer.healthkit.background-delivery` entitlement
- [ ] Foreground refresh on app `.active` as primary sync mechanism
- [ ] Import/export dedup: bundle ID filtering + sync identifier + timestamp fuzzy match
- [ ] Source app attribution on imported entries (`HKSourceQuery`)
- [ ] Settings toggle for HealthKit import (separate from export)
- [ ] Updated privacy strings in Info.plist
- [ ] Imported meals shown alongside manual meals on chart
- [ ] Debounce chart series metadata recalculation

### Files to Create/Modify (Phase 2)

| Action | File | Description |
|--------|------|-------------|
| CREATE | `App/Modules/AppleImport/AppleHealthImport.swift` | Import middleware + service |
| CREATE | `Library/Content/ExerciseEntry.swift` | Exercise data model |
| MODIFY | `App/Modules/DataStore/DataStore.swift` | Add ExerciseEntry GRDB extension |
| CREATE | `App/Modules/DataStore/ExerciseStore.swift` | Exercise GRDB store + middleware |
| MODIFY | `Library/DirectAction.swift` | Add import actions |
| MODIFY | `Library/DirectState.swift` | Add exerciseEntryValues, heartRateSeries, appleHealthImport |
| MODIFY | `App/AppState.swift` | Implement new state properties |
| MODIFY | `Library/DirectReducer.swift` | Handle new setters |
| MODIFY | `App/Views/Overview/ChartView.swift` | Heart rate overlay, exercise bars |
| MODIFY | `App/Views/Settings/` | Add HealthKit import toggle |
| MODIFY | `App/App.swift` | Register import middleware in BOTH arrays |
| MODIFY | `App/App.entitlements` | Add background-delivery entitlement |
| MODIFY | `Info.plist` | Update NSHealthShareUsageDescription |
| MODIFY | `DOSBTS.xcodeproj/project.pbxproj` | Add new files |

---

## Phase 3: AI-Powered Analysis (DMNC-427)

### Claude API Integration

#### Architecture: BYOK (Bring Your Own Key)

**Recommended approach** for an independent/free app:
- User enters their own Anthropic API key in Settings
- Key stored in Keychain via `KeychainService` (not UserDefaults)
- No backend proxy needed — direct `URLSession` API calls to `api.anthropic.com` (TLS)
- Zero ongoing cost for the developer
- Cost to user: ~$0.003/call with Haiku 4.5

> **Architecture review:** The Claude API integration should be a standalone `ClaudeService` class (not a middleware). Middlewares are for action-reactive flows; API calls are user-initiated and async with complex error handling. The middleware dispatches actions to trigger analysis, but the actual API work lives in the service. Pattern: middleware receives `.analyzeFood(image:)` → calls `ClaudeService.analyzeFood()` → dispatches `.setFoodAnalysisResult(result:)`.

#### API Request Format (Direct URLSession)

```swift
struct ClaudeService {
    private let apiKey: String  // From KeychainService
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    func analyzeFood(imageData: Data) async throws -> NutritionEstimate {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let base64Image = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64Image
                    ]],
                    ["type": "text", "text": "Analyze this meal photo. Identify each food item and estimate nutritional content."]
                ]]
            ],
            "output_config": [
                "effort": "low",  // Fast, cheap — food photos are constrained
                "format": [
                    "type": "json_schema",
                    "schema": nutritionSchema
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode,
                                       body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(ClaudeResponse.self, from: data).toNutritionEstimate()
    }
}
```

#### Structured Output via JSON Schema

> **Research finding:** Use `output_config.format.json_schema` (newer API, replaces deprecated `response_format`). This guarantees valid JSON matching the schema.

```swift
let nutritionSchema: [String: Any] = [
    "type": "object",
    "properties": [
        "description": ["type": "string", "description": "Brief meal description"],
        "items": ["type": "array", "items": [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "carbs_g": ["type": "number"],
                "protein_g": ["type": "number"],
                "fat_g": ["type": "number"],
                "calories": ["type": "number"]
            ],
            "required": ["name", "carbs_g"]
        ]],
        "total_carbs_g": ["type": "number"],
        "total_calories": ["type": "number"],
        "confidence": ["type": "string", "enum": ["high", "medium", "low"]]
    ],
    "required": ["description", "items", "total_carbs_g", "confidence"]
]
```

#### Image Preparation

> **Research finding:** Resize food photos to max 1024px on the longest edge before base64 encoding. Full-res iPhone photos (4032x3024) are 5-10MB; resized to 1024px at JPEG quality 0.7 → ~150-250KB. This reduces API token usage and upload time on cellular.

```swift
extension UIImage {
    func preparedForVisionAPI(maxDimension: CGFloat = 1024) -> Data? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.7)
    }
}
```

#### Cost Estimates (Current 2026 Pricing)

| Model | Input/MTok | Output/MTok | Est. per food photo | Monthly (3 meals/day) |
|-------|-----------|-------------|--------------------|-----------------------|
| Haiku 4.5 | $1 | $5 | ~$0.003 | ~$0.27 |
| Sonnet 4.6 | $3 | $15 | ~$0.01 | ~$0.90 |

> Haiku 4.5 is the clear choice for food photos — a constrained visual task where speed matters more than deep reasoning.

#### App Store Compliance: Guideline 5.1.2(i)

> **CRITICAL — Apple updated App Review Guidelines November 2025:** Section 5.1.2(i) now requires explicit disclosure when sharing personal data with third-party AI services. This applies directly to Phase 3.

**Requirements:**
1. **Name the AI provider explicitly** — "Your food photo and meal description will be sent to Anthropic (Claude AI) for nutritional analysis." Generic "AI service" is insufficient.
2. **Per-feature opt-in consent** — Cannot bundle AI consent with general privacy policy or account creation. Must be a separate, visible in-app prompt before the first API call.
3. **Explain data types, storage, model training** — Must state whether Anthropic stores the data, uses it for training (they don't with API), and for how long.
4. **Cannot rely on privacy policy links alone** — Must use pop-ups or other visible interaction methods.

**Implementation:**
```swift
// On first tap of "Analyze with AI" button:
struct AIConsentView: View {
    var body: some View {
        VStack {
            Text("Food Photo Analysis")
            Text("Your food photo will be sent to Anthropic (Claude AI) to estimate nutritional content.")
            Text("• Only the photo and a text prompt are sent")
            Text("• No glucose or health data is included")
            Text("• Anthropic does not store your images or use them for model training")
            Text("• You can revoke access anytime in Settings")
            Button("Allow") { /* store consent, proceed */ }
            Button("Not Now") { /* dismiss */ }
        }
    }
}
```

> **For correlation analysis (Feature 2):** A SEPARATE consent prompt is needed because glucose data IS sent. This is health data and must be disclosed distinctly: "Your glucose readings, meal logs, and exercise data will be sent to Anthropic (Claude AI) for pattern analysis."

#### Feature 1: Food Photo → Carb Estimation

User flow:
1. User taps "Add Meal" → option to take photo or enter manually
2. Photo resized to 1024px JPEG, base64 encoded
3. Sent to Claude Haiku 4.5 with structured output schema
4. Response parsed → user sees pre-filled form with AI estimates + confidence level
5. User confirms/adjusts values → saves as MealEntry
6. Entry exported to HealthKit (Phase 2)

#### Feature 2: Glucose-Food Correlation Analysis

User flow:
1. User taps "Analyze" on a time period (separate AI consent required)
2. App sends **summarized** glucose stats + meal entries + exercise data to Claude
3. **Data minimization:** Send aggregated stats (min, max, avg, time-in-range) not raw readings. Send meal descriptions + carb values, not photos.
4. Claude identifies patterns: "Your glucose spikes ~45 min after rice-based meals. Exercise within 30 min of eating reduces the spike by ~30%."
5. Results displayed with disclaimer: "AI estimates are informational only. Consult your healthcare provider for medical decisions."

#### Feature 3: Substance/Supplement Tracking

Add a `SubstanceEntry` model for tracking:
- Medications (metformin, etc.)
- Supplements (vitamins, mushroom supplements)
- Caffeine, alcohol

Simple model: name, dose, timestamp. Display as chart markers. HealthKit doesn't have standard types for supplements, so this is local-only (GRDB).

### Acceptance Criteria (Phase 3)

- [ ] BYOK API key entry in Settings (SecureField + Keychain storage via `KeychainService`)
- [ ] API key validation on entry (lightweight test call)
- [ ] Food photo → carb estimation via Claude Vision (Haiku 4.5)
- [ ] Image resized to 1024px JPEG before sending
- [ ] Structured response parsing via `output_config.format.json_schema`
- [ ] User confirmation step before saving AI estimates (pre-filled editable form)
- [ ] Confidence level displayed (high/medium/low)
- [ ] App Store 5.1.2(i) compliance: named provider disclosure, per-feature opt-in consent
- [ ] Separate consent for correlation analysis (sends glucose data)
- [ ] Glucose correlation analysis view with data minimization (aggregated stats, not raw readings)
- [ ] Disclaimer on all AI outputs: "informational only"
- [ ] Substance/supplement tracking model and UI
- [ ] Error handling: rate limits, network failures, invalid API key

### Files to Create/Modify (Phase 3)

| Action | File | Description |
|--------|------|-------------|
| CREATE | `App/Modules/Claude/ClaudeService.swift` | API client (URLSession, no SDK) |
| CREATE | `App/Modules/Claude/ClaudeMiddleware.swift` | Action handler for AI features |
| CREATE | `App/Views/AddViews/FoodPhotoAnalysisView.swift` | Photo capture + AI results |
| CREATE | `App/Views/Analysis/CorrelationAnalysisView.swift` | AI insight display |
| CREATE | `App/Views/Settings/AISettingsView.swift` | API key entry, consent management |
| CREATE | `Library/Content/SubstanceEntry.swift` | Substance data model |
| CREATE | `App/Modules/DataStore/SubstanceStore.swift` | GRDB store + middleware |
| MODIFY | `Library/DirectAction.swift` | Add AI + substance actions |
| MODIFY | `Library/DirectState.swift` | Add AI state properties |
| MODIFY | `App/AppState.swift` | Implement new state |
| MODIFY | `App/App.swift` | Register Claude + substance middlewares |

---

## Findings from Research

### HealthKit Read Permissions Are Opaque

HealthKit deliberately hides whether the user granted read access. `authorizationStatus(for:)` always returns `.notDetermined` for read types, even if denied. The UI must gracefully handle empty query results without distinguishing "no data" from "access denied."

### HealthKit Food Correlations vs Flat Samples

`HKCorrelationType.food` groups nutrition samples into a logical meal. However, many apps (including MyFitnessPal) write flat `HKQuantitySample` objects WITHOUT correlations. Phase 2 import must handle **both** patterns — query for food correlations AND standalone nutrition samples, then merge by time window (~30 min grouping). See implementation code in Phase 2 section.

### Background Delivery Entitlement Required

Phase 2 background HealthKit delivery requires adding `com.apple.developer.healthkit.background-delivery` to `App.entitlements`. Confirmed required since iOS 15+. Without it, `enableBackgroundDelivery` fails silently with `HKError.errorAuthorizationDenied`.

### Store Dispatch Bug (Pre-existing)

> **Architecture review finding:** `Library/Extensions/State.swift:51` uses `break` in the middleware dispatch loop, which exits the entire `for mw in middlewares` loop. When any middleware returns `nil`, all subsequent middlewares are skipped for that action. This should be `continue`, not `break`. The existing middlewares work around this by returning `Empty().eraseToAnyPublisher()` instead of `nil`, but the bug is latent and could be triggered by any new middleware that accidentally returns `nil`. Consider fixing this before adding more middlewares in Phase 2/3.

### Security: Critical Logging Vulnerabilities

> **Security audit finding (CRITICAL):** `LibreLinkUpConnection.swift` lines 311, 366, 399, 436 log FULL API response bodies including `authTicket.token`, user IDs, and patient IDs to file-based logs. These logs are exportable via the "Send Logs" UIActivityViewController. Additionally, the log middleware may log action descriptions containing credential data. Fix before Phase 2 begins.

### Performance: Chart Rendering Headroom

- **Current:** ~288 marks. **Phase 2 projected:** ~330 marks. **Swift Charts limit:** ~2,000-3,000 before frame drops. **Ample headroom.**
- **Heart rate query:** `HKStatisticsCollectionQuery` for 24 hours of hourly averages returns in <50ms. 24 data points per day is trivial.
- **Photo preparation (Phase 3):** Resize to 1024px + JPEG 0.7 quality → ~150-250KB. Upload time on LTE: <1 second.

### Performance: Debounce Chart Updates

> **Performance finding:** ChartView has multiple `onChange` handlers that each trigger `updateSeriesMetadata()`. Adding heart rate + exercise series means 6-7 handlers firing on date change. Debounce by coalescing updates on the next run loop tick, or use a single `onChange` that watches a computed "data version" counter.

---

## Technical Considerations

### iOS Compatibility

- Swift Charts requires iOS 16+ — already the effective minimum
- `HKAnchoredObjectQueryDescriptor` requires iOS 15.4+ — no issue
- `HKStatisticsCollectionQuery` available since iOS 8
- `output_config` in Claude API — current API version
- Keychain APIs available since iOS 2

### HealthKit Entitlements

Already configured in `App/App.entitlements`:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array><string>health-records</string></array>
```

**Add for Phase 2:**
```xml
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Data Deduplication

Three-layer strategy (detailed in Phase 2 section):
1. Bundle ID filtering on import (exclude our own exports)
2. `HKMetadataKeySyncIdentifier` cross-reference
3. Timestamp + carbs fuzzy match (5-minute window)

### Performance

- Heart rate: hourly `HKStatisticsCollectionQuery`, 24 points/day, <50ms query
- Chart: ~330 marks total, well under Swift Charts' 2,000+ comfort zone
- Debounce `updateSeriesMetadata()` before adding more data series
- Photo resize: 1024px JPEG 0.7 → ~200KB, <1s upload on LTE

### Middleware Registration

**Critical:** `App.swift` has TWO middleware arrays — `createAppStore()` (device) and `createSimulatorAppStore()` (simulator). Both must include new middlewares. Fix the `break` → `continue` bug in `State.swift:51` to prevent middleware ordering issues.

### Database Migration

No migration needed for Phase 2 — new tables (ExerciseEntry) created with `ifNotExists: true`. For Phase 2 MealEntry update (adding `source` column), use `ALTER TABLE MealEntry ADD COLUMN source TEXT` with a guard for column existence.

---

## Implementation Order

```
Pre-Phase 2: Security Fixes — ~1 session
├── 0.1 Fix credential/token logging in LibreLinkUpConnection.swift (CRITICAL)
├── 0.2 Fix log middleware action description logging
├── 0.3 Create KeychainService wrapper
├── 0.4 Fix deleteGlucose bug in AppleHealthExport.swift:220
└── 0.5 Fix Store dispatch break→continue bug (State.swift:51)

Phase 1 (MVP) — ✅ COMPLETE
├── [x] All items shipped to TestFlight

Phase 2 (HealthKit Import) — ~3-4 sessions
├── 2.1 AppleHealthImport middleware + NutritionSyncManager service
├── 2.2 HealthKit read permissions + privacy strings + entitlements
├── 2.3 Nutrition import (anchored queries, food correlations + flat samples)
├── 2.4 Import/export dedup (bundle ID + sync ID + fuzzy match)
├── 2.5 ExerciseEntry model + GRDB store + exercise import
├── 2.6 Heart rate chart overlay (HKStatisticsCollectionQuery, normalized Y-axis)
├── 2.7 Exercise chart bars (RectangleMark)
├── 2.8 Debounce chart updateSeriesMetadata()
├── 2.9 Background delivery + entitlement
├── 2.10 Source filtering UI (HKSourceQuery)
├── 2.11 Settings toggle for import
└── 2.12 HealthKit carb export for manual meals

Phase 3 (AI) — ~3-4 sessions
├── 3.1 BYOK API key settings + Keychain + validation
├── 3.2 App Store 5.1.2(i) consent UI (per-feature, named provider)
├── 3.3 ClaudeService (URLSession, no SDK, base64 image)
├── 3.4 Image preparation (1024px resize, JPEG 0.7)
├── 3.5 Food photo → structured nutrition estimate (json_schema)
├── 3.6 User confirmation form (pre-filled, editable, confidence level)
├── 3.7 Correlation analysis (separate consent, data minimization)
├── 3.8 SubstanceEntry model + GRDB store + UI
└── 3.9 Error handling (rate limits, network, invalid key)
```

## Dependencies & Risks

| Risk | Mitigation |
|------|-----------|
| HealthKit read permissions rejected by user | Graceful fallback — manual logging still works, empty results same as denied |
| HealthKit background delivery unreliable | Foreground refresh on app `.active` as primary; background is bonus |
| Claude API costs too high for users | BYOK with Haiku 4.5 (~$0.27/month at 3 meals/day); show cost estimate in settings |
| App Store review for health claims | "Informational" framing only; disclaimers on all AI output |
| App Store 5.1.2(i) compliance | Named provider disclosure, per-feature opt-in, separate consent per data type |
| Heart rate data too dense for chart | Hourly `HKStatisticsCollectionQuery` — 24 points/day max |
| Duplicate entries from import + manual | Three-layer dedup: bundle ID + sync identifier + timestamp fuzzy match |
| Import/export feedback loop | Bundle ID filtering + `HKMetadataKeySyncIdentifier` |
| Food correlations vs flat samples | Query both, merge by 30-min time window |
| Store dispatch `break` bug | Fix before Phase 2, or ensure all middlewares return `Empty()` not `nil` |
| Credential logging vulnerability | Fix before any new network-facing features |

## Sources & References

### Internal References
- Existing HealthKit export: `App/Modules/AppleExport/AppleHealthExport.swift`
- Existing GRDB patterns: `App/Modules/DataStore/InsulinDeliveryStore.swift`
- GRDB extensions centralized: `App/Modules/DataStore/DataStore.swift`
- Existing chart marks: `App/Views/Overview/ChartView.swift:170-258`
- Existing add view template: `App/Views/AddViews/AddInsulinView.swift`
- InsulinDelivery model template: `Library/Content/InsulinDelivery.swift`
- Middleware registration: `App/App.swift` (TWO arrays: device + simulator)
- Store dispatch loop: `Library/Extensions/State.swift:51` (break bug)
- Credential logging: `App/Modules/SensorConnector/LibreConnection/LibreLinkUpConnection.swift:311,366,399,436`

### Linear Issues
- DMNC-389: Food Logging MVP (original)
- DMNC-422: Food Logging Idea (broader vision, original)
- DMNC-425: Phase 1 Food Logging MVP (implementation, High) — ✅ COMPLETE
- DMNC-426: Phase 2 HealthKit Import (implementation, Medium, blocked by 425)
- DMNC-427: Phase 3 AI-Powered Food Analysis (implementation, Low, blocked by 425)

### External References
- Apple HealthKit docs: [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- Apple HealthKit docs: [Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- Apple App Store Review Guidelines 5.1.2(i): [Third-party AI data sharing](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- Anthropic API Messages: [Messages API reference](https://docs.anthropic.com/en/api/messages)
- Anthropic Vision: [Vision image input](https://docs.anthropic.com/en/docs/build-with-claude/vision)

### Known Bugs to Fix
- ~~`AppleHealthExport.swift:220` — `deleteGlucose` uses `self.insulinType` instead of `self.glucoseType`~~ FIXED
- ~~`State.swift:51` — `break` in middleware dispatch loop should be `continue`~~ FIXED
- ~~`LibreLinkUpConnection.swift:311,366,399,436` — Full API response bodies logged to disk (tokens, user IDs)~~ FIXED
- ~~`UserDefaults.swift:68` — `appSerial` saves to wrong key (`alarmHigh` instead of `appSerial`)~~ FIXED
- LibreLinkUp credentials in plaintext UserDefaults (existing vulnerability — will address with KeychainService in Phase 3)
