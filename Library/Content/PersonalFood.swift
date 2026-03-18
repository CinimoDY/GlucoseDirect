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

    init(name: String, carbsG: Double) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.carbsG = carbsG
        self.lastUsed = Date()
    }

    init(id: UUID, name: String, carbsG: Double, lastUsed: Date) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.carbsG = carbsG
        self.lastUsed = lastUsed
    }

    // MARK: Internal

    let id: UUID
    let name: String
    let carbsG: Double
    let lastUsed: Date
}

// MARK: Equatable

extension PersonalFood: Equatable {
    static func == (lhs: PersonalFood, rhs: PersonalFood) -> Bool {
        lhs.id == rhs.id
    }
}
