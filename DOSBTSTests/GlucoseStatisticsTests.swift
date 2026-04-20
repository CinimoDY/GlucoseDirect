//
//  GlucoseStatisticsTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - GlucoseStatistics Tests

@Suite("GlucoseStatistics computed properties")
struct GlucoseStatisticsComputedTests {

    private func makeStats(tbr: Double = 5, tar: Double = 10, variance: Double = 100, avg: Double = 120) -> GlucoseStatistics {
        GlucoseStatistics(
            readings: 100,
            fromTimestamp: Date(),
            toTimestamp: Date(),
            gmi: 6.5,
            avg: avg,
            tbr: tbr,
            tar: tar,
            variance: variance,
            days: 7,
            maxDays: 90
        )
    }

    @Test("tir is 100 minus tor")
    func tirComputation() {
        let stats = makeStats(tbr: 5, tar: 10)
        #expect(stats.tir == 85.0)
    }

    @Test("tor is tbr plus tar")
    func torComputation() {
        let stats = makeStats(tbr: 5, tar: 10)
        #expect(stats.tor == 15.0)
    }

    @Test("tir is 100 when tbr and tar are both zero")
    func tirPerfect() {
        let stats = makeStats(tbr: 0, tar: 0)
        #expect(stats.tir == 100.0)
    }

    @Test("stdev is square root of variance")
    func stdevComputation() {
        let stats = makeStats(variance: 100)
        #expect(stats.stdev == 10.0)
    }

    @Test("stdev of zero variance is zero")
    func stdevZero() {
        let stats = makeStats(variance: 0)
        #expect(stats.stdev == 0.0)
    }

    @Test("cv is 100 * stdev / avg")
    func cvComputation() {
        let stats = makeStats(variance: 100, avg: 100)
        // stdev = 10, cv = 100 * 10 / 100 = 10
        #expect(stats.cv == 10.0)
    }
}

// MARK: - SensorGlucose Value Clamping

@Suite("SensorGlucose value clamping and type")
struct SensorGlucoseValueTests {

    @Test("glucoseValue clamps low values to minReadableGlucose")
    func clampLow() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 20, intGlucoseValue: 20)
        #expect(sg.glucoseValue == DirectConfig.minReadableGlucose)
    }

    @Test("glucoseValue clamps high values to maxReadableGlucose")
    func clampHigh() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 600, intGlucoseValue: 600)
        #expect(sg.glucoseValue == DirectConfig.maxReadableGlucose)
    }

    @Test("glucoseValue passes through normal values")
    func normalValue() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 120, intGlucoseValue: 120)
        #expect(sg.glucoseValue == 120)
    }

    @Test("type is .low when below minimum")
    func typeLow() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 20, intGlucoseValue: 20)
        #expect(sg.type == .low)
    }

    @Test("type is .high when above maximum")
    func typeHigh() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 600, intGlucoseValue: 600)
        #expect(sg.type == .high)
    }

    @Test("type is .normal for values in range")
    func typeNormal() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 120, intGlucoseValue: 120)
        #expect(sg.type == .normal)
    }

    @Test("trend delegates to SensorTrend from minuteChange")
    func trendFromMinuteChange() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 120, intGlucoseValue: 120, minuteChange: 4.0)
        #expect(sg.trend == .rapidlyRising)
    }

    @Test("trend is unknown when minuteChange is nil")
    func trendUnknown() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 120, intGlucoseValue: 120, minuteChange: nil)
        #expect(sg.trend == .unknown)
    }
}

// MARK: - SensorGlucose minuteChange

@Suite("SensorGlucose minuteChange calculation")
struct SensorGlucoseMinuteChangeTests {

    @Test("populateChange computes correct minute change")
    func minuteChangeComputation() {
        let t0 = Date()
        let t1 = t0.addingTimeInterval(5 * 60) // 5 minutes later
        let prev = SensorGlucose(timestamp: t0, rawGlucoseValue: 100, intGlucoseValue: 100)
        let current = SensorGlucose(timestamp: t1, rawGlucoseValue: 110, intGlucoseValue: 110)

        let result = current.populateChange(previousGlucose: prev)
        // (110 - 100) / 5 = 2.0 mg/dL/min
        #expect(result.minuteChange != nil)
        #expect(abs(result.minuteChange! - 2.0) < 0.01)
    }

    @Test("populateChange with no previous returns self unchanged")
    func noPrevious() {
        let sg = SensorGlucose(timestamp: Date(), rawGlucoseValue: 120, intGlucoseValue: 120)
        let result = sg.populateChange(previousGlucose: nil)
        #expect(result.minuteChange == nil)
    }

    @Test("populateChange with same timestamp returns zero change")
    func sameTimestamp() {
        let t = Date()
        let prev = SensorGlucose(timestamp: t, rawGlucoseValue: 100, intGlucoseValue: 100)
        let current = SensorGlucose(timestamp: t, rawGlucoseValue: 120, intGlucoseValue: 120)

        let result = current.populateChange(previousGlucose: prev)
        #expect(result.minuteChange == 0.0)
    }
}

// MARK: - Array<SensorGlucose> stdev

@Suite("SensorGlucose array standard deviation")
struct SensorGlucoseArrayStdevTests {

    @Test("stdev of identical values is zero")
    func identicalValues() {
        let values = (0..<5).map { _ in
            SensorGlucose(timestamp: Date(), rawGlucoseValue: 100, intGlucoseValue: 100)
        }
        #expect(values.stdev == 0.0)
    }

    @Test("stdev of known values matches expected")
    func knownValues() {
        // Values: 100, 110, 120, 130, 140 → mean=120, sample stdev ≈ 15.81
        let timestamps = (0..<5).map { Date().addingTimeInterval(Double($0) * 60) }
        let glucoseValues = [100, 110, 120, 130, 140]
        let values = zip(timestamps, glucoseValues).map { (t, g) in
            SensorGlucose(timestamp: t, rawGlucoseValue: g, intGlucoseValue: g)
        }
        #expect(abs(values.stdev - 15.811) < 0.01)
    }
}
