//
//  UIScreen.swift
//  DOSBTS
//
//  Lives under App/ (not Library/) because UIApplication.shared is
//  NS_EXTENSION_UNAVAILABLE and the widget target would fail to compile.
//  Do not move back to Library/Extensions/ without a shared abstraction.
//

import SwiftUI

extension UIScreen {
    private static var current: UIScreen? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        // Prefer foregroundActive, then foregroundInactive (mid-transition
        // during Control Center / notification-drawer gestures), then any
        // attached scene. Fall back to the first window scene for the
        // background-launch / scene-restoration cold path.
        return windowScenes.first { $0.activationState == .foregroundActive }?.screen
            ?? windowScenes.first { $0.activationState == .foregroundInactive }?.screen
            ?? windowScenes.first?.screen
    }

    static var screenWidth: CGFloat {
        current?.bounds.size.width ?? 0
    }

    static var screenHeight: CGFloat {
        current?.bounds.size.height ?? 0
    }

    static var screenSize: CGSize {
        current?.bounds.size ?? .zero
    }
}
