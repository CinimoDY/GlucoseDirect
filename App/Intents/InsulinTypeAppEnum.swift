//
//  InsulinTypeAppEnum.swift
//  DOSBTSApp
//
//  Siri-facing mirror of `InsulinType`. The core enum is Codable + CaseIterable
//  but App Intents needs its own AppEnum conformance with localizable display
//  representations — and giving the enum its own life here keeps Siri-facing
//  copy decoupled from the in-app `InsulinType.description` (which Siri reads
//  awkwardly, e.g. "Meal Bolus" vs "meal bolus").
//

import AppIntents

enum InsulinTypeAppEnum: String, AppEnum {
    case meal
    case snack
    case correction
    case basal

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Insulin type")

    static let caseDisplayRepresentations: [InsulinTypeAppEnum: DisplayRepresentation] = [
        .meal: DisplayRepresentation(title: "meal bolus"),
        .snack: DisplayRepresentation(title: "snack bolus"),
        .correction: DisplayRepresentation(title: "correction"),
        .basal: DisplayRepresentation(title: "basal")
    ]

    /// Map to the canonical in-app enum.
    var insulinType: InsulinType {
        switch self {
        case .meal: return .mealBolus
        case .snack: return .snackBolus
        case .correction: return .correctionBolus
        case .basal: return .basal
        }
    }
}
