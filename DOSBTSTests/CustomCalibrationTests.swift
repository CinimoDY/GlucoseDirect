//
//  CustomCalibrationTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - Slope Tests

@Suite("CustomCalibration slope computation")
struct CustomCalibrationSlopeTests {

    @Test("slope with fewer than 2 points returns 1.0")
    func slopeSinglePoint() {
        let cals = [CustomCalibration(x: 100, y: 110)]
        #expect(cals.slope == 1.0)
    }

    @Test("slope with zero points returns 1.0")
    func slopeEmpty() {
        let cals: [CustomCalibration] = []
        #expect(cals.slope == 1.0)
    }

    @Test("slope with identity points (x == y) returns 1.0")
    func slopeIdentity() {
        let cals = [
            CustomCalibration(x: 100, y: 100),
            CustomCalibration(x: 200, y: 200)
        ]
        #expect(cals.slope == 1.0)
    }

    @Test("slope is clamped to minimum 0.8")
    func slopeClampedLow() {
        // slope would be ~0.5 without clamping
        let cals = [
            CustomCalibration(x: 100.0, y: 50.0),
            CustomCalibration(x: 200.0, y: 100.0)
        ]
        #expect(cals.slope == 0.8)
    }

    @Test("slope is clamped to maximum 1.25")
    func slopeClampedHigh() {
        // slope would be ~2.0 without clamping
        let cals = [
            CustomCalibration(x: 100.0, y: 200.0),
            CustomCalibration(x: 200.0, y: 400.0)
        ]
        #expect(cals.slope == 1.25)
    }

    @Test("slope with all identical x values returns 1.0 (divide by zero guard)")
    func slopeDivideByZero() {
        let cals = [
            CustomCalibration(x: 100.0, y: 90.0),
            CustomCalibration(x: 100.0, y: 110.0)
        ]
        #expect(cals.slope == 1.0)
    }
}

// MARK: - Intercept Tests

@Suite("CustomCalibration intercept computation")
struct CustomCalibrationInterceptTests {

    @Test("intercept with zero points returns 0")
    func interceptEmpty() {
        let cals: [CustomCalibration] = []
        #expect(cals.intercept == 0.0)
    }

    @Test("intercept for identity calibration is 0")
    func interceptIdentity() {
        let cals = [
            CustomCalibration(x: 100, y: 100),
            CustomCalibration(x: 200, y: 200)
        ]
        #expect(abs(cals.intercept) < 0.01)
    }

    @Test("intercept is clamped to minimum -100")
    func interceptClampedLow() {
        // With slope=1.0 and large offset, intercept would be very negative
        let cals = [
            CustomCalibration(x: 300.0, y: 100.0),
            CustomCalibration(x: 400.0, y: 200.0)
        ]
        #expect(cals.intercept == -100.0)
    }

    @Test("intercept is clamped to maximum 100")
    func interceptClampedHigh() {
        let cals = [
            CustomCalibration(x: 100.0, y: 300.0),
            CustomCalibration(x: 200.0, y: 400.0)
        ]
        #expect(cals.intercept == 100.0)
    }
}

// MARK: - Calibrate Tests

@Suite("CustomCalibration calibrate output")
struct CustomCalibrationCalibrateTests {

    @Test("calibrate with identity returns same value")
    func calibrateIdentity() {
        let cals = [
            CustomCalibration(x: 100, y: 100),
            CustomCalibration(x: 200, y: 200)
        ]
        let result = cals.calibrate(sensorGlucose: 150.0)
        #expect(abs(result - 150.0) < 0.01)
    }

    @Test("calibrate clamps result to minReadableGlucose")
    func calibrateClampLow() {
        let cals = [
            CustomCalibration(x: 100, y: 100),
            CustomCalibration(x: 200, y: 200)
        ]
        let result = cals.calibrate(sensorGlucose: 10.0)
        #expect(result == Double(DirectConfig.minReadableGlucose))
    }

    @Test("calibrate clamps result to maxReadableGlucose")
    func calibrateClampHigh() {
        let cals = [
            CustomCalibration(x: 100, y: 100),
            CustomCalibration(x: 200, y: 200)
        ]
        let result = cals.calibrate(sensorGlucose: 600.0)
        #expect(result == Double(DirectConfig.maxReadableGlucose))
    }
}
