//
//  AddMealIntent.swift
//  DOSBTSApp
//
//  "Hey Siri, log 30 grams of toast" / "log a snack" — quick carb-anchored
//  meal entries from voice without opening the app.
//

import AppIntents
import Combine
import Foundation
import WidgetKit

struct AddMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Log meal"

    static let description = IntentDescription(
        "Log a meal into DOSBTS with carbs in grams and an optional description.",
        categoryName: "Logging"
    )

    @Parameter(title: "Carbs (grams)", controlStyle: .field)
    var carbs: Double

    @Parameter(
        title: "Description",
        description: "Short label such as 'toast' or 'apple'. Defaults to 'meal'.",
        default: "meal"
    )
    var mealDescription: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$carbs)g of \(\.$mealDescription)")
    }

    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "meal" : trimmed
        let entry = MealEntry(timestamp: Date(), mealDescription: label, carbsGrams: carbs)

        try await persist(entry)
        await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }

        let formattedCarbs = carbs == carbs.rounded() ? "\(Int(carbs))" : String(format: "%.1f", carbs)
        return .result(dialog: "Logged \(formattedCarbs) grams: \(label).")
    }

    private func persist(_ entry: MealEntry) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?
            var resumed = false
            cancellable = DataStore.shared.insertMealEntry([entry])
                .sink(
                    receiveCompletion: { completion in
                        guard !resumed else { return }
                        resumed = true
                        switch completion {
                        case .finished:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { _ in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume()
                        cancellable?.cancel()
                    }
                )
        }
    }
}
