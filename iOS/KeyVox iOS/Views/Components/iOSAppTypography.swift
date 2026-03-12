import SwiftUI
import UIKit

enum AppTypography {
    private static let candidateFontNames = [
        "Kanit-Medium",
        "Kanit Medium",
    ]

    static func resolvedFontName(for size: CGFloat) -> String? {
        for name in candidateFontNames where UIFont(name: name, size: size) != nil {
            return name
        }

        return nil
    }
}

extension Font {
    static func appFont(_ size: CGFloat) -> Font {
        if let name = AppTypography.resolvedFontName(for: size) {
            return .custom(name, size: size)
        }

        return .system(size: size, weight: .regular)
    }
}
