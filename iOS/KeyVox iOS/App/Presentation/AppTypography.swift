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

    /// Kanit has no narrow no-break space (U+202F), which French formatting puts between a number and its unit
    /// and between thousands groups. The regular no-break space keeps the value together without a wide fallback gap.
    nonisolated static func fontSupportedSpacing(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: "\u{00A0}")
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
