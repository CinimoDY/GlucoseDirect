---
title: "feat: Portion Presets & Smart Quantities"
type: feat
status: completed
date: 2026-03-21
deepened: 2026-03-21
linear: DMNC-562
---

# Portion Presets & Smart Quantities

## Enhancement Summary

**Deepened on:** 2026-03-21
**Research agents:** architecture-strategist, code-simplicity-reviewer

### Key Simplifications
1. **UserDefaults, not GRDB** — 6 presets stored as `Codable` array in UserDefaults (same as `customCalibration`)
2. **No separate middleware** — preset loading folded into FavoriteStore's `.startup`
3. **No dedicated Settings screen** — inline preset picker on staging plate
4. **Scaling at save time only** — prevents correction system pollution (critical finding)
5. **Scoped to single-item barcode results** — multi-item Claude meals have no meaningful uniform base

### Critical Finding
Applying the multiplier to `EditableFoodItem.carbsG` would cause `computeCorrections()` to misattribute portion scaling as AI carb errors, polluting the PersonalFood dictionary. Fix: scale only at save time, pass unscaled items to corrections.

---

## Overview

Inline portion picker on the staging plate for barcode-scanned products. When OFF returns "per 100g" nutrition, user selects a preset ("Large glass 350ml") or enters a custom amount → nutrition scales proportionally → MealEntry stores the scaled values. ~65 LOC across existing files, 1 new model file.

## Problem Statement

Barcode products report nutrition "per 100g" or "per serving (30g)", but users eat variable portions. The NL text parser handles quantities via Claude, but barcode results have no portion adjustment. Users need a quick way to scale without mental math.

## Proposed Solution

### UX Flow

1. Barcode scan returns product with "per 100g" nutrition
2. Staging plate shows items with a **portion picker** below the nutrition banner:
   - Horizontal row of preset chips: "200ml", "350ml", "Custom"
   - Custom: text field for entering amount (e.g., "150g")
   - Display: "150g (×1.5)"
3. Nutrition banner shows **scaled** totals in real-time
4. User taps "Log Meal" → `saveAnalysis()` stores scaled values in MealEntry
5. `computeCorrections()` receives **unscaled** items → no correction pollution

### When Portion Picker Appears

- **Barcode results**: `stagedItems.count == 1 && stagedItems[0].baseServingG != nil` → show picker
- **NL text results**: hidden (Claude already handles portions inline)
- **Photo results**: hidden (no base serving amount)
- **Multi-item results**: hidden (uniform scaling doesn't make sense)

### Architecture (Simplified)

**1 new model file only:** `Library/Content/ServingPreset.swift`

```swift
struct ServingPreset: Codable, Identifiable {
    let id: UUID
    let label: String     // "Small glass", "Large glass"
    let amountML: Double  // amount in ml (or g — 1:1 for most foods)
}
```

**UserDefaults storage** (not GRDB): `[ServingPreset]` as JSON, same pattern as `customCalibration`. Default presets seeded in `AppState.init`:
- Small glass — 200ml
- Large glass — 350ml
- Mug — 250ml
- Small bowl — 200g
- Large bowl — 350g

**No separate middleware.** Presets loaded from UserDefaults on access (computed property). No async, no GRDB, no middleware registration.

**View-layer scaling with save-time application:**
```swift
@State private var portionMultiplier: Double = 1.0
@State private var baseStagedItems: [EditableFoodItem] = []  // original unscaled
```

- `baseStagedItems` populated alongside `stagedItems` in `populateStagedItems(from:)`
- Nutrition banner shows `baseStagedItems[0].carbsG * portionMultiplier`
- `saveAnalysis()` creates `MealEntry` with scaled values: `carbsGrams: baseCarbs * portionMultiplier`
- `computeCorrections()` receives `baseStagedItems` (unscaled) — no correction pollution

**`baseServingG` on `EditableFoodItem`:** Set during `populateStagedItems` from `NutritionItem.servingSize` parsing (for barcode results, OFF provides `serving_quantity`).

## Technical Considerations

### New File

| File | Target | Purpose |
|------|--------|---------|
| `Library/Content/ServingPreset.swift` | Library | Model (Codable, Identifiable) |

### Files to Modify

| File | Change |
|------|--------|
| `Library/Extensions/UserDefaults.swift` | Add `servingPresets` key + computed property |
| `Library/DirectState.swift` + `App/AppState.swift` | Add `servingPresets: [ServingPreset]` (UserDefaults-backed with defaults) |
| `Library/DirectReducer.swift` | Reducer case for `setServingPresets` |
| `Library/DirectAction.swift` | Add `setServingPresets` action |
| `App/Views/AddViews/FoodPhotoAnalysisView.swift` | `EditableFoodItem.baseServingG`, `baseStagedItems`, portion picker UI, scaling in `saveAnalysis()` |
| `DOSBTS.xcodeproj/project.pbxproj` | Add ServingPreset.swift (1 file × 4 sections) |

### Key Decisions

1. **UserDefaults, not GRDB** — 5 presets is settings data, not query-able database content. Same pattern as `customCalibration`.

2. **No separate middleware** — presets are synchronous UserDefaults reads. No async needed.

3. **Scale at save time only** — `computeCorrections()` receives unscaled `baseStagedItems`. The PersonalFood dictionary stays clean. Nutrition banner shows `base × multiplier` as a computed display.

4. **Scoped to single-item barcode results** — portion picker hidden for multi-item Claude results (no meaningful uniform base serving).

5. **`baseServingG` on `EditableFoodItem`** — not on `NutritionEstimate`. Set from OFF `serving_quantity` during `populateStagedItems`. Correct architectural boundary (view-local state).

6. **No Settings screen for MVP** — presets are hardcoded defaults. User-managed custom presets deferred until needed.

### Learnings Applied

- **Correction system integrity** — scaling must not be mistaken for AI corrections (architecture review finding)
- **Nested sheet constraint** — if custom preset editing is added later, use NavigationLink not sheet
- **Both middleware arrays** — not needed since no new middleware
- **NavigationLink for all push navigation** from staging plate

### Edge Cases

- **No base amount** (photo/text path) → portion picker hidden
- **Multi-item meal** → portion picker hidden (uniform scaling doesn't make sense)
- **Custom amount 0 or negative** → clamp to minimum 1
- **Very large portion** → cap multiplier at 20x
- **Barcode with no `serving_quantity`** → default base to 100g
- **Picker shows current serving** → "per 100g" label with ×1.0 default

## Acceptance Criteria

- [x] **ServingPreset model** in Library with UserDefaults storage
- [x] **Default presets** seeded (200ml, 250ml, 350ml, 200g, 350g)
- [x] **Portion picker** on staging plate for single-item barcode results
- [x] **Nutrition banner scales** in real-time (display only — base × multiplier)
- [x] **MealEntry stores scaled values** at save time
- [x] **Corrections use unscaled values** — no PersonalFood dictionary pollution
- [x] **Custom amount entry** — text field for entering specific g/ml
- [x] **Multiplier capped** at 20x, minimum 0.1x
- [x] **Hidden for multi-item/photo/text results**
- [x] **Builds on simulator**

## Success Metrics

- Scan milk carton (per 100ml) → pick "Large glass 350ml" → nutrition shows ×3.5
- Custom "150g" on per-100g product → correct ×1.5 scaling
- Corrections logged after portion-adjusted meal contain unscaled AI values (no pollution)
- Photo/text results show no portion picker (zero friction for non-barcode flows)

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| `serving_quantity` missing from OFF | Default to 100g base |
| Correction system pollution from scaling | Scale at save time only; corrections use `baseStagedItems` |
| Unit mismatch (ml preset on g product) | Allow approximate scaling (1ml ≈ 1g for liquids) |
| 1 new file needs pbxproj | 4 manual entries (standard) |

## Sources & References

### Linear
- [DMNC-562](https://linear.app/lizomorf/issue/DMNC-562) — This issue

### Internal References
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` — staging plate (add portion picker + baseStagedItems)
- `Library/Extensions/UserDefaults.swift` — UserDefaults Codable storage pattern
- `Library/Content/FavoriteFood.swift` — model pattern reference
- `App/Modules/Claude/ClaudeMiddleware.swift` — OFF parser (serving_quantity)
- `docs/references/staging-plate-pattern.md` — "portion multipliers at log time"
