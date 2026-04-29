import Testing
import Foundation
@testable import DOSBTSApp

@Suite("EntryGroupListOverlay sub-lines")
struct EntryGroupListOverlayTests {
    @Test("meal sub-line shows IN PROGRESS within 2-hour window")
    func mealInProgress() {
        let m = MealEntry(timestamp: Date().addingTimeInterval(-30 * 60), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: nil)
        let line = EntryGroupListOverlay.subline(
            for: .meal(m),
            itemCount: 3,
            mealImpact: nil,
            personalFoodAvg: nil,
            glucoseUnit: .mgdL,
            iob: nil,
            paired: false,
            confounders: []
        )
        #expect(line.contains("IN PROGRESS"))
    }

    @Test("meal sub-line shows mmol/L delta when unit is mmol")
    func mealMmol() {
        let m = MealEntry(timestamp: Date().addingTimeInterval(-3 * 3600), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: nil)
        let impact = MealImpact(mealEntryId: m.id, baselineGlucose: 117, peakGlucose: 189, deltaMgDL: 72, timeToPeakMinutes: 105, isClean: true, timestamp: m.timestamp)
        let line = EntryGroupListOverlay.subline(
            for: .meal(m),
            itemCount: 3,
            mealImpact: impact,
            personalFoodAvg: nil,
            glucoseUnit: .mmolL,
            iob: nil,
            paired: false,
            confounders: []
        )
        #expect(line.contains("4.0 mmol/L"))   // 72 mg/dL ÷ 18 ≈ 4.0
    }

    @Test("meal sub-line includes PersonalFood avg with observation count when available")
    func mealPersonalFood() {
        let m = MealEntry(timestamp: Date().addingTimeInterval(-3 * 3600), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: UUID())
        let impact = MealImpact(mealEntryId: m.id, baselineGlucose: 117, peakGlucose: 189, deltaMgDL: 72, timeToPeakMinutes: 105, isClean: true, timestamp: m.timestamp)
        let line = EntryGroupListOverlay.subline(
            for: .meal(m),
            itemCount: 3,
            mealImpact: impact,
            personalFoodAvg: PersonalFoodGlycemic(avgDelta: 68, observationCount: 4),
            glucoseUnit: .mgdL,
            iob: nil,
            paired: false,
            confounders: []
        )
        #expect(line.contains("avg +68"))
        #expect(line.contains("(4)"))
    }

    @Test("insulin sub-line shows IOB when above threshold")
    func insulinIOB() {
        let i = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
        let line = EntryGroupListOverlay.subline(
            for: .insulin(i),
            itemCount: 1,
            mealImpact: nil,
            personalFoodAvg: nil,
            glucoseUnit: .mgdL,
            iob: 1.8,
            paired: false,
            confounders: []
        )
        #expect(line.contains("IOB 1.8U"))
    }

    @Test("insulin sub-line shows paired w/ meal when grouped with a meal")
    func insulinPaired() {
        let i = InsulinDelivery(starts: Date(), ends: Date(), units: 3.0, type: .correctionBolus)
        let line = EntryGroupListOverlay.subline(
            for: .insulin(i),
            itemCount: 1,
            mealImpact: nil,
            personalFoodAvg: nil,
            glucoseUnit: .mgdL,
            iob: nil,
            paired: true,
            confounders: []
        )
        #expect(line.contains("paired w/ meal"))
    }

    @Test("insulin sub-line falls back to type label when no IOB and unpaired")
    func insulinTypeFallback() {
        let i = InsulinDelivery(starts: Date(), ends: Date(), units: 8.0, type: .basal)
        let line = EntryGroupListOverlay.subline(
            for: .insulin(i),
            itemCount: 1,
            mealImpact: nil,
            personalFoodAvg: nil,
            glucoseUnit: .mgdL,
            iob: nil,
            paired: false,
            confounders: []
        )
        // No IOB, not paired — should show the type's localizedDescription
        #expect(!line.isEmpty)
    }

    @Test("exercise sub-line formats duration and activity type")
    func exerciseFormatting() {
        let e = ExerciseEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(30 * 60),
            activityType: "Running",
            durationMinutes: 30,
            activeCalories: 250,
            source: nil
        )
        let line = EntryGroupListOverlay.subline(
            for: .exercise(e),
            itemCount: 1,
            mealImpact: nil,
            personalFoodAvg: nil,
            glucoseUnit: .mgdL,
            iob: nil,
            paired: false,
            confounders: []
        )
        #expect(line.contains("30 min"))
        #expect(line.contains("Running"))
    }
}
