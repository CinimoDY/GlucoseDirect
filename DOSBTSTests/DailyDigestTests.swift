//
//  DailyDigestTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - DailyDigest Model Tests

@Suite("DailyDigest model")
struct DailyDigestModelTests {

    @Test("DailyDigest initializes with all fields and auto-generates UUID")
    func initWithAllFields() {
        let date = Date()
        let digest = DailyDigest(
            date: date, tir: 78.0, tbr: 5.0, tar: 17.0,
            avg: 142.0, stdev: 35.0, readings: 288,
            lowCount: 2, highCount: 3,
            totalCarbsGrams: 185.0, totalInsulinUnits: 24.0,
            totalExerciseMinutes: 30.0, mealCount: 3, insulinCount: 5
        )

        #expect(digest.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(digest.tir == 78.0)
        #expect(digest.tbr == 5.0)
        #expect(digest.tar == 17.0)
        #expect(digest.avg == 142.0)
        #expect(digest.readings == 288)
        #expect(digest.lowCount == 2)
        #expect(digest.highCount == 3)
        #expect(digest.totalCarbsGrams == 185.0)
        #expect(digest.totalInsulinUnits == 24.0)
        #expect(digest.totalExerciseMinutes == 30.0)
        #expect(digest.mealCount == 3)
        #expect(digest.insulinCount == 5)
        #expect(digest.aiInsight == nil)
        #expect(digest.generatedAt == nil)
    }

    @Test("Two digests with different dates are not equal")
    func differentDatesNotEqual() {
        let d1 = DailyDigest(
            date: Date(), tir: 78.0, tbr: 5.0, tar: 17.0,
            avg: 142.0, stdev: 35.0, readings: 288,
            lowCount: 0, highCount: 0,
            totalCarbsGrams: 0, totalInsulinUnits: 0,
            totalExerciseMinutes: 0, mealCount: 0, insulinCount: 0
        )
        let d2 = DailyDigest(
            date: Date().addingTimeInterval(-86400), tir: 78.0, tbr: 5.0, tar: 17.0,
            avg: 142.0, stdev: 35.0, readings: 288,
            lowCount: 0, highCount: 0,
            totalCarbsGrams: 0, totalInsulinUnits: 0,
            totalExerciseMinutes: 0, mealCount: 0, insulinCount: 0
        )
        #expect(d1 != d2)
    }

    @Test("DailyDigest with nil aiInsight and nil generatedAt")
    func preAIState() {
        let digest = DailyDigest(
            date: Date(), tir: 80.0, tbr: 3.0, tar: 17.0,
            avg: 135.0, stdev: 30.0, readings: 200,
            lowCount: 1, highCount: 2,
            totalCarbsGrams: 150.0, totalInsulinUnits: 20.0,
            totalExerciseMinutes: 0, mealCount: 2, insulinCount: 3
        )
        #expect(digest.aiInsight == nil)
        #expect(digest.generatedAt == nil)
    }

    @Test("DailyDigest with aiInsight populated")
    func withInsight() {
        var digest = DailyDigest(
            date: Date(), tir: 65.0, tbr: 10.0, tar: 25.0,
            avg: 160.0, stdev: 45.0, readings: 288,
            lowCount: 3, highCount: 5,
            totalCarbsGrams: 200.0, totalInsulinUnits: 28.0,
            totalExerciseMinutes: 45.0, mealCount: 4, insulinCount: 6
        )
        digest.aiInsight = "Your late dinner caused an overnight high."
        digest.generatedAt = Date()

        #expect(digest.aiInsight != nil)
        #expect(digest.generatedAt != nil)
    }
}
