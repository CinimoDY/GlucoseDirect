//
//  MealEntry.swift
//  DOSBTS
//

import Foundation

// MARK: - MealEntry

struct MealEntry: CustomStringConvertible, Codable, Identifiable {
    // MARK: Lifecycle

    init(timestamp: Date, mealDescription: String, carbsGrams: Double?, proteinGrams: Double? = nil, fatGrams: Double? = nil, calories: Double? = nil, fiberGrams: Double? = nil, analysisSessionId: UUID? = nil) {
        let roundedTimestamp = timestamp.toRounded(on: 1, .minute)

        self.id = UUID()
        self.timestamp = roundedTimestamp
        self.mealDescription = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        self.carbsGrams = carbsGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.calories = calories
        self.fiberGrams = fiberGrams
        self.timegroup = roundedTimestamp.toRounded(on: DirectConfig.timegroupRounding, .minute)
        self.analysisSessionId = analysisSessionId
    }

    init(id: UUID, timestamp: Date, mealDescription: String, carbsGrams: Double?, proteinGrams: Double? = nil, fatGrams: Double? = nil, calories: Double? = nil, fiberGrams: Double? = nil, analysisSessionId: UUID? = nil) {
        let roundedTimestamp = timestamp.toRounded(on: 1, .minute)

        self.id = id
        self.timestamp = roundedTimestamp
        self.mealDescription = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        self.carbsGrams = carbsGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.calories = calories
        self.fiberGrams = fiberGrams
        self.timegroup = roundedTimestamp.toRounded(on: DirectConfig.timegroupRounding, .minute)
        self.analysisSessionId = analysisSessionId
    }

    // MARK: Internal

    let id: UUID
    let timestamp: Date
    let mealDescription: String
    let carbsGrams: Double?
    let proteinGrams: Double?
    let fatGrams: Double?
    let calories: Double?
    let fiberGrams: Double?
    let timegroup: Date
    let analysisSessionId: UUID?

    var description: String {
        "{ id: \(id), timestamp: \(timestamp.toLocalTime()), mealDescription: \(mealDescription), carbsGrams: \(carbsGrams ?? 0) }"
    }
}

// MARK: Equatable

extension MealEntry: Equatable {
    static func == (lhs: MealEntry, rhs: MealEntry) -> Bool {
        lhs.id == rhs.id
    }
}
