//
//  ServingPreset.swift
//  DOSBTS
//

import Foundation

// MARK: - ServingPreset

struct ServingPreset: Codable, Identifiable {
    let id: UUID
    let label: String
    let amountML: Double // ml for liquids, g for solids (1:1 approximation)

    init(label: String, amountML: Double) {
        self.id = UUID()
        self.label = label
        self.amountML = amountML
    }

    static let defaults: [ServingPreset] = [
        ServingPreset(label: "Small glass", amountML: 200),
        ServingPreset(label: "Mug", amountML: 250),
        ServingPreset(label: "Large glass", amountML: 350),
        ServingPreset(label: "Small bowl", amountML: 200),
        ServingPreset(label: "Large bowl", amountML: 350),
    ]
}
