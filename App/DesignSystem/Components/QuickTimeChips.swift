//
//  QuickTimeChips.swift
//  DOSBTS
//

import SwiftUI

enum TimeOffset: Hashable {
    case now
    case minus(Int)  // minutes

    var label: String {
        switch self {
        case .now: return "NOW"
        case .minus(let m): return m < 60 ? "−\(m)m" : "−\(m / 60)h"
        }
    }
}

struct QuickTimeChips: View {
    let title: String
    @Binding var date: Date
    var presets: [TimeOffset] = [.now, .minus(15), .minus(30), .minus(60)]

    @State private var showCustomPicker: Bool = false
    @State private var anchorDate: Date = Date()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(presets, id: \.self) { preset in
                AmberChip(
                    label: preset.label,
                    variant: .preset,
                    tint: AmberTheme.amber,
                    isSelected: matches(preset),
                    action: { date = Self.applyPreset(preset, anchor: anchorDate) }
                )
            }
            AmberChip(
                label: "⋯",
                variant: .preset,
                tint: AmberTheme.amber,
                isSelected: showCustomPicker,
                action: { showCustomPicker.toggle() }
            )
            .popover(isPresented: $showCustomPicker) {
                DatePicker(title, selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
            }
        }
        .onAppear { anchorDate = Date() }
    }

    private func matches(_ preset: TimeOffset) -> Bool {
        let target = Self.applyPreset(preset, anchor: anchorDate)
        return abs(date.timeIntervalSince(target)) < 30
    }

    static func applyPreset(_ preset: TimeOffset, anchor: Date) -> Date {
        switch preset {
        case .now: return anchor
        case .minus(let minutes): return anchor.addingTimeInterval(TimeInterval(-minutes * 60))
        }
    }
}
