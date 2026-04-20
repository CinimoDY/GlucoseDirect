//
//  SensorTrendTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - Slope Classification

@Suite("SensorTrend slope classification")
struct SensorTrendSlopeTests {

    @Test("slope > 3.5 is rapidlyRising")
    func rapidlyRising() {
        #expect(SensorTrend(slope: 4.0) == .rapidlyRising)
    }

    @Test("slope > 2.0 and <= 3.5 is fastRising")
    func fastRising() {
        #expect(SensorTrend(slope: 2.5) == .fastRising)
    }

    @Test("slope > 1.0 and <= 2.0 is rising")
    func rising() {
        #expect(SensorTrend(slope: 1.5) == .rising)
    }

    @Test("slope < -3.5 is rapidlyFalling")
    func rapidlyFalling() {
        #expect(SensorTrend(slope: -4.0) == .rapidlyFalling)
    }

    @Test("slope < -2.0 and >= -3.5 is fastFalling")
    func fastFalling() {
        #expect(SensorTrend(slope: -2.5) == .fastFalling)
    }

    @Test("slope < -1.0 and >= -2.0 is falling")
    func falling() {
        #expect(SensorTrend(slope: -1.5) == .falling)
    }

    @Test("slope between -1.0 and 1.0 is constant")
    func constant() {
        #expect(SensorTrend(slope: 0.0) == .constant)
        #expect(SensorTrend(slope: 0.5) == .constant)
        #expect(SensorTrend(slope: -0.5) == .constant)
    }

    @Test("exact boundary 3.5 is fastRising not rapidlyRising")
    func boundaryRapidRising() {
        // > 3.5 is rapidlyRising, so exactly 3.5 falls to fastRising
        #expect(SensorTrend(slope: 3.5) == .fastRising)
    }

    @Test("exact boundary -3.5 is fastFalling not rapidlyFalling")
    func boundaryRapidFalling() {
        #expect(SensorTrend(slope: -3.5) == .fastFalling)
    }

    @Test("exact boundary 1.0 is constant")
    func boundaryRising() {
        // > 1.0 is rising, so exactly 1.0 falls to constant
        #expect(SensorTrend(slope: 1.0) == .constant)
    }

    @Test("exact boundary -1.0 is constant")
    func boundaryFalling() {
        #expect(SensorTrend(slope: -1.0) == .constant)
    }

    @Test("default init is unknown")
    func defaultInit() {
        #expect(SensorTrend() == .unknown)
    }
}

// MARK: - Nightscout Conversions

@Suite("SensorTrend Nightscout conversion")
struct SensorTrendNightscoutTests {

    @Test("toNightscoutTrend maps all cases correctly")
    func nightscoutTrend() {
        #expect(SensorTrend.rapidlyRising.toNightscoutTrend() == 1)
        #expect(SensorTrend.fastRising.toNightscoutTrend() == 2)
        #expect(SensorTrend.rising.toNightscoutTrend() == 3)
        #expect(SensorTrend.constant.toNightscoutTrend() == 4)
        #expect(SensorTrend.falling.toNightscoutTrend() == 5)
        #expect(SensorTrend.fastFalling.toNightscoutTrend() == 6)
        #expect(SensorTrend.rapidlyFalling.toNightscoutTrend() == 7)
        #expect(SensorTrend.unknown.toNightscoutTrend() == 0)
    }

    @Test("toNightscoutDirection maps all cases correctly")
    func nightscoutDirection() {
        #expect(SensorTrend.rapidlyRising.toNightscoutDirection() == "DoubleUp")
        #expect(SensorTrend.fastRising.toNightscoutDirection() == "SingleUp")
        #expect(SensorTrend.rising.toNightscoutDirection() == "FortyFiveUp")
        #expect(SensorTrend.constant.toNightscoutDirection() == "Flat")
        #expect(SensorTrend.falling.toNightscoutDirection() == "FortyFiveDown")
        #expect(SensorTrend.fastFalling.toNightscoutDirection() == "SingleDown")
        #expect(SensorTrend.rapidlyFalling.toNightscoutDirection() == "DoubleDown")
        #expect(SensorTrend.unknown.toNightscoutDirection() == "NONE")
    }
}
