---
title: "SwiftUI .onChange doesn't fire while the scene is backgrounded — don't rely on it for must-happen-in-background work"
date: 2026-04-24
category: logic-errors
module: ui
problem_type: bug
component: swiftui-lifecycle
severity: high
applies_when:
  - "Dispatching something (widget reload, notification, HealthKit write, network call) in response to state changes via SwiftUI .onChange"
  - "That response must happen even when the app's scene is in the background"
  - "Concretely: a CGM app writing to a home-screen widget, a timer app updating a Live Activity, or an HK-export flow triggered by sensor data"
tags:
  - swiftui
  - onchange
  - background
  - widgetkit
  - lifecycle
  - reloadalltimelines
  - cgm-safety
---

# SwiftUI `.onChange` is dormant when the scene is backgrounded

## What happened

DOSBTS's home-screen glucose widget was stuck showing stale values when the user backgrounded the app. New sensor readings were arriving (via the BLE callback in `SensorConnector`) and the data was being written to the App Group — `UserDefaults.shared.latestSensorGlucose` had the fresh value. But the widget kept showing the last 15-minute-old number until the user either opened the app or the widget's own 15-minute scheduled tick fired.

For a CGM the consequence is safety-critical: users look at the widget *instead of* opening the app, and a stale read can mask a dangerous trajectory.

## Root cause

The widget-reload chain had three entry points:

1. `widgetCenterMiddleware` on `.setAppState(.active)` — fires on foreground transition.
2. `ContentView.onChange(of: scenePhase)` when `newPhase == .active` — fires on foreground transition.
3. **`ContentView.onChange(of: store.state.latestSensorGlucose)` — fires when the value changes.**

Path 3 is the one that should catch new readings. It looks correct:

```swift
.onChange(of: store.state.latestSensorGlucose) { _, _ in
    WidgetCenter.shared.reloadAllTimelines()
}
```

But **SwiftUI pauses body evaluation when the scene is backgrounded**. `.onChange` is implemented as a side-effect triggered during view updates — if the view isn't being re-evaluated, the comparison never runs and the handler never fires. New readings silently fail to reload the widget.

Paths 1 and 2 cover foreground transitions only. When the app sits in the background for 30 minutes receiving readings, nothing wakes WidgetKit.

## The pattern

**SwiftUI lifecycle modifiers — `.onChange`, `.onReceive`, `.task`, `.onAppear`, `.onDisappear` — are tied to view-tree evaluation.** When the scene is backgrounded, view evaluation pauses. Handlers that need to fire regardless of foreground/background state must live somewhere that keeps running:

| Surface | Runs while backgrounded? | Use for |
|---|---|---|
| `@main`/`ScenePhase` handlers in the view layer | No (evaluated only while scene active) | UI-facing side effects |
| SwiftUI `.onChange` / `.onReceive` / `.task` | No | UI-facing side effects |
| Redux middleware (actions dispatched from BLE/NFC/URLSession callbacks) | **Yes** | Persistence, widget reloads, notifications, HK writes |
| `AppDelegate` / `UIApplicationDelegate` lifecycle hooks | Yes (app-level, not scene-level) | Cross-scene work |
| Background tasks registered via `BGTaskScheduler` | Yes | Longer work windows |

The rule: **if the work must happen whenever a given Redux action fires, put it in the middleware for that action, not in a `.onChange` in the view that observes the action's state mutation.**

## The fix we applied (DMNC — build 67, 2026-04-24)

Added the reload to the middleware, not the view:

```swift
// App/Modules/WidgetCenter/WidgetCenter.swift
case .addSensorGlucose(glucoseValues: _):
    // Home-screen widget reload. Critical that this fires from the
    // middleware (not the view layer) because SwiftUI .onChange
    // handlers don't run when the app is backgrounded.
    WidgetCenter.shared.reloadAllTimelines()

    guard state.glucoseLiveActivity else {
        break
    }
    // ... Live Activity handling follows ...
```

Middleware dispatch runs synchronously on the reducer thread regardless of scene state. The moment `.addSensorGlucose` is dispatched (from the BLE callback in `SensorConnector`), the widget reload is requested.

The existing `ContentView.onChange(of: latestSensorGlucose)` is left in place as a belt-and-suspenders foreground path. Redundant but harmless.

## Verification checklist when editing widget/LA/HK code

For anything that must keep working while the app's scene is not active, answer these:

1. **Where is the trigger?** Is it a Redux action dispatched from a middleware callback (safe), a Combine publisher in the view (unsafe), or a SwiftUI lifecycle modifier (unsafe)?
2. **Does the app actually run in the background in our case?** BLE callbacks keep the process alive for sensor reads. `BGTaskScheduler` tasks get a windowed budget. Push-driven wake-ups run briefly. Fully suspended or terminated apps run none of the above — scheduled widget ticks and push notifications are the only paths.
3. **Is the write to shared state synchronous or async?** `AppState.didSet` writes are synchronous and complete before middlewares fire. Anything pushed to a background `DispatchQueue` may not have landed by the time WidgetKit re-fetches. Order the middleware pipeline so the reload is dispatched *after* the data has been persisted.

## Where this could still bite

Quick audit targets in DOSBTS if more widget / Live Activity / HK symptoms appear:

- **Live Activity updates** — today handled in the same middleware's `.addSensorGlucose` branch, so the pattern is correct.
- **Apple HealthKit export** — `AppleExport` middleware handles writes on `.addSensorGlucose`. Matches the pattern.
- **Nightscout upload** — `NightscoutUpload` middleware. Matches.
- **App Group writes from `AppGroupSharing`** — synchronous for `sharedGlucose` JSON; async for sparkline/TIR/IOB. Widget reloads from the middleware fire AFTER the middleware pipeline runs `AppGroupSharing`, so the sync writes are guaranteed landed. The async ones may lag by ≤ one reading, which is acceptable for non-critical widget chrome.
- **Anything new that dispatches work off a `store.state` change via `.onChange`** — move it to a middleware unless it's truly foreground-only (animations, focus management, etc.).

## Related

- `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md` — the other side of the lifecycle coin: don't run middleware side-effects while app is `.inactive`, but do run them on `.active`.
- CLAUDE.md § *Architecture gotchas* — existing note on reducer running before middlewares explains why synchronous `AppState.didSet` writes are visible to subsequent middlewares in the pipeline.
