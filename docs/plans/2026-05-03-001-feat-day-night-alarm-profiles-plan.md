---
title: "feat: Day/night alarm profiles"
type: feat
status: active
date: 2026-05-03
origin: docs/superpowers/specs/2026-05-02-day-night-alarm-profiles-design.md
---

# feat: Day/night alarm profiles

## Overview

Two alarm profiles (Day and Night) with separate glucose thresholds and alarm volume, switched on a fixed user-configured time window. Solves the nighttime alarm fatigue pain point — the #1 reason T1Ds disable CGM alerts entirely — without changing day-time behavior for users who do not opt in.

The architectural shift is small: three currently-stored properties on `DirectState` (`alarmHigh`, `alarmLow`, `alarmVolume`) become read-only computed accessors that switch by time of day, backed by six new stored per-profile properties + four new schedule properties. Migration copies legacy values into both day and night slots so observable behavior is unchanged until the user touches Night fields. The Live Activity and Home Screen widget receive the schedule and per-profile values via `UserDefaults.shared` and compute the active profile themselves so lock-screen surfaces stay in sync without app-side push churn — and they render the moon-glyph indicator at night so the user has a visible signal on the surfaces they actually see while sleeping.

This plan honors the spec's "active profile always wins, no pinning" principle for boundary-crossing behavior, and accepts the up-to-5-minute responsiveness floor at the boundary as inherent to the sensor-driven evaluation cadence (per the spec's offered alternative). Treatment-cycle behavior, snooze, predictive low, and critical-low breakthrough all read the active profile transparently via the computed accessors.

---

## Problem Frame

DOSBTS today has one 24/7 alarm profile. A user who wants quieter nights either disables CGM alerts entirely or accepts being woken by every 195 mg/dL reading at 03:00. Clinical guidance and T1D community feedback consistently identify nighttime alarm fatigue as the dominant reason for CGM alert disablement — and disabling alerts entirely is the worst possible safety outcome.

The motivation, design space, and decisions are documented in the origin spec. This plan turns the spec into a sequenced implementation, having resolved the spec's 12 deferred Open Questions in collaboration with the user via doc-review (see the spec's "Deferred / Open Questions — From 2026-05-03 review" section for the original questions).

---

## Requirements Trace

- R1. User can set a different `alarmHigh` for night versus day (see origin: spec § Per-profile fields)
- R2. User can set a different `alarmLow` for night versus day (see origin: spec § Per-profile fields)
- R3. User can set a different `alarmVolume` for night versus day (see origin: spec § Per-profile fields)
- R4. User can configure the night-window start and end times (see origin: spec § Sleep window source)
- R5. Migration on first post-update launch leaves observable behavior unchanged (see origin: spec § Migration)
- R6. Critical-low safety floor (`alarmLow - 15`) tracks the *active* profile (no cycle pinning — honors spec § Boundary-crossing behavior)
- R7. Settings UI shows symmetric warning rows when night thresholds are more permissive than day in either direction (low or high)
- R8. Active-profile indicator (moon glyph) renders in `SensorLineView`, in `GlucoseActivityWidget` (Live Activity), and in `GlucoseWidget` (Home Screen + Lock Screen widgets) when the night profile is active. VoiceOver announces "Night profile active" on `SensorLineView`.
- R9. `GlucoseWidget` and `GlucoseActivityWidget` evaluate alarms against the active profile's thresholds at render time (not at glucose-update push time). The schedule and both profile threshold sets flow through `UserDefaults.shared` (widget) and `SensorGlucoseActivityAttributes.ContentState` (Live Activity).
- R10. `DirectState` protocol-level access to `alarmHigh / alarmLow / alarmVolume` is read-only (`{ get }`); mutation flows through per-profile actions only.
- R11. Existing `setAlarmHigh / setAlarmLow / setAlarmVolume` action call sites are updated to compile under the new model. Known call sites: `DirectReducerTests.swift:312-338` (action mutation tests), `DirectReducerTests.swift:326-346` (`isAlarmLow`/`isAlarmHigh`/`isAlarmNone` test cases), `SensorGlucoseStore` middleware match arms, `AlarmSettingsView.swift:85` volume-slider Binding, `GlucoseSettingsView.swift:24,28` low/high `NumberSelectorView` Bindings (these are removed entirely as the controls move to AlarmSettingsView per U6). Implementer should run a final grep for `setAlarmHigh`, `setAlarmLow`, `setAlarmVolume` after the action removal to catch any stragglers.

---

## Scope Boundaries

- HealthKit Sleep Schedule integration — fixed times only for v1
- More than two profiles — Day and Night only
- Per-profile sounds, predictive-low toggle, treatment-recheck wait, ignore-mute — all stay global
- Full per-profile volume scope split for non-glucose alarms — only the *debug* alarm follows the active profile (accepted bleed); the *expiring-sensor* alarm reads `max(dayAlarmVolume, nightAlarmVolume)` so a silent night setting cannot suppress a sensor end-of-life warning overnight. No `globalAlarmVolume` state property; the floor is computed inline at the call site.
- Master enable/disable toggle for the night profile — feature is "free" if you do not tweak it
- Pre-populated "night = day + delta" suggestions — defaults match day exactly on first launch
- Tap-glyph-to-Settings navigation from the active-profile indicator — read-only signal in v1
- 24h-night escape hatch (always-conservative mode) — accepted limitation; user must use a wide schedule like 00:01 → 23:59 if they want near-24h conservative coverage
- Treatment-cycle profile pinning — dropped per honor of the spec's "active profile always wins, no pinning" decision. Symmetric warning rows discourage atypical cross-profile configs that would create the failure mode pinning was meant to address.
- Boundary-wake middleware (forced re-evaluation at the exact boundary) — dropped. The spec offered "accept the up-to-5-min responsiveness floor as inherent to sensor-driven evaluation" as a valid resolution; this plan takes that path. Lock-screen surfaces stay correct via render-time profile resolution; the in-app alarm path catches up at the next sensor reading.
- Notification banner profile context (e.g., `[Night]` prefix on alarm titles) — deferred. The lock-screen widget + Live Activity moon glyph in v1 close the visual trust loop. If notification-banner context proves needed in practice, follow-up issue.
- Onboarding nudge / first-run prompt to set night thresholds — deferred. Settings → Alarms shows both profiles always; the user discovers the feature when they next visit alarm settings. Real adoption signal will tell us whether a nudge is worth adding.

---

## Context & Research

### Relevant Code and Patterns

- `Library/DirectState.swift:16-20` — current `alarmHigh / alarmLow / alarmSnoozeUntil / alarmSnoozeKind / alarmVolume` properties on the protocol
- `App/AppState.swift:88,149,228-232` — `AppState` stored properties with `didSet` UserDefaults persistence and init-from-UserDefaults
- `Library/Extensions/UserDefaults.swift` — `Keys` enum + per-property computed accessors (3-step pattern from `CLAUDE.md`)
- `Library/DirectAction.swift:177-184` — existing alarm-related actions
- `Library/DirectReducer.swift` — pure mutations
- `App/Modules/GlucoseNotification/GlucoseNotification.swift:107-149` — alarm middleware reads `state.alarmHigh / alarmLow / alarmVolume` and the critical-low breakthrough at `state.alarmLow - 15` (line 116). All transparently inherit per-profile via the computed accessors.
- `App/Modules/BellmanAlarm/BellmanAlarm.swift:43` — uses `state.isAlarm(glucoseValue:)` only; transparently inherits per-profile via the computed overlay
- `App/Modules/TreatmentCycle/` — owns `treatmentCycleActive`, `treatmentCycleSnoozeUntil`, `alarmFiredAt`. Active profile wins everywhere; no pinning state added.
- `App/Modules/AppGroupSharing/` — middleware that writes shared values to `UserDefaults.shared` on each glucose update (see `CLAUDE.md` § Widget shared data via App Group). Important: this middleware does NOT currently write `alarmLow` or `alarmHigh` — the widget today reads `UserDefaults.shared.alarmLow / .alarmHigh` and falls through to hardcoded defaults (80/180). This plan establishes the threshold-write path for the first time, also closing a latent widget-rendering bug.
- `App/Modules/WidgetCenter/WidgetCenter.swift` — Live Activity start/update/end paths and `SensorGlucoseActivityAttributes.ContentState`
- `App/Views/Settings/AlarmSettingsView.swift` — current sound pickers, volume slider, ignoreMute toggle, predictive-low toggle, treatment-recheck wait. **Body returns a single `Section`, not a `Form` or `Group`** — adding multiple sibling sections requires restructuring the body to a `Group { Section { ... }; Section { ... }; ... }` since the parent `SettingsView` consumes Sections directly inside its `List`.
- `App/Views/Settings/GlucoseSettingsView.swift:23-27` — current `NumberSelectorView` for `alarmHigh / alarmLow` (these move into `AlarmSettingsView` Day section)
- `App/Views/Overview/SensorLineView.swift` — connection-status row using `accessibilityElement(children: .combine)` and a `currentState`-switched `accessibilityLabelString`. The existing dot circle uses `.accessibilityHidden(true)` (line 60) — the moon glyph follows the same pattern.
- `Widgets/GlucoseWidget.swift:82-83` — reads `UserDefaults.shared.alarmLow / .alarmHigh` directly from the App Group suite
- `Widgets/GlucoseActivityWidget.swift:83` — Live Activity threshold evaluation against `ContentState`
- `App/Modules/SensorGlucoseStore/SensorGlucoseStore.swift:20-25` — has `case .setAlarmLow` / `case .setAlarmHigh` middleware match arms that trigger statistics recompute. Statistics are threshold-relative (TIR/TBR/TAR depend on the alarm thresholds), so all four `.setDay*Alarm{High,Low}` and `.setNight*Alarm{High,Low}` actions must trigger recompute.
- `Library/Content/SparklineBuilder.swift` — pattern for cross-target shared logic types in `Library/Content/`. New profile-resolution helper follows this convention.
- `DOSBTSTests/IOBCalculatorTests.swift` — pattern for new `AlarmProfileTests`, `AlarmThresholdProfileTests`, `AlarmProfileMigrationTests` (Swift Testing framework — `@Test`, `#expect`)
- `DOSBTSTests/DirectReducerTests.swift:312-338` — existing `setAlarmHigh / setAlarmLow` test cases that must be rewritten

### Institutional Learnings

- `CLAUDE.md` § Adding New State Properties — the canonical 4-file UserDefaults pattern (DirectState protocol, AppState property + didSet + init, UserDefaults Keys enum + computed property, DirectReducer case)
- `CLAUDE.md` § Live Activity data flows through ContentState — never read `UserDefaults.shared` directly in Live Activity views; everything must pass through `SensorGlucoseActivityAttributes.ContentState`. This plan modifies the constraint slightly: ContentState now carries the *schedule* and *per-profile thresholds*, not the resolved active threshold, and the Live Activity widget computes the active profile at render time. The constraint's spirit (no `UserDefaults.shared` reads from Live Activity views) is preserved.
- `CLAUDE.md` § Widget shared data via App Group — `AppGroupSharing` writes shared values on each glucose update. Widget views can read `UserDefaults.shared` directly (unlike Live Activity).

### External References

None — this is purely internal Swift work using established repo patterns.

---

## Key Technical Decisions

- **Computed-overlay protocol shape:** `DirectState.alarmHigh / alarmLow / alarmVolume` demote to `{ get }` only. Rationale: project's stated convention is action-dispatch mutation only; demoting catches any rogue setter at compile time. Resolves spec OQ#1.
- **Schedule storage:** four `Int` UserDefaults keys (`nightStartHour`, `nightStartMinute`, `nightEndHour`, `nightEndMinute`). Trivial round-trip, locale-independent. `DateComponents` is view-only at the picker layer. Resolves spec OQ#1 (DateComponents persistence).
- **Composite schedule actions:** Settings-side schedule edits dispatch `setNightScheduleStart(hour: Int, minute: Int)` and `setNightScheduleEnd(hour: Int, minute: Int)` rather than four separate hour/minute actions. Reducer mutates both stored Int properties atomically; AppGroupSharing pushes once per change. Avoids the half-updated-state window from two serial dispatches.
- **`alarmVolume` scope:** accepted bleed for the *debug* alarm only — debug alarms read `state.alarmVolume` (now computed) and follow the active profile's volume. The *expiring-sensor* alarm uses `max(state.dayAlarmVolume, state.nightAlarmVolume)` instead, so a user who silences night glucose alarms (`nightAlarmVolume = 0`) still hears sensor end-of-life warnings overnight — missing an overnight sensor failure is a real safety regression we're not willing to ship. Resolves spec OQ#2 with a hybrid: simpler than reintroducing `globalAlarmVolume`, safer than full bleed.
- **Widget profile resolution:** `AppGroupSharing` middleware writes the schedule + both day and night thresholds to `UserDefaults.shared` on every glucose update **and** on every per-profile setter action (so settings changes appear in the widget without waiting for the next 5-min sensor tick). The widget computes the active profile at render time from the shared values. Resolves spec OQ#3.
- **Live Activity profile resolution:** `SensorGlucoseActivityAttributes.ContentState` carries the schedule + both day and night thresholds. The Live Activity widget evaluates alarms at render time. The new ContentState fields are **optional** with sensible defaults so in-flight activities at upgrade time don't break Codable decode (additive migration, not breaking). Resolves spec OQ#4.
- **Boundary wake / re-evaluation:** dropped. Accept the up-to-5-min sensor-driven evaluation cadence at the boundary. Lock-screen surfaces (widget + Live Activity) stay correct via render-time resolution, so the user-visible truth doesn't lag; the in-app alarm dispatch path catches up at the next sensor reading. Resolves spec OQ#5 with the simpler alternative.
- **Active-profile indicator scope:** OverviewView (`SensorLineView`), Home Screen widget (`GlucoseWidget`), Lock Screen widget, and Live Activity (`GlucoseActivityWidget`) all render the moon glyph when night profile is active. Notification banners deferred. Resolves spec OQ#6 with extended scope (per doc-review pass — the lock-screen surfaces are exactly where the trust loop matters most at night).
- **Sound preview volume:** use `dayAlarmVolume` for all global sound picker previews. Day is the implicit default; previewing at day volume is intuitive. Footer label: "Previews play at day volume." Resolves spec OQ#7.
- **Snooze cross-boundary:** accept the suppression window as-documented. Adding "clear snooze on flip" is complexity for a narrow timing edge case. Documented in implementation notes. Resolves spec OQ#8.
- **Treatment-cycle threshold pinning:** **none.** Honor the spec's "active profile always wins, no pinning" — read the active profile's thresholds at every evaluation including treatment-cycle recheck and critical-low breakthrough. The doc-review surfaced a P1 mid-cycle false-breakthrough scenario; the symmetric warning rows in Settings (R7) discourage the atypical configs that would create it. Resolves spec OQ#9 and OQ#10 by accepting the simpler model.
- **Migration rollback safety:** **dual-write only for day setters.** When `setDayAlarmHigh(value:)` fires, AppState writes both `dayAlarmHigh` and the legacy `alarmHigh` UserDefaults key. Old binaries reading legacy keys see day values. Night-side changes are NOT mirrored — a user who configures night thresholds and then rolls back gets day behavior on the rolled-back binary. This is acceptable: rollback recovers to the user's day configuration (safer than the night configuration), not to a stale pre-migration default. **Migration trigger condition is `dayAlarmHigh == nil` only** (not `&& alarmHigh != nil`); the `alarmHigh != nil` half would always be true after dual-write or fresh-install dual-write. Resolves spec OQ#11 with the asymmetry explicitly acknowledged.
- **24h-night escape hatch:** none. Stay opinionated. Always-night requires a wide schedule like 00:01 → 23:59. Resolves spec OQ#12.
- **`AlarmSettingsView` body restructure:** the existing single-`Section` body becomes a `Group { Section; Section; Section; Section }` to host the new Day/Night/Sleep-schedule sections plus the existing global section. Required because `SettingsView` consumes `Section`s directly inside its `List`.

---

## Open Questions

### Resolved During Planning

All 12 spec Open Questions resolved above in **Key Technical Decisions**, in collaboration with the user via doc-review. Summary:

| OQ | Resolution |
|----|------------|
| #1 Computed-property `{ get set }` mismatch | Demote protocol to `{ get }` |
| #2 `alarmVolume` scope creep | Accept the bleed (no `globalAlarmVolume`) |
| #3 Widget shared sync | Write schedule + both profile thresholds to `UserDefaults.shared`; widget resolves at render time |
| #4 Live Activity push on boundary | ContentState carries schedule + both profile thresholds; widget resolves at render time |
| #5 Boundary wake / re-evaluation | Drop boundary wake; accept the 5-min floor |
| #6 Indicator scope | Extend to Live Activity + widgets in v1 |
| #7 Sound preview volume | Day volume always |
| #8 Snooze cross-boundary | Accept suppression window |
| #9 Mid-cycle critical-low breakthrough | No pinning; active profile wins (with Settings warning rows as the user-facing safeguard) |
| #10 Mid-cycle safety downgrade | Same — no pinning |
| #11 Migration rollback safety | Dual-write day setters only; document the asymmetry |
| #12 24h-night escape hatch | Stay opinionated; not supported |

### Deferred to Implementation

- **Exact `Group { Section; ... }` restructure of `AlarmSettingsView`:** the cleanest way to host four sibling sections depends on how `SettingsView`'s parent `List` consumes the body. Resolve by trying the simplest `Group` wrapper first; fall back to a `ForEach` over a section enum if needed.
- **`SensorGlucoseStore` statistics-recompute trigger surface:** the middleware must trigger on all four `setDay*Alarm{High,Low}` AND `setNight*Alarm{High,Low}` actions because statistics are threshold-relative and the active threshold can flip at the boundary. Confirm the trigger pattern during implementation by reading the existing match arms and replicating them four times (or factoring into a helper).
- **Symmetric warning row exact wording:** the spec defines the *intent*; final text may need tuning for column width. Adjust during U6.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
                                  ┌─────────────────────────┐
                                  │ User edits Night fields │
                                  │ in AlarmSettingsView    │
                                  └────────────┬────────────┘
                                               │ dispatch .setNightAlarmLow(...)
                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         DirectStore.dispatch()                          │
│  reducer mutates dayAlarmLow/nightAlarmLow/etc. (stored)                │
│  AppState didSet writes per-profile UserDefaults key                    │
│   + (Day setters only) writes legacy key for rollback safety            │
│  middlewares receive (state, action)                                    │
└────────┬────────────────────────────────┬───────────────────────────────┘
         │                                │
         ▼                                ▼
┌─────────────────────────────┐    ┌────────────────────────────────────┐
│ AppGroupSharing             │    │ GlucoseNotification (no change)    │
│ writes schedule + both      │    │ reads state.alarmLow (computed →   │
│ profile thresholds to       │    │ active). Critical-low: active      │
│ .shared on glucose tick     │    │ profile's alarmLow - 15.           │
│ AND on each per-profile     │    │                                    │
│ setter action               │    │ SensorGlucoseStore middleware      │
│                             │    │ recomputes statistics on all four  │
│                             │    │ Day/Night threshold setters.       │
└────────┬────────────────────┘    └────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Widget reads .shared, computes activeProfile at render time.        │
│ Renders moon glyph chrome when night profile is active.             │
│                                                                     │
│ Live Activity ContentState carries schedule + both profile          │
│ thresholds (additive optional fields for backward-compat).          │
│ Widget computes active at render via Date(). Renders moon glyph.    │
└─────────────────────────────────────────────────────────────────────┘
```

The `state.activeAlarmProfile` computed property is the single source of truth in the app process. Widget and Live Activity duplicate the *resolution algorithm* (not the data) so they stay in sync without push churn. Three render contexts (App, Widget, Live Activity) each call `Date()` and resolve locally — known transient inconsistency around the boundary tick documented in System-Wide Impact.

---

## Implementation Units

> Note: U-IDs are stable per ce-plan convention. Units U4 and U5 from the original draft (treatment-cycle pinning and boundary-wake middleware) were dropped during plan deepening; the gaps in the unit numbering reflect that.

- [ ] U1. **State model + protocol shape**

**Goal:** Add ten new `DirectState` stored properties (six per-profile + four schedule Int slots), demote three legacy properties to `{ get }`-only computed accessors, add the `AlarmProfile` enum and `activeAlarmProfile` computed property.

**Requirements:** R1, R2, R3, R4, R10

**Dependencies:** None

**Files:**
- Create: `Library/Content/AlarmProfile.swift` — enum + a small `resolveActiveAlarmProfile(at: Date, nightStartHour: Int, nightStartMinute: Int, nightEndHour: Int, nightEndMinute: Int) -> AlarmProfile` free function (placed in `Library/Content/` so it's auto-included in both app and widget targets per the `SparklineBuilder.swift` precedent)
- Modify: `Library/DirectState.swift` — demote `alarmHigh`/`alarmLow`/`alarmVolume` to `{ get }`; add the ten new `{ get set }` properties; add `activeAlarmProfile` computed
- Modify: `App/AppState.swift` — add stored properties with `didSet` for the ten new keys; remove direct storage of `alarmHigh`/`alarmLow`/`alarmVolume`; add `init`-from-UserDefaults entries
- Modify: `Library/Extensions/UserDefaults.swift` — add `Keys` cases and computed properties for `dayAlarmHigh`, `dayAlarmLow`, `dayAlarmVolume`, `nightAlarmHigh`, `nightAlarmLow`, `nightAlarmVolume`, `nightStartHour`, `nightStartMinute`, `nightEndHour`, `nightEndMinute`
- Test: `DOSBTSTests/AlarmProfileTests.swift`

**Approach:**
- `AlarmProfile` is `enum AlarmProfile { case day; case night }` — no logic
- The free function `resolveActiveAlarmProfile(at:...)` is the single source of truth for the day/night resolution algorithm — both `state.activeAlarmProfile` (in the app) and the widget/LA render-time helpers call it
- Boundary semantics: `[start, end)` — start is inclusive, end is exclusive. Midnight wrap (start > end as minute-of-day) handled with: `if startMinute <= currentMinute && currentMinute < endMinute` for non-wrapping vs `currentMinute >= startMinute || currentMinute < endMinute` for wrapping
- Degenerate `start == end` returns `.day` always
- Legacy `alarmHigh / alarmLow / alarmVolume` become `var alarmHigh: Int { activeAlarmProfile == .night ? nightAlarmHigh : dayAlarmHigh }` (and same shape for low/volume) on the `DirectState` extension

**Patterns to follow:**
- `Library/Extensions/UserDefaults.swift` 3-step pattern for each new key
- `Library/Content/SparklineBuilder.swift` placement pattern — cross-target shared logic types live in `Library/Content/`

**Test scenarios:**
- Happy path — `activeAlarmProfile` returns `.day` at 14:00 with default schedule 22:00→07:00
- Happy path — `activeAlarmProfile` returns `.night` at 22:30 with default schedule
- Happy path — `activeAlarmProfile` returns `.night` at 06:30 with default schedule
- Happy path — `activeAlarmProfile` returns `.day` at 07:30 with default schedule
- Edge case — boundary at exact `nightStartHour:Minute`: returns `.night` (inclusive lower bound)
- Edge case — boundary at exact `nightEndHour:Minute`: returns `.day` (exclusive upper bound)
- Edge case — midnight wrap: schedule 21:00→06:00, evaluation at 23:00 returns `.night`; at 02:00 returns `.night`; at 06:00 returns `.day`
- Edge case — degenerate same-time: `start == end` returns `.day` always (no time slot is "night")
- Edge case — degenerate same-time at midnight (00:00 == 00:00) returns `.day`
- Happy path — `state.alarmHigh` resolves to `dayAlarmHigh` when `activeAlarmProfile == .day`
- Happy path — `state.alarmHigh` resolves to `nightAlarmHigh` when `activeAlarmProfile == .night`
- Same for `alarmLow` and `alarmVolume`
- Happy path — the free `resolveActiveAlarmProfile(at:...)` function returns the same value as `state.activeAlarmProfile` for matching inputs (sanity check that the app and widget paths agree)

**Verification:**
- Project compiles with the legacy stored properties removed and the computed accessors in place
- All call sites reading `state.alarmHigh`/`alarmLow`/`alarmVolume` continue to work (no errors)
- New test file passes

---

- [ ] U2. **Actions + reducer + migration + call site cleanup**

**Goal:** Add the eight new `DirectAction` cases (six per-profile threshold/volume + two composite schedule actions), remove the three legacy actions, update `DirectReducer` with the new mutation cases, update all three call sites of the removed actions (`DirectReducerTests`, `SensorGlucoseStore`, `AlarmSettingsView` volume slider), and add migration logic in `AppState.init`.

**Requirements:** R1–R5, R10, R11

**Dependencies:** U1

**Files:**
- Modify: `Library/DirectAction.swift` — add `setDayAlarmHigh / setDayAlarmLow / setDayAlarmVolume / setNightAlarmHigh / setNightAlarmLow / setNightAlarmVolume / setNightScheduleStart(hour:minute:) / setNightScheduleEnd(hour:minute:)`; remove `setAlarmHigh / setAlarmLow / setAlarmVolume`
- Modify: `Library/DirectReducer.swift` — add cases for each of the eight new actions; the schedule actions mutate both `nightStartHour`+`nightStartMinute` (or end) atomically in one reducer pass; remove the three legacy cases
- Modify: `App/AppState.swift` — add migration block in `init` that runs once when the per-profile keys are absent; configure `didSet` dual-write for Day setters (writes both per-profile key AND legacy key) and single-write for Night setters
- Modify: `App/Modules/SensorGlucoseStore/SensorGlucoseStore.swift` — rewrite the `case .setAlarmLow` / `case .setAlarmHigh` middleware match arms to fire on all four `.setDayAlarmHigh`, `.setDayAlarmLow`, `.setNightAlarmHigh`, `.setNightAlarmLow` actions (statistics are threshold-relative; active threshold can flip at boundary; recompute on any threshold change)
- Modify: `App/Views/Settings/AlarmSettingsView.swift:85` — update the `alarmVolume` Binding to dispatch `.setDayAlarmVolume(volume:)` instead of the removed `.setAlarmVolume(volume:)`. (This is the missed call site flagged in doc-review; full Settings UI restructure happens in U6.)
- Test: `DOSBTSTests/AlarmProfileMigrationTests.swift`
- Test: update `DOSBTSTests/DirectReducerTests.swift:312-338` to dispatch the new per-profile actions

**Approach:**
- **Migration trigger condition (idempotent):** `UserDefaults.standard.object(forKey: "dayAlarmHigh") == nil`. The single-key check is sufficient — if `dayAlarmHigh` is absent, this is either a fresh install or an unmigrated upgrader; in either case migration runs. We do NOT additionally check `alarmHigh != nil` because dual-write keeps the legacy key present forever after the first day-side edit, breaking the would-be guard.
- On migration:
  - If legacy `alarmHigh` exists → copy `alarmHigh → dayAlarmHigh, nightAlarmHigh`; same for low and volume
  - If legacy keys absent (fresh install) → set defaults: `dayAlarmHigh=180, nightAlarmHigh=180, dayAlarmLow=80, nightAlarmLow=80, dayAlarmVolume=0.5, nightAlarmVolume=0.5`
  - Always: default `nightStartHour=22, nightStartMinute=0, nightEndHour=7, nightEndMinute=0`
- **Dual-write for rollback safety (Day setters only):** Each Day setter `didSet` writes to BOTH the per-profile key AND the legacy key. Example: `dayAlarmHigh.didSet { UserDefaults.standard.dayAlarmHigh = dayAlarmHigh; UserDefaults.standard.alarmHigh = dayAlarmHigh }`. Old binaries reading legacy keys see day values. Night setters do NOT dual-write — night values are lost on rollback (acceptable: rolled-back binary recovers to safer day-strict configuration).
- The reducer cases are pure mutations on the new stored properties. The schedule composite actions mutate two stored properties in a single reducer pass: `case .setNightScheduleStart(hour: let h, minute: let m): state.nightStartHour = h; state.nightStartMinute = m`.
- The `SensorGlucoseStore` rewrite: existing single match arm handling `.setAlarmLow`/`.setAlarmHigh` becomes a multi-case arm handling all four day/night threshold setters. The recompute itself reads `state.alarmLow / state.alarmHigh` (computed accessors) so the call to `getSensorGlucoseStatistics` resolves correctly against the active profile.

**Execution note:** Update existing `DirectReducerTests` first (they currently invoke the legacy actions — they will fail to compile after the action removal), then write new migration tests, then add the new reducer cases.

**Patterns to follow:**
- `App/AppState.swift` existing `didSet` pattern for UserDefaults persistence
- `Library/DirectReducer.swift` existing case shape: `case .setX(value: let value): state.x = value`

**Test scenarios:**
- Migration — first launch with legacy `alarmHigh=180, alarmLow=80, alarmVolume=0.6` populates `dayAlarmHigh=180, nightAlarmHigh=180, dayAlarmLow=80, nightAlarmLow=80, dayAlarmVolume=0.6, nightAlarmVolume=0.6`
- Migration — first launch with no legacy keys (fresh install) sets defaults: `dayAlarmHigh=180, nightAlarmHigh=180, dayAlarmLow=80, nightAlarmLow=80, dayAlarmVolume=0.5, nightAlarmVolume=0.5`
- Migration — both branches set `nightStartHour=22, nightStartMinute=0, nightEndHour=7, nightEndMinute=0`
- Migration idempotency — second launch (per-profile keys present) does NOT re-migrate; user's tweaked night values are preserved
- Migration idempotency — even AFTER a day-side edit (which dual-writes legacy key), second launch still does not re-migrate (because `dayAlarmHigh != nil` blocks it)
- Dual-write — dispatching `.setDayAlarmHigh(value: 175)` updates BOTH `UserDefaults.standard.dayAlarmHigh` AND `UserDefaults.standard.alarmHigh` to 175
- Dual-write — dispatching `.setNightAlarmHigh(value: 200)` updates `UserDefaults.standard.nightAlarmHigh` to 200 but does NOT change the legacy `alarmHigh` key
- Reducer — `.setDayAlarmHigh(value: 175)` mutates `state.dayAlarmHigh` only; `state.nightAlarmHigh` and `state.dayAlarmLow` etc. are unchanged
- Reducer — `.setNightScheduleStart(hour: 23, minute: 30)` mutates BOTH `state.nightStartHour` (to 23) AND `state.nightStartMinute` (to 30) in one reducer pass
- Integration — `SensorGlucoseStore` middleware recomputes statistics when any of `.setDayAlarmHigh`, `.setDayAlarmLow`, `.setNightAlarmHigh`, `.setNightAlarmLow` fires (verify by mocking the store and checking that `loadSensorGlucoseStatistics` is dispatched)

**Verification:**
- Project compiles with all eight new actions in place and the three legacy actions removed
- `DirectReducerTests` passes after the rewrite
- `AlarmProfileMigrationTests` passes
- `AlarmSettingsView` volume slider compiles (uses the new `.setDayAlarmVolume(volume:)`)
- A pre-update build can read the legacy keys and see day values after a roundtrip through the new build

---

- [ ] U3. **Threshold integration tests**

**Goal:** Verify that `state.isAlarm(glucoseValue:)`, `state.isSnoozed(alarm:)`, and the critical-low breakthrough all use the active profile's thresholds correctly.

**Requirements:** R1, R2, R6

**Dependencies:** U2

**Files:**
- Test: `DOSBTSTests/AlarmThresholdProfileTests.swift`

**Approach:**
- Mock the active-profile resolution by setting per-profile threshold values such that the test asserts the right one was read (regardless of clock). Set `dayAlarmHigh = 180, nightAlarmHigh = 200`, configure schedule for night, verify `state.alarmHigh == 200`. (This pattern is simpler than injecting a clock and works because the only thing varying is which stored property is read.)

**Patterns to follow:**
- `DOSBTSTests/IOBCalculatorTests.swift` — Swift Testing framework, `@Test`, `#expect`

**Test scenarios:**
- Happy path — `state.isAlarm(glucoseValue: 195)` returns `.highAlarm` when day high=180 and active profile is day
- Happy path — `state.isAlarm(glucoseValue: 195)` returns `.none` when night high=200 and active profile is night
- Happy path — `state.isAlarm(glucoseValue: 75)` returns `.lowAlarm` when day low=80 and active profile is day
- Happy path — `state.isAlarm(glucoseValue: 75)` returns `.lowAlarm` when night low=85 and active profile is night
- Edge case — critical-low breakthrough: glucose at `nightAlarmLow - 16` during night fires breakthrough (against active profile's alarmLow)
- Edge case — critical-low breakthrough: same glucose value during day with higher day low does NOT fire breakthrough
- Integration — snooze evaluation: `alarmSnoozeUntil` set during day, evaluation during night — snooze respected (time-based), threshold checked against night profile
- Integration — `state.alarmVolume` read by `GlucoseNotification.setLowGlucoseAlarm` resolves to active-profile volume
- Integration — `Debug.swift` reads `state.alarmVolume` and resolves to active-profile volume (documenting the accepted debug-alarm bleed)
- Integration — `ExpiringNotification.swift` reads `max(state.dayAlarmVolume, state.nightAlarmVolume)` and ignores the active profile, so an expiring-sensor warning at night plays at the louder of the two configured volumes

**Verification:**
- All scenarios pass
- No existing alarm-related tests in `DOSBTSTests` regress

---

- [ ] U6. **Settings UI**

**Goal:** Update `AlarmSettingsView` with three new sections (Day profile, Night profile, Sleep schedule) and the symmetric warning rows. Move the threshold `NumberSelectorView`s out of `GlucoseSettingsView` into the new Day section. Replace the global volume slider with the per-profile sliders. Add the degenerate-schedule inactive label. Update sound preview Bindings to use day volume.

**Requirements:** R1–R4, R7

**Dependencies:** U2

**Files:**
- Modify: `App/Views/Settings/AlarmSettingsView.swift` — restructure body from a single `Section` to a `Group { Section; Section; Section; Section }`; add three new sections; remove the global volume slider; preserve and update existing global section
- Modify: `App/Views/Settings/GlucoseSettingsView.swift` — remove the `NumberSelectorView` for `alarmHigh` and `alarmLow` on lines 23-27; keep unit selector and any non-alarm controls
- No new test file — UI testing via screenshot review on simulator

**Approach:**
- **Body restructure:** the existing `var body: some View { Section { ... } }` becomes `var body: some View { Group { Section { dayProfile }; Section { nightProfile }; Section { sleepSchedule }; Section { existingGlobals } } }`. Each subsection extracted into a small `@ViewBuilder` private property for readability.
- **Day profile section:** `NumberSelectorView` for high (binding to `dayAlarmHigh`, dispatches `.setDayAlarmHigh`); `NumberSelectorView` for low (binding to `dayAlarmLow`, dispatches `.setDayAlarmLow`); `Slider` bound to `dayAlarmVolume`
- **Night profile section:** same three controls (binding to `night*` properties, dispatching `.setNight*` actions). Inline warning rows beneath:
  - Below night-low control: when `nightAlarmLow < dayAlarmLow`, render `Text("Lows will need to drop \((dayAlarmLow - nightAlarmLow).asGlucose(glucoseUnit: store.state.glucoseUnit, withUnit: true)) further before alarming at night. Less margin to react if you're asleep.").font(.caption).foregroundStyle(AmberTheme.amber)`
  - Below night-high control: when `nightAlarmHigh > dayAlarmHigh`, render `Text("Highs will need to rise \((nightAlarmHigh - dayAlarmHigh).asGlucose(glucoseUnit: store.state.glucoseUnit, withUnit: true)) further before alarming at night.").font(.caption).foregroundStyle(AmberTheme.amber)`
  - **Color choice:** `AmberTheme.amber` (#ffb000, primary token) used at caption size for accessibility (the design system explicitly restricts `amberDark` to 18pt+ per the comment in `AmberTheme.swift`). `Font.caption` (not `DOSTypography.caption`) honors Dynamic Type so users with larger accessibility text sizes see the warning at scaled size.
  - **Unit-correctness:** the delta is formatted via `.asGlucose(glucoseUnit:withUnit:)` so mmol/L users see a correctly-converted-and-labeled value rather than a hardcoded `mg/dL` string.
- **Sleep schedule section:** two `DatePicker(.hourAndMinute)` controls. Each wrapped in a `Binding<Date>` that:
  - **Read:** constructs a `Date` from `(nightStartHour, nightStartMinute)` (or end) using `Calendar.current.date(from:)`
  - **Write:** decomposes the new Date via `Calendar.current.dateComponents([.hour, .minute], from:)` and dispatches the **single composite** action `.setNightScheduleStart(hour:minute:)` (or End) — atomic mutation, no half-updated state
  - Below the pickers, conditional inactive label: `if nightStartHour == nightEndHour && nightStartMinute == nightEndMinute { Text("Night profile inactive — start and end times are equal.").font(.caption).foregroundStyle(AmberTheme.amber) }`
- **Existing global section:** retains sound pickers + `ignoreMute` + predictive-low + recheck. The `selectedLowGlucoseAlarmSound`, `selectedHighGlucoseAlarmSound`, `selectedConnectionAlarmSound`, and `selectedExpiringAlarmSound` Bindings each call `DirectNotifications.shared.testSound(sound: sound, volume: store.state.dayAlarmVolume)` (note: NOT `store.state.alarmVolume` which would resolve to active-profile volume — preview always uses day volume per the resolved decision). Footer row: `Text("Previews play at day volume.").font(.caption).foregroundStyle(AmberTheme.amber)`. **All four** sound-preview call sites must be updated, not just two.
- **NumberSelectorView constraint clamping:** Each profile clamps intra-profile only — night-high `min: nightAlarmLow`, night-low `max: nightAlarmHigh`. Cross-profile inversion (e.g., `nightAlarmLow < dayAlarmLow`) is NOT hard-clamped — it surfaces as the warning row. Preserves user agency for atypical configs while making the safety implication visible.

**Patterns to follow:**
- Existing `App/Views/Settings/AlarmSettingsView.swift` `Picker; Picker; Slider; Toggle` shape inside each section
- Existing `App/Views/Settings/GlucoseSettingsView.swift` `NumberSelectorView` usage for the threshold pickers, including the `displayValue: store.state.alarmLow.asGlucose(glucoseUnit:withUnit:)` formatter pattern

**Test scenarios:**
- Test expectation: none — UI rendering verified by manual simulator screenshot review at U8 verification step. The threshold/binding/atomic-dispatch logic is covered by U2 (reducer/migration) and U3 (threshold integration) tests.

**Verification:**
- Build the app and open Settings → Alarm settings
- Day profile section shows three controls; Night profile section shows three controls; Sleep schedule shows two pickers
- Set night low below day low → low warning row appears with correct delta IN THE USER'S CONFIGURED UNIT (mg/dL or mmol/L)
- Set night high above day high → high warning row appears with correct delta in user's unit
- Drag both schedule pickers to the same time → inactive label appears
- Tap a global sound picker → preview plays at day volume; footer says "Previews play at day volume"
- Open Settings → Glucose settings — confirm no `alarmHigh`/`alarmLow` `NumberSelectorView`s remain
- Edit a schedule picker — confirm only ONE reducer pass fires per edit (no half-updated intermediate state visible in any subscriber)

---

- [ ] U7. **Active-profile indicator (all surfaces) + cross-target sync**

**Goal:** Add the conditional moon glyph to `SensorLineView`, `GlucoseWidget` (Home Screen + Lock Screen), and `GlucoseActivityWidget` (Live Activity). Wire `AppGroupSharing` to mirror schedule + per-profile thresholds to `UserDefaults.shared` on every glucose update AND on every per-profile setter action. Update `GlucoseWidget` and `GlucoseActivityWidget` to compute the active profile at render time.

**Goal context — net-new behavior:** The widget today calls `UserDefaults.shared.alarmLow / .alarmHigh` via the computed properties in `Library/Extensions/UserDefaults.swift`. Those computed properties read whatever key is present in the suite they're invoked on; the App Group suite has never had `alarmLow`/`alarmHigh` written to it (the existing `AppGroupSharing` middleware writes TIR / IOB / sparkline / last-meal but NOT thresholds), so the widget falls through to the hardcoded defaults (80/180). This is a latent bug — the widget today shows alarm-coloring against defaults rather than the user's configured thresholds. U7 fixes this as a side effect of shipping per-profile sync; the v1 widget will be the first version that actually renders against user-configured thresholds.

**Requirements:** R8, R9

**Dependencies:** U1, U2

**Files:**
- Modify: `App/Views/Overview/SensorLineView.swift` — add leading moon glyph rendered when `store.state.activeAlarmProfile == .night`; mark the glyph `.accessibilityHidden(true)` (matching the existing dot circle pattern at line 60); extend the combined `accessibilityLabelString` switch to prepend "Night profile active. " when in night mode (this is the ONLY VoiceOver path — the glyph's own label is swallowed by `.combine`)
- Modify: `App/Modules/AppGroupSharing/AppGroupSharing.swift` (or wherever the shared writes live) — write `nightStartHour`, `nightStartMinute`, `nightEndHour`, `nightEndMinute`, `dayAlarmHigh`, `dayAlarmLow`, `nightAlarmHigh`, `nightAlarmLow` to `UserDefaults.shared` on every `.addSensorGlucose` AND on every `.setDayAlarmHigh / .setDayAlarmLow / .setDayAlarmVolume / .setNightAlarmHigh / .setNightAlarmLow / .setNightAlarmVolume / .setNightScheduleStart / .setNightScheduleEnd` action. **Use raw key strings** (e.g., `UserDefaults.shared.set(state.dayAlarmHigh, forKey: "dayAlarmHigh")`) — the existing `Library/Extensions/UserDefaults.swift` computed properties target `UserDefaults.standard`; do NOT extend them to handle the shared suite. The widget reads the same raw keys via its own helper. After each per-profile setter writes to `UserDefaults.shared`, call `WidgetCenter.shared.reloadAllTimelines()` to force the home/lock-screen widget timeline to refresh — `GlucoseWidget`'s `TimelineProvider` schedules a 15-minute reload by default; without an explicit reload, settings changes won't appear until that interval expires.
- Modify: `Widgets/GlucoseWidget.swift:82-83` — replace direct `UserDefaults.shared.alarmLow / .alarmHigh` reads with calls to a small helper that reads schedule + profile-thresholds from `UserDefaults.shared`, computes active profile at `Date()`, and returns active alarmLow/alarmHigh; render the moon glyph in the widget chrome (small, top-right corner or wherever fits the existing layout — pick during implementation) when active profile is night
- Modify: `Library/Content/SensorGlucoseActivityAttributes.swift` — extend the `ContentState` struct with eight **optional** fields: `nightStartHour: Int?`, `nightStartMinute: Int?`, `nightEndHour: Int?`, `nightEndMinute: Int?`, `dayAlarmHigh: Int?`, `dayAlarmLow: Int?`, `nightAlarmHigh: Int?`, `nightAlarmLow: Int?`. **Keep the existing `alarmLow`/`alarmHigh` fields** so in-flight Live Activities at upgrade time decode without error. (The struct lives in `Library/Content/` for cross-target visibility; do NOT modify it inside `WidgetCenter.swift`.)
- Modify: `App/Modules/WidgetCenter/WidgetCenter.swift` — populate the eight new ContentState fields from `state.dayAlarmHigh / dayAlarmLow / nightAlarmHigh / nightAlarmLow / nightStartHour / nightStartMinute / nightEndHour / nightEndMinute` whenever building or updating ContentState. Continue populating the legacy `alarmLow / alarmHigh` from `state.dayAlarmHigh / dayAlarmLow` (NOT from `state.alarmHigh / alarmLow` — the legacy fields must be a stable day-anchored fallback for pre-upgrade in-flight activities, not the active-profile resolved value that would oscillate at the boundary). Also: dispatch `service.value.update(...)` in response to ALL eight per-profile setter actions (currently `WidgetCenter` only handles `.addSensorGlucose / .setGlucoseUnit / .setGlucoseLiveActivity / .setAppState(active) / .setConnectionState / .startup`) — without this, Live Activity stays stale on settings changes until the next sensor tick.
- Modify: `Widgets/GlucoseActivityWidget.swift:83` — add a small `effectiveAlarmThresholds(at:)` helper that returns `(low, high)`. **Strict all-or-nothing check:** if ALL four schedule fields AND ALL four per-profile threshold fields are present, compute via `resolveActiveAlarmProfile(at:...)`; if ANY of the eight is nil, fall back to `(context.alarmLow, context.alarmHigh)` for both values together. Never mix a per-profile field with a legacy field — that would produce a threshold pair (e.g., `nightAlarmLow` + `dayAlarmHigh`) that exists in neither profile. Update the threshold evaluation to use the helper. Render the moon glyph in the lock-screen Live Activity layout when the effective profile is night (only when all eight new fields are present — no glyph in the legacy-fallback path, since pre-upgrade activities have no schedule data to evaluate).
- Modify: `App/Modules/ExpiringNotification/ExpiringNotification.swift:40` — change `volume: state.alarmVolume` to `volume: max(state.dayAlarmVolume, state.nightAlarmVolume)`. Floors sensor end-of-life warnings against night silencing. (`Debug.swift:20` is unchanged — accepted bleed for the debug path only.)
- Modify: `Widgets/SensorWidget.swift` and `Widgets/TransmitterWidget.swift` — verify whether they read alarm thresholds; update if they do (likely don't, but check)
- Test: `DOSBTSTests/AppGroupSharingProfileTests.swift` — verify the AppGroup write path includes the new keys on both `.addSensorGlucose` AND each per-profile setter
- Test: `DOSBTSTests/ActivityContentStateProfileTests.swift` — verify ContentState carries the new optional fields, AND that decoding a payload with the new fields nil falls back to legacy fields correctly

**Approach:**
- **Profile-resolution helper** lives in `Library/Content/AlarmProfile.swift` (created in U1) as the free function `resolveActiveAlarmProfile(at:nightStartHour:nightStartMinute:nightEndHour:nightEndMinute:)`. App, widget, and Live Activity all call it.
- **Moon glyph in `SensorLineView`:** `if store.state.activeAlarmProfile == .night { Image(systemName: "moon.fill").foregroundStyle(AmberTheme.amberDark).accessibilityHidden(true) }`. The visual signal is the glyph; the VoiceOver signal is the prepended string.
- **Moon glyph in widgets:** match the widget's existing visual density. For `GlucoseWidget` small/medium/large variants, the glyph occupies a small corner slot; for the Lock Screen widget, it appears next to the connection indicator. Specific placement decided during implementation by reviewing the existing layouts.
- **Moon glyph in Live Activity:** appears in both the compact (Dynamic Island) and expanded states. Specific placement decided during implementation; the principle is "visible without dominating."
- **AppGroupSharing trigger expansion:** the existing middleware handles `.addSensorGlucose`. Add eight new match arms — one per per-profile setter — that perform the same shared-write but without requiring a current glucose value (the schedule + thresholds don't depend on glucose). Factor into a single `writeProfileDataToShared(state:)` helper called from all relevant arms.
- **ContentState backward compat:** the new fields are optional. When `WidgetCenter` constructs a ContentState in the new build, it populates all eight new fields. When the Live Activity widget renders, `effectiveAlarmThresholds(at:)` checks for nil and uses the helper or falls back. This means in-flight activities from the pre-upgrade build (with the legacy two fields populated and the new eight nil) continue to decode and render correctly — they just won't be profile-aware until the next `WidgetCenter` update populates the new fields.
- **ContentState size budget:** the 4KB ActivityKit limit applies to the encoded payload. The new fields add ~50 bytes (eight `Int?` values). Existing payload includes glucose history, IOB, sparkline. Add a sizing check to U8 verification: encode current `ContentState` and the proposed `ContentState`, log both byte sizes, fail the smoke if either exceeds 3.5KB (leaving headroom for future additions).
- Bellman: confirmed in `App/Modules/BellmanAlarm/BellmanAlarm.swift:43` that it reads `state.isAlarm(glucoseValue:)` only. No code change.

**Patterns to follow:**
- `Library/Content/SparklineBuilder.swift` placement convention — cross-target shared logic types live in `Library/Content/`
- Existing `App/Modules/AppGroupSharing/` write pattern (factor the new bits into a helper to avoid duplication)
- Existing `SensorGlucoseActivityAttributes.ContentState` field structure
- Existing dot-circle pattern in `SensorLineView` for `.accessibilityHidden(true)` on visual-only chrome

**Test scenarios:**
- Happy path — `AppGroupSharing` writes all four schedule keys + four per-profile threshold keys to `UserDefaults.shared` on `.addSensorGlucose`
- Happy path — `AppGroupSharing` writes the same keys on each of the eight per-profile setter actions (`.setDayAlarmHigh`, `.setDayAlarmLow`, `.setDayAlarmVolume`, `.setNightAlarmHigh`, `.setNightAlarmLow`, `.setNightAlarmVolume`, `.setNightScheduleStart`, `.setNightScheduleEnd`)
- Happy path — `SensorGlucoseActivityAttributes.ContentState` initializer carries the new optional fields in the new build
- Backward compat — decoding a ContentState with the new fields nil and the legacy `alarmLow`/`alarmHigh` populated does not throw, and `effectiveAlarmThresholds(at:)` returns the legacy values
- Backward compat — decoding a ContentState with all new fields populated returns the active-profile values from `effectiveAlarmThresholds(at:Date())`
- Happy path — the shared profile-resolution helper returns the same value when called from app, widget, and Live Activity contexts with identical inputs
- Edge case — degenerate schedule via shared values returns `.day` always
- Test expectation for moon-glyph visual rendering: none — verified by simulator screenshot at U8

**Verification:**
- Build the app
- Trigger a glucose update during day window, observe widget shows day thresholds + no moon glyph
- Advance simulator clock past `nightStartHour:Minute`, force a widget timeline reload, observe widget re-renders with night thresholds + moon glyph (without the app needing to receive a new sensor reading — the widget timeline polls)
- Same for Live Activity on lock screen
- Open OverviewView during night window, observe moon glyph leading the connection-status row; turn on VoiceOver and verify "Night profile active. Sensor connected, ..." is read
- Edit a Night threshold in Settings — confirm widget re-renders with the new value within the next render cycle, without waiting for a new sensor reading
- Trigger an expiring-sensor notification at a time when night volume = 0 and day volume = 0.7; verify it plays at 0.7 (max of the two), NOT at 0 — confirms the safety floor for sensor end-of-life warnings overnight
- Trigger a debug alarm at a time when day volume ≠ night volume; verify it plays at the *active* profile's volume (documenting the accepted debug-alarm bleed)

---

- [ ] U8. **CHANGELOG + manual smoke verification + ContentState sizing check**

**Goal:** Add a `[Unreleased]` CHANGELOG entry. Run a final manual smoke pass through the full feature on the simulator. Measure ContentState encoded size against the 4KB ceiling.

**Requirements:** All

**Dependencies:** U1, U2, U3, U6, U7

**Files:**
- Modify: `CHANGELOG.md` — add entry under `## [Unreleased]`
- No new tests

**Approach:**
- CHANGELOG entry under `### Added`:
  > Day/night alarm profiles. Two separate threshold + volume profiles switched on a fixed user-configured time window (default 22:00–07:00). Solves nighttime alarm fatigue without changing day-time behavior for users who don't opt in. Settings → Alarms now has Day profile, Night profile, and Sleep schedule sections; the existing single threshold/volume controls migrate transparently into both profiles. A small moon glyph appears in the Overview tab, the Home Screen + Lock Screen widgets, and the Live Activity when night profile is active. Boundary transitions use a 5-min responsiveness floor (next sensor reading triggers re-evaluation); lock-screen surfaces stay correct in real time via render-time profile resolution. Treatment-cycle behavior, snooze, predictive low, and critical-low breakthrough all read the active profile transparently — no cycle pinning. **Rollback note:** day-side threshold and volume changes dual-write to legacy keys for safe rollback to the prior build; night-side changes are not mirrored, so a rollback after night customization recovers to the day configuration — DMNC-692, PR #NN.
- ContentState sizing check during smoke: encode a sample `ContentState` with all new fields populated and a representative sparkline payload; log byte size; confirm < 3.5KB.

**Test scenarios:**
- Test expectation: none — manual smoke pass

**Verification:**
- Open Settings → Alarms — all sections render correctly, warning rows appear in the user's configured unit (mg/dL or mmol/L), schedule pickers work, inactive label appears for degenerate schedule
- Configure `nightStartHour=22, nightAlarmHigh=200`, simulator clock 21:55 → 22:01: at 22:00 a 195 reading does NOT fire alarm (under night high=200); at 21:55 the same 195 fires under day high=180
- Trigger a low alarm at 21:55, snooze for 30min: at 22:01 confirm snooze still active and that profile transition does not break behavior
- Force-quit and relaunch the app: confirm Night settings persist; confirm migration does NOT re-fire (user's tweaked night values preserved)
- Lock the device, observe widget at boundary transition: thresholds change AND moon glyph appears within the next widget timeline tick (no sensor update required)
- Lock the device, observe Live Activity at boundary transition: same — moon glyph appears, thresholds shift
- Turn on VoiceOver, navigate to OverviewView during night: verify "Night profile active" is announced as part of the SensorLineView combined label
- Roll back to a pre-update build (TestFlight): confirm the old binary reads day values from the legacy keys (dual-write verified). If the user had configured night-side changes, confirm the rollback recovers to day values (documented behavior, not a bug).
- Edit night threshold in Settings without a concurrent glucose reading; observe widget re-renders within the next timeline tick (no waiting for sensor)
- Encode a representative ContentState payload; confirm encoded size < 3.5KB
- Decode a synthetic legacy-build ContentState (only `alarmLow` + `alarmHigh` populated, new fields nil); confirm Live Activity renders without error and uses fallback thresholds

---

## System-Wide Impact

- **Interaction graph:** `GlucoseNotification`, `BellmanAlarm`, `TreatmentCycleMiddleware`, `AppGroupSharing`, `Debug`, `SensorGlucoseStore` middleware all read alarm-related state. All inherit profile-awareness transparently via the computed `alarmHigh / alarmLow / alarmVolume` accessors. `SensorGlucoseStore` middleware match arms must be rewritten to fire on all four day/night threshold setters. `Debug` continues reading `state.alarmVolume` (now computed) — accepted bleed for that path. `ExpiringNotification` is the exception: it reads `max(state.dayAlarmVolume, state.nightAlarmVolume)` to floor sensor end-of-life warnings against night silencing, since silencing an overnight sensor failure would be a real safety regression.
- **Error propagation:** Migration failures (per-profile keys partially populated mid-migration) could leave the app in an inconsistent state. Mitigation: migration runs as a single atomic block in `AppState.init`; if any per-profile key write fails, the next launch re-runs migration (the `dayAlarmHigh == nil` guard catches the partial-write case).
- **State lifecycle risks:** None added by this plan — no new long-lived state with cleanup obligations.
- **API surface parity:** Widget, Live Activity, and the in-app `state.activeAlarmProfile` all call the same `resolveActiveAlarmProfile(at:...)` free function in `Library/Content/AlarmProfile.swift`. If the algorithm changes, all three update together.
- **Render-time profile drift:** Three independent render contexts (App via `state.activeAlarmProfile`, Home Screen Widget timeline, Live Activity render) each call `Date()` and resolve locally. Around the boundary tick they can disagree by 1–2 minutes — widget shows night thresholds while a just-fired alarm banner shows a day-evaluated value. The moon-glyph indicator can also flicker across surfaces (visible on Lock Screen widget but not yet on Live Activity, etc.) for the same reason. This is documented known transient inconsistency, accepted as the cost of avoiding push-driven sync. If it proves disruptive in practice, a follow-up could add a small grace window (60s) to the resolution helper that holds the prior profile briefly, OR bucket `Date()` to the whole minute inside `resolveActiveAlarmProfile(at:...)` so all callers within the same minute agree.
- **Chart historical coloring:** `ChartView` reads `state.alarmHigh / state.alarmLow` to color historical glucose points and to render the dashed reference range lines. After demotion, those resolve to the *currently active* profile — so at 22:01 a chart showing 24h of history will color yesterday's daytime points against night thresholds, and the reference lines jump at the boundary. This is a coherent consequence of the design (the chart shows "what's in range NOW for the active profile") and is accepted for v1; per-point time-of-day-aware coloring would be significantly more complex (the chart's color computation is not currently profile-segmented). Document the boundary jump in TestFlight release notes if it surprises users.
- **Snooze expiry across boundary:** A snooze entered under day rules that expires inside the night window evaluates the next reading against night thresholds. The user's mental model "snooze 30 min then alarm me again" silently shifts to "snooze 30 min then alarm me at the night threshold" — which can suppress an alarm that would have fired under day rules. This is the same accepted-tradeoff as the symmetric snooze-cross-boundary case (OQ#8) but the asymmetry is worth flagging. If a user reports "my snooze didn't end," this is the most likely explanation.
- **Integration coverage:** The widget render-time profile resolution depends on `UserDefaults.shared` having the new keys. AppGroupSharing must populate them on every glucose tick AND every per-profile setter (per U7) — otherwise the widget can lag arbitrarily after a settings change. Manual smoke at U8 verification covers this.
- **Live Activity ContentState backward compat:** the new fields are optional; in-flight activities from pre-upgrade builds continue to decode and render. The Live Activity widget falls back to the legacy `alarmLow`/`alarmHigh` fields when the new schedule fields are nil. This means pre-upgrade activities are not profile-aware until they next receive a `WidgetCenter` update from the new build — acceptable.
- **Unchanged invariants:** `alarmSnoozeUntil` and `alarmSnoozeKind` remain unchanged in shape and semantics — snooze stays time-based; only the threshold against which snooze evaluates changes (via the computed `alarmHigh / alarmLow`). `predictiveLowAlarmFired` flag, treatment-cycle suppression rules, critical-low breakthrough rule (`alarmLow - 15`) all retain their pre-existing behavior modulo the per-profile resolution layer.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Computed-property migration breaks an undocumented call site that mutates `state.alarmHigh` directly via setter | Demoting protocol to `{ get }` makes this a compile-time error — caught at build, not runtime. Audit during U1 implementation. |
| Migration silently sets night thresholds to defaults instead of copying from legacy | Migration tests in U2 verify the copy explicitly against actual UserDefaults state. The `dayAlarmHigh == nil` guard ensures migration runs exactly once per install. |
| Treatment-cycle behavior changes mid-cycle when boundary flips | The plan accepts this — active profile wins. Symmetric warning rows in Settings discourage atypical configs that would create the false-breakthrough scenario. The user can read the actual glucose value on screen. |
| 5-min responsiveness gap at boundary in the in-app alarm path | Acceptable per spec OQ#5 alternative. Lock-screen surfaces (widget + Live Activity) stay correct in real time via render-time resolution, so the user-visible truth doesn't lag — only the in-app push notification at the exact boundary is delayed. |
| Render-time profile drift across surfaces (1–2 min around boundary) | Documented as known transient inconsistency. Mitigation if needed is a 60s grace window in the resolution helper — defer until proven necessary. |
| Live Activity ContentState size approaching 4KB limit | Sizing check in U8 verification. New fields add ~50 bytes; existing payload includes sparkline. Threshold of 3.5KB leaves headroom. |
| In-flight Live Activities break on upgrade | New ContentState fields are optional with fallback to legacy `alarmLow`/`alarmHigh`. Tested in U7. |
| Dual-write to legacy keys creates UserDefaults bloat | Per Day-setter call adds one extra UserDefaults write — negligible. Night setters do not dual-write. |
| Settings UI confusion when user moves thresholds from GlucoseSettings → AlarmSettings | One-time migration in user mental model. CHANGELOG mentions the move. Acceptable given the cleaner IA. |
| Adoption gap: feature ships, no behavior changes for most users | Real signal will tell us. If after a build cycle most users haven't touched Night settings, consider a one-time onboarding nudge as a follow-up. Not in v1 scope. |

---

## Documentation / Operational Notes

- CHANGELOG entry covers the user-facing change (per `CLAUDE.md` § CHANGELOG)
- TestFlight release notes for the build that ships this feature should explicitly mention:
  - The Settings location move (alarmHigh/alarmLow now under Settings → Alarms, not Settings → Glucose)
  - The dual-write rollback safety asymmetry (rollback recovers to day configuration; night customizations are lost on rollback)
  - The 5-min responsiveness floor at boundary transitions
- No new permissions required — `UNUserNotificationCenter` already authorized for glucose notifications; no boundary-wake notification scheduling
- No HealthKit additions — fixed times only
- Widget refresh budget: the widget timeline already polls; no additional `WidgetCenter.shared.reloadAllTimelines()` calls beyond what AppGroupSharing already triggers

---

## Sources & References

- **Origin document:** [docs/superpowers/specs/2026-05-02-day-night-alarm-profiles-design.md](../superpowers/specs/2026-05-02-day-night-alarm-profiles-design.md)
- **Linear issue:** [DMNC-692](https://linear.app/lizomorf/issue/DMNC-692/daynight-alarm-profiles-separate-thresholds-and-sounds-by-time)
- Related code: `Library/DirectState.swift`, `App/Modules/GlucoseNotification/`, `App/Modules/AppGroupSharing/`, `App/Modules/WidgetCenter/`, `Widgets/GlucoseWidget.swift`, `Widgets/GlucoseActivityWidget.swift`, `App/Views/Overview/SensorLineView.swift`
- Related conventions: `CLAUDE.md` § Adding New State Properties, § Architecture gotchas, § Live Activity data flows through ContentState, § Widget shared data via App Group, § CHANGELOG
