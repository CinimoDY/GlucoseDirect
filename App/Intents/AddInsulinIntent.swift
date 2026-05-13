//
//  AddInsulinIntent.swift
//  DOSBTSApp
//
//  "Hey Siri, log 2 units of insulin" / "log 3 units of basal".
//
//  Writes directly via DataStore.shared (the async GRDB writer) — bypasses
//  the Redux store because Siri may invoke the intent in a lighter context
//  where the full app `@main` hasn't initialized the store. After the write
//  completes, reload widget timelines so the home-screen marker shows up
//  alongside the log entry.
//

import AppIntents
import Combine
import Foundation
import WidgetKit

struct AddInsulinIntent: AppIntent {
    static let title: LocalizedStringResource = "Log insulin"

    static let description = IntentDescription(
        "Log an insulin dose into DOSBTS — meal, snack, correction, or basal.",
        categoryName: "Logging"
    )

    @Parameter(title: "Units", controlStyle: .field)
    var units: Double

    @Parameter(
        title: "Type",
        description: "Defaults to snack bolus when omitted (rapid-acting, no meal anchor).",
        default: .snack
    )
    var type: InsulinTypeAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$units) units of \(\.$type)")
    }

    /// The intent doesn't need to open the app — it writes and confirms via
    /// voice/text. Setting `openAppWhenRun = false` lets Siri run it in the
    /// background.
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let resolvedType = type.insulinType
        // Bolus deliveries are zero-duration (ends == starts). Basal entries
        // get a 24h duration to match the in-app default for once-daily
        // injections (Tresiba/Lantus/Levemir). Users editing the timing
        // manually do it from the Add Insulin screen — Siri is the fast path.
        let ends = resolvedType == .basal
            ? Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(24 * 60 * 60)
            : now
        let delivery = InsulinDelivery(starts: now, ends: ends, units: units, type: resolvedType)

        try await persist(delivery)
        await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }

        let unitLabel = units == 1 ? "unit" : "units"
        let formattedUnits = units == units.rounded() ? "\(Int(units))" : String(format: "%.1f", units)
        let typeLabel = InsulinTypeAppEnum.caseDisplayRepresentations[type]?.title ?? "insulin"
        return .result(dialog: "Logged \(formattedUnits) \(unitLabel) of \(typeLabel).")
    }

    private func persist(_ delivery: InsulinDelivery) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?
            var resumed = false
            cancellable = DataStore.shared.insertInsulinDelivery([delivery])
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
