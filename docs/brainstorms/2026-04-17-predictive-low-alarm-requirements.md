---
date: 2026-04-17
topic: predictive-low-alarm
---

# Predictive Low Alarm (Trend-Based Early Warning)

## Problem Frame

Current low glucose alarms fire when glucose crosses the `alarmLow` threshold — but by that point, the Libre sensor's interstitial lag (5-15 min) means blood glucose was already low 10+ minutes ago. The user is reactive, not proactive. The Rule of 15 treatment workflow helps *after* a low is detected, but doesn't prevent lows from happening.

A predictive alarm uses the existing rate-of-change data (`minuteChange` on SensorGlucose) to extrapolate where glucose is heading and warn before the threshold is crossed — giving the user time to eat carbs and prevent the low entirely.

## Requirements

**Prediction Engine**

- R1. The app extrapolates glucose trajectory using the latest `minuteChange` value, projecting forward 20 minutes.
- R2. When the projected glucose value crosses below `alarmLow` within the prediction window, a predictive low alarm fires.
- R3. The prediction uses simple linear extrapolation: `predictedGlucose = currentGlucose + (minuteChange * 20)`. No complex curve fitting in V1.
- R4. The prediction only fires when glucose is still above `alarmLow` (actual) — if glucose has already crossed the threshold, the existing alarm handles it, not the predictive one.

**Alarm Behavior**

- R5. The predictive low alarm integrates with the existing treatment workflow: notification offers "Trending low — treat now?" with the TREAT NOW action button, same as the current low alarm treatment prompt.
- R6. The predictive alarm is visually and audibly distinct from the actual low alarm — different notification text, softer sound. The user should know this is a *prediction*, not a confirmed low.
- R7. If the user treats via the predictive alarm (enters the treatment cycle), the treatment cycle's existing alarm suppression handles repeat notifications. No separate predictive alarm snooze in V1.
- R8. If the predictive alarm fires but glucose levels off or rises (false positive), no harm — the alarm naturally doesn't repeat since the prediction no longer crosses the threshold.
- R8a. The predictive alarm must NOT trigger the existing 5-minute autosnooze (`setAlarmSnoozeUntil`). If a predictive alarm fires and the user ignores it, the actual low alarm must still fire when glucose truly crosses `alarmLow`. The predictive alarm is a warning, not a gating event for the real alarm.
- R8b. When `minuteChange` is nil (first reading after launch, sensor reconnect, data gap), the prediction does not fire and the projection line is not shown. No fallback or approximation — wait for the next reading with valid trend data.
- R8c. If the user ignores the predictive alarm and it continues to predict a crossing on subsequent readings, it should not re-fire more than once per prediction episode. A new predictive alarm fires only after the prediction resolves (glucose rises or the actual low alarm fires and handles it).

**Chart Visualization**

- R9. The chart shows a dashed projection line extending 20 minutes forward from the latest glucose reading when `minuteChange` is available (non-nil) and the latest reading is less than 5 minutes old. Hidden when data is stale or trend unavailable.
- R10. The projection line uses the existing glucose color at the predicted endpoint (green if in-range, red if predicted to cross low/high threshold, amber if in transition zone).
- R11. When the projection line crosses the `alarmLow` threshold line on the chart, the crossing point is visually highlighted (e.g., a dot or marker where the projection intersects the threshold).

**Settings**

- R12. Predictive low alarm can be toggled on/off independently in alarm settings (default: on).
- R13. The prediction window (default 20 min) is not user-configurable in V1 — hardcoded constant that can be made configurable later.

## Success Criteria

- User receives a warning notification 10-20 minutes *before* glucose drops below `alarmLow`, with enough lead time to eat carbs and prevent the low
- The projection line on the chart provides constant visual awareness of glucose trajectory
- False positive rate is tolerable — prediction naturally self-corrects when trend changes
- Treating from a predictive alarm enters the same treatment cycle as a real low alarm

## Scope Boundaries

- **Not in scope:** Predictive high alarm (lows only in V1 — highs are less time-critical)
- **Not in scope:** Configurable prediction window (hardcoded at 20 min, constant can be changed later)
- **Not in scope:** Non-linear prediction models (quadratic extrapolation, ML — simple linear is fine for V1)
- **Not in scope:** Separate predictive alarm snooze (reuses treatment cycle suppression)
- **Not in scope:** Historical prediction accuracy tracking
- **Not in scope:** Projection line on ChartViewCompatibility (iOS 15 fallback) — Swift Charts only (iOS 16+). The predictive alarm notification still fires on iOS 15, just no visual line.

## Key Decisions

- **Focus on lows only:** Hypoglycemia is the dangerous direction. Highs are annoying but not an emergency. Predictive high alarms can be added later using the same infrastructure.
- **20-min prediction window:** Enough lead time for carbs to absorb (~15 min for glucose tabs) plus some margin. Conservative enough to limit false positives.
- **Linear extrapolation:** Simple and transparent. The user can visually verify: "I can see the line heading down toward the threshold." Complex models are a black box. Good enough for V1.
- **Integration with treatment workflow:** The predictive alarm becomes the *pre-emptive entry point* to the treatment cycle. This is the key insight — you're treating lows before they happen, not after. The existing treatment infrastructure (notification actions, TreatmentModalView, countdown, recheck) is fully reused.
- **Projection line always visible:** Builds trust in the prediction system. User can see the extrapolation and judge for themselves. Also useful even when no alarm is firing — constant trajectory awareness.
- **Reuse treatment cycle suppression:** Avoids new snooze complexity. If the user treats, the cycle handles everything. Can revisit with a separate predictive snooze if real-world use reveals a gap.

## Dependencies / Assumptions

- `SensorGlucose.minuteChange` is reliably populated (verified: computed from consecutive readings in `SensorGlucose.swift`)
- The treatment workflow (Rule of 15) is complete and working (shipped in build 49)
- `UNNotificationCategory` with action buttons is already registered for low glucose alarms (shipped in build 49)
- Sensor readings arrive at regular intervals (typically every 1-5 minutes depending on connection type)

## Outstanding Questions

### Deferred to Planning

- [Affects R3][Technical] Should the extrapolation use a smoothed `minuteChange` (average of last 3-5 readings) to reduce noise, or the raw latest value? Raw is simpler but noisier.
- [Affects R5][Technical] Should the predictive alarm use the existing `"lowGlucoseAlarm"` notification category (same TREAT NOW button) or a new category with different action labels (e.g., "EAT NOW" vs "TREAT NOW")?
- [Affects R9][Technical] How to render the dashed projection line in Swift Charts (iOS 16+ `LineMark` with dash style) and whether ChartViewCompatibility (iOS 15 fallback) should show it
- [Affects R6][Technical] Which sound to use for the predictive alarm — a distinct softer tone, or the existing alarm sound at lower volume?
- [Affects R2][Technical] Best place to evaluate the prediction: inside GlucoseNotification middleware (alongside existing alarm logic) or in a new PredictiveLowMiddleware

## Next Steps

-> `/ce:plan` for structured implementation planning
