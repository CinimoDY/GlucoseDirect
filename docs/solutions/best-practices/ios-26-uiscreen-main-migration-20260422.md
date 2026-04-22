---
title: "Migrating off UIScreen.main on iOS 26 — three subtleties the naive replacement misses"
date: 2026-04-22
category: best-practices
module: ios-platform-apis
problem_type: best_practice
component: tooling
severity: medium
applies_when:
  - "Deployment target bumped to iOS 26+"
  - "Any `UIScreen.main.bounds` / `.scale` / `.traitCollection` read in the codebase"
  - "Project has an app-extension target (widget, intent, share) sharing code with the main app"
tags:
  - ios-26
  - uiscreen
  - deprecation
  - scene-based-lifecycle
  - app-extensions
  - swiftui
  - cold-start
---

# Migrating off UIScreen.main on iOS 26 — three subtleties the naive replacement misses

## Context

iOS 26 deprecates `UIScreen.main`. Apple's deprecation notice says "Use a UIScreen instance found through context instead (i.e., `view.window.windowScene.screen`), or for properties like `UIScreen.scale` with trait equivalents, use a `traitCollection` found through context." A quick grep-and-replace makes it look like a three-line fix. It isn't — there are three subtleties that only surface at review time or on a specific cold-launch path.

Discovered in DOSBTS during DMNC-780 (PR #25). The initial one-liner replacement compiled and ran fine in normal usage. ce:review caught two of the three failures (cross-reviewer agreement between correctness and adversarial at 0.92 confidence on the cold-start cascade); the extension-target issue was caught by the first build after the naive replacement.

## Guidance

### 1. Build a connected-scene lookup with a layered fallback

`UIScreen.current` isn't a thing. The replacement is walking `UIApplication.shared.connectedScenes`:

```swift
extension UIScreen {
    private static var current: UIScreen? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        // Prefer foregroundActive, then foregroundInactive (mid-transition
        // during Control Center / notification-drawer gestures), then any
        // attached scene. Fall back to the first window scene for the
        // background-launch / scene-restoration cold path.
        return windowScenes.first { $0.activationState == .foregroundActive }?.screen
            ?? windowScenes.first { $0.activationState == .foregroundInactive }?.screen
            ?? windowScenes.first?.screen
    }

    static var screenWidth: CGFloat {
        current?.bounds.size.width ?? 0
    }

    static var screenHeight: CGFloat {
        current?.bounds.size.height ?? 0
    }

    static var screenSize: CGSize {
        current?.bounds.size ?? .zero
    }
}
```

`.foregroundActive` alone is not enough — Control Center and notification-drawer gestures put the scene in `.foregroundInactive` for the duration of the gesture, and naive code missing that state falls through to the "first scene" branch, which is enumeration-order-unstable and may pick the wrong screen on iPad Stage Manager or AirPlay mirroring.

### 2. The extension must live under the app target, not `Library/`

`UIApplication.shared` is declared `NS_EXTENSION_UNAVAILABLE` — app extensions (widgets, intents, share sheets) cannot reference it. In DOSBTS the extension originally sat at `Library/Extensions/UIScreen.swift` where it was shared between the app and widget target. Using the new implementation there made the widget target fail to compile with `'shared' is unavailable in application extensions for iOS`.

Move the file under the app target's source tree (`App/Extensions/UIScreen.swift` in this project's convention) so the widget target never picks it up. Add a header comment explaining why it lives there — the relocation looks arbitrary in `git log` without the explanation:

```swift
//
//  UIScreen.swift
//
//  Lives under App/ (not Library/) because UIApplication.shared is
//  NS_EXTENSION_UNAVAILABLE and the widget target would fail to compile.
//  Do not move back to Library/Extensions/ without a shared abstraction.
//
```

If a helper needs to be shared between app and widget, it needs a different implementation strategy (pass the scene or size in from a SwiftUI `GeometryReader`, or derive from `traitCollection`).

### 3. Clamp at the consumer, not at the extension

On scene-restoration cold launches, `UIApplication.shared.connectedScenes` is briefly empty before the scene is wired. `current` returns nil → `screenWidth` returns 0 → any consumer that does arithmetic on it produces a wrong value.

In DOSBTS the ChartView had:

```swift
private var screenWidth: CGFloat {
    UIScreen.screenWidth - 40  // -40 when scenes not yet wired
}
```

`-40` then cached into a SwiftUI `@State` (`seriesWidth`) which is NOT observable on `UIScreen` changes. The chart rendered at a zero/negative frame and **stayed blank** until an unrelated trigger (new glucose reading, rotation, zoom-level change) re-evaluated `body`. The pre-migration `UIScreen.main.bounds` path did not have this failure mode because `UIScreen.main` was always available, even mid-launch.

Fix at the **consumer**, not the extension. The extension returning 0 when there's no scene is semantically honest — the consumer knows what it's computing and can choose the right floor:

```swift
private var screenWidth: CGFloat {
    // Clamp to 0: pre-scene cold launch returns 0 for UIScreen.screenWidth,
    // and 0 - 40 = -40 would cache into seriesWidth @State and stick there.
    max(0, UIScreen.screenWidth - 40)
}
```

Don't push the clamp into the extension — a consumer that wants `max(0, screenWidth)` semantics might not be the right default for another consumer doing ratio math.

## Why This Matters

The three subtleties all compound into the same class of failure: a migration that *appears* complete because the app launches, the compiler is happy, and the warning is gone, but has behavior regressions on narrow cold-start paths that only trigger for some users some of the time.

- Missing `.foregroundInactive` shows up when users pull down notification center during a rotation — the chart momentarily sizes against stale pre-rotation bounds.
- The extension-target issue is caught immediately by the build but only if the widget target is actually built; a developer running `xcodebuild -scheme DOSBTSApp` without also building the widget scheme won't see it.
- The zero-scene cold-start cascade is the hardest to catch. It only fires on scene-restoration cold launches (app killed in the background, user taps the icon while screen is locked, system wakes the app to restore state). On a warm launch or a from-Xcode launch, `connectedScenes` is already populated.

The review-time cost of catching all three is high — correctness + adversarial reviewers only caught it because the seed mentioned scene restoration. The runtime cost of *missing* them is a blank chart on first launch for some users, which is difficult to diagnose post-deploy because the bug self-heals on the next trigger.

## When to Apply

- Any iOS 26+ app that previously used `UIScreen.main.bounds` / `.scale` / `.traitCollection`
- Any shared-code app/widget architecture where `Library/`-style common extensions might host UIKit-application-level APIs
- Any SwiftUI view that reads a `UIScreen`-derived value and caches it into `@State`

## Examples

### Before (iOS 15-blessed)

```swift
// Library/Extensions/UIScreen.swift (shared between app + widget)
extension UIScreen {
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.size.width
    }
}

// ChartView.swift
private var screenWidth: CGFloat {
    UIScreen.screenWidth - 40  // always valid, main is never nil
}
```

### After (iOS 26+)

```swift
// App/Extensions/UIScreen.swift (app-target only — widget would fail to compile)
extension UIScreen {
    private static var current: UIScreen? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        return windowScenes.first { $0.activationState == .foregroundActive }?.screen
            ?? windowScenes.first { $0.activationState == .foregroundInactive }?.screen
            ?? windowScenes.first?.screen
    }

    static var screenWidth: CGFloat {
        current?.bounds.size.width ?? 0  // honest default: no scene → 0
    }
}

// ChartView.swift
private var screenWidth: CGFloat {
    max(0, UIScreen.screenWidth - 40)  // clamp at the consumer
}
```

## Related

- DMNC-780 — iOS 26 UIScreen.main migration tracking issue
- PR #25 (DOSBTS) — the migration commit with subsequent `7c9ba955` hardening from ce:review
- `docs/solutions/build-errors/ios-deployment-target-blocks-swift-api-cleanup-20260422.md` — sibling finding: the iOS 17 deployment-target mismatch that blocked an earlier API cleanup (same bump-target prerequisite applies here)
