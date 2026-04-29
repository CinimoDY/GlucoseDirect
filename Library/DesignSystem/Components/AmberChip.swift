//
//  AmberChip.swift
//  DOSBTS
//

import SwiftUI

public struct AmberChip: View {
    public enum Variant {
        case type      // 44pt segmented selection chip
        case preset    // 40pt single-tap action chip
    }

    public let label: String
    public let icon: String?
    public let variant: Variant
    public let tint: Color
    public let isSelected: Bool
    public let action: () -> Void

    public init(
        label: String,
        icon: String? = nil,
        variant: Variant = .type,
        tint: Color = AmberTheme.amber,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 11)) }
                Text(label)
                    .font(.system(size: variant == .type ? 13 : 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
                    .tracking(0.4)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: variant == .type ? 44 : 40)
            .foregroundStyle(isSelected ? Color.black : tint)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? tint : Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? tint : AmberTheme.amberDark, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        // Replace ASCII-art labels with readable text
        switch label {
        case "⋯": return "Custom time"
        case "−15m": return "15 minutes ago"
        case "−30m": return "30 minutes ago"
        case "−1h": return "1 hour ago"
        default: return label
        }
    }
}
