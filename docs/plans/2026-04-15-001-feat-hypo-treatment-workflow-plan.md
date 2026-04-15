---
title: "feat: Low Glucose Treatment Workflow (Rule of 15)"
type: feat
status: active
date: 2026-04-15
origin: docs/brainstorms/2026-04-15-hypo-treatment-workflow-requirements.md
---

# feat: Low Glucose Treatment Workflow (Rule of 15)

## Overview

Add a guided treatment cycle when the low glucose alarm fires: one-tap logging of hypo treatment foods, a 15-minute countdown with alarm suppression (plus critical-low safety floor), automatic recheck of glucose at expiry, and repeat-cycle support. Treatment metadata is captured for future absorption analysis.

## Problem Frame

When glucose drops below the low alarm threshold, the user must mentally track whether they treated, when, and when to recheck. The app fires an alarm with a generic message but offers no structured guidance. The "Rule of 15" protocol (15g carbs, wait 15 min, recheck) is well-known in the diabetes community — DOSBTS should make it effortless. (see origin: `docs/brainstorms/2026-04-15-hypo-treatment-workflow-requirements.md`)

## Requirements Trace

- R1. Notification actions (background) + in-app modal (foreground) for treatment logging
- R2. "More..." opens UnifiedFoodEntryView filtered to isHypoTreatment items
- R3. Workflow offered automatically on low alarm; cycle activates on treatment log
- R4. Quick-action logs default hypo treatment (lowest sortOrder among isHypoTreatment)
- R5. Timestamp nudge at >5 min with inline dismissible time picker
- R6. Logging isHypoTreatment food via "More..." also enters cycle
- R7. 15-min countdown with alarm suppression + critical-low floor (alarmLow - 15)
- R7a. Persistent countdown banner in OverviewView between hero and chart
- R8. Foreground-only auto-check; background fires generic "Time to recheck" notification
- R9/R10. Stabilised confirmation or "treat again" prompt based on glucose vs threshold
- R11. Recheck uses current glucose — no special sensor poll
- R12. Chained cycles: "treat again" logs new entry, resets countdown
- R13. Dismiss clears all cycle state and re-enables alarms immediately
- R14. Snooze without treatment = no cycle; manual treatment via regular flow still starts cycle
- R15. Treatment metadata: alarm_fired_at, treatment_logged_at, treatment_type, carbs_grams, glucose_at_treatment
- R17. Data capture enables future correlation analysis (UI not in V1 scope)
- R18. Configurable wait time (default 15 min), 4-file UserDefaults pattern
- R19. Default treatment = lowest sortOrder isHypoTreatment item
- R20. Cycle state persists to UserDefaults across app kill/restart

## Scope Boundaries

- Treatment→rise correlation analysis/visualization UI (data captured, analysis is future work)
- Apple Watch companion
- Custom alarm thresholds per treatment type
- Integration with insulin logging

## Context & Research

### Relevant Code and Patterns

- **Notification middleware:** `App/Modules/GlucoseNotification/GlucoseNotification.swift` — fires low/high alarms, auto-snoozes 5 min, sets `userInfo["action": "snooze"]`. No `UNNotificationCategory` or `UNNotificationAction` exists anywhere.
- **Notification delegate:** `App/App.swift` lines 90-110 — `willPresent` and `didReceive` handlers. `didReceive` only checks `userInfo["action"]`, does not use `response.actionIdentifier`.
- **Notification service:** `Library/DirectNotifications.swift` — `addNotification`, `removeNotification`, sound/haptic.
- **Snooze state:** `alarmSnoozeUntil: Date?`, `alarmSnoozeKind: Alarm?` in DirectState. Reducer clears sound on snooze set. `isSnoozed()` checks date + kind match.
- **FavoriteFood model:** `Library/Content/FavoriteFood.swift` — has `isHypoTreatment: Bool`, `sortOrder: Int`. Seeded with "Dextrose tabs" (15g) and "Juice box" (25g) but only when total count == 0.
- **MealEntry model:** `Library/Content/MealEntry.swift` — id, timestamp, mealDescription, carbsGrams, protein/fat/calories/fiber, timegroup.
- **Meal store:** `App/Modules/DataStore/MealStore.swift` — GRDB middleware, handles addMealEntry/deleteMealEntry/load.
- **Favorite store:** `App/Modules/DataStore/FavoriteStore.swift` — CRUD, seed, reorder. `logFavoriteFood` updates `lastUsed`.
- **UnifiedFoodEntryView:** `App/Views/AddViews/UnifiedFoodEntryView.swift` — shows favorites (green for hypoTreatment), recent meals, action buttons. No filter parameter currently.
- **OverviewView:** `App/Views/OverviewView.swift` — List with GlucoseView → ChartView → ConnectionView → SensorView, plus StickyQuickActions bottom bar. Sheets attached to individual buttons via @State bools.
- **Expiring notification pattern:** `App/Modules/ExpiringNotification/ExpiringNotification.swift` — timer-based notification with `nextExpiredAlert` guard.
- **4-file UserDefaults pattern:** DirectState (protocol) → AppState (didSet) → UserDefaults+Keys (key + computed property) → DirectReducer (case).
- **Middleware registration:** Two arrays in App.swift (device line ~165, simulator line ~119) — both must be updated.

### Institutional Learnings

- **Nested sheets:** Never present `.sheet` from within a `.sheet`. Use `NavigationLink` for sub-navigation. Also: sibling `.sheet()` modifiers on the same parent collide on iOS 15 — use single `.sheet(item:)` with enum discriminator. (see `docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`)
- **appState guards:** All DataStore middlewares must handle `.setAppState(.active)` to trigger load AND guard `.active` before DB reads. Without this, data silently fails to load on device. (see `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`)
- **Undo UUID:** Entity must be created at the view level (not middleware) if undo is needed. (see `docs/solutions/logic-errors/redux-undo-uuid-mismatch-middleware-creates-object-20260315.md`)
- **Future promise:** Every early-exit in a `Future` closure must call `promise(...)` or the Combine subscriber hangs. (see `docs/solutions/logic-errors/grdb-future-nil-dbqueue-hangs-subscriber-20260318.md`)
- **Reducer-first ordering:** Never guard middleware on state the reducer just changed for the triggering action. (see `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`)

## Key Technical Decisions

- **TreatmentEvent as separate GRDB model (not MealEntry columns):** MealEntry would gain 4+ nullable columns used only for treatment context. A dedicated TreatmentEvent model with a `mealEntryId` foreign key is cleaner — it stores alarm_fired_at, treatment_logged_at, glucose_at_treatment, and links to the MealEntry for carbs/description. Keeps MealEntry untouched.
- **Separate `treatmentCycleSnoozeUntil` state (not reuse `alarmSnoozeUntil`):** R14 requires distinguishing user-initiated snooze from treatment-cycle suppression. A separate property avoids conflict with the existing snooze mechanism.
- **Treatment cycle state in UserDefaults (not GRDB):** The active cycle is ephemeral session state (one active cycle at a time), not historical data. UserDefaults is simpler and matches the snooze pattern. TreatmentEvent (historical) goes to GRDB.
- **Default hypo treatment = lowest sortOrder isHypoTreatment:** No new isDefault flag needed. If none exist, quick-action hidden.
- **Notification category built from scratch:** Register `UNNotificationCategory` with "tookDextro" and "moreOptions" actions in App.swift's `applicationDidFinishLaunching`. Set `categoryIdentifier` on low glucose notification content. Rewrite `didReceive` to switch on `response.actionIdentifier`.
- **Dismiss-then-present for "More..." path:** The notification action or in-app modal triggers state that OverviewView observes, dismissing the treatment modal first, then presenting UnifiedFoodEntryView as a separate sheet — avoiding nested sheets.
- **Seed guard fix:** Change FavoriteStore seed check from `count == 0` (all favorites) to a separate check for `isHypoTreatment` count, so existing users get hypo treatments seeded.

## Open Questions

### Resolved During Planning

- **TreatmentEvent vs MealEntry extension:** Separate model. MealEntry stays clean, TreatmentEvent stores treatment-specific metadata with a foreign key to MealEntry.
- **Treatment snooze vs alarm snooze:** Separate `treatmentCycleSnoozeUntil: Date?` property. GlucoseNotification middleware checks BOTH `isSnoozed(alarm:)` AND the treatment snooze before firing alarms: `if isSnoozed || isTreatmentSnoozed { suppress }`. This ensures the alarm doesn't re-trigger at the 5-min auto-snooze expiry while a 15-min treatment cycle is active.
- **Alarm suppression scope:** Treatment-cycle suppression matches existing snooze behavior — suppress sound/haptic only, notification banners continue firing. This keeps the user informed of readings during the wait. Critical-low floor breaks through with full alarm (sound + banner).
- **alarmFiredAt trigger mechanism:** GlucoseNotification middleware dispatches a new `.showTreatmentPrompt(alarmFiredAt: Date)` action when a low alarm fires and user hasn't snoozed. This sets a transient `showTreatmentPrompt: Bool` state (NOT persisted to UserDefaults) that OverviewView observes to present the treatment modal. The `alarmFiredAt` Date is passed through this action and later forwarded to `.logHypoTreatment`.
- **Recheck result UI:** Recovered → banner transitions to "STABILISED AT X" (auto-dismisses after 5 seconds). Still low → re-triggers TreatmentModalView with current glucose and "TREAT AGAIN" as primary action.
- **Notification body tap:** Keeps existing 30-minute snooze behavior. Treatment workflow is accessible via the notification action buttons only.
- **Recheck staleness:** If countdown expired and no glucose reading arrives within 5 minutes, banner shows "NO RECENT DATA — CHECK SENSOR" instead of waiting indefinitely.
- **How UnifiedFoodEntryView signals treatment log:** No callback needed. TreatmentCycleMiddleware handles `.addMealEntry` (cross-middleware listening) — when a treatment cycle is pending and the logged food is `isHypoTreatment`, the middleware dispatches `.startTreatmentCycle`. OverviewView observes `store.state.treatmentCycleActive` via Redux, avoiding a second signalling channel.

### Deferred to Implementation

- Exact banner animation/transition for the countdown display
- Whether the countdown timer uses a `Timer` publisher or relies on `TimelineView` (iOS 15 fallback needed)
- Precise layout of the timestamp nudge inline picker

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
LOW ALARM FIRES
    │
    ├─▶ GlucoseNotification middleware dispatches .showTreatmentPrompt(alarmFiredAt: Date)
    │   (sets transient showTreatmentPrompt state — NOT persisted)
    │
    ├─[Background]──▶ System notification with actions:
    │                  [TOOK DEXTRO] [MORE...] (body tap = existing 30-min snooze)
    │                       │            │
    │                       │            └─▶ Opens app → UnifiedFoodEntryView (hypo filter)
    │                       │
    │                       └─▶ didReceive → dispatch .logHypoTreatment(default favorite)
    │
    ├─[Foreground]──▶ OverviewView observes showTreatmentPrompt → presents TreatmentModalView:
    │                  [TOOK DEXTRO] [MORE...] [DISMISS]
    │                       │            │
    │                       │            └─▶ Dismiss modal → present UnifiedFoodEntryView
    │                       │
    │                       └─▶ dispatch .logHypoTreatment(default favorite)
    │
    ▼
.logHypoTreatment ACTION
    │
    ├─▶ Reducer: set treatmentCycleActive, alarmFiredAt, treatmentLoggedAt, countdownExpiry
    ├─▶ TreatmentMiddleware: create MealEntry + TreatmentEvent in GRDB
    ├─▶ TreatmentMiddleware: schedule recheck notification (UNTimeIntervalNotificationTrigger)
    ├─▶ TreatmentMiddleware: set treatmentCycleSnoozeUntil = countdownExpiry
    │
    ▼
COUNTDOWN (15 min)
    │
    ├─ OverviewView: shows treatment banner with live countdown
    ├─ Low alarms suppressed UNLESS glucose < (alarmLow - 15) [critical floor]
    │
    ▼
COUNTDOWN EXPIRES
    │
    ├─[Foreground]──▶ Middleware detects on next glucose reading:
    │                  Compare latestSensorGlucose vs alarmLow
    │                  ├─ Above threshold → dispatch .treatmentCycleRecovered(glucose)
    │                  └─ Below threshold → dispatch .treatmentCycleStillLow(glucose)
    │
    ├─[Background]──▶ Scheduled notification: "Time to recheck your glucose"
    │                  User taps → app opens → same check runs on next glucose
    │
    ▼
RESULT
    ├─ Recovered → Banner transitions to "STABILISED AT X" (cgaGreen, auto-dismiss 5s) → cycle ends
    ├─ Still low → Re-trigger TreatmentModalView: "STILL LOW AT X — TREAT AGAIN?" → restarts cycle
    └─ No data  → Banner shows "NO RECENT DATA — CHECK SENSOR" (if no glucose for >5 min)
```

## Implementation Units

- [ ] **Unit 1: TreatmentEvent Model + GRDB Store**

**Goal:** Create the data model and persistence layer for treatment events.

**Requirements:** R15, R17

**Dependencies:** None

**Files:**
- Create: `Library/Content/TreatmentEvent.swift`
- Modify: `App/Modules/DataStore/DataStore.swift` (add FetchableRecord/PersistableRecord extension)
- Create: `App/Modules/DataStore/TreatmentEventStore.swift` (table creation, CRUD, middleware)
- Modify: `Library/DirectAction.swift` (add treatment actions)
- Note: TreatmentEvent is write-only in V1 (no UI consumer). Skip adding treatmentEventValues to DirectState/AppState/DirectReducer — only implement the GRDB insert path in TreatmentCycleMiddleware. Add state array plumbing when correlation analysis UI is scoped.
- Modify: `App/App.swift` (register middleware in both arrays)
- Modify: `DOSBTS.xcodeproj/project.pbxproj` (add new files)
- Test: Manual — verify table creation on app launch, insert/query treatment events

**Approach:**
- TreatmentEvent struct: id (UUID), mealEntryId (UUID), alarmFiredAt (Date), treatmentLoggedAt (Date), treatmentType (String — description from favorite), glucoseAtTreatment (Int), countdownMinutes (Int)
- GRDB table with id as PK, mealEntryId indexed
- Middleware follows MealStore pattern: handle `.startup` for table creation, `.setAppState(.active)` for load trigger, guard `.active` on loads
- All Future closures must resolve promise on every path (including dbQueue == nil)

**Patterns to follow:**
- `App/Modules/DataStore/MealStore.swift` — table creation, CRUD middleware
- `Library/Content/MealEntry.swift` — model struct pattern
- `App/Modules/DataStore/DataStore.swift` — FetchableRecord extension pattern

**Test scenarios:**
- Happy path: Create TreatmentEvent linked to MealEntry, query by date range, verify all fields persisted
- Edge case: Create TreatmentEvent when dbQueue is nil — should not hang (Future resolves with empty)
- Integration: `.setAppState(.active)` triggers load, values appear in state

**Verification:** TreatmentEvent can be written and read back from GRDB. Middleware loads events on app activation.

---

- [ ] **Unit 2: Treatment Cycle State + Redux Actions**

**Goal:** Add all state properties, actions, and reducer cases for the treatment cycle lifecycle.

**Requirements:** R7, R13, R18, R20

**Dependencies:** None (Unit 3 gates on both Unit 1 and Unit 2)

**Files:**
- Modify: `Library/DirectState.swift` (add cycle state properties)
- Modify: `App/AppState.swift` (add properties with UserDefaults persistence)
- Modify: `Library/Extensions/UserDefaults.swift` (add keys + computed properties)
- Modify: `Library/DirectAction.swift` (add cycle actions)
- Modify: `Library/DirectReducer.swift` (add cycle reducer cases)

**Approach:**
- New UserDefaults-backed state properties (4-file pattern): `treatmentCycleActive: Bool`, `alarmFiredAt: Date?`, `treatmentLoggedAt: Date?`, `treatmentCycleCountdownExpiry: Date?`, `treatmentCycleSnoozeUntil: Date?`, `hypoTreatmentWaitMinutes: Int` (default 15)
- New actions: `.logHypoTreatment(favorite: FavoriteFood, alarmFiredAt: Date, overrideTimestamp: Date?)`, `.startTreatmentCycle`, `.endTreatmentCycle`, `.dismissTreatmentCycle`, `.treatmentCycleRecovered(glucoseValue: Int)`, `.treatmentCycleStillLow(glucoseValue: Int)`, `.setHypoTreatmentWaitMinutes(minutes: Int)`
- Reducer handles state mutations; middleware handles side effects (DB writes, notification scheduling)
- `.dismissTreatmentCycle` clears all cycle state and sets `treatmentCycleSnoozeUntil = nil`

**Patterns to follow:**
- `showScanlines` in DirectState/AppState/UserDefaults/DirectReducer — 4-file UserDefaults pattern
- `alarmSnoozeUntil`/`alarmSnoozeKind` — snooze state pattern

**Test scenarios:**
- Happy path: `.logHypoTreatment` sets all cycle state, `.dismissTreatmentCycle` clears it
- Edge case: Cycle state survives app restart (read back from UserDefaults on init)
- Edge case: `.dismissTreatmentCycle` when no cycle is active — no crash, no-op
- Integration: Reducer sets state before middleware runs (verify middleware sees updated state)

**Verification:** All cycle state properties round-trip through UserDefaults. Actions dispatch cleanly without crashes.

---

- [ ] **Unit 3: Treatment Cycle Middleware (Core Logic)**

**Goal:** Implement the treatment cycle orchestration: logging treatment, scheduling recheck, handling recheck result, chaining cycles.

**Requirements:** R4, R6, R7, R8, R9, R10, R11, R12, R13, R14, R20

**Dependencies:** Unit 1, Unit 2

**Files:**
- Create: `App/Modules/TreatmentCycle/TreatmentCycleMiddleware.swift`
- Modify: `App/App.swift` (register in both middleware arrays)
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- On `.logHypoTreatment`: create MealEntry via `favorite.toMealEntry()`, capture its `.id`, create TreatmentEvent with `mealEntryId = mealEntry.id`, dispatch `.addMealEntry(mealEntryValues: [mealEntry])`, dispatch `.startTreatmentCycle`, schedule recheck notification. Note: MealEntry is created in middleware (not view) since hypo treatment logging does not need undo support.
- On `.addSensorGlucose` (cross-middleware listening): if cycle active AND countdown expired AND app foregrounded AND recheck not yet dispatched, compare glucose vs alarmLow → dispatch `.treatmentCycleRecovered` or `.treatmentCycleStillLow`. Use a `recheckDispatched: Bool` state flag (set by reducer on these actions, cleared on `.logHypoTreatment`) to prevent duplicate dispatches from rapid glucose readings.
- On `.addSensorGlucose`: if cycle active AND glucose < (alarmLow - 15), dispatch low alarm override (critical floor bypass)
- On `.treatmentCycleStillLow` + user taps "treat again": dispatch `.logHypoTreatment` again (chain)
- On `.dismissTreatmentCycle`: cancel scheduled notification, clear state
- On `.setAppState(.active)`: if cycle was persisted and countdown expired, trigger immediate recheck on next glucose reading. If cycle is active but countdown has NOT expired, re-schedule the recheck notification with remaining time (`UNTimeIntervalNotificationTrigger(timeInterval: remainingSeconds)`) since the original notification may have been lost on app kill.
- Comment cross-middleware dependency with `.addSensorGlucose` (also handled by SensorConnector, GlucoseNotification)

**Patterns to follow:**
- `App/Modules/GlucoseNotification/GlucoseNotification.swift` — alarm middleware pattern
- `App/Modules/ExpiringNotification/ExpiringNotification.swift` — timer/notification scheduling

**Test scenarios:**
- Happy path: `.logHypoTreatment` creates MealEntry + TreatmentEvent, schedules notification, sets snooze
- Happy path: Glucose recovers after countdown → `.treatmentCycleRecovered` dispatched, cycle ends
- Happy path: Glucose still low → `.treatmentCycleStillLow` dispatched, user treats again → new cycle
- Edge case: App killed mid-cycle → on restart, cycle state loaded from UserDefaults, recheck triggered on next glucose
- Edge case: Critical low floor — glucose drops below alarmLow - 15 during suppression → alarm fires anyway
- Edge case: User dismisses cycle → snooze cleared, alarms re-enabled, scheduled notification cancelled
- Edge case: User snoozes alarm without treating (R14) → no cycle starts
- Integration: `.logHypoTreatment` triggers both TreatmentEventStore (persist) and MealStore (addMealEntry) via cross-middleware

**Verification:** Full cycle completes: alarm → treat → countdown → recheck → stabilised/treat-again. Critical low floor bypasses suppression.

---

- [ ] **Unit 4: Notification Category Infrastructure**

**Goal:** Register UNNotificationCategory with action buttons for the low glucose alarm, and rewrite the notification response handler.

**Requirements:** R1

**Dependencies:** Unit 2, Unit 3

**Files:**
- Modify: `App/App.swift` (register categories in applicationDidFinishLaunching, rewrite didReceive)
- Modify: `App/Modules/GlucoseNotification/GlucoseNotification.swift` (set categoryIdentifier on low alarm content)

**Approach:**
- Define category `"lowGlucoseAlarm"` with actions: `"tookDextro"` (title: "TOOK DEXTRO", options: .foreground) and `"moreOptions"` (title: "More...", options: .foreground)
- Register category in `applicationDidFinishLaunching` via `UNUserNotificationCenter.current().setNotificationCategories()`
- Set `content.categoryIdentifier = "lowGlucoseAlarm"` in GlucoseNotificationService when building low-alarm notification content
- Rewrite `didReceive` to switch on `response.actionIdentifier`:
  - `"tookDextro"` → dispatch `.logHypoTreatment(defaultFavorite, alarmFiredAt: notificationDate)`
  - `"moreOptions"` → set state flag to present UnifiedFoodEntryView with hypo filter
  - `UNNotificationDefaultActionIdentifier` (notification body tap) → existing snooze behavior
- The recheck notification uses no category (generic local notification) — add a category only when future work adds action buttons to it

**Patterns to follow:**
- Existing `didReceive` handler in App.swift (line ~96) — extend, don't replace wholesale
- Standard iOS UNNotificationCategory registration pattern

**Test scenarios:**
- Happy path: Low alarm notification shows "TOOK DEXTRO" and "More..." action buttons on lock screen
- Happy path: Tapping "TOOK DEXTRO" opens app and logs default hypo treatment
- Happy path: Tapping "More..." opens app and presents filtered UnifiedFoodEntryView
- Happy path: Tapping notification body (not action) still triggers existing snooze
- Edge case: No isHypoTreatment favorites exist — "TOOK DEXTRO" action dispatched but middleware gracefully handles missing default (no-op, presents "More..." instead)

**Verification:** Lock-screen notification shows action buttons. Each button dispatches the correct Redux action.

---

- [ ] **Unit 5: Alarm Suppression + Critical-Low Floor**

**Goal:** Implement treatment-cycle alarm suppression with a critical-low safety floor.

**Requirements:** R7

**Dependencies:** Unit 2

**Files:**
- Modify: `App/Modules/GlucoseNotification/GlucoseNotification.swift` (add suppression logic)
- Modify: `Library/DirectState.swift` (add helper method for treatment suppression check)

**Approach:**
- Add a local `isTreatmentSnoozed` check inside GlucoseNotification middleware (not on DirectState protocol — single call site): checks `state.treatmentCycleActive && Date() < state.treatmentCycleSnoozeUntil`
- In GlucoseNotification middleware, evaluate BOTH `isSnoozed(alarm:)` AND `isTreatmentSnoozed` before firing the alarm sound/haptic. This is critical: without the combined check, the existing 5-min auto-snooze expiry would re-trigger alarms at minute 5 even though the 15-min treatment cycle is active.
- Suppression scope: sound/haptic only (matches existing snooze behavior). Notification banners continue to fire during treatment cycle — keeps user informed of readings.
  - If treatment-snoozed AND glucose >= (alarmLow - 15): suppress sound/haptic
  - If treatment-snoozed AND glucose < (alarmLow - 15): FIRE full alarm (sound + banner) — critical floor
  - If not treatment-snoozed: existing behavior unchanged
- The critical-low floor offset (15) is always in mg/dL — internal glucose values are stored as mg/dL integers regardless of display unit

**Patterns to follow:**
- Existing `isSnoozed(alarm:)` / `isAlarm(glucoseValue:)` methods in DirectState

**Test scenarios:**
- Happy path: During treatment cycle, low alarm is suppressed (glucose at alarmLow)
- Happy path: Critical floor — glucose drops below alarmLow - 15 during cycle → alarm fires
- Edge case: Treatment cycle dismissed → suppression immediately stops, normal alarm behavior resumes
- Edge case: User-initiated snooze AND treatment cycle active simultaneously → both suppress; critical floor still applies
- Edge case: High glucose alarm during treatment cycle → not suppressed (suppression is low-alarm only)

**Verification:** Low alarms suppressed during cycle. Critical-low floor tested by verifying alarm fires when glucose is dangerously low.

---

- [ ] **Unit 6: In-App Treatment Modal (Foreground)**

**Goal:** Present a treatment modal over OverviewView when a low alarm fires while the app is in foreground.

**Requirements:** R1, R2, R3, R4, R5, R6

**Dependencies:** Unit 2, Unit 3

**Files:**
- Create: `App/Views/AddViews/TreatmentModalView.swift`
- Modify: `App/Views/OverviewView.swift` (add sheet trigger, state observation)
- Modify: `App/Views/AddViews/UnifiedFoodEntryView.swift` (add filterToHypoTreatments parameter + onHypoTreatmentLogged callback)
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- TreatmentModalView: shows current glucose value (cgaRed), "TOOK DEXTRO" button (primary, with default favorite name + carbs), "More..." button (secondary), dismiss button (tertiary/nav bar). Also used for "still low" recheck result — re-presented with current glucose and "TREAT AGAIN" as primary.
- If >5 min since alarm, show inline time picker (not a separate sheet) with "Just now" default. Applies to both quick-action and "More..." paths.
- "TOOK DEXTRO" dispatches `.logHypoTreatment`; "More..." dismisses modal then sets a transient in-memory flag to present UnifiedFoodEntryView (avoids nested sheet). Flag is cleared on presentation (one-shot, not persisted).
- OverviewView observes `store.state.showTreatmentPrompt` (transient, not persisted) — set by GlucoseNotification middleware when a low alarm fires via new `.showTreatmentPrompt(alarmFiredAt:)` action. This fixes the chicken-and-egg: modal appears when alarm fires, not when treatment is logged.
- Sheet collision prevention: consolidate OverviewView sheets into a single `.sheet(item:)` with an `ActiveSheet` enum discriminator (`case insulin, meal, treatmentModal, filteredFoodEntry`). This prevents iOS 15 sibling sheet collisions.
- UnifiedFoodEntryView gets `filterToHypoTreatments: Bool = false` parameter. When true: favorites section only shows isHypoTreatment items, search/scan/photo/AI actions hidden. Empty state: "NO HYPO TREATMENTS — tap to add" with link to favorites management.
- No callback needed on UnifiedFoodEntryView — TreatmentCycleMiddleware listens for `.addMealEntry` and checks if a treatment prompt is pending + the food is isHypoTreatment to start the cycle via Redux

**Patterns to follow:**
- `App/Views/AddViews/AddMealView.swift` — modal with callback pattern
- Sheet presentation pattern on StickyQuickActions buttons in OverviewView

**Test scenarios:**
- Happy path: Low alarm fires while app is open → TreatmentModalView appears
- Happy path: Tap "TOOK DEXTRO" → modal dismisses, treatment logged, countdown starts
- Happy path: Tap "More..." → modal dismisses, UnifiedFoodEntryView (filtered) appears
- Happy path: Log juice box from filtered view → treatment cycle starts
- Edge case: >5 min since alarm → inline time picker shown, "Just now" dismisses it
- Edge case: No isHypoTreatment favorites → "TOOK DEXTRO" button hidden, only "More..." shown
- Edge case: App returns to foreground after alarm fired in background → modal appears
- Integration: Dismiss-then-present avoids nested sheet (verified on iOS 15)

**Verification:** Modal appears on low alarm. Both logging paths enter the treatment cycle. No nested sheet issues.

---

- [ ] **Unit 7: Treatment Countdown Banner in OverviewView**

**Goal:** Display a persistent countdown banner between the hero glucose and chart during an active treatment cycle.

**Requirements:** R7a, R13

**Dependencies:** Unit 2

**Files:**
- Create: `App/Views/Overview/TreatmentBannerView.swift`
- Modify: `App/Views/OverviewView.swift` (insert banner row)
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- TreatmentBannerView has 4 states:
  1. **Countdown active:** "HYPO TREATMENT — recheck in Xm Xs" with dismiss (X) button
  2. **Rechecking:** "RECHECKING..." (countdown expired, waiting for glucose reading)
  3. **Stale data:** "NO RECENT DATA — CHECK SENSOR" (countdown expired + no glucose for >5 min)
  4. **Recovered:** "STABILISED AT X" in cgaGreen text (auto-dismisses after 5 seconds, clears cycle)
- Uses a Timer publisher (not TimelineView) to update countdown every second — reliable on iOS 15
- Dismiss button dispatches `.dismissTreatmentCycle`
- Inserted as a List row between GlucoseView and ChartView in OverviewView, conditionally shown when `store.state.treatmentCycleActive`
- Styled with cgaGreen text on black background (not cgaGreen fill — matches design system's black background rule). DOSTypography monospace.

**Patterns to follow:**
- `App/Views/Overview/GlucoseView.swift` — List row pattern in OverviewView
- `App/DesignSystem/Components/DOSButtonStyle.swift` — button styling
- `Library/DesignSystem/AmberTheme.swift` — color tokens

**Test scenarios:**
- Happy path: Treatment logged → banner appears with countdown
- Happy path: Countdown reaches 0 → banner updates to show "Rechecking..."
- Happy path: Dismiss tapped → banner disappears, cycle cleared
- Edge case: App returns to foreground mid-countdown → banner shows correct remaining time (calculated from persisted countdownExpiry)

**Verification:** Banner visible during active cycle. Countdown accurate. Dismiss clears cycle.

---

- [ ] **Unit 8: FavoriteStore Seed Fix for Existing Users**

**Goal:** Ensure existing users who already have favorites get hypo treatment favorites seeded.

**Requirements:** R4 dependency

**Dependencies:** None

**Files:**
- Modify: `App/Modules/DataStore/FavoriteStore.swift` (fix seed guard)

**Approach:**
- Add a separate GRDB migration in FavoriteStore that checks `isHypoTreatment` count specifically
- If 0 isHypoTreatment items exist, insert the default "Dextrose tabs" (15g) and "Juice box" (25g) regardless of total favorite count
- Use `DatabaseMigrator` with a named migration so it only runs once

**Patterns to follow:**
- Existing `DatabaseMigrator` pattern in FavoriteStore.swift (line ~132)

**Test scenarios:**
- Happy path: Fresh install → both hypo favorites seeded (existing behavior)
- Happy path: Existing user with favorites but no hypo items → migration seeds hypo items
- Edge case: Existing user already has hypo favorites → migration is no-op

**Verification:** After migration, all users have at least the 2 default hypo treatment favorites.

---

- [ ] **Unit 9: Settings UI for Wait Time**

**Goal:** Add a wait-time picker to Settings.

**Requirements:** R18

**Dependencies:** Unit 2

**Files:**
- Modify: `App/Views/SettingsView.swift` (add picker row)

**Approach:**
- Add a picker in the appropriate settings section (near alarm settings) for `hypoTreatmentWaitMinutes`
- Options: 10, 15, 20, 25, 30 minutes
- Label: "Treatment recheck time"
- Dispatches `.setHypoTreatmentWaitMinutes(minutes:)` on change

**Patterns to follow:**
- Existing picker patterns in SettingsView.swift (e.g., glucose unit picker, alarm sound pickers)

**Test scenarios:**
- Happy path: Change wait time to 20 min → next treatment cycle uses 20-min countdown
- Edge case: Active cycle in progress → changing wait time doesn't affect current cycle (only next)

**Verification:** Setting persists across app restart. New treatment cycles use the configured wait time.

## System-Wide Impact

- **Interaction graph:** `.addSensorGlucose` is now handled by TreatmentCycleMiddleware (in addition to SensorConnector, GlucoseNotification) — comment this cross-middleware dependency. `.logHypoTreatment` triggers both TreatmentEventStore and MealStore (via `.addMealEntry`).
- **Error propagation:** TreatmentEvent GRDB write failure should not block the treatment cycle from starting — log the error, continue with cycle state in UserDefaults.
- **State lifecycle risks:** App kill during cycle — mitigated by UserDefaults persistence (R20). Stale glucose at recheck — accepted limitation per R11.
- **API surface parity:** Notification action buttons are a new surface. The "TOOK DEXTRO" action and in-app modal button must dispatch the same action.
- **Integration coverage:** Full cycle test (alarm → treat → countdown → recheck → result) crosses GlucoseNotification, TreatmentCycleMiddleware, TreatmentEventStore, MealStore, and OverviewView.
- **Unchanged invariants:** Existing alarm behavior for users who don't interact with treatment actions remains identical. High glucose alarms are unaffected. Manual snooze behavior preserved.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| UNNotificationAction buttons may not render in all iOS versions/configurations | Test on iOS 15, 16, 17. Fallback: notification tap opens treatment modal (existing deep link path) |
| Background notification delivery not guaranteed by iOS | Accepted — foreground auto-check is primary. Background is best-effort reminder. |
| Sheet collision on iOS 15 if treatment modal + food entry both use .sheet | Dismiss-then-present pattern. Never two sheets active simultaneously. |
| pbxproj merge conflicts from new files | Add files in a single commit to minimize conflict surface |
| Existing auto-snooze (5 min) may conflict with treatment snooze (15 min) | Separate state properties. Both evaluated; longer window wins. |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-15-hypo-treatment-workflow-requirements.md](docs/brainstorms/2026-04-15-hypo-treatment-workflow-requirements.md)
- **Linear issue:** DMNC-646
- Related code: `App/Modules/GlucoseNotification/GlucoseNotification.swift`, `App/Modules/DataStore/FavoriteStore.swift`
- Institutional learnings: `docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md`, `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`
