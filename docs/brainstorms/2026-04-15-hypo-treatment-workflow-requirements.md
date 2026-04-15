---
date: 2026-04-15
topic: hypo-treatment-workflow
---

# Low Glucose Treatment Workflow ("Rule of 15")

## Problem Frame

When glucose drops below the low alarm threshold, the user needs to act quickly: consume fast-acting carbs, wait, and recheck. Today the app fires an alarm and shows a generic message ("With sweetened drinks or dextrose, blood glucose levels can often return to normal"), but offers no structured guidance. The user must mentally track whether they treated, when they treated, and when to recheck. In a stressful low-glucose moment, this cognitive load is unnecessary — the app already has the data to guide the process.

The diabetes community's "Rule of 15" provides a well-known protocol: consume 15g fast carbs, wait 15 minutes, recheck. If still low, repeat. DOSBTS should make this effortless.

## Requirements

**Trigger & Entry**

- R1. When a low glucose alarm fires, treatment actions are presented on two surfaces:
  - **Background/lock screen:** UNNotificationAction buttons ("TOOK DEXTRO", "More...") on the system notification. Requires building UNNotificationCategory infrastructure (currently absent).
  - **Foreground:** An in-app treatment modal presented over OverviewView with the same actions.
- R2. The "More..." action dismisses any active modal first, then presents UnifiedFoodEntryView filtered to `isHypoTreatment` items as a new sheet from the root view (avoids nested sheet constraint). Note: UnifiedFoodEntryView needs a new `filterToHypoTreatments: Bool` parameter.
- R3. The workflow is offered automatically when a low alarm fires. The treatment cycle activates only when the user logs a treatment (not on alarm fire alone). If the user snoozes without logging treatment (R14), no cycle starts.

**Treatment Logging**

- R4. Tapping the quick-action button logs a MealEntry using the user's default hypo treatment favorite. The "default" is determined by the lowest `sortOrder` among `isHypoTreatment` favorites. If no `isHypoTreatment` favorite exists, the quick-action button is hidden and only "More..." is shown.
- R5. If more than 5 minutes have elapsed since the alarm fired, the app shows an inline time picker (not a separate sheet) defaulting to now: "When did you actually take this?" The picker is dismissible with a single "Just now" tap. This requires a new `alarmFiredAt: Date?` state property to track when the last low alarm fired.
- R6. Logging any `isHypoTreatment` food through the "More..." path also enters the treatment cycle, same as the quick-action. Logging a non-hypo food does NOT trigger the cycle.

**Countdown & Recheck**

- R7. After treatment is logged, a 15-minute countdown begins. The app suppresses repeat low-glucose alarms during this window, with one exception: if glucose drops below a critical-low floor (`alarmLow - 15 mg/dL`), the alarm breaks through suppression. This is new safety behavior — the existing 5-min auto-snooze has no floor.
- R7a. OverviewView displays a persistent treatment-cycle banner during the countdown: "HYPO TREATMENT ACTIVE — recheck in Xm". The banner includes a dismiss button. Placed between the hero glucose display and the chart.
- R8. At countdown expiry, behavior depends on app state:
  - **Foreground:** The app automatically checks the current glucose reading against `alarmLow` and shows R9/R10 result inline.
  - **Background:** A scheduled local notification fires: "Time to recheck your glucose." Tapping it opens the app, which then performs the glucose check and shows R9/R10.
- R9. If glucose has recovered (at or above threshold): show a "Glucose stabilised at X" confirmation and end the cycle.
- R10. If glucose is still below threshold: prompt "Still low at X — treat again?" with options to log another treatment (restarting the cycle) or dismiss.
- R11. The recheck uses whatever glucose reading the app currently has — no special sensor poll.

**Cycle Behavior**

- R12. Multiple treatment cycles can chain: each "treat again" action logs a new MealEntry and resets the 15-minute countdown.
- R13. The user can dismiss/cancel the cycle at any point. Dismissing clears all treatment-cycle state and re-enables low-glucose alarms immediately.
- R14. If the user manually snoozes the alarm before logging treatment, no treatment cycle starts. The user can still log a treatment manually via the regular food logging flow, which will start a treatment cycle.

**Data & Future Analysis**

- R15. Each treatment event captures: alarm_fired_at, treatment_logged_at, treatment_type (which favorite), carbs_grams, and the glucose value at treatment time. This requires either new columns on MealEntry or a dedicated TreatmentEvent model — the "no new data stores" claim is incorrect and this decision is deferred to planning.
- R16. The glucose curve after treatment is already captured by existing sensor data. Combined with R15's treatment timestamps, no additional sensor data collection is needed for future correlation analysis.
- R17. R15's data capture is in V1 scope and fully enables future treatment→rise correlation analysis (e.g. "Your glucose typically starts rising ~N min after Dextro"). The analysis UI/visualization is not in V1 scope.

**Settings**

- R18. Wait time is configurable in settings (default: 15 minutes). Presented as a simple picker. Requires the standard 4-file UserDefaults-backed property pattern (`hypoTreatmentWaitMinutes: Int`).
- R19. The default hypo treatment favorite is implicitly the lowest-sortOrder `isHypoTreatment` item. Users reorder favorites via the existing favorites management UI to change which one is "default."

**State Persistence**

- R20. Treatment cycle state (alarmFiredAt, treatmentLoggedAt, countdownExpiry, cycleActive) persists to UserDefaults so it survives app kill/restart. On relaunch, the app resumes the cycle if countdown hasn't expired, or immediately triggers recheck if it has.

## Success Criteria

- Low alarm → treatment logged → recheck reminder completes in ≤3 taps for the common case (quick-action path)
- Treatment timestamps are accurate enough to support future absorption analysis (R5 nudge ensures this)
- Repeat treatment cycles work reliably when glucose doesn't recover after first treatment
- The workflow feels like guidance, not enforcement — dismissable at every step (R13)
- Critical-low floor (R7) ensures safety is never compromised by alarm suppression

## Scope Boundaries

- **Not in scope:** Treatment→rise correlation analysis/visualization UI (R17 — data is captured, analysis is future work)
- **Not in scope:** Blog article about absorption timing research (separate personal research project)
- **Not in scope:** Custom alarm thresholds per treatment type
- **Not in scope:** Apple Watch companion for the treatment workflow
- **Not in scope:** Integration with insulin logging (treating lows is carb-only)

## Key Decisions

- **Auto-offer on alarm, activate on treatment log:** Reduces friction in a stressful moment. The workflow is always dismissable. Snoozing without treating does not start a cycle.
- **Two UI surfaces (notification actions + in-app modal):** Covers both background and foreground scenarios. More implementation work but complete coverage.
- **Foreground-only auto-check, background generic reminder:** Avoids the iOS limitation where local notifications can't execute app code. Background recheck is a simple "Time to recheck" notification.
- **Critical-low floor on alarm suppression:** If glucose drops below `alarmLow - 15`, the alarm breaks through treatment-cycle suppression. New safety behavior for the 3x longer suppression window.
- **Rule of 15 as default (15g / 15 min):** Most widely cited in clinical guidelines. Configurable for users who prefer different timing.
- **Nudge for timestamp accuracy at >5 min:** Balances data quality with UX. Inline time picker, dismissible with single tap. Threshold raised from 3 to 5 min to account for impaired state during hypo.
- **Default hypo treatment = lowest sortOrder:** No new `isDefault` flag needed. Reorder favorites to change the default.
- **Dismiss-then-present for "More..." path:** Avoids nested sheet constraint from CLAUDE.md.
- **R15 data capture is V1 scope:** The treatment metadata (alarm_fired_at, treatment_logged_at, etc.) must be built now to enable future analysis. Model choice (extend MealEntry vs. new TreatmentEvent) deferred to planning.
- **Cycle state persists to UserDefaults:** Survives app kill. 15-minute countdown is too long to risk losing on background termination.

## Dependencies / Assumptions

- Low glucose alarm notification system is working and delivers reliably (existing)
- FavoriteFood with isHypoTreatment=true is seeded on first launch (existing: "Dextrose tabs" 15g, "Juice box" 25g). Note: current seed guard checks `count == 0` across ALL favorites — existing users who already have favorites won't get hypo items seeded. This needs a migration or separate seed check.
- iOS local notification scheduling (UNTimeIntervalNotificationTrigger) is reliable for the background recheck reminder
- UNNotificationCategory/UNNotificationAction infrastructure does not exist yet and must be built from scratch

## Outstanding Questions

### Deferred to Planning

- [Affects R1][Technical] UNNotificationCategory registration, UNNotificationAction definitions, categoryIdentifier on notification content, and rewritten didReceive response handler — all prerequisites for notification action buttons
- [Affects R7][Technical] Best way to implement treatment-cycle alarm suppression vs. user-initiated snooze — likely needs separate `treatmentSnoozeUntil` state (R14 requires distinguishing the two)
- [Affects R8][Technical] Background notification scheduling for recheck — reuse ExpiringNotification pattern or create a new module
- [Affects R15][Needs research] Whether to add a dedicated TreatmentEvent model or extend MealEntry with nullable treatment columns. Both require GRDB migration.
- [Affects R6][Technical] How UnifiedFoodEntryView signals back that an `isHypoTreatment` food was logged (to trigger cycle start) — needs a callback or action flag
- [Affects R7a][Technical] Where in the OverviewView layout the treatment-cycle banner sits and how it interacts with the existing snooze view

## Next Steps

-> `/ce:plan` for structured implementation planning
