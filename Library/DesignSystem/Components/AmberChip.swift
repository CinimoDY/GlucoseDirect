//
//  AmberChip.swift
//  DOSBTS
//

import SwiftUI

public struct AmberChip: View {
    public enum Variant {
        case type      // segmented selection chip
        case preset    // single-tap action chip
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
                Text(label).font(DOSTypography.caption)
            }
            .padding(.horizontal, DOSSpacing.sm)
            .frame(minHeight: 28)
            .foregroundStyle(isSelected ? tint : AmberTheme.amberDark)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? tint.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
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
