---
title: "feat: Predictive Low Alarm (Trend-Based Early Warning)"
type: feat
status: active
date: 2026-04-17
origin: docs/brainstorms/2026-04-17-predictive-low-alarm-requirements.md
---

# feat: Predictive Low Alarm (Trend-Based Early Warning)

## Overview

Add a trend-based predictive low alarm that warns before glucose crosses `alarmLow`, using linear extrapolation from `minuteChange`. Includes a chart projection line showing the 20-minute glucose trajectory. Integrates with the treatment workflow as a pre-emptive entry point.

## Problem Frame

Current alarms fire when glucose crosses the threshold — but Libre sensor lag means blood glucose was already low 10+ minutes ago. A predictive alarm fires *before* crossing, giving time to eat carbs and prevent the low. (see origin: `docs/brainstorms/2026-04-17-predictive-low-alarm-requirements.md`)

## Requirements Trace

- R1. Extrapolate glucose trajectory using smoothed minuteChange, projecting 20 minutes forward
- R2. Fire predictive alarm when projection crosses below alarmLow
- R3. Linear extrapolation: `predictedGlucose = currentGlucose + (smoothedMinuteChange * 20)`
- R4. Only fire when glucose is still above alarmLow (prediction, not actual)
- R5. Integrate with treatment workflow: "Trending low — treat now?" with TREAT NOW button
- R6. Distinct from actual alarm: different notification text, softer sound
- R7. Reuse treatment cycle suppression after treating
- R8a. Must NOT trigger autosnooze — actual low alarm must still fire if user ignores prediction
- R8b. No prediction when minuteChange is nil or reading is >5 min stale
- R8c. Once-per-episode dedup — no re-fire until prediction resolves
- R9. Projection line on chart (iOS 16+ only) when minuteChange available and reading <5 min old
- R10. Projection line colored by predicted endpoint (green/amber/red)
- R11. Threshold crossing point highlighted on chart
- R12. Toggle on/off in alarm settings (default: on)

## Scope Boundaries

- Predictive high alarm (lows only in V1)
- Configurable prediction window (hardcoded 20 min)
- Non-linear prediction models
- Projection line on iOS 15 ChartViewCompatibility
- Separate predictive alarm snooze

## Context & Research

### Relevant Code and Patterns

- **Alarm middleware:** `App/Modules/GlucoseNotification/GlucoseNotification.swift` — handles `.addSensorGlucose`, computes `isAlarm()`, fires notifications, manages autosnooze. The prediction check adds here.
- **Glucose data:** `Library/Content/SensorGlucose.swift` — `minuteChange: Double?` computed from consecutive readings. `trend: SensorTrend` derived from slope.
- **Chart:** `App/Views/Overview/ChartView.swift` — Swift Charts (iOS 16+), already renders glucose line, meal/insulin markers. Projection line adds a `LineMark`.
- **Treatment integration:** `App/Modules/TreatmentCycle/TreatmentCycleMiddleware.swift` — handles `.logHypoTreatment`, `.showTreatmentPrompt`. The predictive alarm dispatches `.showTreatmentPrompt` to enter the workflow.
- **Notification categories:** `App/App.swift` — `lowGlucoseAlarm` category registered with actions. Add a new `predictiveLowAlarm` category.
- **Settings pattern:** 4-file UserDefaults pattern for `showPredictiveLowAlarm: Bool`.

### Institutional Learnings

- **Reducer-first ordering:** Middleware sees post-reduction state. The prediction check in GlucoseNotification runs after `.addSensorGlucose` has updated `latestSensorGlucose`.
- **Autosnooze trap:** The existing autosnooze (5 min) fires after every unhandled alarm. The predictive alarm must NOT return `.setAlarmSnoozeUntil` — critical safety requirement.
- **Cross-middleware listening:** TreatmentCycleMiddleware also listens on `.addSensorGlucose`. Comment the dependency.

## Key Technical Decisions

- **Prediction inside GlucoseNotification middleware (not a new middleware):** All alarm logic stays in one place. The prediction check runs before the actual alarm check. If prediction fires, it dispatches `.showTreatmentPrompt` and skips the autosnooze. If prediction doesn't fire, the existing alarm logic runs unchanged.
- **Smoothed minuteChange (rolling average of 3):** Average the last 3 readings' minuteChange values to reduce noise from single-reading spikes. Falls back to latest value if fewer than 3 available.
- **New notification category `predictiveLowAlarm`:** Allows distinct button label ("EAT NOW"), distinct sound (existing alarm at lower volume), and distinct notification text ("Trending low — eat now?"). Separate from `lowGlucoseAlarm`.
- **Once-per-episode via state flag:** `predictiveLowAlarmFired: Bool` (transient, not persisted). Set true when prediction fires, cleared when glucose rises above alarmLow + 10 (buffer) or actual low alarm fires.
- **Projection line as LineMark with dash style:** Two-point line from (latestTimestamp, latestGlucose) to (latestTimestamp + 20min, predictedGlucose). Dashed stroke. Color matches endpoint zone.

## Open Questions

### Resolved During Planning

- **Smoothed vs raw minuteChange:** Rolling average of last 3. Simple, effective, falls back gracefully.
- **Middleware placement:** Inside GlucoseNotification. No new file.
- **Notification category:** New `predictiveLowAlarm` category for distinct UX.
- **Sound:** Existing alarm sound at reduced volume via `UNNotificationSound.defaultCriticalSound(withAudioVolume: 0.5)` or `.default`. Revisit if needed.
- **iOS 15 projection line:** Out of scope per requirements.

### Deferred to Implementation

- Exact smoothing behavior when only 1-2 minuteChange values are available
- Whether the crossing point marker (R11) should show the predicted time or value as a label

## Implementation Units

- [ ] **Unit 1: Predictive Low Alarm State + Settings**

**Goal:** Add the toggle and transient state for the predictive alarm.

**Requirements:** R12, R8c

**Dependencies:** None

**Files:**
- Modify: `Library/DirectState.swift`
- Modify: `App/AppState.swift`
- Modify: `Library/Extensions/UserDefaults.swift`
- Modify: `Library/DirectAction.swift`
- Modify: `Library/DirectReducer.swift`

**Approach:**
- `showPredictiveLowAlarm: Bool` — UserDefaults-backed, default true (4-file pattern)
- `predictiveLowAlarmFired: Bool` — transient (not persisted), default false. Set true when prediction fires, cleared when glucose rises above alarmLow + 10 or actual low alarm fires.
- Action: `.setShowPredictiveLowAlarm(enabled: Bool)`

**Patterns to follow:**
- `showScanlines` for the Bool toggle pattern
- `recheckDispatched` for the transient flag pattern

**Test scenarios:**
- Happy path: Toggle on/off persists across restart
- Edge case: `predictiveLowAlarmFired` resets to false on app restart (not persisted)

**Verification:** Setting toggleable in alarm settings. Transient flag accessible in state.

---

- [ ] **Unit 2: Prediction Logic in GlucoseNotification Middleware**

**Goal:** Add the predictive low alarm evaluation to the existing alarm middleware.

**Requirements:** R1, R2, R3, R4, R8a, R8b, R8c

**Dependencies:** Unit 1

**Files:**
- Modify: `App/Modules/GlucoseNotification/GlucoseNotification.swift`

**Approach:**
- In the `.addSensorGlucose` handler, BEFORE the existing alarm check:
  - Guard `state.showPredictiveLowAlarm` is enabled
  - Guard `!state.predictiveLowAlarmFired` (once-per-episode)
  - Guard glucose is above alarmLow (R4) — if already low, the existing alarm handles it
  - Guard minuteChange is non-nil and reading is <5 min old (R8b)
  - Compute smoothed minuteChange: average of last 3 `sensorGlucoseValues` that have non-nil minuteChange
  - Compute `predictedGlucose = currentGlucose + (smoothedMinuteChange * 20)`
  - If `predictedGlucose < alarmLow`: dispatch `.showTreatmentPrompt(alarmFiredAt: Date())` AND a new action `.setPredictiveLowAlarmFired(fired: true)`
  - CRITICAL: Do NOT return `.setAlarmSnoozeUntil` — the predictive alarm must not autosnooze
- Clearing the flag: when glucose rises above `alarmLow + 10`, dispatch `.setPredictiveLowAlarmFired(fired: false)`. This happens in the same `.addSensorGlucose` handler.
- The existing alarm logic (actual low/high) runs unchanged after the prediction check

**Patterns to follow:**
- Existing alarm check flow in GlucoseNotification (isAlarm, isSnoozed, notification dispatch)
- Treatment cycle's cross-middleware pattern for `.addSensorGlucose`

**Test scenarios:**
- Happy path: glucose=90, minuteChange=-2.0, smoothed=-1.8 → predicted=90+(-1.8*20)=54 → fires (below alarmLow=70)
- Happy path: glucose=90, minuteChange=-0.5 → predicted=80 → does NOT fire (above 70)
- Edge case: glucose already below alarmLow → prediction skipped, existing alarm handles
- Edge case: minuteChange is nil → prediction skipped
- Edge case: reading is 6 minutes old → prediction skipped (staleness guard)
- Edge case: predictiveLowAlarmFired=true → prediction not re-fired
- Edge case: glucose rises to alarmLow+11 → flag cleared, can re-fire on next drop
- Integration: prediction fires `.showTreatmentPrompt` → treatment modal appears (via OverviewView)
- Safety: prediction does NOT dispatch `.setAlarmSnoozeUntil` — actual alarm still fires when glucose truly crosses

**Verification:** Prediction fires before threshold crossing. Actual alarm still fires independently. No autosnooze from prediction.

---

- [ ] **Unit 3: Predictive Notification Category + Handler**

**Goal:** Register a distinct notification category for predictive alarms and route actions to the treatment workflow.

**Requirements:** R5, R6

**Dependencies:** Unit 2

**Files:**
- Modify: `App/App.swift` (register category, update didReceive)
- Modify: `App/Modules/GlucoseNotification/GlucoseNotification.swift` (use category on predictive notification)

**Approach:**
- Register `predictiveLowAlarm` category in `applicationDidFinishLaunching` alongside existing `lowGlucoseAlarm`
- Actions: `"eatNow"` (title: "EAT NOW", foreground), `"moreOptions"` (title: "More...", foreground)
- Notification content: title "Trending Low", body "Glucose predicted to drop below X in ~N minutes. Eat now to prevent a low."
- Sound: `.default` (softer than the existing alarm's `.defaultCritical`)
- interruptionLevel: `.timeSensitive`
- Set `categoryIdentifier = "predictiveLowAlarm"` on the predictive notification
- In `didReceive`: handle `"eatNow"` same as `"tookDextro"` — dispatch `.logHypoTreatment` with default favorite
- Store `alarmFiredAt` in notification userInfo (same pattern as existing)

**Patterns to follow:**
- Existing `lowGlucoseAlarm` category registration in App.swift
- Existing `didReceive` handler routing

**Test scenarios:**
- Happy path: predictive notification shows "Trending Low" with EAT NOW and More... buttons
- Happy path: tapping EAT NOW logs default hypo treatment and starts cycle
- Happy path: tapping notification body does NOT snooze (different from low alarm body tap)
- Edge case: no hypo treatment favorites → falls through to `.showTreatmentPrompt`

**Verification:** Predictive notification visually distinct from actual low alarm. Action buttons work.

---

- [ ] **Unit 4: Chart Projection Line**

**Goal:** Render a dashed 20-minute projection line on the glucose chart.

**Requirements:** R9, R10, R11

**Dependencies:** None (independent of alarm logic)

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`

**Approach:**
- Add a `LineMark` after the glucose series rendering, guarded by `if #available(iOS 16, *)`
- Two data points: (latestTimestamp, latestGlucose) → (latestTimestamp + 20min, predictedGlucose)
- Compute smoothed minuteChange same as Unit 2 (extract to a helper or compute in updateSeries)
- Style: `.lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))` — dashed line
- Color: use `AmberTheme.glucoseColor(forValue: predictedEndpoint, low: alarmLow, high: alarmHigh)` — matches existing glucose coloring
- Only render when: latestSensorGlucose has non-nil minuteChange AND timestamp is <5 min old
- R11 crossing marker: add a `PointMark` at the intersection of projection line and alarmLow rule. Compute intersection time: `minutesToCrossing = (alarmLow - currentGlucose) / minuteChange`. Place at `(latestTimestamp + minutesToCrossing, alarmLow)`. Use `symbolSize(80)`, `.symbol(.cross)`, cgaRed color. Only show when projection actually crosses alarmLow.

**Patterns to follow:**
- Existing `LineMark` rendering for glucose in ChartView
- `AmberTheme.glucoseColor()` for color derivation

**Test scenarios:**
- Happy path: stable glucose at 120, minuteChange=-1.0 → dashed line slopes down from 120 to 100, green color
- Happy path: glucose=85, minuteChange=-1.5 → line slopes to 55, crosses alarmLow=70, red color, crossing marker visible
- Edge case: minuteChange is nil → no projection line rendered
- Edge case: reading is 6 min old → no projection line rendered
- Edge case: minuteChange is positive (rising) → line slopes up, green, no crossing marker
- Edge case: glucose already below alarmLow → projection line still renders (shows continued trajectory)

**Verification:** Dashed line visible on chart. Colors match glucose zones. Crossing marker appears when projection crosses threshold.

---

- [ ] **Unit 5: Settings Toggle**

**Goal:** Add predictive alarm toggle to alarm settings UI.

**Requirements:** R12

**Dependencies:** Unit 1

**Files:**
- Modify: `App/Views/Settings/AlarmSettingsView.swift`

**Approach:**
- Add a Toggle row for "Predictive low alarm" in the alarm settings section, near the existing alarm toggles
- Bound to `store.state.showPredictiveLowAlarm`
- Dispatches `.setShowPredictiveLowAlarm(enabled:)` on change
- Footer text: "Warns before glucose is predicted to drop below your low alarm threshold"

**Patterns to follow:**
- Existing Toggle patterns in AlarmSettingsView (e.g., `hasLowGlucoseAlarm`)

**Test scenarios:**
- Happy path: toggle off → predictive alarm does not fire, projection line still visible
- Happy path: toggle on → predictive alarm fires when trend predicts low

**Verification:** Toggle visible in settings. Persists across restart. Controls alarm firing.

## System-Wide Impact

- **Interaction graph:** GlucoseNotification middleware gains prediction logic on `.addSensorGlucose` (already handles actual alarms). TreatmentCycleMiddleware receives `.showTreatmentPrompt` from predictive alarms (same as existing). OverviewView presents treatment modal from `.showTreatmentPrompt`.
- **Error propagation:** Prediction failure (nil minuteChange, stale data) silently skips — no alarm fires, no error surfaced. This is the safe default.
- **State lifecycle risks:** `predictiveLowAlarmFired` is transient — resets on app restart. If the app restarts during a downtrend, the prediction will re-fire once, which is acceptable.
- **Unchanged invariants:** Existing low alarm behavior is completely unchanged. Actual alarm still fires independently of prediction. Autosnooze only from actual alarms.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| False positives from noisy minuteChange | Rolling 3-reading average smooths noise. Once-per-episode dedup prevents alarm spam. |
| Predictive alarm suppresses actual alarm via autosnooze | R8a: prediction explicitly does NOT dispatch autosnooze. Tested in Unit 2. |
| Treatment cycle recheck shows "STABILISED" when user was never actually low | Acceptable for V1 — the cycle prevented a low, which is success. Can refine banner copy later. |
| Sensor lag makes 20-min prediction effectively 5-10 min actual lead time | Acknowledged — still better than zero lead time from current threshold alarms. |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-17-predictive-low-alarm-requirements.md](docs/brainstorms/2026-04-17-predictive-low-alarm-requirements.md)
- **Linear issue:** DMNC-686
- Related code: `App/Modules/GlucoseNotification/GlucoseNotification.swift`, `Library/Content/SensorGlucose.swift`
