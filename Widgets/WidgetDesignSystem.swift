//
//  WidgetDesignSystem.swift
//  DOSBTSWidget
//
//  Widget-local design system mirroring AmberTheme + DOSTypography
//  for the widget extension target (can't import app's design system).
//

import SwiftUI

// MARK: - WidgetColors

/// Mirrors AmberTheme color constants for widget target
enum WidgetColors {
    /// #ffb000 - P3 phosphor amber (602nm)
    static let amber = Color(red: 1.0, green: 176.0 / 255.0, blue: 0)

    /// #9a5700 - Secondary text, dimmed states
    static let amberDark = Color(red: 154.0 / 255.0, green: 87.0 / 255.0, blue: 0)

    /// #fdca9f - Highlights, focus states
    static let amberLight = Color(red: 253.0 / 255.0, green: 202.0 / 255.0, blue: 159.0 / 255.0)

    /// #555555 - Disabled, muted
    static let amberMuted = Color(red: 85.0 / 255.0, green: 85.0 / 255.0, blue: 85.0 / 255.0)

    /// #55ff55 - CGA green (in-range, low)
    static let cgaGreen = Color(red: 85.0 / 255.0, green: 1.0, blue: 85.0 / 255.0)

    /// #55ffff - CGA cyan (IOB, info)
    static let cgaCyan = Color(red: 85.0 / 255.0, green: 1.0, blue: 1.0)

    /// #ff5555 - CGA red (alarm, high)
    static let cgaRed = Color(red: 1.0, green: 85.0 / 255.0, blue: 85.0 / 255.0)

    /// #000000 - Pure black background
    static let dosBlack = Color(red: 0, green: 0, blue: 0)
}

// MARK: - WidgetFonts

/// Mirrors DOSTypography for widget target
enum WidgetFonts {
    static let glucoseHero = Font.system(size: 44, weight: .bold, design: .monospaced)
    static let glucoseLarge = Font.system(size: 52, weight: .bold, design: .monospaced)
    static let body = Font.system(size: 17, weight: .regular, design: .monospaced)
    static let bodySmall = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let caption = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let label = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let labelSmall = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let tabBar = Font.system(size: 10, weight: .medium, design: .monospaced)

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Phosphor Glow Modifier

extension View {
    /// Phosphor CRT glow effect — tight inner glow + diffuse outer
    func phosphorGlow(color: Color = WidgetColors.amber) -> some View {
        self
            .shadow(color: color.opacity(0.8), radius: 1, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
    }
}

// MARK: - DataStaleness Widget Extensions (color properties depend on WidgetColors)

extension DataStaleness {
    var timestampColor: Color {
        switch self {
        case .fresh: return WidgetColors.amberDark
        case .stale: return WidgetColors.amber
        case .veryStale: return WidgetColors.cgaRed
        }
    }

    var glucoseOpacity: Double {
        switch self {
        case .fresh: return 1.0
        case .stale: return 0.6
        case .veryStale: return 0.4
        }
    }
}
