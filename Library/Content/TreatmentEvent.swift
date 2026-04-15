//
//  TreatmentEvent.swift
//  DOSBTS
//

import Foundation

// MARK: - TreatmentEvent

struct TreatmentEvent: CustomStringConvertible, Codable, Identifiable {
    // MARK: Lifecycle

    init(mealEntryId: UUID, alarmFiredAt: Date, treatmentLoggedAt: Date, treatmentType: String, glucoseAtTreatment: Int, countdownMinutes: Int) {
        let roundedLoggedAt = treatmentLoggedAt.toRounded(on: 1, .minute)

        self.id = UUID()
        self.mealEntryId = mealEntryId
        self.alarmFiredAt = alarmFiredAt.toRounded(on: 1, .minute)
        self.treatmentLoggedAt = roundedLoggedAt
        self.treatmentType = treatmentType.trimmingCharacters(in: .whitespacesAndNewlines)
        self.glucoseAtTreatment = glucoseAtTreatment
        self.countdownMinutes = countdownMinutes
        self.timegroup = roundedLoggedAt.toRounded(on: DirectConfig.timegroupRounding, .minute)
    }

    // MARK: Internal

    let id: UUID
    let mealEntryId: UUID
    let alarmFiredAt: Date
    let treatmentLoggedAt: Date
    let treatmentType: String
    let glucoseAtTreatment: Int
    let countdownMinutes: Int
    let timegroup: Date

    var description: String {
        "{ id: \(id), mealEntryId: \(mealEntryId), treatmentType: \(treatmentType), glucoseAtTreatment: \(glucoseAtTreatment), countdownMinutes: \(countdownMinutes) }"
    }
}

// MARK: Equatable

extension TreatmentEvent: Equatable {
    static func == (lhs: TreatmentEvent, rhs: TreatmentEvent) -> Bool {
        lhs.id == rhs.id
    }
}
