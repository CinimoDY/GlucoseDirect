---
title: SwiftUI sheet collision when multiple .sheet modifiers on sibling views
category: ui-bugs
tags: [swiftui, sheet, ios15, view-hierarchy, modal]
module: App/Views/AddViews/UnifiedFoodEntryView
symptom: "Tapping one button presents the wrong sheet first; both sheets present sequentially"
root_cause: "Multiple .sheet(isPresented:) on sibling views in the same container are ambiguous on iOS 15"
severity: high
platform: iOS 15
date: 2026-03-15
---

# SwiftUI Sheet Collision on iOS 15

## Problem

Two `.sheet(isPresented:)` modifiers attached to sibling `Button` views inside the same `HStack`. When tapping the PHOTO button, the MANUAL sheet appeared first. After dismissing it, the PHOTO sheet appeared. Same behavior for MANUAL — both sheets presented in wrong order.

No error or warning is produced. The bug is silent.

## Root Cause

SwiftUI on iOS 15 resolves sheet presentation per-container. Two `.sheet()` modifiers on sibling views inside the same `HStack` compete for the single presentation slot. SwiftUI cannot reliably distinguish which sheet to present when multiple are at the same hierarchy level.

This was fixed in iOS 16+, but with a deployment target of iOS 15.0, the limitation applies.

## Solution

Move the `.sheet()` modifiers to **different levels** in the view hierarchy. Keep the buttons together in the `HStack`, but attach each sheet to a different ancestor.

### Before (broken)

```swift
HStack {
    Button { showManual = true }
    .sheet(isPresented: $showManual) { AddMealView { ... } }

    Button { showPhoto = true }
    .sheet(isPresented: $showPhoto) { FoodPhotoAnalysisView() }
}
```

### After (working)

```swift
// Buttons stay together — no .sheet on them
HStack {
    Button { showManual = true }
    Button { showPhoto = true }
}

// Sheet 1 on the List (inside NavigationView)
List { ... }
.sheet(isPresented: $showManual) { AddMealView { ... } }

// Sheet 2 on the NavigationView (parent of List)
NavigationView { ... }
.sheet(isPresented: $showPhoto) { FoodPhotoAnalysisView() }
```

## Prevention

- **Rule:** Never attach two `.sheet()` calls to views that share the same immediate parent container on iOS 15.
- **Alternative for iOS 15:** Use a single `.sheet(item:)` with an enum discriminator instead of multiple `.sheet(isPresented:)`.
- **Added to CLAUDE.md** gotchas section for future reference.

## Related

- CLAUDE.md architecture gotchas (iOS 15 deployment target)
- `docs/plans/2026-03-15-feat-food-logging-quick-relogging-plan.md`
