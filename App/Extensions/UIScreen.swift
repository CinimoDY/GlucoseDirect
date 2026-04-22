//
//  UIScreen.swift
//  DOSBTS
//

import SwiftUI

extension UIScreen {
    private static var current: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .screen
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
