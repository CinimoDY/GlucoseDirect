//
//  IOBCalculatorTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - ExponentialInsulinModel Tests

@Suite("Exponential Insulin Model")
struct ExponentialInsulinModelTests {

    let rapidActing = InsulinPreset.rapidActing.model
    let ultraRapid = InsulinPreset.ultraRapid.model

    @Test("IOB at t=0 is 1.0 (full dose)")
    func iobAtZero() {
        #expect(rapidActing.percentEffectRemaining(at: 0) == 1.0)
    }

    @Test("IOB at t=DIA is 0.0 (fully absorbed)")
    func iobAtDIA() {
        #expect(rapidActing.percentEffectRemaining(at: 6 * 60 * 60) == 0.0)
    }

    @Test("IOB at t=DIA/2 matches expected exponential value")
    func iobAtHalfDIA() {
        let iob = rapidActing.percentEffectRemaining(at: 3 * 60 * 60)
        // Exponential model at t=DIA/2 with peak=75m, DIA=6h
        #expect(iob > 0.15)
        #expect(iob < 0.45)
    }

    @Test("IOB at negative time is 1.0 (delivery in future)")
    func iobNegativeTime() {
        #expect(rapidActing.percentEffectRemaining(at: -60) == 1.0)
    }

    @Test("IOB past DIA is 0.0")
    func iobPastDIA() {
        #expect(rapidActing.percentEffectRemaining(at: 7 * 60 * 60) == 0.0)
    }

    @Test("Ultra-rapid decays faster than rapid-acting at same elapsed time")
    func ultraRapidFasterDecay() {
        let elapsed: TimeInterval = 2 * 60 * 60 // 2 hours
        let rapidIOB = rapidActing.percentEffectRemaining(at: elapsed)
        let ultraIOB = ultraRapid.percentEffectRemaining(at: elapsed)
        #expect(ultraIOB < rapidIOB)
    }

    @Test("IOB is monotonically decreasing over time")
    func monotonicallyDecreasing() {
        var previous = 1.0
        for minutes in stride(from: 5, through: 360, by: 5) {
            let current = rapidActing.percentEffectRemaining(at: Double(minutes) * 60)
            #expect(current <= previous)
            previous = current
        }
    }
}

// MARK: - computeIOB Tests

@Suite("IOB Computation")
struct IOBComputationTests {

    let bolusModel = InsulinPreset.rapidActing.model
    let basalModel = ExponentialInsulinModel(actionDuration: 6 * 60 * 60, peakActivityTime: 75 * 60)
    let now = Date()

    @Test("1U bolus at t=0, IOB is 1.0U")
    func singleBolusAtZero() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.total - 1.0) < 0.01)
    }

    @Test("1U bolus at t=DIA, IOB is 0.0")
    func singleBolusAtDIA() {
        let sixHoursAgo = now.addingTimeInterval(-6 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: sixHoursAgo, ends: sixHoursAgo, units: 1.0, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
    }

    @Test("Empty delivery list returns all zeros")
    func emptyDeliveries() {
        let result = computeIOB(deliveries: [], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
        #expect(result.mealSnackIOB == 0.0)
        #expect(result.correctionBasalIOB == 0.0)
    }

    @Test("IOB below 0.05U threshold returns 0.0")
    func belowThreshold() {
        let almostDone = now.addingTimeInterval(-5.9 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: almostDone, ends: almostDone, units: 1.0, type: .mealBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
    }

    @Test("Future delivery has zero IOB — not yet delivered")
    func futureDelivery() {
        let future = now.addingTimeInterval(30 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: future, ends: future, units: 2.0, type: .mealBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
    }

    @Test("Split IOB separates rapid-acting bolus (meal+snack+correction) from basal")
    func splitIOB() {
        // Meal, snack, and correction boluses are all rapid-acting and share
        // the bolus IOB bucket; only basal is in the basal bucket.
        let meal = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 3.0, type: .mealBolus
        )
        let correction = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [meal, correction], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.mealSnackIOB - 4.0) < 0.01)
        #expect(abs(result.correctionBasalIOB - 0.0) < 0.01)
        #expect(abs(result.total - 4.0) < 0.01)
    }

    @Test("Multiple overlapping boluses sum IOB correctly")
    func overlappingBoluses() {
        let oneHourAgo = now.addingTimeInterval(-1 * 60 * 60)
        let delivery1 = InsulinDelivery(
            id: UUID(), starts: oneHourAgo, ends: oneHourAgo, units: 2.0, type: .mealBolus
        )
        let delivery2 = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .snackBolus
        )
        let result = computeIOB(deliveries: [delivery1, delivery2], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total > 2.0) // 1.0 from recent + partial from 1h ago
        #expect(result.total < 3.0) // Less than full sum since 1h decayed
    }

    @Test("Basal entry decays via segmented integration")
    func basalDecay() {
        let twoHoursAgo = now.addingTimeInterval(-2 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: twoHoursAgo, ends: now, units: 2.0, type: .basal
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        // Basal spread over 2 hours, partially decayed — should be significant but less than 2.0
        #expect(result.total > 0.5)
        #expect(result.total < 2.0)
        #expect(result.correctionBasalIOB > 0.5) // Basal goes to correction+basal bucket
    }

    @Test("Snack bolus goes to mealSnack bucket")
    func snackBolus() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .snackBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.mealSnackIOB - 1.0) < 0.01)
        #expect(result.correctionBasalIOB == 0.0)
    }

    @Test("Zero-duration basal is treated as bolus using basal model")
    func zeroDurationBasal() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .basal
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.total - 1.0) < 0.01)
        #expect(result.correctionBasalIOB > 0) // Basal goes to correction+basal bucket
    }

    @Test("Split components sum to total")
    func splitSumsToTotal() {
        let meal = InsulinDelivery(id: UUID(), starts: now, ends: now, units: 3.0, type: .mealBolus)
        let corr = InsulinDelivery(id: UUID(), starts: now, ends: now, units: 1.0, type: .correctionBolus)
        let result = computeIOB(deliveries: [meal, corr], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.total - (result.mealSnackIOB + result.correctionBasalIOB)) < 0.001)
    }

    @Test("IOB is non-negative for any input")
    func iobNonNegative() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now.addingTimeInterval(-5 * 60 * 60), ends: now.addingTimeInterval(-5 * 60 * 60), units: 0.1, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total >= 0)
        #expect(result.mealSnackIOB >= 0)
        #expect(result.correctionBasalIOB >= 0)
    }
}
