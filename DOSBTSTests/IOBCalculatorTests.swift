//
//  IOBCalculatorTests.swift
//  DOSBTSTests
//

import Foundation
import Testing
@testable import DOSBTSApp

// MARK: - ExponentialInsulinModel Tests

@Suite("Exponential Insulin Model")
struct ExponentialInsulinModelTests {

    let rapidActing = InsulinPreset.rapidActing.model
    let ultraRapid = InsulinPreset.ultraRapid.model

    @Test("IOB at t=0 is 1.0 (full dose)")
    func iobAtZero() {
        #expect(rapidActing.percentEffectRemaining(at: 0) == 1.0)
    }

    @Test("IOB at t=DIA is 0.0 (fully absorbed)")
    func iobAtDIA() {
        #expect(rapidActing.percentEffectRemaining(at: 6 * 60 * 60) == 0.0)
    }

    @Test("IOB at t=DIA/2 matches expected exponential value")
    func iobAtHalfDIA() {
        let iob = rapidActing.percentEffectRemaining(at: 3 * 60 * 60)
        // Exponential model at t=DIA/2 with peak=75m, DIA=6h
        #expect(iob > 0.15)
        #expect(iob < 0.45)
    }

    @Test("IOB at negative time is 1.0 (delivery in future)")
    func iobNegativeTime() {
        #expect(rapidActing.percentEffectRemaining(at: -60) == 1.0)
    }

    @Test("IOB past DIA is 0.0")
    func iobPastDIA() {
        #expect(rapidActing.percentEffectRemaining(at: 7 * 60 * 60) == 0.0)
    }

    @Test("Ultra-rapid decays faster than rapid-acting at same elapsed time")
    func ultraRapidFasterDecay() {
        let elapsed: TimeInterval = 2 * 60 * 60 // 2 hours
        let rapidIOB = rapidActing.percentEffectRemaining(at: elapsed)
        let ultraIOB = ultraRapid.percentEffectRemaining(at: elapsed)
        #expect(ultraIOB < rapidIOB)
    }

    @Test("Basal factory: 24h-DIA basal curve shape is pinned to the dia/2.5 calibration")
    func basal24hStaysActivePastBolusDIA() {
        // The Maksimovic model with the rapid-acting 75-min peak would dump
        // most of a 24h basal's activity in the first ~5 hours. The basal
        // factory must scale the peak with DIA so the curve stays roughly
        // flat — that's the whole point of long-acting insulin.
        //
        // Two-sided bands centered on the dia/2.5 expected values pin the
        // curve shape, not just "isn't bolus-shaped." A regression that
        // changed the peak ratio (e.g., from 0.4 to 0.22) would slip past
        // single-sided floor assertions but fail these.
        let basal24h = ExponentialInsulinModel.basal(diaMinutes: 24 * 60)
        let iobAt6h = basal24h.percentEffectRemaining(at: 6 * 60 * 60)
        let iobAt12h = basal24h.percentEffectRemaining(at: 12 * 60 * 60)
        let iobAt18h = basal24h.percentEffectRemaining(at: 18 * 60 * 60)
        #expect(iobAt6h > 0.75 && iobAt6h < 0.85)
        #expect(iobAt12h > 0.40 && iobAt12h < 0.50)
        #expect(iobAt18h > 0.08 && iobAt18h < 0.18)
    }

    @Test("Basal factory: short DIAs respect the safety ceiling (peak < DIA/2)")
    func basalShortDIAFloors() {
        // A 2h "basal" DIA cannot use the rapid-acting 75-min floor because
        // that would put peak > DIA/2 and break the Maksimovic constants.
        // The safety ceiling (0.49 × DIA) wins out — peak ends up at
        // 58.8 min, the 75-min floor is overridden in this neighborhood.
        let shortBasal = ExponentialInsulinModel.basal(diaMinutes: 120)
        #expect(shortBasal.actionDuration == 120 * 60)
        #expect(shortBasal.peakActivityTime < shortBasal.actionDuration / 2)
        #expect(shortBasal.peakActivityTime == 120 * 60 * 0.49)
    }

    @Test("Basal factory: peak scales linearly with DIA above the floor")
    func basalPeakScalesWithDIA() {
        let basal12h = ExponentialInsulinModel.basal(diaMinutes: 12 * 60)
        let basal24h = ExponentialInsulinModel.basal(diaMinutes: 24 * 60)
        // 24h DIA should put its peak roughly twice as late as a 12h DIA.
        #expect(basal24h.peakActivityTime > basal12h.peakActivityTime * 1.8)
        // And both peaks must stay strictly below DIA/2 so the Maksimovic
        // constants remain well-defined.
        #expect(basal12h.peakActivityTime < basal12h.actionDuration / 2)
        #expect(basal24h.peakActivityTime < basal24h.actionDuration / 2)
    }

    @Test("Basal factory: peak < DIA/2 invariant holds across the full DIA domain")
    func basalPeakAlwaysBelowHalfDIA() {
        // The factory's safety ceiling must hold for every DIA the UI can
        // produce (60 min floor through 24h stepper max), so the Maksimovic
        // denominator (1 - 2·tp/td) stays strictly positive and tau/a/S
        // stay well-defined. The previous version of this factory failed
        // this for DIA ∈ [60, 150) min because the 75-min peak floor won
        // out over the safety check.
        for diaMinutes in stride(from: 60, through: 24 * 60, by: 30) {
            let basal = ExponentialInsulinModel.basal(diaMinutes: diaMinutes)
            #expect(basal.peakActivityTime < basal.actionDuration / 2,
                    "peak !< DIA/2 at diaMinutes=\(diaMinutes)")
        }
    }

    @Test("Basal factory: degenerate DIA inputs (zero / negative) clamp safely")
    func basalDegenerateDIAClampsToFloor() {
        // The factory must not crash on diaMinutes <= 0; it floors at 60 min
        // and the safety ceiling caps peak below DIA/2. Belt-and-suspenders
        // for a future caller that doesn't validate input.
        for badInput in [0, -1, -100] {
            let basal = ExponentialInsulinModel.basal(diaMinutes: badInput)
            #expect(basal.actionDuration == 60 * 60)
            #expect(basal.peakActivityTime < basal.actionDuration / 2)
            #expect(basal.percentEffectRemaining(at: 0) == 1.0)
        }
    }

    @Test("Basal factory: long DIAs (Tresiba 42h) stay well-defined and flat")
    func basalLongDIATresiba() {
        // Tresiba (insulin degludec) has a real-world DIA of ~42h. The
        // factory must produce a usable curve at that range — flat across
        // most of the duration and well below DIA/2 at peak.
        let tresiba = ExponentialInsulinModel.basal(diaMinutes: 42 * 60)
        #expect(tresiba.peakActivityTime < tresiba.actionDuration / 2)
        let iobAt12h = tresiba.percentEffectRemaining(at: 12 * 60 * 60)
        let iobAt24h = tresiba.percentEffectRemaining(at: 24 * 60 * 60)
        #expect(iobAt12h > 0.5)
        #expect(iobAt24h > 0.15)
    }

    @Test("Basal factory: scaledPeak vs floor transition is continuous")
    func basalFloorScaledTransition() {
        // At DIA = 75 min / peakDIARatio (0.4) = 187.5 min, scaledPeak
        // crosses the rapid-acting floor. The curve at 60 min elapsed
        // should be near-continuous across that transition — no visible
        // jump, since both branches converge to peak ≈ 75 min in this
        // neighborhood.
        let just187 = ExponentialInsulinModel.basal(diaMinutes: 187)
        let just188 = ExponentialInsulinModel.basal(diaMinutes: 188)
        let iob187 = just187.percentEffectRemaining(at: 60 * 60)
        let iob188 = just188.percentEffectRemaining(at: 60 * 60)
        #expect(abs(iob187 - iob188) < 0.05)
    }

    @Test("IOB is monotonically decreasing over time")
    func monotonicallyDecreasing() {
        var previous = 1.0
        for minutes in stride(from: 5, through: 360, by: 5) {
            let current = rapidActing.percentEffectRemaining(at: Double(minutes) * 60)
            #expect(current <= previous)
            previous = current
        }
    }
}

// MARK: - computeIOB Tests

@Suite("IOB Computation")
struct IOBComputationTests {

    let bolusModel = InsulinPreset.rapidActing.model
    // Hand-built model (not via ExponentialInsulinModel.basal) so the
    // existing assertion bands below (e.g. basalDecay's `> 0.5 / < 2.0`)
    // stay stable. These tests exercise computeIOB plumbing — bucketing,
    // segmentation, threshold — not the basal curve shape, which is
    // covered by the `basal*` factory tests above.
    let basalModel = ExponentialInsulinModel(actionDuration: 6 * 60 * 60, peakActivityTime: 75 * 60)
    let now = Date()

    @Test("1U bolus at t=0, IOB is 1.0U")
    func singleBolusAtZero() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.total - 1.0) < 0.01)
    }

    @Test("1U bolus at t=DIA, IOB is 0.0")
    func singleBolusAtDIA() {
        let sixHoursAgo = now.addingTimeInterval(-6 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: sixHoursAgo, ends: sixHoursAgo, units: 1.0, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
    }

    @Test("Empty delivery list returns all zeros")
    func emptyDeliveries() {
        let result = computeIOB(deliveries: [], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
        #expect(result.mealSnackIOB == 0.0)
        #expect(result.correctionBasalIOB == 0.0)
    }

    @Test("IOB below 0.05U threshold returns 0.0")
    func belowThreshold() {
        let almostDone = now.addingTimeInterval(-5.9 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: almostDone, ends: almostDone, units: 1.0, type: .mealBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
    }

    @Test("Future delivery has zero IOB — not yet delivered")
    func futureDelivery() {
        let future = now.addingTimeInterval(30 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: future, ends: future, units: 2.0, type: .mealBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total == 0.0)
    }

    @Test("Split IOB separates rapid-acting bolus (meal+snack+correction) from basal")
    func splitIOB() {
        // Meal, snack, and correction boluses are all rapid-acting and share
        // the bolus IOB bucket; only basal is in the basal bucket.
        let meal = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 3.0, type: .mealBolus
        )
        let correction = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [meal, correction], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.mealSnackIOB - 4.0) < 0.01)
        #expect(abs(result.correctionBasalIOB - 0.0) < 0.01)
        #expect(abs(result.total - 4.0) < 0.01)
    }

    @Test("Multiple overlapping boluses sum IOB correctly")
    func overlappingBoluses() {
        let oneHourAgo = now.addingTimeInterval(-1 * 60 * 60)
        let delivery1 = InsulinDelivery(
            id: UUID(), starts: oneHourAgo, ends: oneHourAgo, units: 2.0, type: .mealBolus
        )
        let delivery2 = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .snackBolus
        )
        let result = computeIOB(deliveries: [delivery1, delivery2], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total > 2.0) // 1.0 from recent + partial from 1h ago
        #expect(result.total < 3.0) // Less than full sum since 1h decayed
    }

    @Test("Basal entry decays from `starts` over the basal model's DIA")
    func basalDecay() {
        let twoHoursAgo = now.addingTimeInterval(-2 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: twoHoursAgo, ends: now, units: 2.0, type: .basal
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        // Basal is treated as a point dose at `starts` decaying over the
        // basal model's DIA (6h in this test setup). At t=2h, partial decay.
        #expect(result.total > 0.5)
        #expect(result.total < 2.0)
        #expect(result.correctionBasalIOB > 0.5) // Basal goes to correction+basal bucket
    }

    @Test("24h-DIA basal fades to zero at t=24h (no segmentation tail past DIA)")
    func basalFadesAtDIA() {
        // Regression guard for the previous segmented-infusion behavior, which
        // extended observable IOB to ~2× DIA because each segment decayed
        // independently from its midpoint. Users entering once-a-day Tresiba
        // expect "24h DIA = fade in 24h," and that's what the point-dose
        // interpretation guarantees.
        let basal24h = ExponentialInsulinModel.basal(diaMinutes: 24 * 60)
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 60 * 60)
        let delivery = InsulinDelivery(
            id: UUID(), starts: twentyFourHoursAgo, ends: now, units: 12.0, type: .basal
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basal24h, at: now)
        #expect(result.total < 0.05) // below the 0.05U zero threshold
    }

    @Test("Snack bolus goes to mealSnack bucket")
    func snackBolus() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .snackBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.mealSnackIOB - 1.0) < 0.01)
        #expect(result.correctionBasalIOB == 0.0)
    }

    @Test("Zero-duration basal is treated as bolus using basal model")
    func zeroDurationBasal() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now, ends: now, units: 1.0, type: .basal
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.total - 1.0) < 0.01)
        #expect(result.correctionBasalIOB > 0) // Basal goes to correction+basal bucket
    }

    @Test("Split components sum to total")
    func splitSumsToTotal() {
        let meal = InsulinDelivery(id: UUID(), starts: now, ends: now, units: 3.0, type: .mealBolus)
        let corr = InsulinDelivery(id: UUID(), starts: now, ends: now, units: 1.0, type: .correctionBolus)
        let result = computeIOB(deliveries: [meal, corr], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(abs(result.total - (result.mealSnackIOB + result.correctionBasalIOB)) < 0.001)
    }

    @Test("IOB is non-negative for any input")
    func iobNonNegative() {
        let delivery = InsulinDelivery(
            id: UUID(), starts: now.addingTimeInterval(-5 * 60 * 60), ends: now.addingTimeInterval(-5 * 60 * 60), units: 0.1, type: .correctionBolus
        )
        let result = computeIOB(deliveries: [delivery], bolusModel: bolusModel, basalModel: basalModel, at: now)
        #expect(result.total >= 0)
        #expect(result.mealSnackIOB >= 0)
        #expect(result.correctionBasalIOB >= 0)
    }
}
