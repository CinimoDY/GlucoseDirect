//
//  NutritionEstimate.swift
//  DOSBTS
//

import Foundation

// MARK: - ConversationTurn

/// Lightweight struct for multi-turn Claude API conversation
struct ConversationTurn {
    let role: String // "user" or "assistant"
    let content: String
}

// MARK: - NutritionEstimate

struct NutritionEstimate: Codable {
    var description: String
    var items: [NutritionItem]
    var totalCarbsG: Double
    var totalCalories: Double?
    var confidence: Confidence
    var confidenceNotes: String?
    /// Transient: raw JSON from Claude for multi-turn follow-up.
    /// Not in CodingKeys — intentionally excluded from encode/decode.
    /// Lost on any serialization round-trip. Do NOT persist or rely on across sessions.
    var rawAssistantJSON: String?

    enum Confidence: String, Codable {
        case high
        case medium
        case low
    }

    var totalProteinG: Double? {
        let values = items.compactMap(\.proteinG)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var totalFatG: Double? {
        let values = items.compactMap(\.fatG)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var totalFiberG: Double? {
        let values = items.compactMap(\.fiberG)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    enum CodingKeys: String, CodingKey {
        case description
        case items
        case totalCarbsG = "total_carbs_g"
        case totalCalories = "total_calories"
        case confidence
        case confidenceNotes = "confidence_notes"
    }
}

// MARK: - NutritionItem

struct NutritionItem: Codable, Identifiable {
    let id = UUID()
    var name: String
    var carbsG: Double
    var proteinG: Double?
    var fatG: Double?
    var calories: Double?
    var fiberG: Double?
    var servingSize: String?

    enum CodingKeys: String, CodingKey {
        case name
        case carbsG = "carbs_g"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case calories
        case fiberG = "fiber_g"
        case servingSize = "serving_size"
    }
}
