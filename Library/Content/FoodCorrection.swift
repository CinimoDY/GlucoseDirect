//
//  FoodCorrection.swift
//  DOSBTS
//

import Foundation

// MARK: - FoodCorrection

/// Records what the AI got wrong during food photo analysis.
/// Used to inject corrections into future Claude prompts so the AI learns from mistakes.
/// Distinct from PersonalFood (dictionary) — this is the raw correction log.

struct FoodCorrection: Codable, Identifiable {
    // MARK: Lifecycle

    init(correctionType: CorrectionType, originalName: String?, correctedName: String?, originalCarbsG: Double?, correctedCarbsG: Double?) {
        self.id = UUID()
        self.timestamp = Date()
        self.correctionType = correctionType
        self.originalName = originalName
        self.correctedName = correctedName
        self.originalCarbsG = originalCarbsG
        self.correctedCarbsG = correctedCarbsG
    }

    // MARK: Internal

    let id: UUID
    let timestamp: Date
    let correctionType: CorrectionType
    let originalName: String?
    let correctedName: String?
    let originalCarbsG: Double?
    let correctedCarbsG: Double?

    // Stable raw values — never rename these; historical data depends on them
    enum CorrectionType: String, Codable {
        case nameChange = "name_change"
        case carbChange = "carb_change"
        case deleted = "deleted"
        case added = "added"
    }
}

// MARK: Equatable

extension FoodCorrection: Equatable {
    static func == (lhs: FoodCorrection, rhs: FoodCorrection) -> Bool {
        lhs.id == rhs.id
    }
}
