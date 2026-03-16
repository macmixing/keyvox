import UIKit

enum KeyboardTypography {
    enum Variant {
        case medium
        case light

        var candidateFontNames: [String] {
            switch self {
            case .medium:
                return ["Kanit-Medium", "Kanit Medium"]
            case .light:
                return ["Kanit-Light", "Kanit Light"]
            }
        }

        var fallbackWeight: UIFont.Weight {
            switch self {
            case .medium:
                return .medium
            case .light:
                return .light
            }
        }
    }

    static func font(_ size: CGFloat, variant: Variant = .medium) -> UIFont {
        for name in variant.candidateFontNames {
            if let font = UIFont(name: name, size: size) {
                return font
            }
        }

        return UIFont.systemFont(ofSize: size, weight: variant.fallbackWeight)
    }
}
