# Phase 3: AI Food Photo Analysis -- Technical Documentation

## Overview

Phase 3 adds AI-powered food photo analysis to DOSBTS using the Anthropic Claude API (Haiku 4.5). Users photograph meals to receive nutritional estimates that can be edited and saved as food log entries.

## Architecture

### New Components

| File | Purpose |
|------|---------|
| `App/Modules/Claude/ClaudeService.swift` | HTTP client for Claude Messages API with vision support |
| `App/Modules/Claude/ClaudeMiddleware.swift` | Redux middleware handling `.analyzeFood` actions |
| `App/Modules/Claude/ClaudeError.swift` | Error types with sanitized descriptions |
| `App/Modules/Claude/KeychainService.swift` | iOS Keychain wrapper for API key storage |
| `App/Views/AddViews/FoodPhotoAnalysisView.swift` | Results display and editing UI |
| `App/Views/AddViews/AIConsentView.swift` | App Store 5.1.2(i) consent flow |
| `App/Views/AddViews/CameraView.swift` | UIImagePickerController SwiftUI wrapper |
| `App/Views/Settings/AISettingsView.swift` | API key management settings |
| `Library/Content/NutritionEstimate.swift` | Domain model for AI estimates |

### Data Flow

```
Action: .analyzeFood(image: UIImage)
  -> ClaudeMiddleware
    -> ClaudeService.analyzeFood(image:)
      -> POST /v1/messages (claude-haiku-4-5-20250315)
      -> Parse JSON response into [NutritionEstimate]
    -> Action: .setFoodAnalysisResult(estimates:)
      -> Reducer updates AppState.foodAnalysisResults
        -> FoodPhotoAnalysisView re-renders

Action: .saveFoodAnalysis
  -> Existing meal creation pipeline
```

### State Changes

Added to `DirectState` / `AppState`:
- `claudeAPIKeySet: Bool` -- whether a key exists in Keychain (not the key itself)
- `aiConsentGiven: Bool` -- user has accepted the AI disclosure
- `foodAnalysisInProgress: Bool` -- concurrent request guard
- `foodAnalysisResults: [NutritionEstimate]?` -- latest analysis results
- `foodAnalysisError: String?` -- sanitized error message

Added to `DirectAction`:
- `.analyzeFood(image: UIImage)` -- trigger analysis
- `.setFoodAnalysisResult(estimates: [NutritionEstimate])` -- receive results
- `.setFoodAnalysisError(error: String)` -- receive error
- `.clearFoodAnalysis` -- reset state
- `.setClaudeAPIKey(key: String)` -- store key in Keychain
- `.removeClaudeAPIKey` -- delete key from Keychain
- `.setAIConsent(granted: Bool)` -- update consent state

### Security Model

1. **API key storage:** iOS Keychain only. Never in UserDefaults, Redux state, or logs.
2. **Error sanitization:** `ClaudeError` descriptions strip any key fragments. The middleware catches raw errors and re-wraps them.
3. **Concurrent request guard:** `foodAnalysisInProgress` flag prevents duplicate API calls. The middleware returns `nil` (no-op) if a request is already in flight.
4. **Log redaction:** The Log middleware filters `.analyzeFood` actions to avoid logging image data.
5. **CSV export protection:** `StoreExport.swift` escapes fields starting with `=`, `+`, `-`, `@`, `\t`, `\r` to prevent formula injection in spreadsheet applications.

### Claude API Integration

**Endpoint:** `POST https://api.anthropic.com/v1/messages`
**Model:** `claude-haiku-4-5-20250315`
**Content:** Multi-part message with image (base64 JPEG, max 1MB after compression) and text prompt requesting structured JSON.

**Response schema:**
```json
{
  "items": [
    {
      "name": "Grilled chicken breast",
      "portion": "6 oz",
      "calories": 280,
      "carbs": 0,
      "protein": 52,
      "fat": 6,
      "fiber": 0,
      "confidence": "high"
    }
  ]
}
```

**NutritionEstimate model:**
```swift
struct NutritionEstimate: Codable, Identifiable {
    let id: UUID
    var name: String
    var portion: String
    var calories: Double
    var carbs: Double
    var protein: Double
    var fat: Double
    var fiber: Double
    var confidence: ConfidenceLevel

    enum ConfidenceLevel: String, Codable {
        case high, medium, low
    }
}
```

### iOS Version Compatibility

- **iOS 15+:** UIImagePickerController for camera and photo library
- **iOS 16+:** PhotosPicker for photo library (preferred path)
- Availability checks via `@available(iOS 16.0, *)` and `#available`

### App Store Compliance

`AIConsentView` satisfies App Store Review Guideline 5.1.2(i):
- Names "Anthropic" as the third-party AI provider
- Explains that food photos are sent to Anthropic's API for analysis
- Requires explicit opt-in before any API calls
- Consent can be revoked in AI Settings
- Consent state persisted in UserDefaults via `aiConsentGiven`

## Testing

- **VirtualConnection** provides simulated glucose data for testing without a real sensor
- AI analysis can be tested with any food photo when an API key is configured
- The concurrent request guard can be verified by rapid-tapping the analyze button

## Dependencies

No new external dependencies. The Claude API client is a vanilla URLSession implementation using Codable for serialization.
