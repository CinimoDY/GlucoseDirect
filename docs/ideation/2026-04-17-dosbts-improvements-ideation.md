---
date: 2026-04-17
topic: dosbts-improvements
focus: how could we make this app even better
---

# Ideation: DOSBTS Improvements

## Codebase Context

DOSBTS is a personal CGM (continuous glucose monitoring) iOS app with DOS amber CGA aesthetic, forked from GlucoseDirect. It connects to Libre sensors via BLE/NFC and displays real-time glucose data with food logging (photo AI, text, barcode, favorites), treatment workflow (Rule of 15), and HealthKit integration.

**Recent work:** Treatment workflow (build 49), chart marker improvements with grouping (build 50). Both shipped to TestFlight.

**Known pain points from institutional learnings:** SwiftUI sheet presentation bugs, Redux middleware timing traps (reducer-first ordering, silent failures), dangling GRDB Futures (systemic), zero automated tests.

**Existing backlog (not duplicated):** Side panel navigation (DMNC-671), Siri voice logging (DMNC-633/634), widget rework (DMNC-579), app icon redesign (DMNC-566), module audit (DMNC-386), gamified UI (DMNC-647), food logging 2026 vision (DMNC-563).

## Ranked Ideas

### 1. Predictive Alarm (Trend-Based Early Warning)
**Description:** Fire warnings when rate-of-change predicts a threshold crossing in 15-30 min, before it actually happens. Simple linear extrapolation from existing `minuteChange` data on SensorGlucose.
**Rationale:** 3 of 4 ideation agents independently flagged this — strongest signal in the session. Libre's sensor lag means current binary threshold alarms are always 10+ minutes late. This turns the lag from a liability into irrelevance. Dexcom G7 and Guardian 4 already market predictive alerts as a headline feature.
**Downsides:** False positives from noisy sensor data need smoothing. Users may distrust "predicted" alarms initially.
**Confidence:** 90%
**Complexity:** Medium
**Status:** Unexplored

### 2. Insulin-on-Board (IOB) Decay Model
**Description:** Calculate remaining active insulin from logged boluses using standard decay curves (configurable DIA, defaulting to 4 hours). Display IOB on the hero screen. Warn when stacking corrections on top of still-active insulin.
**Rationale:** 2 agents flagged this. "Rage bolusing into a hypo" is the most dangerous daily T1D mistake. IOB makes every other feature smarter: treatment workflow can factor in active insulin, AI meal suggestions can warn about stacking, chart can show expected trajectory.
**Downsides:** Requires accurate insulin logging (which users often skip). Decay curves are approximate and vary by insulin type.
**Confidence:** 85%
**Complexity:** Medium
**Status:** Unexplored

### 3. Meal Impact Overlay (Personal Glycemic Response)
**Description:** After logging a meal, highlight the 2-4hr post-meal glucose window on the chart. Show peak rise, time-to-peak, return-to-baseline. Over time, build per-food glycemic impact scores in the existing PersonalFood dictionary.
**Rationale:** 2 agents flagged this. Closes the feedback loop on food logging — turns it from a chore into a learning tool. Makes AI food analysis accountable (did estimated carbs match reality?). Compounds with every meal logged.
**Downsides:** Requires consistent meal logging. Confounded by insulin timing, exercise, and stacking meals.
**Confidence:** 80%
**Complexity:** Medium-High
**Status:** Unexplored

### 4. Snapshot Testing for Reducer + Key Middlewares
**Description:** Add XCTest target with snapshot tests for DirectReducer (given state + action -> expected state) and highest-risk middlewares (TreatmentCycle, GlucoseNotification). Pure logic tests only, no UI.
**Rationale:** Zero automated tests + 8 documented past bugs = every change is a regression gamble. Reducer tests are the highest-leverage tests in Redux architecture — pure functions, trivial to write, cover the single state mutation bottleneck. Makes every future refactor safe.
**Downsides:** Setup cost for test target + pbxproj. No immediate user-facing value.
**Confidence:** 95%
**Complexity:** Low-Medium
**Status:** Unexplored

### 5. Stale Data Prominence (Connection Loss Indicator)
**Description:** Show an impossible-to-miss visual indicator on the hero glucose when data is stale (>5 min since last reading). Include elapsed time since last reading and a reconnect action. A 30-minute-old reading should never look identical to a fresh one.
**Rationale:** Making dosing decisions on stale data is genuinely dangerous. Current GlucoseView shows "No Data" only when nil — a 20-minute-old reading displays identically to a fresh one. TreatmentBannerView already has a stale-data state but only during treatment cycles.
**Downsides:** Could add visual noise during normal BLE hiccups (brief disconnects). Needs threshold tuning.
**Confidence:** 85%
**Complexity:** Low
**Status:** Unexplored

### 6. Daily Digest / End-of-Day Summary
**Description:** End-of-day summary screen: TIR%, number of lows/highs, total carbs logged, total insulin, and optionally a single-sentence AI-generated insight about the day. Push notification at configurable time.
**Rationale:** The app monitors all day but never summarizes. T1Ds trying to improve management need a "how did today go?" signal, not just raw numbers. Compounds with food logging and insulin data.
**Downsides:** AI insight requires Claude API call (small cost). Summary only as good as logged data.
**Confidence:** 75%
**Complexity:** Medium
**Status:** Unexplored

### 7. Day/Night Alarm Profiles
**Description:** Separate alarm thresholds, sounds, and volumes for daytime vs. nighttime. E.g., higher high-alarm at night (200 vs 180) to reduce nuisance wakeups, louder low-alarm during sleep hours.
**Rationale:** Nighttime alarm fatigue is the #1 reason T1Ds disable CGM alerts entirely. Current alarms are 24/7 single-profile with no time-of-day awareness. Users who tighten thresholds for daytime control get woken repeatedly at night.
**Downsides:** Adds complexity to alarm settings. Edge cases around schedule transitions.
**Confidence:** 80%
**Complexity:** Medium
**Status:** Unexplored

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | Kill chart as primary view | Too radical — chart works fine as primary for a single user |
| 2 | Glucose as ambient sound | Impractical — battery drain, social awkwardness, iOS audio limits |
| 3 | Silence Means Safe (heartbeat) | Inverts decades of CGM mental model — would cause more anxiety |
| 4 | Self-calibrating personal thresholds | Risky for a medical tool — dynamic thresholds could mask real lows |
| 5 | Invert logging (passive capture) | Requires ML/pattern detection for uncertain benefit — too expensive |
| 6 | Remove manual meal timestamp | Glucose inflection detection unreliable — insulin/stress also cause rises |
| 7 | Auto-detect sensor replacement | iOS NFC pairing can't be bypassed by app logic |
| 8 | Remove AI consent gate | Legal/ethical requirement, not friction — can't remove |
| 9 | Action metadata envelope | Infrastructure for infrastructure — no user-facing value |
| 10 | Action replay for bug reports | Too complex for a personal single-developer app |
| 11 | Derived state cache layer | Premature optimization — current performance is fine |
| 12 | Unified timeline event model | Good architecture, no immediate user benefit — defer |
| 13 | Auto-log insulin from NFC pen | Requires specific hardware (NovoPen 6) — too narrow |
| 14 | Collapse settings into contextual controls | Huge refactor across 11 sections for marginal gain |
| 15 | One-tap meal replay from chart | Already partially solved by grouped markers + favorites |
| 16 | Faster repeated meal logging | Already addressed by favorites quick-log |
| 17 | Structured AI context protocol | Good direction but abstract — better as part of a specific feature |
| 18 | Quick-log from high glucose notification | Partially addressed by treatment workflow pattern — extend later |
| 19 | Glucose-aware Do Not Disturb | Interesting but overlaps with day/night profiles (#7) |
| 20 | Middleware health monitor | Good idea but too much infra for a personal app |

## Session Log
- 2026-04-17: Initial ideation — 37 candidates generated across 4 frames (pain/friction, inversion/removal, assumption-breaking, leverage/compounding), 7 survived filtering. Sources: Linear project (33 issues), codebase scan, institutional learnings (8 documented solutions).
