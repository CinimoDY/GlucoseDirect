//
//  AlarmProfileMigrationTests.swift
//  DOSBTSTests
//
//  Verifies the once-per-install migration that copies legacy alarm settings
//  into both day and night profiles, and the dual-write rollback safety
//  behavior on day-side setters.
//

import Foundation
import Testing
@testable import DOSBTSApp

private let legacyHighKey = "libre-direct.settings.alarm-high"
private let legacyLowKey = "libre-direct.settings.alarm-low"
private let legacyVolumeKey = "libre-direct.settings.alarm-volume"
private let dayHighKey = "libre-direct.settings.day-alarm-high"
private let dayLowKey = "libre-direct.settings.day-alarm-low"
private let dayVolumeKey = "libre-direct.settings.day-alarm-volume"
private let nightHighKey = "libre-direct.settings.night-alarm-high"
private let nightLowKey = "libre-direct.settings.night-alarm-low"
private let nightVolumeKey = "libre-direct.settings.night-alarm-volume"
private let nightStartHourKey = "libre-direct.settings.night-start-hour"
private let nightStartMinuteKey = "libre-direct.settings.night-start-minute"
private let nightEndHourKey = "libre-direct.settings.night-end-hour"
private let nightEndMinuteKey = "libre-direct.settings.night-end-minute"

private let perProfileKeys = [
    dayHighKey, dayLowKey, dayVolumeKey,
    nightHighKey, nightLowKey, nightVolumeKey,
    nightStartHourKey, nightStartMinuteKey, nightEndHourKey, nightEndMinuteKey
]

private let allAlarmKeys = perProfileKeys + [legacyHighKey, legacyLowKey, legacyVolumeKey]

private func clearAllAlarmKeys() {
    for key in allAlarmKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@Suite("AlarmProfile migration", .serialized)
struct AlarmProfileMigrationTests {

    @Test("Fresh install seeds defaults for both profiles + schedule")
    func freshInstall() {
        clearAllAlarmKeys()

        _ = AppState()

        #expect(UserDefaults.standard.integer(forKey: dayHighKey) == 180)
        #expect(UserDefaults.standard.integer(forKey: nightHighKey) == 180)
        #expect(UserDefaults.standard.integer(forKey: dayLowKey) == 80)
        #expect(UserDefaults.standard.integer(forKey: nightLowKey) == 80)
        #expect(UserDefaults.standard.float(forKey: dayVolumeKey) == 0.5)
        #expect(UserDefaults.standard.float(forKey: nightVolumeKey) == 0.5)
        #expect(UserDefaults.standard.integer(forKey: nightStartHourKey) == 22)
        #expect(UserDefaults.standard.integer(forKey: nightStartMinuteKey) == 0)
        #expect(UserDefaults.standard.integer(forKey: nightEndHourKey) == 7)
        #expect(UserDefaults.standard.integer(forKey: nightEndMinuteKey) == 0)
    }

    @Test("Legacy install copies threshold + volume into both profiles")
    func legacyCopy() {
        clearAllAlarmKeys()
        UserDefaults.standard.set(195, forKey: legacyHighKey)
        UserDefaults.standard.set(75, forKey: legacyLowKey)
        UserDefaults.standard.set(Float(0.65), forKey: legacyVolumeKey)

        _ = AppState()

        #expect(UserDefaults.standard.integer(forKey: dayHighKey) == 195)
        #expect(UserDefaults.standard.integer(forKey: nightHighKey) == 195)
        #expect(UserDefaults.standard.integer(forKey: dayLowKey) == 75)
        #expect(UserDefaults.standard.integer(forKey: nightLowKey) == 75)
        #expect(abs(UserDefaults.standard.float(forKey: dayVolumeKey) - 0.65) < 0.0001)
        #expect(abs(UserDefaults.standard.float(forKey: nightVolumeKey) - 0.65) < 0.0001)
        // Schedule defaults are seeded regardless of legacy state
        #expect(UserDefaults.standard.integer(forKey: nightStartHourKey) == 22)
        #expect(UserDefaults.standard.integer(forKey: nightEndHourKey) == 7)
    }

    @Test("Migration is idempotent — second launch preserves user-tweaked night values")
    func idempotentBasic() {
        clearAllAlarmKeys()
        // Simulate a completed migration with tweaked night thresholds
        UserDefaults.standard.set(180, forKey: dayHighKey)
        UserDefaults.standard.set(220, forKey: nightHighKey)
        UserDefaults.standard.set(80, forKey: dayLowKey)
        UserDefaults.standard.set(85, forKey: nightLowKey)
        UserDefaults.standard.set(Float(0.5), forKey: dayVolumeKey)
        UserDefaults.standard.set(Float(0.0), forKey: nightVolumeKey)
        UserDefaults.standard.set(23, forKey: nightStartHourKey)
        UserDefaults.standard.set(30, forKey: nightStartMinuteKey)
        UserDefaults.standard.set(6, forKey: nightEndHourKey)
        UserDefaults.standard.set(45, forKey: nightEndMinuteKey)

        _ = AppState()

        #expect(UserDefaults.standard.integer(forKey: nightHighKey) == 220)
        #expect(UserDefaults.standard.integer(forKey: nightLowKey) == 85)
        #expect(UserDefaults.standard.float(forKey: nightVolumeKey) == 0)
        #expect(UserDefaults.standard.integer(forKey: nightStartHourKey) == 23)
        #expect(UserDefaults.standard.integer(forKey: nightStartMinuteKey) == 30)
        #expect(UserDefaults.standard.integer(forKey: nightEndHourKey) == 6)
        #expect(UserDefaults.standard.integer(forKey: nightEndMinuteKey) == 45)
    }

    @Test("Migration is idempotent even after legacy key dual-write")
    func idempotentAfterDualWrite() {
        clearAllAlarmKeys()
        // After first migration + a day-side edit, the legacy alarmHigh key
        // is present (dual-write side effect) AND dayAlarmHigh is present.
        UserDefaults.standard.set(170, forKey: dayHighKey)  // user edited via Day picker
        UserDefaults.standard.set(170, forKey: legacyHighKey)  // dual-write echo
        UserDefaults.standard.set(220, forKey: nightHighKey)  // user-customised night
        UserDefaults.standard.set(80, forKey: dayLowKey)
        UserDefaults.standard.set(80, forKey: nightLowKey)
        UserDefaults.standard.set(Float(0.5), forKey: dayVolumeKey)
        UserDefaults.standard.set(Float(0.5), forKey: nightVolumeKey)

        _ = AppState()

        // Night high should still be the user's customised value, not overwritten
        // back to the legacy 170.
        #expect(UserDefaults.standard.integer(forKey: nightHighKey) == 220)
        #expect(UserDefaults.standard.integer(forKey: dayHighKey) == 170)
    }
}

@Suite("AlarmProfile dual-write rollback safety", .serialized)
struct AlarmProfileDualWriteTests {

    @Test("setDayAlarmHigh writes both day and legacy keys")
    func dayAlarmHighDualWrites() {
        clearAllAlarmKeys()
        var state: DirectState = AppState()
        directReducer(state: &state, action: .setDayAlarmHigh(value: 175))

        #expect(UserDefaults.standard.integer(forKey: dayHighKey) == 175)
        #expect(UserDefaults.standard.integer(forKey: legacyHighKey) == 175)
    }

    @Test("setDayAlarmLow writes both day and legacy keys")
    func dayAlarmLowDualWrites() {
        clearAllAlarmKeys()
        var state: DirectState = AppState()
        directReducer(state: &state, action: .setDayAlarmLow(value: 72))

        #expect(UserDefaults.standard.integer(forKey: dayLowKey) == 72)
        #expect(UserDefaults.standard.integer(forKey: legacyLowKey) == 72)
    }

    @Test("setDayAlarmVolume writes both day and legacy keys")
    func dayAlarmVolumeDualWrites() {
        clearAllAlarmKeys()
        var state: DirectState = AppState()
        directReducer(state: &state, action: .setDayAlarmVolume(value: 0.65))

        #expect(abs(UserDefaults.standard.float(forKey: dayVolumeKey) - 0.65) < 0.0001)
        #expect(abs(UserDefaults.standard.float(forKey: legacyVolumeKey) - 0.65) < 0.0001)
    }

    @Test("setNightAlarmHigh writes only night key (no legacy mirror)")
    func nightAlarmHighSingleWrite() {
        clearAllAlarmKeys()
        var state: DirectState = AppState()
        // After init the migration copies whatever is in legacy (or defaults) to legacy too.
        // To verify the night-side does NOT touch the legacy key, we record its value first.
        let legacyBefore = UserDefaults.standard.integer(forKey: legacyHighKey)
        directReducer(state: &state, action: .setNightAlarmHigh(value: 215))

        #expect(UserDefaults.standard.integer(forKey: nightHighKey) == 215)
        #expect(UserDefaults.standard.integer(forKey: legacyHighKey) == legacyBefore)
    }
}
