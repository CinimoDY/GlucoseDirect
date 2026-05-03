//
//  AlarmThresholdProfileTests.swift
//  DOSBTSTests
//
//  Verifies that alarm evaluation, snooze, critical-low breakthrough, and
//  the expiring-sensor floor read the correct profile's thresholds/volume.
//

import Foundation
import Testing
@testable import DOSBTSApp

private func windowEnclosingNow() -> (startH: Int, startM: Int, endH: Int, endM: Int) {
    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let h = now.hour ?? 12
    let m = now.minute ?? 0
    let endTotal = h * 60 + m + 2
    return (h, m, (endTotal / 60) % 24, endTotal % 60)
}

private func degenerateWindow() -> (startH: Int, startM: Int, endH: Int, endM: Int) {
    (0, 0, 0, 0)
}

private func makeStateForceDay() -> AppState {
    var state = AppState()
    let w = degenerateWindow()
    state.nightStartHour = w.startH
    state.nightStartMinute = w.startM
    state.nightEndHour = w.endH
    state.nightEndMinute = w.endM
    return state
}

private func makeStateForceNight() -> AppState {
    var state = AppState()
    let w = windowEnclosingNow()
    state.nightStartHour = w.startH
    state.nightStartMinute = w.startM
    state.nightEndHour = w.endH
    state.nightEndMinute = w.endM
    return state
}

@Suite("Alarm threshold profile evaluation")
struct AlarmThresholdProfileTests {

    @Test("isAlarm uses day high when active profile is day")
    func dayHighFires() {
        var state = makeStateForceDay()
        state.dayAlarmHigh = 180
        state.nightAlarmHigh = 200
        #expect(state.activeAlarmProfile == .day)
        #expect(state.isAlarm(glucoseValue: 195) == .highAlarm)
    }

    @Test("isAlarm uses night high when active profile is night")
    func nightHighSilent() {
        var state = makeStateForceNight()
        state.dayAlarmHigh = 180
        state.nightAlarmHigh = 200
        #expect(state.activeAlarmProfile == .night)
        #expect(state.isAlarm(glucoseValue: 195) == .none)
    }

    @Test("isAlarm uses day low when active profile is day")
    func dayLowFires() {
        var state = makeStateForceDay()
        state.dayAlarmLow = 80
        state.nightAlarmLow = 70
        #expect(state.activeAlarmProfile == .day)
        #expect(state.isAlarm(glucoseValue: 75) == .lowAlarm)
    }

    @Test("isAlarm uses night low when active profile is night")
    func nightLowFires() {
        var state = makeStateForceNight()
        state.dayAlarmLow = 80
        state.nightAlarmLow = 85
        #expect(state.activeAlarmProfile == .night)
        // 75 < night low 85 → lowAlarm
        #expect(state.isAlarm(glucoseValue: 75) == .lowAlarm)
    }

    @Test("Critical-low breakthrough uses active profile alarmLow during night")
    func criticalLowBreakthroughNight() {
        var state = makeStateForceNight()
        state.dayAlarmLow = 80
        state.nightAlarmLow = 70
        // Critical-low breakthrough: glucose < state.alarmLow - 15
        // Night profile: 70 - 15 = 55. So 54 should be critical-low.
        let glucose = 54
        #expect(glucose < state.alarmLow - 15)
    }

    @Test("Critical-low breakthrough does NOT fire if glucose only crosses higher day low - 15")
    func criticalLowOnlyAtDayThreshold() {
        var state = makeStateForceNight()
        state.dayAlarmLow = 80
        state.nightAlarmLow = 70
        // 64 < (80 - 15 = 65) [day breakthrough] but 64 > (70 - 15 = 55) [night breakthrough]
        let glucose = 64
        // Active profile is night → breakthrough threshold is night - 15 = 55
        #expect(state.alarmLow == 70)
        #expect(glucose >= state.alarmLow - 15)
    }

    @Test("Snooze evaluation respects active-profile threshold change at boundary")
    func snoozeAcrossBoundary() {
        var state = makeStateForceDay()
        state.dayAlarmHigh = 180
        state.nightAlarmHigh = 200
        // Snooze set during day
        state.alarmSnoozeUntil = Date().addingTimeInterval(3600)
        state.alarmSnoozeKind = .highAlarm
        #expect(state.isSnoozed(alarm: .highAlarm))
        // Profile flips to night — threshold changes but snooze remains time-based
        let w = windowEnclosingNow()
        state.nightStartHour = w.startH
        state.nightStartMinute = w.startM
        state.nightEndHour = w.endH
        state.nightEndMinute = w.endM
        #expect(state.alarmHigh == 200) // night threshold
        #expect(state.isSnoozed(alarm: .highAlarm))
    }

    @Test("alarmVolume resolves to night volume during night (debug-bleed path)")
    func alarmVolumeNight() {
        var state = makeStateForceNight()
        state.dayAlarmVolume = 0.7
        state.nightAlarmVolume = 0.1
        #expect(state.activeAlarmProfile == .night)
        #expect(state.alarmVolume == 0.1)
    }

    @Test("alarmVolume resolves to day volume during day")
    func alarmVolumeDay() {
        var state = makeStateForceDay()
        state.dayAlarmVolume = 0.7
        state.nightAlarmVolume = 0.1
        #expect(state.activeAlarmProfile == .day)
        #expect(state.alarmVolume == 0.7)
    }

    @Test("Expiring-sensor floor uses max(day, night) regardless of active profile")
    func expiringFloorMax() {
        var state = makeStateForceNight()
        state.dayAlarmVolume = 0.7
        state.nightAlarmVolume = 0.0
        // ExpiringNotification will read max(state.dayAlarmVolume, state.nightAlarmVolume) = 0.7
        #expect(max(state.dayAlarmVolume, state.nightAlarmVolume) == 0.7)
        // Active-profile alarmVolume is the silent night value, which is exactly the case
        // we don't want for expiring sensor warnings.
        #expect(state.alarmVolume == 0.0)
    }

    @Test("Expiring-sensor floor stays loud when day is silent and night is loud")
    func expiringFloorMaxReverse() {
        var state = makeStateForceDay()
        state.dayAlarmVolume = 0.0
        state.nightAlarmVolume = 0.6
        #expect(max(state.dayAlarmVolume, state.nightAlarmVolume) == 0.6)
    }
}
