//
//  MealImpact.swift
//  DOSBTS
//

import Foundation

// MARK: - MealImpact

struct MealImpact: CustomStringConvertible, Codable, Identifiable {
    // MARK: Lifecycle

    init(mealEntryId: UUID, baselineGlucose: Int?, peakGlucose: Int, deltaMgDL: Int, timeToPeakMinutes: Int, isClean: Bool, timestamp: Date) {
        self.id = UUID()
        self.mealEntryId = mealEntryId
        self.baselineGlucose = baselineGlucose
        self.peakGlucose = peakGlucose
        self.deltaMgDL = deltaMgDL
        self.timeToPeakMinutes = timeToPeakMinutes
        self.isClean = isClean
        self.timestamp = timestamp
    }

    init(id: UUID, mealEntryId: UUID, baselineGlucose: Int?, peakGlucose: Int, deltaMgDL: Int, timeToPeakMinutes: Int, isClean: Bool, timestamp: Date) {
        self.id = id
        self.mealEntryId = mealEntryId
        self.baselineGlucose = baselineGlucose
        self.peakGlucose = peakGlucose
        self.deltaMgDL = deltaMgDL
        self.timeToPeakMinutes = timeToPeakMinutes
        self.isClean = isClean
        self.timestamp = timestamp
    }

    // MARK: Internal

    let id: UUID
    let mealEntryId: UUID
    let baselineGlucose: Int?
    let peakGlucose: Int
    let deltaMgDL: Int
    let timeToPeakMinutes: Int
    let isClean: Bool
    let timestamp: Date

    var description: String {
        "{ id: \(id), mealEntryId: \(mealEntryId), delta: \(deltaMgDL) mg/dL, peak: \(peakGlucose), timeToPeak: \(timeToPeakMinutes) min, isClean: \(isClean) }"
    }
}

// MARK: Equatable

extension MealImpact: Equatable {
    static func == (lhs: MealImpact, rhs: MealImpact) -> Bool {
        lhs.id == rhs.id
    }
}
