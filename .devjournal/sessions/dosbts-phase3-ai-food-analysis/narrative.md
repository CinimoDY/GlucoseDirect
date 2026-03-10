# Phase 3: AI-Powered Food Photo Analysis

**Project:** DOSBTS (formerly GlucoseDirect)
**Date:** 2026-03-08 to 2026-03-09
**Status:** Shipped to TestFlight

---

## Context

DOSBTS is an iOS continuous glucose monitoring (CGM) app that connects to Libre sensors via Bluetooth/NFC and displays real-time glucose data. It uses a distinctive DOS amber CGA aesthetic -- green-on-black phosphor monitor vibes rendered through the eiDotter design system.

The food logging capability was planned in three phases:
- **Phase 1:** Manual food logging MVP (shipped)
- **Phase 2:** HealthKit import for nutrition, exercise, and heart rate (shipped)
- **Phase 3:** AI-powered food photo analysis (this session)

Phase 3 is the capstone: point your camera at a meal and get instant nutritional estimates powered by Claude's vision capabilities.

## What Was Built

### 1. BYOK Anthropic API Integration

Users bring their own Anthropic API key. The key is stored securely in the iOS Keychain via a new `KeychainService` -- never persisted in UserDefaults, never exposed in Redux state, never logged. This is a deliberate privacy-by-design choice aligned with the app's philosophy.

### 2. Food Photo Capture

Dual-path image acquisition:
- **Camera capture** via `UIImagePickerController` wrapped in `CameraView` (works on iOS 15+)
- **Photo library** via `PhotosPicker` on iOS 16+ with `UIImagePickerController` fallback for iOS 15

The iOS 15 compatibility constraint shaped several architectural decisions -- no `PhotosUI` assumptions, no async/await-only APIs in the capture path.

### 3. Claude Vision API (Haiku 4.5)

`ClaudeService` sends food photos to claude-haiku-4-5-20250315 with a structured prompt requesting JSON output containing:
- Food item names and estimated portions
- Calorie and macronutrient estimates (carbs, protein, fat, fiber)
- Confidence levels (high/medium/low) for each estimate

The structured JSON output parsing handles Claude's response format directly -- no regex extraction, clean Codable decoding.

### 4. Editable Results UI

`FoodPhotoAnalysisView` (327 lines) presents the AI estimates in the DOS amber theme with:
- Per-item breakdown with editable quantities
- Confidence indicators (high/medium/low) with appropriate CGA colors
- Total nutritional summary
- Save action that creates food log entries through the Redux pipeline

### 5. App Store 5.1.2(i) Consent Flow

`AIConsentView` implements Apple's required disclosure for apps using third-party AI services. It explicitly names Anthropic as the AI provider and requires user consent before any API calls are made. This consent state is persisted and can be revoked in settings.

### 6. Redux Middleware Integration

`ClaudeMiddleware` follows the established pattern -- a middleware function (not a class) that returns `AnyPublisher<DirectAction, DirectError>?`. It handles:
- `.analyzeFood(image:)` actions
- Concurrent request guarding (one analysis at a time)
- Error sanitization (API key details stripped from error messages)
- Result dispatch back through the store

The middleware was registered in both the device and simulator middleware arrays in `App.swift`.

### 7. Security Hardening

- API key stored in Keychain, never in Redux state or UserDefaults
- Sanitized error messages -- no API key fragments in logs or UI
- Concurrent request guard prevents duplicate API calls
- Log middleware updated to redact sensitive action payloads

### 8. CSV Export Protection

`StoreExport.swift` received CSV formula injection protection -- escaping fields that start with `=`, `+`, `-`, `@`, `\t`, or `\r` to prevent spreadsheet formula injection. This protects the `mealDescription` field which now contains AI-generated content.

## Architecture

```
User taps "Analyze Food" -> CameraView/PhotosPicker captures image
  -> Store.dispatch(.analyzeFood(image:))
    -> ClaudeMiddleware intercepts
      -> ClaudeService.analyzeFood(image:) calls Claude API
        -> Response parsed into [NutritionEstimate]
          -> Store.dispatch(.setFoodAnalysisResult(estimates:))
            -> Reducer updates state
              -> FoodPhotoAnalysisView renders results
                -> User edits and saves
                  -> Store.dispatch(.addMeal(meal:))
```

All new files:
- `App/Modules/Claude/ClaudeError.swift` -- Error types
- `App/Modules/Claude/ClaudeMiddleware.swift` -- Redux middleware
- `App/Modules/Claude/ClaudeService.swift` -- API client (215 lines)
- `App/Modules/Claude/KeychainService.swift` -- Secure key storage
- `App/Views/AddViews/AIConsentView.swift` -- App Store consent flow
- `App/Views/AddViews/CameraView.swift` -- Camera wrapper
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` -- Results UI
- `App/Views/Settings/AISettingsView.swift` -- API key management
- `Library/Content/NutritionEstimate.swift` -- Domain model

## Code Review

A code review with 5 parallel agents was run against the Phase 3 branch. It found 12 issues across security, correctness, and robustness categories. All 12 were addressed in commit `b258c1e8` and `0e563dac`:

- Concurrent request guard added to middleware
- Error message sanitization
- CSV formula injection protection
- API key handling hardened
- Edge cases in JSON parsing

## Stats

- **23 files changed**, 1,546 insertions, 73 deletions
- **9 new source files** across 4 directories
- **5 commits** on the feature branch
- **12 code review issues** identified and fixed
- Development time: evening of March 8 through morning of March 9

## Milestone

This completes the full three-phase food logging plan for DOSBTS:

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Manual food logging MVP | Shipped |
| 2 | HealthKit import (nutrition, exercise, heart rate) | Shipped |
| 3 | AI-powered food photo analysis | Shipped |

The app now offers a complete food logging workflow: snap a photo, get AI-estimated nutrition, edit if needed, save, and see the data correlated with glucose readings on the main chart.

## Learnings

- **iOS 15 compatibility** continues to shape architectural decisions. PhotosPicker requires iOS 16+, so the fallback to UIImagePickerController was essential.
- **BYOK (Bring Your Own Key)** is a clean pattern for App Store apps using third-party AI -- avoids proxy server costs, gives users control, and simplifies the privacy story.
- **Structured JSON output from Claude** works reliably for nutrition estimation. The key is a clear prompt with an explicit JSON schema.
- **5-agent parallel code review** is an effective QA pass -- found issues a single reviewer might miss, especially around security edge cases.
- **App Store 5.1.2(i)** requires explicit third-party AI disclosure. Building the consent flow upfront avoids review rejection.
