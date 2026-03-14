import Combine
import SwiftUI
import UIKit

enum AppTypography {
    enum Variant {
        case medium
        case light

        fileprivate var candidateFontNames: [String] {
            switch self {
            case .medium:
                return [
                    "Kanit-Medium",
                    "Kanit Medium",
                ]
            case .light:
                return [
                    "Kanit-Light",
                    "Kanit Light",
                ]
            }
        }

        fileprivate var fallbackWeight: Font.Weight {
            switch self {
            case .medium:
                return .regular
            case .light:
                return .light
            }
        }
    }

    static func resolvedFontName(for size: CGFloat, variant: Variant) -> String? {
        for name in variant.candidateFontNames where UIFont(name: name, size: size) != nil {
            return name
        }

        return nil
    }
}

extension Font {
    static func appFont(_ size: CGFloat, variant: AppTypography.Variant = .medium) -> Font {
        if let name = AppTypography.resolvedFontName(for: size, variant: variant) {
            return .custom(name, size: size)
        }

        return .system(size: size, weight: variant.fallbackWeight)
    }
}
