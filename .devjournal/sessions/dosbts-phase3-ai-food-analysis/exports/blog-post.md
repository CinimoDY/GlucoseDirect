# Adding AI Food Analysis to a CGM App (With a DOS Aesthetic)

## The Problem

DOSBTS is an iOS app for continuous glucose monitoring -- it connects to Libre sensors and shows real-time blood sugar data. We'd already built manual food logging and HealthKit import, but the friction of typing in every meal was too high. People with diabetes need to track what they eat to understand their glucose response. What if they could just take a photo?

## The Journey

The plan was straightforward: let users photograph their food, send it to an AI vision model, and get back nutritional estimates they can edit and save. The reality involved navigating iOS version compatibility, App Store compliance, security constraints, and the Redux-like architecture the app is built on.

### Bring Your Own Key

Rather than running a proxy server or bundling an API key, we went with BYOK -- users enter their own Anthropic API key, which gets stored in the iOS Keychain. This keeps the privacy story clean (the app never sees your key on our servers, because there are no servers) and avoids ongoing infrastructure costs. The key never touches Redux state or UserDefaults.

### Camera + Photo Library

iOS 15 compatibility was a constraint throughout. `PhotosPicker` (the modern SwiftUI photo picker) requires iOS 16+, so we built a dual path: `PhotosPicker` when available, `UIImagePickerController` wrapped in a `UIViewControllerRepresentable` as fallback. Camera capture always uses the UIKit wrapper since there's no SwiftUI-native camera API.

### Claude Vision Does the Heavy Lifting

We send the food photo to Claude Haiku 4.5 with a structured prompt asking for JSON output: food items, estimated portions, calories, macros (carbs, protein, fat, fiber), and a confidence level for each estimate. The structured output parsing is clean Codable -- no regex hacks.

### The DOS Amber Treatment

The results screen follows the app's CGA amber aesthetic. Confidence levels map to CGA palette colors: high confidence in amber, medium in yellow, low in the dim amber. Everything in SF Mono. It looks like a nutrition database terminal from 1985, which is exactly the point.

### Code Review Found 12 Issues

We ran a code review with 5 parallel agents against the feature branch. They found 12 issues: missing concurrent request guards, unsanitized error messages that could leak API key fragments, CSV formula injection vectors in the export writer, and various edge cases. All fixed before merge.

## The Solution

The complete flow: tap "Analyze Food" on the food logging screen, capture or select a photo, wait a few seconds for Claude to process it, review and edit the nutritional estimates, save. The food log entry then appears on the main glucose chart, correlated with sensor readings.

This was the third and final phase of the food logging plan:
1. **Phase 1:** Manual food entry (type in what you ate)
2. **Phase 2:** HealthKit import (pull in nutrition data from other apps)
3. **Phase 3:** AI photo analysis (snap a photo, get estimates)

23 files changed, ~1,500 lines of new code, 9 new source files, deployed to TestFlight.

## What I Learned

- **BYOK is underrated** for App Store apps using third-party AI. No server costs, clear privacy story, user control over their own API usage.
- **App Store 5.1.2(i)** requires you to name the AI provider explicitly in a consent flow. Build this upfront.
- **iOS version constraints cascade.** One iOS 15 requirement meant dual-path implementations across multiple components.
- **Parallel agent code review** catches things serial review misses. The CSV injection vector was found by one agent that the others didn't flag.
- **Structured JSON output from vision models** is reliable enough for production use when you give a clear schema in the prompt.

## Tech Stack

Swift, SwiftUI, Redux-like architecture (Store/Action/Reducer/Middleware), Anthropic Claude API (Haiku 4.5), iOS Keychain, UIKit interop, GRDB, HealthKit
