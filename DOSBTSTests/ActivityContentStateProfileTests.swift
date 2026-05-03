//
//  ActivityContentStateProfileTests.swift
//  DOSBTSTests
//
//  Coverage of the Live Activity ContentState's effective-threshold
//  resolution lives alongside the AppGroupSharingProfileTests file
//  (since the helper in question is widget-target-private). This file
//  retains a small surface for any app-target-visible behavior that
//  ContentState owns.
//

import Foundation
import Testing
@testable import DOSBTSApp

@Suite("ContentState type contract")
struct ContentStateTypeContractTests {

    @Test("ContentState exposes optional profile fields")
    func optionalFieldsExist() {
        let state = SensorGlucoseActivityAttributes.ContentState(
            alarmLow: 80,
            alarmHigh: 180
        )
        // All eight new fields are optional and default to nil — tested via construction
        // through the implicit memberwise init that fills them with nil.
        #expect(state.dayAlarmHigh == nil)
        #expect(state.dayAlarmLow == nil)
        #expect(state.nightAlarmHigh == nil)
        #expect(state.nightAlarmLow == nil)
        #expect(state.nightStartHour == nil)
        #expect(state.nightStartMinute == nil)
        #expect(state.nightEndHour == nil)
        #expect(state.nightEndMinute == nil)
    }
}
