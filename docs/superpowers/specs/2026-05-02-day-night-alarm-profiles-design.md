# Day/Night Alarm Profiles — Design

**Linear:** [DMNC-692](https://linear.app/lizomorf/issue/DMNC-692/daynight-alarm-profiles-separate-thresholds-and-sounds-by-time)
**Status:** Brainstorm complete; ready for planning
**Owner:** dosmi
**Date:** 2026-05-02

## Goal

Two alarm profiles (Day, Night) with separate glucose **thresholds** and alarm **volume**, switched on a fixed user-configured time window. Solves the "nighttime alarm fatigue" pain point — the #1 reason T1Ds disable CGM alerts entirely — without changing day-time behavior for users who do not opt in.

**Sounds are intentionally NOT per-profile**, despite the original Linear ticket title ("Separate alarm thresholds and sounds by time"). Rationale: sounds are *identity* — the user should recognize "this is my glucose alert" without learning two sound vocabularies. Volume + threshold differences carry the sleep-friendly delta. If user testing shows sounds-per-profile is genuinely wanted, it can be added without disturbing the v1 model.

## Non-goals (deferred)

- HealthKit Sleep Schedule integration
- More than two profiles
- Per-profile sounds, predictive-low toggle, treatment-recheck wait, or ignore-mute
- A master enable/disable toggle for the night profile
- Pre-populated "night = day + delta" suggestions
- Tap-glyph-to-Settings navigation from the active-profile indicator

These are revisitable after v1 ships and we have user feedback. None of them are necessary to solve the stated pain point.

## Design decisions

### Sleep window source

**Fixed user-set times.** Two `DatePicker(.hourAndMinute)` controls in Settings: night start (default 22:00) and night end (default 07:00). The boundary is a daily repeating clock check — no permissions, no async, no platform dependency. Same boundary every night.

Rejected alternative: HealthKit Sleep Schedule. Adds dependency surface (read permission, async fetch, fallback path) for a feature whose stated benefit is "stop being woken up unnecessarily" — solvable without HealthKit. Revisit if users specifically ask for time-of-week adaptation.

### Profile granularity

**Two profiles: Day and Night.** Matches the stated pain point exactly. The system is in either "give me everything" or "only wake me for serious" mode — a one-bit problem, not a multi-block scheduling problem.

Rejected alternatives: three profiles (day/evening/night) and arbitrary blocks. Both add settings UI complexity without evidence the day/night cliff-edge bothers users.

### Per-profile fields

Per profile: `alarmHigh`, `alarmLow`, `alarmVolume`. That is all.

Global (unchanged): low/high/connection/expiring sound pickers, predictive-low alarm toggle, treatment-recheck wait minutes, ignore-mute toggle.

Rejected alternatives: per-profile sounds (sounds are *identity* — you want to recognize "this is my glucose alert," not learn two sound vocabularies), per-profile predictive-low toggle and recheck wait (premature flexibility — turn them off entirely if they're noisy, don't make them time-of-day).

### Critical-low safety floor across profiles

The existing critical-low breakthrough — `glucoseValue < (alarmLow - 15)` overrides treatment-cycle snooze — **tracks the active profile's `alarmLow`**. So if the user raises night low to 75 (typical, more conservative at night), the night breakthrough threshold becomes 60 (more protective). If the user lowers night low below day low (atypical, more permissive), the breakthrough threshold falls with it.

The Settings UI shows an inline warning row under the night `alarmLow` control whenever `nightAlarmLow < dayAlarmLow`:

> Lows will need to drop {nightAlarmLow − dayAlarmLow} mg/dL further before alarming at night. Less margin to react if you're asleep.

A symmetric warning row appears under the night `alarmHigh` control whenever `nightAlarmHigh > dayAlarmHigh`:

> Highs will need to rise {nightAlarmHigh − dayAlarmHigh} mg/dL further before alarming at night.

The warnings name the safety consequence directly (less margin / later alarm) rather than describing the configuration ("alarms will fire less often") — a configuration description reads as feature confirmation to a user who deliberately set the looser threshold, defeating the purpose. Trust the user, but never let them slip into a less-safe configuration silently.

Rejected alternative: `min(dayAlarmLow, nightAlarmLow) - 15` anchoring. Defensible, but means a user who deliberately wants a lower night threshold cannot actually get one — feels paternalistic for a self-tracking app.

### Boundary-crossing behavior

**Active profile always wins. No pinning.** Every alarm evaluation reads the currently-active profile's thresholds and volume. This applies to:

- Snooze: `alarmSnoozeUntil` remains pure time-based, but the threshold against which "is this above/below alarm?" is evaluated follows the active profile.
- Treatment cycle: cycles started under day rules use night rules during a night recheck. Cycles are short (15–45 min); the threshold flip mid-cycle is a one-direction safety upgrade *only when night thresholds are more conservative than day* (the typical case). The inverse configuration (`nightAlarmLow < dayAlarmLow` or `nightAlarmHigh > dayAlarmHigh`) produces a one-direction safety **downgrade** mid-cycle — the recheck silently passes a value that would have re-alarmed under day rules. This is the same warning-row case from the Critical-low safety floor section, surfaced here because it has implications beyond initial threshold setup.
- Predictive low: same — uses active profile's `alarmLow` for the prediction boundary.

**Implementation note — `setAlarmSnoozeUntil` reducer:** the reducer captures `state.isAlarm(glucoseValue:)` into `state.alarmSnoozeKind` at reducer time. With computed-overlay thresholds, evaluating at 21:59:59 vs. 22:00:01 returns different alarm kinds. The system survives this because `isSnoozed(alarm:)` treats nil-kind permissively (matches any), but the cross-boundary semantic is subtle — implementers should not depend on `alarmSnoozeKind` being deterministic across a profile flip.

Rejected alternative: pin the cycle to its starting profile. Adds state machinery for a rare timing edge case; the user can always read the actual glucose number on screen and reason about it.

### Migration

On first launch after the update:

1. Copy current `alarmHigh` → both `dayAlarmHigh` and `nightAlarmHigh`
2. Copy current `alarmLow` → both `dayAlarmLow` and `nightAlarmLow`
3. Copy current `alarmVolume` → both `dayAlarmVolume` and `nightAlarmVolume`
4. Default `nightStartTime = 22:00`, `nightEndTime = 07:00`

**Migration trigger condition (idempotent):**

```swift
let needsMigration = UserDefaults.standard.object(forKey: "dayAlarmHigh") == nil
                  && UserDefaults.standard.object(forKey: "alarmHigh") != nil
```

Use `object(forKey:)` rather than the typed accessor because `UserDefaults.standard.alarmHigh` returns the literal default (180) when the key is absent — indistinguishable from "user hasn't set anything yet" vs. "key was deleted." The `object(forKey:) != nil` check distinguishes presence from default. Migration runs once per install (the day-key check guards against re-running) and never on a fresh install (the legacy-key check guards against migrating empty defaults).

Behavior is identical until the user explicitly opens AlarmSettingsView and changes a Night field. No master enable/disable toggle — the feature is "free" if you do not tweak it.

### Settings UI

Three new sections inserted into `AlarmSettingsView` *before* the existing global section:

1. **Day profile** — `NumberSelectorView` for high + low, `Slider` for volume.
2. **Night profile** — same three controls. Inline warning rows appear when `nightAlarmLow < dayAlarmLow` and/or when `nightAlarmHigh > dayAlarmHigh` (see Critical-low safety floor for copy).
3. **Sleep schedule** — two `DatePicker(.hourAndMinute)` controls (night start, night end). When `nightStartTime == nightEndTime`, the section appends an inline label below the pickers: *"Night profile inactive — start and end times are equal."* This makes the degenerate (always-day) configuration visible rather than silently inert.

The existing low/high `NumberSelectorView` controls **move** from `GlucoseSettingsView` into the Day profile section. `GlucoseSettingsView` keeps the unit selector and any non-alarm threshold controls. Rationale: keeps all alarm config in one place, eliminates the day-fields-split-across-two-screens awkwardness. The migration noise is one-time (users who knew the old location will find them under Settings → Alarms instead).

Existing global section retains its sound pickers, predictive-low toggle, treatment-recheck wait, and ignore-mute toggle. The existing single `alarmVolume` slider is **removed** — volume is now per-profile.

**`NumberSelectorView` constraints (clamping rules):** Each profile clamps intra-profile only — night-high is bounded by night-low (`min: nightAlarmLow`), night-low is bounded by night-high (`max: nightAlarmHigh`). Cross-profile inversion (e.g., `nightAlarmLow < dayAlarmLow`) is **not** hard-clamped — it surfaces as the warning row described in the Critical-low safety floor section. This preserves user agency for atypical configurations while making the safety implication visible.

Layout rationale: both profiles always visible (vertically stacked) makes "is my night high higher than my day high?" a one-glance check, which matters for the safety-warning logic. Matches the existing `Section { Picker; Picker; Slider; Toggle }` pattern in the codebase — no new SwiftUI patterns to invent.

Rejected alternatives: segmented Day/Night switcher (loses at-a-glance comparison), side-by-side columns (awkward on smaller widths, unusual for this app), push-to-dedicated-screen (adds nav friction, hides the feature).

### Active-profile indicator

When `state.activeAlarmProfile == .night`, render a small moon glyph (`Image(systemName: "moon.fill")`, `AmberTheme.amberDark`) **leading the connection-status row** in `SensorLineView` (positioned before the green/red status dot). Day mode renders nothing in that slot.

**Accessibility:** the glyph carries `.accessibilityLabel("Night profile active")`. `SensorLineView` already uses `.accessibilityElement(children: .combine)` on the row, so the combined VoiceOver label generator (`accessibilityLabelString` switch on `currentState`) must be extended to prepend "Night profile active. " to its output whenever `state.activeAlarmProfile == .night`. Without this, VoiceOver users hear "Sensor connected, 4d remaining" with no night-mode signal — defeating the indicator's whole purpose.

Rationale: day is the implicit default — no need to tell the user "it is day right now." Night is the *exception* state where alarms behave differently, so signalling it earns its pixels. This closes the silent-but-correct → "is it broken?" feedback loop when an out-of-day-range reading does not alarm at night.

Rejected alternatives: no indicator at all (breaks the feedback loop), always-on sun/moon icon (permanent visual chrome for a default state).

## State model

New properties in `DirectState`:

```swift
var dayAlarmHigh: Int { get set }
var dayAlarmLow: Int { get set }
var dayAlarmVolume: Float { get set }

var nightAlarmHigh: Int { get set }
var nightAlarmLow: Int { get set }
var nightAlarmVolume: Float { get set }

// Schedule storage is two Int pairs (not DateComponents) to keep
// UserDefaults round-trip trivial and locale-independent.
var nightStartHour: Int { get set }
var nightStartMinute: Int { get set }
var nightEndHour: Int { get set }
var nightEndMinute: Int { get set }
```

The existing `alarmHigh: Int`, `alarmLow: Int`, `alarmVolume: Float` properties become **computed** on `DirectState`:

```swift
extension DirectState {
    var activeAlarmProfile: AlarmProfile {
        // returns .night if Date() is within [nightStart, nightEnd), else .day
        // start/end built from the two Int pairs via Calendar.current
        // handles midnight wrap (e.g. 22:00 → 07:00)
        // when nightStartHour:Minute == nightEndHour:Minute, returns .day always
    }

    var alarmHigh: Int {
        activeAlarmProfile == .night ? nightAlarmHigh : dayAlarmHigh
    }
    var alarmLow: Int {
        activeAlarmProfile == .night ? nightAlarmLow : dayAlarmLow
    }
    var alarmVolume: Float {
        activeAlarmProfile == .night ? nightAlarmVolume : dayAlarmVolume
    }
}
```

This keeps every existing call site unchanged: `state.isAlarm(glucoseValue:)`, `state.isSnoozed(alarm:)`, `GlucoseNotification`, `BellmanAlarm`, the `AddInsulinView` warning, the chart's threshold lines — all read `state.alarmHigh` / `state.alarmLow` / `state.alarmVolume` and transparently get the active profile.

`AlarmProfile` is a small enum:

```swift
enum AlarmProfile {
    case day
    case night
}
```

Persisted via `UserDefaults` per the project's three-step pattern in `CLAUDE.md` (DirectState protocol declaration; AppState property + `didSet` + init from UserDefaults; UserDefaults `Keys` enum case + computed property; reducer case for the `set` action).

## Actions (DirectAction additions)

```swift
case setDayAlarmHigh(value: Int)
case setDayAlarmLow(value: Int)
case setDayAlarmVolume(volume: Float)

case setNightAlarmHigh(value: Int)
case setNightAlarmLow(value: Int)
case setNightAlarmVolume(volume: Float)

case setNightStartHour(value: Int)
case setNightStartMinute(value: Int)
case setNightEndHour(value: Int)
case setNightEndMinute(value: Int)
```

The existing `setAlarmHigh / setAlarmLow / setAlarmVolume` actions are **removed**. Settings UI now dispatches the per-profile variants directly.

## Bellman

No code change. `BellmanAlarm` reads `state.isAlarm(glucoseValue:)`, which transparently uses the active profile via the computed `alarmHigh` / `alarmLow`. Bellman does not read `alarmVolume` (separate physical device with its own volume), so per-profile volume does not apply.

## Tests (`DOSBTSTests`)

New test file `AlarmProfileTests.swift`:

- `activeAlarmProfile` returns `.day` mid-day (e.g. 14:00 with default schedule).
- `activeAlarmProfile` returns `.night` after night start (e.g. 22:30).
- `activeAlarmProfile` returns `.night` before night end (e.g. 06:30).
- `activeAlarmProfile` returns `.day` after night end (e.g. 07:30).
- Boundary at exact `nightStartTime`: returns `.night` (inclusive lower bound).
- Boundary at exact `nightEndTime`: returns `.day` (exclusive upper bound).
- Midnight wrap: schedule 21:00 → 06:00, evaluation at 23:00 returns `.night`; evaluation at 02:00 returns `.night`; evaluation at 06:00 returns `.day`.
- Same-time edge: `nightStartTime == nightEndTime` returns `.day` always (degenerate config — never night).

New test file `AlarmThresholdProfileTests.swift`:

- `state.isAlarm(glucoseValue:)` uses day high during day; uses night high during night (mock `Date()` via injectable clock or computed-property override).
- `state.isAlarm(glucoseValue:)` uses day low during day; uses night low during night.
- Critical-low breakthrough: glucose at `nightAlarmLow - 16` during night fires breakthrough; same value during day with higher day low does not.
- Snooze evaluation with `alarmSnoozeUntil` set during day, evaluation during night: snooze still respected (time-based), but threshold checked against night profile.

New test in `MigrationTests.swift` (or a new `AlarmProfileMigrationTests.swift`):

- First launch with legacy single-key UserDefaults populates day and night slots with the same values.
- Second launch reads the per-profile keys directly without re-migrating.
- Default night window is 22:00 → 07:00 when no schedule keys exist.

**Existing tests that will break (must be updated, not "continue to pass"):** `DirectReducerTests.swift:312-338` directly invokes `.setAlarmHigh(upperLimit:)` / `.setAlarmLow(lowerLimit:)` — these will fail to compile after the legacy actions are removed. Update each to dispatch the new per-profile actions and assert against the corresponding day or night property. Do not delete the assertions; rewrite them.

## Implementation skeleton (high level — full plan to follow)

1. Add `AlarmProfile` enum to `Library/Content/` (small enum, day/night, no logic).
2. Add the ten new `DirectState` properties (six per-profile + four schedule Int slots); remove direct storage of `alarmHigh / alarmLow / alarmVolume`; add computed-property overlay. **Resolve the `{ get set }` protocol mismatch** by either (a) demoting the three properties to `{ get }` in the protocol, (b) removing them from the protocol entirely, or (c) moving the overlay onto `AppState` directly — see Open Questions for the planning-pass decision; this is a hard prerequisite to compilation.
3. Add the ten new `DirectAction` cases; remove the three legacy actions (`setAlarmHigh`, `setAlarmLow`, `setAlarmVolume`); update `DirectReducer` accordingly.
4. **Update `SensorGlucoseStore` middleware** — its existing `case .setAlarmLow` and `case .setAlarmHigh` arms must be deleted or rewritten to handle the new per-profile actions. Currently overlooked.
5. **Update `DirectReducerTests.swift:312-338`** — rewrite the `.setAlarmHigh` / `.setAlarmLow` test cases to use the new per-profile actions; same for any `setAlarmVolume` usage.
6. Add UserDefaults `Keys` cases and computed properties (one Int per schedule slot); wire `AppState` `didSet` + init.
7. Migration logic in `AppState.init` — guard with the `object(forKey:)` predicate from the Migration section; copy legacy values into both day and night slots.
8. Update `AlarmSettingsView` — three new sections, drop the legacy volume slider, add the two symmetric warning rows, add the schedule pickers, add the degenerate-schedule inactive label.
9. Update `GlucoseSettingsView` — **remove** the existing low/high `NumberSelectorView` pair (they move to AlarmSettingsView Day section). Keep the unit selector and any non-alarm threshold controls.
10. Add the leading moon glyph to `SensorLineView`'s row, conditional on `state.activeAlarmProfile == .night`. Extend `accessibilityLabelString` to prepend "Night profile active. " when in night mode.
11. Tests as above (new `AlarmProfileTests.swift`, `AlarmThresholdProfileTests.swift`, `AlarmProfileMigrationTests.swift`).
12. CHANGELOG entry under `[Unreleased]`.

## Risks

- **Silent migration:** a bug in the migration could silently set night thresholds to defaults rather than copying day values, which would be a real safety regression. Migration must be tested against actual `UserDefaults` state, not just unit-tested in isolation.
- **Computed-property layer:** if any existing call site mutates `alarmHigh` / `alarmLow` / `alarmVolume` via the *setter* (rather than dispatching an action), the computed-property change will fail to compile. Audit must confirm only the action path mutates these (which is the project's stated convention but worth verifying).
- **Time-zone changes:** if the user's `TimeZone` changes (travel) mid-night-window, the boundary shifts. Acceptable for v1 — fixed-clock semantics — but worth flagging for the planning pass.

## Deferred / Open Questions

### From 2026-05-03 review

The following design decisions emerged from the multi-persona document review (`ce-doc-review`) on 2026-05-03 and require explicit resolution during the planning pass before implementation can begin. They are not implementation details — each one has multiple defensible answers with non-trivial tradeoffs.

#### Architecture / state model

- **P0 — Computed-property `{ get set }` protocol mismatch.** `DirectState` declares `alarmHigh / alarmLow / alarmVolume` as `{ get set }`. A get-only computed extension cannot satisfy a `{ get set }` protocol requirement, and a no-op setter silently drops writes. Pick one:
  - (a) Demote the three properties to `{ get }` in the `DirectState` protocol (cleanest type-safety; verifies no caller mutates via setter).
  - (b) Remove the three properties from the `DirectState` protocol entirely; the computed accessors live as plain extension methods (loses protocol-level abstraction over alarm thresholds).
  - (c) Move the overlay onto `AppState` directly (concrete type) and keep the protocol as-is (least disruption to existing protocol consumers but makes `DirectState`-typed call sites read stale stored values).
  - This is a hard prerequisite to anything else. **Implementation cannot proceed without resolving this.**

- **P2 — `alarmVolume` scope creep to non-glucose alarms.** With the computed overlay, `state.alarmVolume` shifts at night for *all* alarm classes — including the expiring-sensor alarm (`ExpiringNotification.swift:40`) and the debug alarm (`Debug.swift:20`). Pick one:
  - Constrain per-profile volume to glucose alarms only (introduce a `glucoseAlarmVolume` computed property; expiring/debug keep using a separate global volume).
  - Accept the bleed and document that all alarm-volume changes follow the active profile.

#### Cross-target / surface scope

- **P1 — Widget `UserDefaults.shared` sync strategy.** `Widgets/GlucoseWidget.swift:82-83` reads `alarmLow` / `alarmHigh` from the App Group suite. The proposed migration writes only to `UserDefaults.standard`. Pick one:
  - Mirror the active-profile values to `UserDefaults.shared` on every glucose-tick write (simple; widget stays unaware of profiles).
  - Push the per-profile keys + the schedule into `UserDefaults.shared` and recompute the active profile in the widget itself (keeps widget time-aware without app-side ticks).

- **P1 — Live Activity push on boundary.** `WidgetCenter.swift:228-232` bakes thresholds into `SensorGlucoseActivityAttributes.ContentState` at update time. After the 22:00 flip, the lock-screen Live Activity uses the day thresholds until the next sensor reading triggers an update (1–5 min lag). Pick one:
  - Schedule a boundary-time `Activity.update(...)` push.
  - Compute the active profile inside the Live Activity widget at render time (mirror the schedule into ContentState instead of resolved thresholds).
  - Accept the lag and document it.

- **P1 — Boundary wake / re-evaluation.** `GlucoseNotification` middleware only evaluates on `.addSensorGlucose`. There's no scheduled wake at the boundary. A user stable just below day-low and above night-low (different per profile) won't get a notification at the flip. Pick one:
  - Schedule a local `UNCalendarNotificationTrigger` at `nightStart` and `nightEnd` to force re-evaluation.
  - Use `BGAppRefreshTask` for boundary-aware background refresh.
  - Accept the up-to-5-min responsiveness floor as inherent to the sensor-driven evaluation cadence.

- **P1 — Active-profile indicator scope.** Spec puts the moon glyph in OverviewView only. The same "is it broken?" feedback loop applies to Live Activity, Lock Screen widget, Home Screen widget, and notification banners. Pick one:
  - Extend the indicator to all surfaces (Live Activity ContentState, widget views, notification subtitle suffix).
  - Keep OverviewView-only and accept that the surfaces users actually look at while in bed have no signal.

#### Settings / interaction

- **P1 — Sound picker preview volume.** All four sound pickers in `AlarmSettingsView` call `testSound(volume: state.alarmVolume)`. After refactor, `state.alarmVolume` is the active-by-clock volume, not the profile being edited. Pick one:
  - Always preview at active-profile volume (current behavior; simple but surprising).
  - Always preview at day volume (predictable but unusual at night).
  - Preview at `max(day, night)` (loud-side guarantee).
  - Remove the preview entirely.

- **P2 — Snooze cross-boundary suppression.** A snooze active across the day→night flip evaluates against the active profile's threshold but the snooze itself is time-based. A user who snoozed under day rules at 21:50 may end up suppressing a night-actionable alarm at 22:10. Pick one:
  - Clear or shorten an active snooze when the profile flips.
  - Accept the suppression window and document it.

#### Safety semantics

- **P1 — Mid-cycle critical-low breakthrough.** When a treatment cycle is in flight and the boundary flips, the breakthrough threshold (`activeAlarmLow - 15`) jumps. If night-low > day-low, this can fire a spurious breakthrough alarm during an in-progress cycle the user is already responding to. Pick one:
  - Pin the breakthrough threshold to the cycle's *triggering* profile for the duration of the cycle (cleanest; matches "no surprises mid-cycle" intuition).
  - Always evaluate against the active profile (current spec; risk of spurious mid-cycle alarms).
  - Lock both directions: pin the entire cycle (thresholds, breakthrough, recheck) to the triggering profile.

- **P1 — Mid-cycle safety downgrade when night-low < day-low.** Same boundary-flip case but inverse: a recheck under day rules would re-alarm; under night rules (more permissive) it passes silently. Symmetric concern to the breakthrough case above; same three resolution options apply.

- **P1 — Migration rollback safety.** TestFlight allows users to roll back to the pre-migration build. After rollback, the old binary reads only legacy keys; any change made on the new build went exclusively to per-profile keys. Pick one:
  - Dual-write to legacy keys on every per-profile set (writes both `dayAlarmHigh` and `alarmHigh` when day-high changes) — preserves rollback safety at the cost of duplicate writes.
  - Accept the rollback risk and document it in the build's TestFlight release notes.

- **P2 — 24h-night escape hatch.** A user who wants the conservative profile applied 24/7 has no way to express it. `nightStart == nightEnd` means always-day (degenerate), not always-night. Pick one:
  - Add a master "always conservative" toggle (small surface; explicit on/off).
  - Make `nightStart == nightEnd` mean always-night instead of always-day (loses the "feature is off" signal).
  - Stay opinionated and accept that always-night is not supported.
