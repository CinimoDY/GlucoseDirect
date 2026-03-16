---
title: SwiftUI nested sheets present wrong view regardless of iOS version
category: ui-bugs
tags: [swiftui, sheet, nested-sheets, navigationlink, modal]
module: App/Views/AddViews/UnifiedFoodEntryView
symptom: "MANUAL button opens AI photo analysis sheet instead of manual entry form"
root_cause: "Presenting a sheet from within an already-presented sheet is unreliable in SwiftUI — not just iOS 15, all versions"
severity: high
platform: iOS 15+, confirmed on iOS 26
date: 2026-03-16
---

# SwiftUI Nested Sheets Present Wrong View

## Problem

The `UnifiedFoodEntryView` is presented as a `.sheet` from `OverviewView`. Within it, MANUAL and PHOTO buttons attempted to present `AddMealView` and `FoodPhotoAnalysisView` as additional sheets. The MANUAL button consistently opened the AI photo analysis sheet instead of the manual entry form.

## Investigation Steps (What Didn't Work)

### Attempt 1: Separate `.sheet(isPresented:)` at different hierarchy levels
Put manual `.sheet` on the `List` and photo `.sheet` on the `NavigationView`. Result: one button worked, the other didn't — just moved the problem.

### Attempt 2: Swap the hierarchy levels
Reversed which sheet was inner vs outer. Result: the *other* button broke instead.

### Attempt 3: Single `.sheet(item:)` with enum discriminator
Replaced both boolean `.sheet(isPresented:)` with a single `.sheet(item: $activeSheet)` using an `ActiveSheet` enum. Result: still broken — the favorites management gear button had its own `.sheet(isPresented:)` which collided.

### Attempt 4: Consolidate ALL sheets into the enum
Added `.favorites` case to the enum so all three sheets used one `.sheet(item:)`. Result: **still broken**. The underlying issue isn't multiple `.sheet` modifiers colliding — it's that SwiftUI can't reliably present a sheet from within a view that is itself already presented as a sheet.

## Root Cause

**Nested sheets are unreliable in SwiftUI.** When `UnifiedFoodEntryView` is already presented via `.sheet` from `OverviewView`, attempting to present *another* sheet from within it (regardless of technique — `isPresented`, `item`, enum, hierarchy level) produces unpredictable behavior. SwiftUI's sheet presentation system operates on the window's presentation stack, and nested sheet requests interfere with each other.

This is **not an iOS 15 issue** — it was confirmed broken on iOS 26.

## Solution

Use **NavigationLink** (push navigation) instead of sheets for MANUAL and PHOTO. Since `UnifiedFoodEntryView` already contains a `NavigationView`, pushing views within it works reliably. Only one sheet remains (favorites management), which is the sole sheet presented from within the parent sheet.

```swift
// BEFORE (broken) — nested sheet from within a sheet
Button { activeSheet = .manual } label: { Text("MANUAL") }
// ... somewhere:
.sheet(item: $activeSheet) { sheet in
    switch sheet {
    case .manual: AddMealView { ... }
    case .photo: FoodPhotoAnalysisView()
    }
}

// AFTER (working) — NavigationLink push within existing NavigationView
NavigationLink {
    AddMealView { time, description, carbs in
        let mealEntry = MealEntry(...)
        store.dispatch(.addMealEntry(mealEntryValues: [mealEntry]))
        dismiss()
    }
    .navigationBarHidden(true)
} label: {
    HStack {
        Image(systemName: "keyboard")
        Text("MANUAL")
    }
}

NavigationLink {
    FoodPhotoAnalysisView()
        .environmentObject(store)
        .navigationBarHidden(true)
} label: {
    HStack {
        Image(systemName: "camera.viewfinder")
        Text("PHOTO")
    }
}
```

## Key Rule

**Never present a sheet from within a view that is itself presented as a sheet.** Use NavigationLink push navigation instead. If you absolutely must present a modal from within a sheet, use `fullScreenCover` (which uses a different presentation mechanism) or restructure to avoid nesting.

## Prevention

- When a view is presented as a `.sheet`, all sub-navigation within it should use `NavigationLink` (push), not additional `.sheet` modifiers.
- One `.sheet` per view is safe for things like settings/management that don't relate to the parent sheet's presentation.
- Document this constraint in CLAUDE.md for the project.

## Related

- `docs/solutions/ui-bugs/swiftui-sheet-collision-ios15-sibling-views-20260315.md` — Earlier, narrower version of this problem (sibling sheets). This doc supersedes it with the broader finding: nested sheets are the real issue.
- CLAUDE.md architecture gotchas section
