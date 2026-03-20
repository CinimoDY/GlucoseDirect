---
title: "feat: Barcode Scanning + Food Database Lookup"
type: feat
status: completed
date: 2026-03-20
deepened: 2026-03-20
linear: DMNC-561
---

# Barcode Scanning + Food Database Lookup

## Enhancement Summary

**Deepened on:** 2026-03-20
**Research agents:** architecture-strategist, security-sentinel, code-simplicity-reviewer

### Key Improvements
1. **Simplified to 1 new file** (down from 3) — OFF API call inlined in ClaudeMiddleware, no separate service or middleware
2. **1 new action** instead of 2 — `.analyzeFoodBarcode(code:)` reuses existing loading/result state
3. **Bounds-clamp OFF data** before HealthKit — missing nutrition treated as nil (not zero), critical for CGM context
4. **Barcode validation** — digits-only, restrict scanner to EAN/UPC formats only
5. **SCAN button outside API key gate** — OFF is free, no auth needed

---

## Overview

Dedicated barcode scanner view in the food entry screen. User taps SCAN → live camera preview with viewfinder overlay → scans EAN-13/EAN-8/UPC barcode → looks up product in Open Food Facts API (free, no auth) → nutrition data lands on existing staging plate for confirmation and logging.

## Problem Statement

For packaged foods with barcodes, users currently have to manually enter nutrition data or take a photo and hope Claude estimates correctly. A barcode scan gives exact, manufacturer-provided nutrition data in seconds — no estimation, no guessing.

## Proposed Solution

### UX Flow

1. User opens UnifiedFoodEntryView (MEAL button)
2. Taps **SCAN** in actionsSection (NavigationLink, NO API key gate — OFF is free)
3. `BarcodeScannerView` — live camera preview with centered amber viewfinder
4. Camera auto-detects EAN-13/EAN-8/UPC barcode via `AVCaptureMetadataOutput`
5. Haptic feedback on detection (`UINotificationFeedbackGenerator.success`)
6. Barcode validated (digits-only, length 8-14) → OFF API lookup (10s timeout)
7. **Product found** → Convert to `NutritionEstimate` → dispatch `.setFoodAnalysisResult` → push to staging plate
8. **Product not found** → "Product not found" with fallback to manual entry / Ask AI
9. User reviews/edits on staging plate → "Log Meal" → saved via existing flow

### Architecture (Simplified)

**1 new file only:**
- `App/Views/AddViews/BarcodeScannerView.swift` — UIViewControllerRepresentable wrapping AVCaptureSession

**1 new action:**
- `DirectAction.analyzeFoodBarcode(code: String)` — handled by existing `claudeMiddleware`

**No new middleware, no new service file.** The OFF API call is a private function inlined in `ClaudeMiddleware.swift` (~30 lines). This matches how all food analysis paths converge in one middleware.

**Shared state:** Reuse `foodAnalysisResult` / `foodAnalysisLoading` / `foodAnalysisError`. View dispatches `.setFoodAnalysisLoading(true)` before `.analyzeFoodBarcode`. Staging plate in `FoodPhotoAnalysisView` works automatically.

**No consent gate:** Unlike photo/text analysis (which require `aiConsentFoodPhoto`), barcode lookup uses OFF's free public API — no API key, no consent needed. The SCAN button sits OUTSIDE the `claudeAPIKeyValid || aiConsentFoodPhoto` conditional in `actionsSection`.

### Open Food Facts API

**Endpoint:**
```
GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json
    ?fields=product_name,brands,serving_size,serving_quantity,nutriments
```

**Required header:** `User-Agent: DOSBTS/1.0 (iOS CGM app)`

**Response mapping to NutritionEstimate:**
- Check `status == 1` AND `nutriments` non-empty
- Use `_serving` values when `serving_quantity > 0`, otherwise `_100g` with "per 100g" label
- Map: `carbohydrates → carbsG`, `proteins → proteinG`, `fat → fatG`, `energy-kcal → calories`, `fiber → fiberG`
- Energy fallback: if `energy-kcal` missing, compute `energy-kj / 4.184`
- Product name: `"{brands} - {product_name}"`, capped at 200 chars
- Confidence: `.medium` by default (crowdsourced data). `.low` if any macro field is missing
- All nutriment fields decoded as `Double?` — missing = nil, NOT zero

**Error handling:**
- `status == 0` → "Product not found" (OFF returns HTTP 200 with status 0)
- Network error → "Network unavailable"
- Empty `nutriments` → "Product found but no nutrition data"
- Timeout: 10 seconds (not 30 — this is a fast DB read, not AI inference)

### Barcode Scanner View

**Implementation:** `UIViewControllerRepresentable` wrapping `UIViewController` with:
- `AVCaptureSession` + `AVCaptureMetadataOutput` (hardware-accelerated, performant on iPhone 8/A11)
- Barcode types: `.ean8`, `.ean13`, `.upce` ONLY — no QR, no Code128 (security: prevents arbitrary string injection)
- Viewfinder: centered amber-bordered rectangle, `metadataOutput.rectOfInterest` restricts detection area
- Haptic: `UINotificationFeedbackGenerator().notificationOccurred(.success)` with `.prepare()` on appear
- Session runs on background queue (`DispatchQueue(label: "barcode.session")`)
- **Communicates via closure** (not direct dispatch) — matches CameraView pattern
- `#if !targetEnvironment(simulator)` — show text field for manual barcode entry in simulator

## Technical Considerations

### Files to Create

| File | Purpose |
|------|---------|
| `App/Views/AddViews/BarcodeScannerView.swift` | UIViewControllerRepresentable with AVCaptureSession, viewfinder, haptic |

### Files to Modify

| File | Change |
|------|--------|
| `Library/DirectAction.swift` | Add `.analyzeFoodBarcode(code: String)` |
| `App/Modules/Claude/ClaudeMiddleware.swift` | Handle `.analyzeFoodBarcode` — validate barcode, call OFF API, convert to NutritionEstimate |
| `App/Views/AddViews/UnifiedFoodEntryView.swift` | Add SCAN NavigationLink OUTSIDE API key gate |
| `App/Modules/Log/Log.swift` | Suppress `.analyzeFoodBarcode` from logs |
| `DOSBTS.xcodeproj/project.pbxproj` | Add BarcodeScannerView.swift (1 file × 4 sections) |

### Key Decisions

1. **No separate service file** — OFF API call is ~30 lines of URLSession code, inlined as a private function in ClaudeMiddleware. Extract later if complexity grows (YAGNI).

2. **No separate middleware** — `claudeMiddleware` already owns the "analyze food → NutritionEstimate → staging plate" pipeline. Barcode is a third input source, not a different pipeline. No consent gate needed (unlike photo/text).

3. **One action:** `.analyzeFoodBarcode(code:)` — reuses `.setFoodAnalysisLoading` and `.setFoodAnalysisResult`. No `.setBarcodeLoading`.

4. **SCAN outside API key gate** — OFF is free. SCAN button always visible (no conditional).

5. **Digits-only barcode validation** — validate `barcode.allSatisfy(\.isNumber) && (8...14).contains(barcode.count)` before URL construction. Prevents path injection.

6. **Missing nutrition = nil, not zero** — critical for CGM: 0g carbs would be dangerous misinformation. Show "unknown" in staging plate for missing fields.

7. **Bounds-clamp before HealthKit** — carbs 0-1000g, calories 0-10000, protein/fat 0-500g, fiber 0-200g. Applied at NutritionEstimate conversion, not in UI.

### Learnings to Apply

- **NavigationLink push, not sheet** — nested sheet constraint
- **SCAN button OUTSIDE the API key conditional** — unlike PHOTO/ASK AI, OFF needs no auth
- **BarcodeScannerView communicates via closure** — view dispatches, not the scanner (UUID ownership pattern)
- **Suppress barcode action from logs** — consistency with food PII suppression
- **Clear shared state before new scan** — `.setFoodAnalysisLoading(true)` before dispatch

### Edge Cases

- **Product not found** → DOS-styled "NOT FOUND" with barcode number, offer manual/AI fallback
- **Product found, no nutrition** → Same as not found
- **Missing fiber** (common in OFF) → Set to nil, staging plate shows "--"
- **Energy in kJ only** → Convert: `kcal = kJ / 4.184`
- **OFF mixed types** (nutriments as string "12.5" vs number 12.5) → Custom decoder handles both
- **Camera permission denied** → Show settings link
- **Offline** → Network error, suggest manual entry
- **Multiple barcodes in frame** → Take first detected
- **UPC-A** → Returned as EAN-13 with leading 0; OFF accepts both formats

## Acceptance Criteria

- [x] **SCAN button** in actionsSection (barcode.viewfinder icon, always visible — no API key gate)
- [x] **Live camera preview** with centered amber viewfinder
- [x] **Auto-detect** EAN-13, EAN-8, UPC-E (no QR/Code128)
- [x] **Haptic feedback** on successful scan
- [x] **OFF API lookup** with User-Agent header, 10s timeout
- [x] **Product found** → NutritionEstimate → staging plate via shared state
- [x] **Product not found** → "not found" with fallback options
- [x] **Per-serving nutrition** from OFF serving data
- [x] **Missing nutrition = nil** (not zero) — staging plate shows "--"
- [x] **Numeric bounds clamped** before HealthKit write (carbs 0-1000, etc.)
- [x] **Barcode validated** digits-only before API call
- [x] **Simulator fallback** — manual barcode text field
- [x] **NavigationLink push** — not a sheet
- [x] **`.analyzeFoodBarcode` suppressed** from log middleware
- [x] **Builds on simulator**

## Success Metrics

- Scan a European grocery product (EAN-13) → accurate nutrition → log in < 10 seconds
- German supermarket products have reasonable hit rate (~400k products in OFF German DB)
- Products with serving sizes show per-serving data correctly
- Failed lookups gracefully offer manual/AI fallback
- Missing nutrition fields shown as "--" not "0g"

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| OFF database gaps (Aldi/Lidl private label) | "Not found" gracefully; fallback to AI text entry |
| OFF API downtime | Network error; manual entry fallback |
| Missing nutrition fields (especially fiber) | nil not zero; staging plate shows "--" |
| Malformed OFF data reaching HealthKit | Bounds-clamp at NutritionEstimate conversion |
| OFF mixed number/string types in JSON | Custom decoder with LosslessStringConvertible fallback |
| New file needs pbxproj | 1 new file = 4 manual pbxproj entries |
| iPhone 8 performance | AVCaptureMetadataOutput uses hardware decoder — no CPU concern |

## Sources & References

### External
- [Open Food Facts API v2](https://openfoodfacts.github.io/openfoodfacts-server/api/) — free, no auth, 100 req/min
- [AVCaptureMetadataOutput — Apple Developer](https://developer.apple.com/documentation/avfoundation/avcapturemetadataoutput)
- [German OFF Database](https://de.openfoodfacts.org/) — ~400k products

### Linear
- [DMNC-561](https://linear.app/lizomorf/issue/DMNC-561) — This issue
- [DMNC-562](https://linear.app/lizomorf/issue/DMNC-562) — Portion presets (future, builds on this)
- [DMNC-563](https://linear.app/lizomorf/issue/DMNC-563) — 2026 food logging vision

### Internal References
- `App/Views/AddViews/CameraView.swift` — UIViewControllerRepresentable pattern to follow
- `App/Modules/Claude/ClaudeMiddleware.swift` — add `.analyzeFoodBarcode` case here
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` — staging plate (reuse via shared state)
- `docs/technology-stack.md` — AVFoundation + Vision recommended
- `docs/requirements.md` — barcode scanning is High priority
