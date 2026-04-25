//
//  MarkerLanePosition.swift
//  DOSBTS
//

import Foundation

enum MarkerLanePosition: String, CaseIterable, Identifiable {
    case top
    case bottom

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .top: return "Above chart (default)"
        case .bottom: return "Below chart"
        }
    }
}
