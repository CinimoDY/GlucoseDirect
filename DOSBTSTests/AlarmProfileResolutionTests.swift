//
//  AlarmProfileResolutionTests.swift
//  DOSBTSTests
//
//  Tests the render-time helpers extracted from the widget targets into
//  Library/Content/AlarmProfile.swift, plus the critical-low breakthrough
//  helper used by GlucoseNotification.swift.
//

import Foundation
import Testing
@testable import DOSBTSApp

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.hour = hour
    components.minute = minute
    components.second = 0
    return Calendar.current.date(from: components) ?? Date()
}

private func makeIntReader(_ values: [String: Int]) -> (String) -> Int? {
    { key in values[key] }
}

private let completeProfile: [String: Int] = [
    AppGroupAlarmProfileKeys.dayAlarmHigh: 180,
    AppGroupAlarmProfileKeys.dayAlarmLow: 80,
    AppGroupAlarmProfileKeys.nightAlarmHigh: 200,
    AppGroupAlarmProfileKeys.nightAlarmLow: 70,
    AppGroupAlarmProfileKeys.nightStartHour: 22,
    AppGroupAlarmProfileKeys.nightStartMinute: 0,
    AppGroupAlarmProfileKeys.nightEndHour: 7,
    AppGroupAlarmProfileKeys.nightEndMinute: 0
]

@Suite("resolveActiveProfileThresholds")
struct ResolveActiveProfileThresholdsTests {

    @Test("Returns nil when any required key is missing")
    func returnsNilOnMissingKey() {
        for missing in AppGroupAlarmProfileKeys.allRequired {
            var partial = completeProfile
            partial.removeValue(forKey: missing)
            let result = resolveActiveProfileThresholds(
                at: dateAt(hour: 23, minute: 0),
                intReader: makeIntReader(partial)
            )
            #expect(result == nil, "Should return nil when '\(missing)' is absent")
        }
    }

    @Test("Returns day thresholds at 14:00 with default schedule")
    func resolvesDayMidday() {
        let result = resolveActiveProfileThresholds(
            at: dateAt(hour: 14, minute: 0),
            intReader: makeIntReader(completeProfile)
        )
        #expect(result?.profile == .day)
        #expect(result?.alarmLow == 80)
        #expect(result?.alarmHigh == 180)
    }

    @Test("Returns night thresholds at 23:00 with default schedule")
    func resolvesNightLate() {
        let result = resolveActiveProfileThresholds(
            at: dateAt(hour: 23, minute: 0),
            intReader: makeIntReader(completeProfile)
        )
        #expect(result?.profile == .night)
        #expect(result?.alarmLow == 70)
        #expect(result?.alarmHigh == 200)
    }

    @Test("Boundary at exact start (22:00) is night (inclusive lower bound)")
    func startInclusive() {
        let result = resolveActiveProfileThresholds(
            at: dateAt(hour: 22, minute: 0),
            intReader: makeIntReader(completeProfile)
        )
        #expect(result?.profile == .night)
    }

    @Test("Boundary at exact end (07:00) is day (exclusive upper bound)")
    func endExclusive() {
        let result = resolveActiveProfileThresholds(
            at: dateAt(hour: 7, minute: 0),
            intReader: makeIntReader(completeProfile)
        )
        #expect(result?.profile == .day)
    }

    @Test("Reader returning 0 for an integer key (legitimate clock value) does NOT trigger fallback")
    func zeroIsNotMissing() {
        // nightStartMinute = 0 is a legitimate clock value. The helper must
        // distinguish "key absent" (nil) from "key present with value 0".
        var midnightSchedule = completeProfile
        midnightSchedule[AppGroupAlarmProfileKeys.nightStartHour] = 0
        midnightSchedule[AppGroupAlarmProfileKeys.nightStartMinute] = 0
        midnightSchedule[AppGroupAlarmProfileKeys.nightEndHour] = 6
        midnightSchedule[AppGroupAlarmProfileKeys.nightEndMinute] = 30
        let result = resolveActiveProfileThresholds(
            at: dateAt(hour: 3, minute: 0),
            intReader: makeIntReader(midnightSchedule)
        )
        #expect(result?.profile == .night)
        #expect(result?.alarmLow == 70)
    }
}

@Suite("nextAlarmProfileBoundary")
struct NextAlarmProfileBoundaryTests {

    @Test("Returns nil for degenerate same-time schedule")
    func degenerateReturnsNil() {
        let next = nextAlarmProfileBoundary(
            from: dateAt(hour: 12, minute: 0),
            nightStartHour: 0, nightStartMinute: 0,
            nightEndHour: 0, nightEndMinute: 0
        )
        #expect(next == nil)
    }

    @Test("Returns nil when no boundary within the lookahead window")
    func outsideLookaheadReturnsNil() {
        // At 14:00, next boundary (start 22:00) is 8h away — well past the 15-min default.
        let next = nextAlarmProfileBoundary(
            from: dateAt(hour: 14, minute: 0),
            nightStartHour: 22, nightStartMinute: 0,
            nightEndHour: 7, nightEndMinute: 0
        )
        #expect(next == nil)
    }

    @Test("Returns the next boundary when within lookahead")
    func returnsNextBoundary() {
        // At 21:55, next boundary (start 22:00) is 5 min away — within the 15-min default.
        let from = dateAt(hour: 21, minute: 55)
        let next = nextAlarmProfileBoundary(
            from: from,
            nightStartHour: 22, nightStartMinute: 0,
            nightEndHour: 7, nightEndMinute: 0
        )
        #expect(next != nil)
        if let next {
            let interval = next.timeIntervalSince(from)
            // 5 minutes = 300 seconds (the helper rounds the seconds component out)
            #expect(interval > 0 && interval <= 5 * 60 + 1)
        }
    }

    @Test("Picks the closer boundary when both are in the future")
    func picksCloserBoundary() {
        // At 06:55, both end (07:00, +5min) and next start (22:00, +15h) are future.
        // End is closer.
        let from = dateAt(hour: 6, minute: 55)
        let next = nextAlarmProfileBoundary(
            from: from,
            nightStartHour: 22, nightStartMinute: 0,
            nightEndHour: 7, nightEndMinute: 0
        )
        #expect(next != nil)
        if let next {
            let interval = next.timeIntervalSince(from)
            #expect(interval <= 5 * 60 + 1)
        }
    }
}

@Suite("isCriticalLow breakthrough decision")
struct IsCriticalLowTests {

    @Test("Returns true when glucose is more than the margin below alarmLow")
    func belowMargin() {
        // alarmLow = 80, margin = 15, threshold = 65.
        #expect(isCriticalLow(glucoseValue: 64, alarmLow: 80))
    }

    @Test("Returns false when glucose is exactly at the breakthrough threshold")
    func atThreshold() {
        // 80 - 15 = 65; the helper uses strict less-than, so 65 is NOT critical.
        #expect(!isCriticalLow(glucoseValue: 65, alarmLow: 80))
    }

    @Test("Returns false when glucose is at alarmLow but above the breakthrough margin")
    func atAlarmLow() {
        #expect(!isCriticalLow(glucoseValue: 80, alarmLow: 80))
    }

    @Test("Tracks the night profile when alarmLow comes from night settings")
    func tracksNightThreshold() {
        // Night alarmLow = 70 → breakthrough threshold = 55.
        // Glucose 60: still above 55, so NOT critical under night.
        #expect(!isCriticalLow(glucoseValue: 60, alarmLow: 70))
        // Glucose 54: below 55, so IS critical under night.
        #expect(isCriticalLow(glucoseValue: 54, alarmLow: 70))
    }

    @Test("Critical-low at higher day threshold but not at lower night threshold")
    func boundaryShiftDoesNotFire() {
        // Day alarmLow = 80 → threshold 65; glucose 64 IS critical.
        #expect(isCriticalLow(glucoseValue: 64, alarmLow: 80))
        // Same glucose under night alarmLow = 70 → threshold 55; 64 is NOT critical.
        #expect(!isCriticalLow(glucoseValue: 64, alarmLow: 70))
    }
}
