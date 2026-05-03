//
//  SensorGlucoseActivityAttributes.swift
//  DOSBTS
//

import ActivityKit
import Foundation

// MARK: - SensorGlucoseActivityAttributes

struct SensorGlucoseActivityAttributes: ActivityAttributes {
    public typealias GlucoseStatus = ContentState

    public struct ContentState: Codable, Hashable {
        var alarmLow: Int
        var alarmHigh: Int

        var sensorState: SensorState?
        var connectionState: SensorConnectionState?

        var glucose: SensorGlucose?
        var glucoseUnit: GlucoseUnit?
        var iob: Double?
        var sparkline: [Int]?

        var startDate: Date?
        var restartDate: Date?
        var stopDate: Date?

        // Day/Night alarm profile fields. All optional so in-flight activities
        // from pre-upgrade builds continue to decode and render via the legacy
        // alarmLow/alarmHigh fields. The Live Activity widget computes the
        // active profile at render time when all eight fields are present.
        var nightStartHour: Int?
        var nightStartMinute: Int?
        var nightEndHour: Int?
        var nightEndMinute: Int?
        var dayAlarmHigh: Int?
        var dayAlarmLow: Int?
        var nightAlarmHigh: Int?
        var nightAlarmLow: Int?
    }
}
