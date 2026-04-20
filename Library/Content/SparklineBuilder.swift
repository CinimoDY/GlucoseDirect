//
//  SparklineBuilder.swift
//  DOSBTS
//
//  Pure-logic types shared between app and widget targets.
//  Moved from WidgetDesignSystem.swift for testability.
//

import SwiftUI

// MARK: - DataStaleness

enum DataStaleness {
    case fresh       // < 5 min
    case stale       // 5-14 min
    case veryStale   // 15+ min

    init(since timestamp: Date) {
        let minutes = Date().timeIntervalSince(timestamp) / 60
        if minutes < 5 {
            self = .fresh
        } else if minutes < 15 {
            self = .stale
        } else {
            self = .veryStale
        }
    }
}

// MARK: - SparklineBuilder

struct SparklineBuilder {
    /// Build a polyline Path from glucose values within the given rect.
    /// - Parameters:
    ///   - values: Glucose values (mg/dL integers)
    ///   - rect: Drawing rect
    ///   - alarmLow: Optional low alarm threshold to draw as dashed line
    ///   - alarmHigh: Optional high alarm threshold to draw as dashed line
    /// - Returns: Tuple of (sparkline path, low threshold Y, high threshold Y)
    static func build(
        values: [Int],
        in rect: CGRect,
        alarmLow: Int? = nil,
        alarmHigh: Int? = nil
    ) -> (path: Path, lowY: CGFloat?, highY: CGFloat?) {
        guard values.count >= 2 else {
            return (Path(), nil, nil)
        }

        let minVal = CGFloat(max((values.min() ?? 40) - 10, 40))
        let maxVal = CGFloat(min((values.max() ?? 400) + 10, 400))
        let range = maxVal - minVal
        guard range > 0 else {
            return (Path(), nil, nil)
        }

        func yFor(_ value: Int) -> CGFloat {
            let normalized = (CGFloat(value) - minVal) / range
            return rect.maxY - normalized * rect.height
        }

        func xFor(_ index: Int) -> CGFloat {
            let step = rect.width / CGFloat(values.count - 1)
            return rect.minX + CGFloat(index) * step
        }

        var path = Path()
        path.move(to: CGPoint(x: xFor(0), y: yFor(values[0])))
        for i in 1 ..< values.count {
            path.addLine(to: CGPoint(x: xFor(i), y: yFor(values[i])))
        }

        let lowY = alarmLow.map { yFor($0) }
        let highY = alarmHigh.map { yFor($0) }

        return (path, lowY, highY)
    }
}
