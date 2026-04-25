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
            mealStart: nil,
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
            mealStart: nil,
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
            mealStart: nil,
            confounders: []
        )
        #expect(line.contains("avg +68"))
        #expect(line.contains("(4)"))
    }
}
