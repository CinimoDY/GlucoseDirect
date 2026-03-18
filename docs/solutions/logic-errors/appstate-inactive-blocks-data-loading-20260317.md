---
title: Data Not Loading After Save — appState Initialization Bug
date: 2026-03-17
category: logic-errors
severity: critical
component: DataStore, AppState lifecycle
tags: [data-persistence, GRDB, app-state, scene-phase, physical-device, middleware-guard]
symptoms:
  - Data saved to GRDB database but never appears in UI
  - Lists tab remains empty after entering meals, blood glucose, or insulin
  - Data lost after app restart on physical device
  - Issue does not reproduce consistently on simulator (scene phase timing differs)
root_cause: appState initialized to .inactive; ContentView.onChange(of: scenePhase) never fires when scene is already .active at launch, leaving appState stuck at .inactive and blocking all data load middlewares
files_modified:
  - App/Views/ContentView.swift
  - App/Modules/DataStore/DataStore.swift
  - App/Modules/DataStore/MealStore.swift
  - App/Modules/DataStore/InsulinDeliveryStore.swift
---

# Data Not Loading After Save — appState Initialization Bug

## Root Cause Analysis

SwiftUI's `.onChange(of: scenePhase)` modifier does **not** fire if the observed value is already at its target state when the view first renders. In this app:

1. `appState` initializes to `.inactive` in `AppState.swift`
2. On a physical device, `scenePhase` may already be `.active` when `ContentView` first mounts
3. `.onChange(of: scenePhase)` only triggers on *changes*, not on the initial value
4. All data load middlewares guard on `state.appState == .active`, creating a deadlock:

```
.addMealEntry → DB write succeeds → dispatches .loadMealEntryValues
→ guard state.appState == .active → FAILS (.inactive) → Empty() → state stays []
```

This affects ALL data types: meals, blood glucose, insulin, favorites, sensor glucose, exercises.

## Solution

### Fix 1: Explicit State Initialization in `.onAppear` (PRIMARY)

Dispatch `.setAppState(.active)` in `ContentView.onAppear()` to guarantee `appState` transitions regardless of current `scenePhase`:

```swift
.onAppear {
    DirectLog.info("onAppear()")
    // Ensure data loads happen even if scenePhase was already .active
    store.dispatch(.setAppState(appState: .active))
    // ... rest of existing code
}
```

This is safe because `.onAppear` only fires when the view is visible (app is in foreground = active). All data load middlewares handle `.setAppState(.active)` by dispatching their respective load actions.

### Fix 2: Correct File Path API (CORRECTNESS)

Changed `databaseURL.absoluteString` to `databaseURL.path` in `DataStore.swift`. GRDB expects a file system path, not a URI string. While `absoluteString` happened to work on Apple platforms due to SQLite's URI support, `.path` is the correct API.

```swift
// Before:
dbQueue = try DatabaseQueue(path: databaseURL.absoluteString)
// After:
dbQueue = try DatabaseQueue(path: databaseURL.path)
```

### Fix 3: Remove Cross-Action Data-Loss Bug (LATENT BUG)

Removed `.clearBloodGlucoseValues` handlers from `MealStore.swift` and `InsulinDeliveryStore.swift` that incorrectly deleted ALL meal/insulin entries when blood glucose was cleared. Dead code today (no view dispatches this action), but a severe latent data-loss bug.

## Prevention Strategies

### SwiftUI Lifecycle Pitfall
`.onChange` only fires on CHANGES, not initial values. **Always pair `.onChange` with `.onAppear`** for critical state initialization:

```swift
.onAppear {
    // Handle initial state
    store.dispatch(.setAppState(appState: .active))
}
.onChange(of: scenePhase) { newPhase in
    // Handle subsequent transitions
    store.dispatch(.setAppState(appState: newPhase))
}
```

### Silent Failure Pattern
Middleware guards that return `Empty()` fail silently. When adding new middleware guards, consider logging rejections at debug level so issues are diagnosable.

### Cross-Action Contamination
Never handle an action in a middleware that deletes data from a different domain. Each data type should have its own clear action (e.g., `.clearMealEntryValues`, `.clearInsulinDeliveryValues`) rather than piggybacking on `.clearBloodGlucoseValues`.

## Related Documentation

- [`docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`](middleware-race-condition-guard-blocks-api-call-Claude-20260313.md) — Related timing issue: reducer runs before middlewares, so guards on state changed by the same action are unreliable.
- [`docs/solutions/logic-errors/redux-undo-uuid-mismatch-middleware-creates-object-20260315.md`](redux-undo-uuid-mismatch-middleware-creates-object-20260315.md) — Related state synchronization issue with middleware-owned entity creation.
- [`docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`](../ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md) — Another SwiftUI lifecycle reliability issue in this codebase.
