//
//  DirectReducerTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - Reducer Test Helpers

/// Creates a minimal AppState for testing. AppState.init() reads from UserDefaults,
/// so these tests exercise the real init path. State mutations are verified by
/// calling directReducer() directly — it's a pure function.
private func makeState() -> AppState {
    AppState()
}

private func reduce(_ state: inout DirectState, _ action: DirectAction) {
    directReducer(state: &state, action: action)
}

// MARK: - Treatment Cycle Tests

@Suite("Treatment Cycle State")
struct TreatmentCycleTests {

    @Test("startTreatmentCycle sets active state and countdown expiry")
    func startCycle() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)

        #expect(state.treatmentCycleActive == true)
        #expect(state.treatmentCycleCountdownExpiry != nil)
        #expect(state.treatmentCycleSnoozeUntil != nil)
        #expect(state.recheckDispatched == false)
    }

    @Test("dismissTreatmentCycle clears all cycle state")
    func dismissCycle() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)
        reduce(&state, .dismissTreatmentCycle)

        #expect(state.treatmentCycleActive == false)
        #expect(state.alarmFiredAt == nil)
        #expect(state.treatmentLoggedAt == nil)
        #expect(state.treatmentCycleCountdownExpiry == nil)
        #expect(state.treatmentCycleSnoozeUntil == nil)
        #expect(state.recheckDispatched == false)
        #expect(state.showTreatmentPrompt == false)
    }

    @Test("endTreatmentCycle clears cycle state same as dismiss")
    func endCycle() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)
        reduce(&state, .endTreatmentCycle)

        #expect(state.treatmentCycleActive == false)
        #expect(state.treatmentCycleCountdownExpiry == nil)
    }

    @Test("treatmentCycleRecovered sets recheckDispatched")
    func recovered() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)
        reduce(&state, .treatmentCycleRecovered(glucoseValue: 90))

        #expect(state.recheckDispatched == true)
    }

    @Test("treatmentCycleStillLow sets recheckDispatched and showTreatmentPrompt")
    func stillLow() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)
        reduce(&state, .treatmentCycleStillLow(glucoseValue: 55))

        #expect(state.recheckDispatched == true)
        #expect(state.showTreatmentPrompt == true)
    }

    @Test("startTreatmentCycle resets recheckDispatched for chained cycles")
    func chainedCycleResetsRecheck() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)
        reduce(&state, .treatmentCycleStillLow(glucoseValue: 55))
        #expect(state.recheckDispatched == true)

        // Chained cycle: logHypoTreatment resets, then startTreatmentCycle also resets
        reduce(&state, .startTreatmentCycle)
        #expect(state.recheckDispatched == false)
    }

    @Test("logHypoTreatment clears stale countdown expiry to prevent race")
    func logTreatmentClearsExpiry() {
        var state: DirectState = makeState()
        reduce(&state, .startTreatmentCycle)
        // Simulate chained treatment: logHypoTreatment should clear expiry
        let fakeFavorite = FavoriteFood(
            mealDescription: "Test",
            carbsGrams: 15,
            proteinGrams: nil,
            fatGrams: nil,
            calories: nil,
            fiberGrams: nil,
            sortOrder: 0,
            isHypoTreatment: true
        )
        reduce(&state, .logHypoTreatment(favorite: fakeFavorite, alarmFiredAt: Date(), overrideTimestamp: nil))

        #expect(state.treatmentCycleCountdownExpiry == nil) // Cleared to prevent race
        #expect(state.recheckDispatched == false)
        #expect(state.showTreatmentPrompt == false)
    }
}

// MARK: - Predictive Low Alarm Tests

@Suite("Predictive Low Alarm State")
struct PredictiveLowAlarmTests {

    @Test("setShowPredictiveLowAlarm toggles the setting")
    func toggleSetting() {
        var state: DirectState = makeState()
        reduce(&state, .setShowPredictiveLowAlarm(enabled: false))
        #expect(state.showPredictiveLowAlarm == false)

        reduce(&state, .setShowPredictiveLowAlarm(enabled: true))
        #expect(state.showPredictiveLowAlarm == true)
    }

    @Test("setPredictiveLowAlarmFired controls the flag")
    func firedFlag() {
        var state: DirectState = makeState()
        #expect(state.predictiveLowAlarmFired == false)

        reduce(&state, .setPredictiveLowAlarmFired(fired: true))
        #expect(state.predictiveLowAlarmFired == true)

        reduce(&state, .setPredictiveLowAlarmFired(fired: false))
        #expect(state.predictiveLowAlarmFired == false)
    }
}

// MARK: - Alarm Snooze Tests

@Suite("Alarm Snooze State")
struct AlarmSnoozeTests {

    @Test("setAlarmSnoozeUntil sets snooze date")
    func setSnooze() {
        var state: DirectState = makeState()
        let future = Date().addingTimeInterval(5 * 60)
        reduce(&state, .setAlarmSnoozeUntil(untilDate: future, autosnooze: true))

        #expect(state.alarmSnoozeUntil != nil)
    }

    @Test("expired snooze is auto-cleared on next action")
    func expiredSnoozeClearsAutomatically() {
        var state: DirectState = makeState()
        let past = Date().addingTimeInterval(-60) // 1 minute ago
        reduce(&state, .setAlarmSnoozeUntil(untilDate: past, autosnooze: false))

        // Any subsequent action should trigger the auto-clear at the end of the reducer
        reduce(&state, .setShowPredictiveLowAlarm(enabled: true))

        #expect(state.alarmSnoozeUntil == nil)
        #expect(state.alarmSnoozeKind == nil)
    }
}

// MARK: - Show Treatment Prompt Tests

@Suite("Treatment Prompt State")
struct TreatmentPromptTests {

    @Test("showTreatmentPrompt sets flag and alarmFiredAt")
    func showPrompt() {
        var state: DirectState = makeState()
        let now = Date()
        reduce(&state, .showTreatmentPrompt(alarmFiredAt: now))

        #expect(state.showTreatmentPrompt == true)
        #expect(state.alarmFiredAt != nil)
    }

    @Test("setShowTreatmentPrompt clears the flag")
    func clearPrompt() {
        var state: DirectState = makeState()
        reduce(&state, .showTreatmentPrompt(alarmFiredAt: Date()))
        reduce(&state, .setShowTreatmentPrompt(show: false))

        #expect(state.showTreatmentPrompt == false)
    }
}
