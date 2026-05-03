---
title: "WidgetKit timelines pre-resolve at build time — schedule boundary entries for time-of-day-dependent rendering"
date: 2026-05-03
category: best-practices
module: Widgets
problem_type: best_practice
component: widgetkit-timeline
severity: medium
related_components:
  - Widgets/GlucoseWidget
  - Widgets/GlucoseActivityWidget
  - Library/Content/AlarmProfile
  - App/Modules/AppGroupSharing
applies_when:
  - Building a WidgetKit `TimelineProvider` whose UI depends on time-of-day state (day/night profiles, sleep mode, business hours, scheduled themes)
  - Reload window can span a state-change boundary (e.g. 15-minute timeline policy crossing a day/night switch)
  - A sibling Live Activity or SwiftUI surface reads the same time-dependent state and resolves it at render time, creating a behavioral asymmetry
  - Adding a new time-of-day-driven property and unsure whether to bake it into the timeline entry or resolve it in the view body
tags: [widgetkit, timeline, live-activity, time-of-day, boundary-scheduling, alarm-profiles, dmnc-692]
---

# WidgetKit timelines pre-resolve at build time — schedule boundary entries for time-of-day-dependent rendering

## Context

Day/night alarm profiles (DMNC-692) introduced two threshold sets and a configurable sleep schedule. The plan promised "render-time profile resolution" so every surface — app, Home Screen widget, Live Activity — would always show the active-profile thresholds, with no push churn at the boundary. Three render contexts consume the profile:

1. **App view bodies** — re-render on every state change, so render-time resolution is automatic.
2. **Live Activity** (`Widgets/GlucoseActivityWidget.swift`) — the view body calls `effectiveAlarmThresholds(at: Date())` and ActivityKit re-renders on every push update; render-time resolution is automatic here too.
3. **Home Screen widget** (`Widgets/GlucoseWidget.swift`) — `getTimeline` is called by WidgetKit *once*, then the widget renders pre-baked entries until the next reload (~15 minutes later).

Code review caught that the Home Screen widget silently violated the render-time guarantee. A single-entry timeline built at 06:50 with `nightEnd = 07:00` baked in the night profile and showed the moon glyph + night thresholds until the next reload around 07:05 — at best ~5 minutes past the schedule flip, often longer under battery/thermal pressure. Live Activity didn't have this problem because its view body resolves `Date()` at render time. The bug was specific to WidgetKit's timeline-provider model.

The original spec/plan considered (and rejected) a "boundary-wake middleware" that would force re-evaluation at the exact boundary via background notifications (session history: spec OQ#5). The chosen approach was render-time profile resolution — but that promise only holds true in app + Live Activity contexts. WidgetKit needs an extra step.

## Guidance

When a `TimelineProvider`'s rendering depends on a time-of-day boundary or any scheduled flip, emit an additional entry anchored *at the boundary* if it falls inside the next reload window. The widget view will re-render at the boundary moment without any extra plumbing.

Three pieces:

**1. A pure boundary-finder helper** (easy to unit-test). Returns the next flip time within a lookahead window, or `nil` if none:

```swift
// Library/Content/AlarmProfile.swift
func nextAlarmProfileBoundary(
    from date: Date,
    nightStartHour: Int,
    nightStartMinute: Int,
    nightEndHour: Int,
    nightEndMinute: Int,
    lookaheadSeconds: TimeInterval = 15 * 60
) -> Date? {
    // Clamp inputs, compute minutes-until-each-boundary, pick the sooner one,
    // return nil if degenerate (start == end) or boundary is past the lookahead.
}
```

**2. A timeline that emits both `now` and the boundary**, with a `.after` reload policy matching the lookahead:

```swift
// Widgets/GlucoseWidget.swift — GlucoseUpdateProvider.getTimeline
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    let now = Date()
    let reloadDate = now.addingTimeInterval(15 * 60)
    var entries = [buildEntry(at: now)]

    let defaults = UserDefaults.shared
    if defaults.object(forKey: AppGroupAlarmProfileKeys.nightStartHour) != nil {
        let boundary = nextAlarmProfileBoundary(
            from: now,
            nightStartHour:   defaults.integer(forKey: AppGroupAlarmProfileKeys.nightStartHour),
            nightStartMinute: defaults.integer(forKey: AppGroupAlarmProfileKeys.nightStartMinute),
            nightEndHour:     defaults.integer(forKey: AppGroupAlarmProfileKeys.nightEndHour),
            nightEndMinute:   defaults.integer(forKey: AppGroupAlarmProfileKeys.nightEndMinute),
            lookaheadSeconds: 15 * 60
        )
        if let boundary {
            entries.append(buildEntry(at: boundary))
        }
    }

    completion(Timeline(entries: entries, policy: .after(reloadDate)))
}
```

**3. Per-entry resolution at the entry's `date`**, not at "now". Both entries flow through the same `buildEntry(at:)` so resolution is uniform:

```swift
private func buildEntry(at date: Date = Date()) -> GlucoseEntry {
    let resolved = WidgetAlarmProfileSnapshot.resolve(at: date)
    return GlucoseEntry(
        date: date,
        // ...
        alarmLow: resolved?.alarmLow ?? defaults.alarmLow,
        alarmHigh: resolved?.alarmHigh ?? defaults.alarmHigh,
        activeAlarmProfile: resolved?.profile ?? .day,
        // ...
    )
}
```

Two invariants:

- **The boundary entry's profile is computed at the boundary timestamp**, not at provider build-time. Both entries flow through `buildEntry(at:)` with the entry's own date.
- **The lookahead matches the reload policy.** If you reload every 15 min, look ahead 15 min. Looking further is wasted work; looking shorter re-introduces the staleness gap.

## Why This Matters

The three render surfaces resolve `Date()` differently:

| Surface | When `Date()` resolves | Time-of-day correctness |
|---|---|---|
| App view body | Render time (every state change) | Automatic |
| Live Activity view body | Render time (re-rendered by ActivityKit) | Automatic |
| Widget timeline entry | **Build time** — when `getTimeline` runs | **Manual — provider must emit boundary entries** |

Without a boundary entry, the widget renders the *pre-boundary* profile data baked into the most recent timeline entry until the next reload tick. WidgetKit's reload budget is not a strict timer — `~15 min` is a target, and the system can defer reloads further under battery/thermal pressure. So "stale for up to 15 min" is the floor, not the ceiling.

This nuance was actively reasoned about in DMNC-692 planning (session history): the spec evaluated "force boundary re-evaluation via background notification" (OQ#5) and rejected it in favor of "compute at render time." That was the right architectural call for the app and Live Activity, but it accidentally papered over the Home Screen widget's actual render model. The multi-entry timeline is the smallest fix that lets the widget honor the same render-time promise the rest of the surfaces deliver.

The user-visible failure mode is high-trust UI showing the wrong state at exactly the moment trust matters most — e.g., a moon glyph and night thresholds during a daytime hypo. That undermines the clinical correctness the alarm-profile feature was built to deliver.

## When to Apply

Apply this pattern in any `TimelineProvider.getTimeline` whose entry rendering depends on:

- **Time-of-day boundaries** — day/night profiles, sleep mode, scheduled DND, school-hours / work-hours profiles.
- **Scheduled state flips** — a meeting that starts at 14:00, a sensor session that expires in 6 minutes, a countdown reaching zero.
- **Calendar boundaries** — daily TIR resets at midnight, weekly digest swaps on Monday 00:00.
- **Sunset/sunrise or other astronomical triggers** if the widget tints differ before/after.

Skip it when:

- Nothing in the entry depends on wall-clock time of day (e.g. a pure "latest glucose" widget with no profile gating).
- The flip happens far outside the reload window — the next regular reload will produce a fresh entry that's already correct.
- You're working on a Live Activity, a SwiftUI app view, or any view that re-renders on its own clock — those resolve at render time already.

## Examples

**Before — naïve single-entry timeline (silently stale across boundary):**

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    let entry = buildEntry()                                   // resolves profile at "now"
    let reload = Date().addingTimeInterval(15 * 60)
    completion(Timeline(entries: [entry], policy: .after(reload)))
}
```

If `now = 06:50` and `nightEnd = 07:00`, this entry locks in the night profile until the system reloads. Best case ~07:05; often later. The moon glyph and night thresholds linger ~5–15 minutes past sunrise.

**After — boundary-aware multi-entry timeline:**

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    let now = Date()
    let reloadDate = now.addingTimeInterval(15 * 60)
    var entries = [buildEntry(at: now)]

    if let boundary = nextAlarmProfileBoundary(from: now, /* schedule from App Group */
                                               lookaheadSeconds: 15 * 60) {
        entries.append(buildEntry(at: boundary))
    }

    completion(Timeline(entries: entries, policy: .after(reloadDate)))
}
```

At 06:50 with `nightEnd = 07:00`, the timeline now contains two entries: one for 06:50 (night profile) and one for 07:00 (day profile). WidgetKit advances to the second entry exactly at 07:00 and re-renders — the moon glyph disappears and day thresholds activate at the schedule boundary, not whenever the next reload tick happens to land.

**Counterpart on Live Activity (already correct, shown for contrast):**

```swift
// Widgets/GlucoseActivityWidget.swift
// View body calls Date() at render time; ActivityKit re-renders on every update.
// No timeline-provider machinery, no boundary entries needed.
let thresholds = effectiveAlarmThresholds(at: Date())
```

## Related

- `docs/solutions/logic-errors/swiftui-onchange-dormant-when-backgrounded-20260424.md` — the *trigger* side of this same family: how to schedule a widget reload from a Redux middleware so it fires while backgrounded. Complementary: that doc covers *when reloads fire*; this one covers *what entries the reloaded timeline contains*.
- `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md` — a different subsystem with the same shape (state-init/timing gap where a value resolved at the wrong moment causes silently-stale UI).
- `Widgets/GlucoseWidget.swift` — `GlucoseUpdateProvider.getTimeline`, `WidgetAlarmProfileSnapshot.resolve(at:)`
- `Library/Content/AlarmProfile.swift` — `nextAlarmProfileBoundary`, `resolveActiveProfileThresholds(at:intReader:)`, `resolveActiveAlarmProfile(at:...)`
- `Widgets/GlucoseActivityWidget.swift` — `GlucoseStatusContext.effectiveAlarmThresholds(at:)` (render-time resolution counterpart)
- `docs/plans/2026-05-03-001-feat-day-night-alarm-profiles-plan.md` — DMNC-692 plan
- `docs/superpowers/specs/2026-05-02-day-night-alarm-profiles-design.md` — DMNC-692 spec, including OQ#5 (boundary-wake middleware, dropped)
