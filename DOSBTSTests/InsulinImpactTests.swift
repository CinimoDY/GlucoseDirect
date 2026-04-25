import Testing
import Foundation
@testable import DOSBTSApp

@Suite("InsulinImpact")
struct InsulinImpactTests {
    @Test("delta is glucoseAtPeak minus glucoseAtDose, signed")
    func deltaSign() {
        let dose = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
        let impact = InsulinImpact.compute(
            for: dose,
            glucoseAtDose: 182,
            glucoseAtPeak: 114,
            peakOffsetMinutes: 72,
            iobAtDose: 1.8,
            confounders: []
        )
        #expect(impact.deltaMgDL == -68)
    }
}
