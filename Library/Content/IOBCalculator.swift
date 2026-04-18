//
//  IOBCalculator.swift
//  DOSBTS
//

import Foundation

// MARK: - InsulinPreset

enum InsulinPreset: String, Codable, CaseIterable {
    case rapidActing
    case ultraRapid

    // MARK: Internal

    var description: String {
        switch self {
        case .rapidActing:
            return "Rapid-acting (Humalog/NovoRapid)"
        case .ultraRapid:
            return "Ultra-rapid (Fiasp/Lyumjev)"
        }
    }

    var model: ExponentialInsulinModel {
        switch self {
        case .rapidActing:
            return ExponentialInsulinModel(actionDuration: 6 * 60 * 60, peakActivityTime: 75 * 60)
        case .ultraRapid:
            return ExponentialInsulinModel(actionDuration: 6 * 60 * 60, peakActivityTime: 55 * 60)
        }
    }

    var diaMinutes: Int {
        switch self {
        case .rapidActing:
            return 360
        case .ultraRapid:
            return 360
        }
    }
}

// MARK: - ExponentialInsulinModel

/// Maksimovic exponential insulin model (oref0/LoopKit).
/// Given DIA (td) and peak activity time (tp), precomputes tau, a, S constants.
/// percentEffectRemaining(at:) returns the fraction of insulin still active at elapsed time t.
struct ExponentialInsulinModel {
    let actionDuration: TimeInterval // td in seconds
    let peakActivityTime: TimeInterval // tp in seconds

    // Precomputed constants
    let tau: Double
    let a: Double
    let S: Double

    init(actionDuration: TimeInterval, peakActivityTime: TimeInterval) {
        self.actionDuration = actionDuration
        self.peakActivityTime = peakActivityTime

        let td = actionDuration
        let tp = peakActivityTime

        self.tau = tp * (1 - tp / td) / (1 - 2 * tp / td)
        self.a = 2 * tau / td
        self.S = 1 / (1 - a + (1 + a) * exp(-td / tau))
    }

    /// Returns the fraction of insulin effect remaining (0.0 to 1.0) at elapsed seconds since delivery.
    func percentEffectRemaining(at time: TimeInterval) -> Double {
        guard time > 0 else { return 1.0 }
        guard time < actionDuration else { return 0.0 }

        let t = time
        let iob = 1 - S * (1 - a) * ((pow(t, 2) / (tau * actionDuration * (1 - a)) - t / tau - 1) * exp(-t / tau) + 1)
        return max(0, min(1, iob))
    }
}

// MARK: - IOBResult

struct IOBResult {
    let total: Double
    let mealSnackIOB: Double
    let correctionBasalIOB: Double
}

// MARK: - IOB Computation

private let basalSegmentDelta: TimeInterval = 5 * 60 // 5-minute chunks

/// Compute IOB from a list of insulin deliveries at a given point in time.
func computeIOB(
    deliveries: [InsulinDelivery],
    bolusModel: ExponentialInsulinModel,
    basalModel: ExponentialInsulinModel,
    at date: Date = Date()
) -> IOBResult {
    var mealSnackIOB: Double = 0
    var correctionBasalIOB: Double = 0

    for delivery in deliveries {
        let iob: Double

        if delivery.type == .basal {
            iob = computeBasalIOB(delivery: delivery, model: basalModel, at: date)
        } else {
            let elapsed = date.timeIntervalSince(delivery.starts)
            iob = delivery.units * bolusModel.percentEffectRemaining(at: elapsed)
        }

        switch delivery.type {
        case .mealBolus, .snackBolus:
            mealSnackIOB += iob
        case .correctionBolus, .basal:
            correctionBasalIOB += iob
        }
    }

    let total = mealSnackIOB + correctionBasalIOB

    // Apply zero threshold
    let threshold = 0.05
    if total < threshold {
        return IOBResult(total: 0, mealSnackIOB: 0, correctionBasalIOB: 0)
    }

    return IOBResult(
        total: total,
        mealSnackIOB: mealSnackIOB < threshold ? 0 : mealSnackIOB,
        correctionBasalIOB: correctionBasalIOB < threshold ? 0 : correctionBasalIOB
    )
}

/// Compute IOB for a basal delivery using continuous infusion segmentation.
/// Segments the basal entry into 5-min chunks, each decayed independently.
private func computeBasalIOB(
    delivery: InsulinDelivery,
    model: ExponentialInsulinModel,
    at date: Date
) -> Double {
    let totalDuration = delivery.ends.timeIntervalSince(delivery.starts)

    // Guard against zero-duration basal (treat as bolus)
    guard totalDuration > 0 else {
        let elapsed = date.timeIntervalSince(delivery.starts)
        return delivery.units * model.percentEffectRemaining(at: elapsed)
    }

    var iob: Double = 0
    var segmentStart: TimeInterval = 0

    while segmentStart < totalDuration {
        let segmentEnd = min(segmentStart + basalSegmentDelta, totalDuration)
        let segmentDuration = segmentEnd - segmentStart
        let segmentDose = delivery.units * segmentDuration / totalDuration
        let segmentMidpoint = delivery.starts.addingTimeInterval(segmentStart + segmentDuration / 2)
        let elapsed = date.timeIntervalSince(segmentMidpoint)

        if elapsed > 0 {
            iob += segmentDose * model.percentEffectRemaining(at: elapsed)
        } else {
            iob += segmentDose // Future segment: full dose remains
        }

        segmentStart = segmentEnd
    }

    return iob
}
