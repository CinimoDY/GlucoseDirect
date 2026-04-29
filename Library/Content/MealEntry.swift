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

// MARK: Hashable

extension MealEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Staging Plate Hydration

extension MealEntry {
    /// Build a `NutritionEstimate` to seed the staging plate when relogging
    /// this meal. When the meal carries an `analysisSessionId` and matching
    /// `PersonalFood` rows exist, the per-item breakdown is restored;
    /// otherwise we fall back to a single aggregate item carrying the meal's
    /// description and totals.
    func toNutritionEstimate(personalFoods: [PersonalFood]) -> NutritionEstimate {
        let linked = analysisSessionId.map { id in
            personalFoods.filter { $0.analysisSessionId == id }
        } ?? []

        let items: [NutritionItem]
        if !linked.isEmpty {
            items = linked.map { food in
                NutritionItem(
                    name: food.name,
                    carbsG: food.carbsG,
                    proteinG: nil,
                    fatG: nil,
                    calories: nil,
                    fiberG: nil,
                    servingSize: nil
                )
            }
        } else {
            items = [
                NutritionItem(
                    name: mealDescription.isEmpty ? "Meal" : mealDescription,
                    carbsG: carbsGrams ?? 0,
                    proteinG: proteinGrams,
                    fatG: fatGrams,
                    calories: calories,
                    fiberG: fiberGrams,
                    servingSize: nil
                ),
            ]
        }

        return NutritionEstimate(
            description: mealDescription,
            items: items,
            totalCarbsG: carbsGrams ?? 0,
            totalCalories: calories,
            confidence: .high,
            confidenceNotes: nil,
            rawAssistantJSON: nil
        )
    }
}
