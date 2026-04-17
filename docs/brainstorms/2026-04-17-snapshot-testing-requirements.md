---
date: 2026-04-17
topic: snapshot-testing
---

# Snapshot Testing for DirectReducer

## Problem Frame

Zero automated tests + 8 documented past bugs = every change is a regression gamble. The Redux-like reducer is a pure function — the highest-leverage test target in the architecture.

## Requirements

- R1. Add an XCTest target to the Xcode project that can import and test the app's Swift code
- R2. Write ~10 reducer snapshot tests covering the most safety-critical action cases: treatment cycle lifecycle (.startTreatmentCycle, .endTreatmentCycle, .dismissTreatmentCycle), predictive alarm flags (.setPredictiveLowAlarmFired, .setShowPredictiveLowAlarm), alarm snooze (.setAlarmSnoozeUntil with auto-clear), and glucose state (.addSensorGlucose)
- R3. Each test: create a mock state, dispatch an action through the reducer, assert the expected state mutations
- R4. Pure logic only — no UI tests, no XCUITest, no simulator required

## Scope Boundaries

- No middleware tests in V1 (middlewares have side effects — harder to test)
- No UI tests
- No test coverage targets or CI integration
- Grow coverage incrementally in future sessions

## Success Criteria

- XCTest target compiles and runs
- 10 reducer tests pass
- Pattern is clear enough to copy for new tests

## Next Steps

-> `/ce:plan` then `/ce:work`
