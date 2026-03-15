---
title: Redux undo fails due to UUID mismatch between middleware and view
category: logic-errors
tags: [redux, uuid, undo, middleware, data-integrity, favorites]
module: App/Modules/DataStore/FavoriteStore, App/Views/AddViews/UnifiedFoodEntryView
symptom: "Tapping UNDO after logging a favorite food does nothing — the meal entry is not deleted"
root_cause: "View creates a local MealEntry with a different UUID than the one created by middleware, so the delete targets a non-existent record"
severity: high
platform: iOS 15+
date: 2026-03-15
---

# Redux Undo UUID Mismatch

## Problem

When logging a favorite food, tapping "Undo" on the toast confirmation did nothing. The meal entry remained in the database. The undo was silently non-functional.

## Root Cause

Two separate `MealEntry` instances were created independently — one in the middleware and one in the view — each with its own auto-generated UUID.

```
View: logFavorite()
  → dispatches .logFavoriteFood(favorite)
  → Middleware creates MealEntry with UUID A, persists it
  → View creates local MealEntry with UUID B for toast
  → User taps UNDO → dispatches .deleteMealEntry(UUID B)
  → GRDB: no row with UUID B → silent failure
```

The fundamental issue: when a middleware creates an entity, the view has no way to know the generated UUID for undo purposes.

## Solution

Split responsibilities: the **view** creates the `MealEntry` (single UUID, single source of truth) and dispatches `.addMealEntry` for persistence. The `.logFavoriteFood` action is reduced to only updating the favorite's `lastUsed` timestamp.

### Before (broken)

```swift
// View
func logFavorite(_ fav: FavoriteFood) {
    store.dispatch(.logFavoriteFood(favoriteFood: fav)) // middleware creates MealEntry
    let localEntry = MealEntry(...)                      // different UUID!
    showToast(for: localEntry)                           // undo uses wrong UUID
}

// Middleware
case .logFavoriteFood(favoriteFood: let fav):
    let mealEntry = fav.toMealEntry()           // UUID A
    return Just(.addMealEntry(mealEntryValues: [mealEntry]))
        .setFailureType(to: DirectError.self)
        .eraseToAnyPublisher()
```

### After (working)

```swift
// View — creates the single MealEntry
func logFavorite(_ fav: FavoriteFood) {
    let mealEntry = fav.toMealEntry()                        // single UUID
    store.dispatch(.addMealEntry(mealEntryValues: [mealEntry])) // persists it
    store.dispatch(.logFavoriteFood(favoriteFood: fav))         // only updates lastUsed
    showToast(for: mealEntry)                                   // undo uses same UUID
}

// Middleware — no longer creates MealEntry
case .logFavoriteFood(favoriteFood: let fav):
    DataStore.shared.updateFavoriteFoodLastUsed(fav)
    return Empty().eraseToAnyPublisher()
```

## Key Principle

**When a Redux-like architecture needs to support undo, the object identity (UUID) must be created at a single point — the call site that also holds the undo reference.** Middlewares should not independently create entities that the view needs to reference for undo/delete.

Split:
- **View-owned:** Create entity, hold reference for undo, dispatch persistence action
- **Middleware-owned:** Side effects only (update timestamps, trigger reloads, export to HealthKit)

## Prevention

- When adding undo to any Redux action, verify that the entity UUID is created at the same scope that holds the undo reference.
- If a middleware must create an entity, emit a confirmation action (e.g., `.mealEntryAdded(mealEntry:)`) so the view can capture the actual UUID.
- Factory methods like `FavoriteFood.toMealEntry()` centralize entity creation and prevent field drift.

## Related

- `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md` — Same Redux architecture timing issues
- `docs/solutions/security-issues/redux-action-secret-leakage-keychain-side-channel.md` — Side-channel pattern for data outside the action stream
