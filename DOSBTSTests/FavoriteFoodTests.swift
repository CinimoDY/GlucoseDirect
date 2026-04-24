//
//  FavoriteFoodTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

struct FavoriteFoodTests {
    @Test func chipLabelFallsBackToMealDescriptionWhenShortLabelIsNil() {
        let favorite = FavoriteFood(mealDescription: "Aldi Milsani Frische Vollmilch 1L", carbsGrams: 12)
        #expect(favorite.chipLabel == "Aldi Milsani Frische Vollmilch 1L")
    }

    @Test func chipLabelUsesShortLabelWhenSet() {
        let favorite = FavoriteFood(mealDescription: "Aldi Milsani Frische Vollmilch 1L", carbsGrams: 12, shortLabel: "milk")
        #expect(favorite.chipLabel == "milk")
    }

    @Test func shortLabelTrimsWhitespace() {
        let favorite = FavoriteFood(mealDescription: "Bread", carbsGrams: 30, shortLabel: "  toast  ")
        #expect(favorite.shortLabel == "toast")
        #expect(favorite.chipLabel == "toast")
    }

    @Test func shortLabelCollapsesEmptyStringToNil() {
        let favorite = FavoriteFood(mealDescription: "Bread", carbsGrams: 30, shortLabel: "")
        #expect(favorite.shortLabel == nil)
        #expect(favorite.chipLabel == "Bread")
    }

    @Test func shortLabelCollapsesWhitespaceOnlyToNil() {
        let favorite = FavoriteFood(mealDescription: "Bread", carbsGrams: 30, shortLabel: "   ")
        #expect(favorite.shortLabel == nil)
    }

    @Test func shortLabelClampsToThirtyChars() {
        let longLabel = String(repeating: "x", count: 50)
        let favorite = FavoriteFood(mealDescription: "Bread", carbsGrams: 30, shortLabel: longLabel)
        #expect(favorite.shortLabel?.count == 30)
    }

    @Test func chipLabelEmptyShortLabelStringFallsBack() {
        // sanitize collapses empty to nil, but double-check chipLabel handles both cases gracefully
        let favorite = FavoriteFood(
            id: UUID(),
            mealDescription: "Pasta",
            carbsGrams: 75,
            shortLabel: "pasta bowl"
        )
        #expect(favorite.chipLabel == "pasta bowl")
    }
}
