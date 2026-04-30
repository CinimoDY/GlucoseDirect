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
        self.actionDuration = max(actionDuration, 60) // Guard: minimum 1 minute to prevent division by zero
        self.peakActivityTime = peakActivityTime

        let td = self.actionDuration
        let tp = peakActivityTime

        // Guard: if tp == td/2, denominator is zero — clamp tp slightly
        let safeTp = (1 - 2 * tp / td) == 0 ? tp * 0.99 : tp

        self.tau = safeTp * (1 - safeTp / td) / (1 - 2 * safeTp / td)
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

    /// Build a long-acting basal model from the user's configured DIA.
    ///
    /// The peak activity time scales with DIA (≈ DIA × `peakDIARatio`) so the
    /// curve stays roughly flat across the full duration — long DIAs no
    /// longer behave like a rapid-acting bolus that happens to last longer.
    ///
    /// Three guards apply, in this order:
    /// 1. DIA is floored at `minDIAMinutes` so degenerate inputs (zero,
    ///    negative) clamp to a defined minimum.
    /// 2. Peak is floored at `rapidActingPeakSeconds` (75 min) so very short
    ///    basal DIAs degrade to a rapid-acting profile rather than producing
    ///    a sub-bolus peak.
    /// 3. Peak is then capped at `peakSafetyCeilingRatio × DIA` (just below
    ///    DIA/2) so the Maksimovic model's denominator `(1 - 2·tp/td)` stays
    ///    strictly positive and `tau`, `a`, `S` remain well-defined. Without
    ///    this cap the floor in (2) silently violates the invariant when
    ///    DIA < 150 min.
    static func basal(diaMinutes: Int) -> ExponentialInsulinModel {
        let dia = TimeInterval(max(minDIAMinutes, diaMinutes)) * 60
        let scaledPeak = dia * peakDIARatio
        let flooredPeak = max(rapidActingPeakSeconds, scaledPeak)
        let peak = min(flooredPeak, dia * peakSafetyCeilingRatio)
        return ExponentialInsulinModel(actionDuration: dia, peakActivityTime: peak)
    }

    // MARK: Constants

    /// Smallest DIA the basal factory will accept. Below this, callers are
    /// passing degenerate input (zero, negative) — clamp rather than crash.
    private static let minDIAMinutes: Int = 60

    /// Rapid-acting bolus peak time (matches `InsulinPreset.rapidActing`).
    /// The basal peak is floored at this so a misconfigured short DIA still
    /// produces a recognizable rapid-acting curve rather than a meaningless
    /// sub-bolus peak.
    private static let rapidActingPeakSeconds: TimeInterval = 75 * 60

    /// Heuristic peak/DIA ratio for long-acting basals. 0.4 (≈ DIA/2.5)
    /// produces a roughly flat curve across the full duration — closer to
    /// real-world Lantus / Levemir / Tresiba pharmacokinetics than a
    /// front-loaded bolus shape would be.
    private static let peakDIARatio: Double = 0.4

    /// Hard ceiling for `peak / DIA` so the Maksimovic constants stay
    /// well-defined: the model's denominator `(1 - 2·tp/td)` goes to zero
    /// at `peak = DIA/2` and negative beyond it, breaking `tau`, `a`, `S`.
    /// 0.49 keeps a small safety margin without pushing peak much below
    /// DIA/2 in cases (long DIAs) where the heuristic doesn't need clamping.
    private static let peakSafetyCeilingRatio: Double = 0.49
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
        // Skip future deliveries entirely — insulin not yet delivered has zero IOB
        guard date.timeIntervalSince(delivery.starts) >= 0 else { continue }

        let iob: Double

        if delivery.type == .basal {
            iob = computeBasalIOB(delivery: delivery, model: basalModel, at: date)
        } else {
            let elapsed = date.timeIntervalSince(delivery.starts)
            iob = delivery.units * bolusModel.percentEffectRemaining(at: elapsed)
        }

        // Bucketing reflects insulin TYPE (rapid-acting vs long-acting), not
        // the user's intent for the dose. Meal/snack/correction boluses are
        // all rapid-acting and belong in the bolus IOB bucket; only basal is
        // long-acting. The previous bucketing put correction-bolus into the
        // basal bucket which was misleading — a 3U correction bolus would
        // appear as "basal IOB" in the chart.
        switch delivery.type {
        case .mealBolus, .snackBolus, .correctionBolus:
            mealSnackIOB += iob
        case .basal:
            correctionBasalIOB += iob
        }
    }

    let total = mealSnackIOB + correctionBasalIOB

    // Apply zero threshold — only on total, keep components consistent
    let threshold = 0.05
    if total < threshold {
        return IOBResult(total: 0, mealSnackIOB: 0, correctionBasalIOB: 0)
    }

    return IOBResult(
        total: total,
        mealSnackIOB: mealSnackIOB,
        correctionBasalIOB: correctionBasalIOB
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

        // Only count segments that have already been delivered (elapsed > 0)
        if elapsed > 0 {
            iob += segmentDose * model.percentEffectRemaining(at: elapsed)
        }
        // Future segments (not yet infused) are skipped — no IOB from undelivered insulin

        segmentStart = segmentEnd
    }

    return iob
}
