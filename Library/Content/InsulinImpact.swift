//
//  InsulinImpact.swift
//  DOSBTS
//

import Foundation

enum InsulinConfounder {
    case stackedBolus(units: Double)
    case exerciseInWindow
    case correctionForLow
}

struct InsulinImpact {
    let dose: InsulinDelivery
    let glucoseAtDose: Int?
    let glucoseAtPeak: Int?
    let peakOffsetMinutes: Int?
    let iobAtDose: Double?
    let confounders: [InsulinConfounder]

    var deltaMgDL: Int? {
        guard let g0 = glucoseAtDose, let g1 = glucoseAtPeak else { return nil }
        return g1 - g0
    }

    static func compute(
        for dose: InsulinDelivery,
        glucoseAtDose: Int?,
        glucoseAtPeak: Int?,
        peakOffsetMinutes: Int?,
        iobAtDose: Double?,
        confounders: [InsulinConfounder]
    ) -> InsulinImpact {
        InsulinImpact(
            dose: dose,
            glucoseAtDose: glucoseAtDose,
            glucoseAtPeak: glucoseAtPeak,
            peakOffsetMinutes: peakOffsetMinutes,
            iobAtDose: iobAtDose,
            confounders: confounders
        )
    }
}
