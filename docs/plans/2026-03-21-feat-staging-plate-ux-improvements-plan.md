---
title: "feat: Staging Plate UX Improvements — Amount Editing + Inline Barcode"
type: feat
status: completed
date: 2026-03-21
deepened: 2026-03-21
linear: DMNC-567
---

# Staging Plate UX Improvements

## Enhancement Summary

**Deepened on:** 2026-03-21
**Research agents:** architecture-strategist, code-simplicity-reviewer

### Key Simplifications
1. **2 new fields instead of 4** — `currentAmountG` + `carbsPerG` replaces baseAmount, userAmount, baseCarbsG, manualCarbOverride
2. **No boolean flag** — `carbsPerG = nil` signals manual override (derivable, not stored)
3. **Callback-based inline scanner** — do NOT reuse BarcodeScannerView (shared Redux state collision). Use a lightweight scanner with closure callback.
4. **Extract OFF lookup** — move `lookupBarcodeInOpenFoodFacts` from private in ClaudeMiddleware to a shared function

### Critical Finding
Reusing `BarcodeScannerView` for per-item scan would corrupt the outer staging plate's Redux state: `onDisappear` clears `foodAnalysisResult`, and auto-push logic would nest a second `FoodPhotoAnalysisView`. The callback pattern avoids Redux entirely.

---

## Overview

Three enhancements to the staging plate from UI testing:
1. **Amount editing** — edit portion amount per item, carbs auto-recalculate proportionally
2. **Manual carb override** — direct carb editing breaks the proportional link (implicit via nil ratio)
3. **Inline barcode scan** — scan individual items via callback-based scanner, bypassing Redux

## Proposed Solution

### Extended EditableFoodItem (2 new fields)

```swift
struct EditableFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var carbsG: Double
    var isExpanded: Bool = false
    var baseServingG: Double? = nil    // existing (for portion presets)
    var currentAmountG: Double? = nil  // NEW: user-visible portion in g/ml
    var carbsPerG: Double? = nil       // NEW: carbs-per-gram ratio (nil = manual override)
}
```

**Populated in `populateStagedItems`:**
- Parse amount from `NutritionItem.servingSize` (existing `parseBaseServingG`)
- Compute ratio: `carbsPerG = item.carbsG / amount`
- Set `currentAmountG = amount`

### Amount Editing + Auto-Scaling

**Expanded item row layout:**
```
Name:   [Rice           ]
Amount: [100     ] g         ← editable, drives carb auto-calculation
Carbs:  [30      ] g         ← editable, typing here sets carbsPerG = nil
```

**Amount field `.onChange`:**
```swift
if let ratio = item.carbsPerG, let newAmt = item.currentAmountG, newAmt > 0 {
    item.carbsG = ratio * newAmt
}
```

**Carbs field `.onChange`:**
```swift
item.carbsPerG = nil  // user broke the proportional link
```

**Amount field shows only when `currentAmountG != nil`** — items without parseable serving info show name + carbs only (current behavior).

### Manual Carb Override (Implicit)

No boolean flag. `carbsPerG` being nil IS the override signal:
- `carbsPerG != nil` → amount changes auto-scale carbs
- `carbsPerG == nil` → amount changes don't touch carbs (user typed carbs directly)
- If user clears carbs and edits amount → can re-derive ratio from `carbsG / currentAmountG`

### Inline Barcode Scan per Item

**Architecture: callback-based scanner, NOT BarcodeScannerView.**

`BarcodeScannerView` uses shared Redux state (`foodAnalysisResult`) which would collide with the outer staging plate. Instead:

1. **Extract `lookupBarcodeInOpenFoodFacts`** from `private` in ClaudeMiddleware to a module-level function (or a small `OpenFoodFactsService` struct)
2. **Barcode icon in expanded row** → `NavigationLink` to a minimal scanner view that:
   - Shows the AVCaptureSession scanner (reuse `ScannerVC_Wrapper`)
   - On scan, calls `lookupBarcodeInOpenFoodFacts` directly (no Redux dispatch)
   - Returns `NutritionEstimate` via a callback closure
   - Does NOT touch `foodAnalysisResult` state
3. **Staging plate replaces the item** at `scanTargetIndex` with the scanned product's data

**State:** `@State private var scanTargetIndex: Int?` — set when user taps a barcode icon, read when callback returns.

**New file:** `App/Views/AddViews/ItemBarcodeScannerView.swift` — lightweight scanner that takes `(NutritionEstimate) -> Void` callback. Reuses `ScannerVC_Wrapper` but does NOT embed `FoodPhotoAnalysisView` or touch Redux.

## Technical Considerations

### Files to Create

| File | Purpose |
|------|---------|
| `App/Views/AddViews/ItemBarcodeScannerView.swift` | Lightweight callback-based scanner for per-item replacement |

### Files to Modify

| File | Change |
|------|--------|
| `App/Views/AddViews/FoodPhotoAnalysisView.swift` | Extend `EditableFoodItem` (2 fields), amount field + auto-scaling in expanded row, barcode icon + NavigationLink, `scanTargetIndex` |
| `App/Modules/Claude/ClaudeMiddleware.swift` | Extract `lookupBarcodeInOpenFoodFacts` from private to internal/file-level |
| `DOSBTS.xcodeproj/project.pbxproj` | Add ItemBarcodeScannerView.swift |

### Key Decisions

1. **`carbsPerG` ratio instead of baseAmount + baseCarbsG** — one field captures the proportional relationship. Nil = user overrode carbs.

2. **Callback-based scanner, not BarcodeScannerView** — avoids Redux state collision. The inline scanner calls OFF directly, returns via closure.

3. **Extract OFF lookup** — `lookupBarcodeInOpenFoodFacts` moves from `private` to accessible. Both the main barcode flow and the per-item flow call the same function.

4. **Amount field only when parseable** — `currentAmountG != nil` gates the field. Items with unparseable serving sizes show current behavior.

5. **Correction system interaction** — items replaced via barcode scan should be marked (e.g., `wasScannedReplacement = true`) so `computeCorrections()` can skip them or record as `.added` rather than `.carbChange`.

### Edge Cases

- **Amount 0 or negative** → clamp to minimum 1g
- **Very large amount** → cap at 10000g
- **Carbs field cleared** → `carbsPerG` stays nil until user re-derives via amount edit
- **Barcode scan returns no nutrition** → inline error in scanner, keep existing item
- **Barcode scan cancelled** → item unchanged
- **parseBaseServingG returns nil** → amount field hidden (current behavior)
- **`.onChange` loop risk** — guard carbs write against epsilon-small changes

## Acceptance Criteria

- [x] **Amount field** on expanded items when `currentAmountG != nil`
- [x] **Auto-carb scaling** — editing amount recalculates carbs via `carbsPerG * amount`
- [x] **Manual carb override** — editing carbs sets `carbsPerG = nil`, amount stops driving carbs
- [x] **Barcode icon** on expanded items — tap to scan
- [x] **Callback-based scanner** — does NOT use BarcodeScannerView or touch Redux state
- [x] **OFF lookup extracted** to shared function
- [x] **Barcode replaces item** — scanned product replaces name, carbs, amount at target index
- [x] **Amount field hidden** when `currentAmountG` is nil
- [x] **Builds on simulator**

## Success Metrics

- Edit "50g → 100g" rice → carbs auto-update from 15g to 30g
- Type carbs directly → subsequent amount changes don't overwrite
- Scan barcode for one item in a multi-item meal → that item updates with OFF nutrition
- Items without serving info show current behavior (name + carbs only)

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| parseBaseServingG doesn't parse all formats | Amount field hidden when nil — graceful fallback |
| `.onChange` infinite loop on carbs write | Guard against epsilon-small changes |
| OFF lookup extraction breaks existing barcode flow | Extract as internal function, existing callers unchanged |
| Per-item scan NavigationLink from staging plate | Uses NavigationLink (not sheet) — safe per nested sheet constraint |

## Sources & References

### Linear
- [DMNC-567](https://linear.app/lizomorf/issue/DMNC-567) — This issue

### Internal References
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` — staging plate
- `App/Views/AddViews/BarcodeScannerView.swift` — ScannerVC_Wrapper to reuse (NOT the full view)
- `App/Modules/Claude/ClaudeMiddleware.swift` — `lookupBarcodeInOpenFoodFacts` to extract
