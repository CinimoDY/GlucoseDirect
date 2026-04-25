//
//  EditableFoodItem.swift
//  DOSBTS
//

import Foundation

// MARK: - EditableFoodItem

/// Staging plate item — editable copy of a NutritionItem
struct EditableFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var carbsG: Double
    var isExpanded: Bool = false
    var baseServingG: Double? = nil  // From OFF serving_quantity, for portion presets
    var currentAmountG: Double? = nil // User-visible portion in g/ml (nil = amount field hidden)
    var carbsPerG: Double? = nil      // Carbs-per-gram ratio (nil = user overrode carbs directly)
}
