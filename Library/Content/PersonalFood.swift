//
//  PersonalFood.swift
//  DOSBTS
//

import Foundation

// MARK: - PersonalFood

/// AI-observed food dictionary, auto-populated from user corrections.
/// Distinct from FavoriteFood: PersonalFood is never user-managed directly,
/// has no sortOrder or isHypoTreatment. It feeds AI prompts only.

struct PersonalFood: Codable, Identifiable {
    // MARK: Lifecycle

    init(name: String, carbsG: Double, analysisSessionId: UUID? = nil, avgDeltaMgDL: Double? = nil, observationCount: Int = 0, lastScoredDate: Date? = nil) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.carbsG = carbsG
        self.lastUsed = Date()
        self.analysisSessionId = analysisSessionId
        self.avgDeltaMgDL = avgDeltaMgDL
        self.observationCount = observationCount
        self.lastScoredDate = lastScoredDate
    }

    init(id: UUID, name: String, carbsG: Double, lastUsed: Date, analysisSessionId: UUID? = nil, avgDeltaMgDL: Double? = nil, observationCount: Int = 0, lastScoredDate: Date? = nil) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.carbsG = carbsG
        self.lastUsed = lastUsed
        self.analysisSessionId = analysisSessionId
        self.avgDeltaMgDL = avgDeltaMgDL
        self.observationCount = observationCount
        self.lastScoredDate = lastScoredDate
    }

    // MARK: Internal

    let id: UUID
    let name: String
    let carbsG: Double
    let lastUsed: Date
    let analysisSessionId: UUID?
    let avgDeltaMgDL: Double?
    let observationCount: Int
    let lastScoredDate: Date?
}

// MARK: Equatable

extension PersonalFood: Equatable {
    static func == (lhs: PersonalFood, rhs: PersonalFood) -> Bool {
        lhs.id == rhs.id
    }
}
