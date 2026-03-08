//
//  MealEntry.swift
//  DOSBTS
//

import Foundation

// MARK: - MealEntry

struct MealEntry: CustomStringConvertible, Codable, Identifiable {
    // MARK: Lifecycle

    init(timestamp: Date, mealDescription: String, carbsGrams: Double?) {
        let roundedTimestamp = timestamp.toRounded(on: 1, .minute)

        self.id = UUID()
        self.timestamp = roundedTimestamp
        self.mealDescription = mealDescription
        self.carbsGrams = carbsGrams
        self.timegroup = roundedTimestamp.toRounded(on: DirectConfig.timegroupRounding, .minute)
    }

    init(id: UUID, timestamp: Date, mealDescription: String, carbsGrams: Double?) {
        let roundedTimestamp = timestamp.toRounded(on: 1, .minute)

        self.id = id
        self.timestamp = roundedTimestamp
        self.mealDescription = mealDescription
        self.carbsGrams = carbsGrams
        self.timegroup = roundedTimestamp.toRounded(on: DirectConfig.timegroupRounding, .minute)
    }

    // MARK: Internal

    let id: UUID
    let timestamp: Date
    let mealDescription: String
    let carbsGrams: Double?
    let timegroup: Date

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
