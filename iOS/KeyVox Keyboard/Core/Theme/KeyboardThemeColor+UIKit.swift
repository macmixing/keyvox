import KeyVoxKeyboardThemes
import UIKit

extension UIColor {
    /// A color that follows the theme carried by the traits it resolves with, in their appearance.
    static func keyboardTheme(_ color: KeyPath<KeyboardThemePalette, KeyboardThemeColor>) -> UIColor {
        UIColor { traits in
            traits.keyboardThemePalette[keyPath: color].resolvedColor(with: traits)
        }
    }
}

extension KeyboardThemeColor {
    func resolvedColor(with traits: UITraitCollection) -> UIColor {
        let shade = traits.userInterfaceStyle == .dark ? dark : light
        switch shade {
        case let .rgba(rgba):
            return UIColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        case let .system(color, alpha):
            let resolved = color.uiColor.resolvedColor(with: traits)
            return alpha.map { resolved.withAlphaComponent($0) } ?? resolved
        }
    }
}

private extension KeyboardThemeSystemColor {
    var uiColor: UIColor {
        switch self {
        case .indigo:
            return .systemIndigo
        case .gray:
            return .systemGray
        case .yellow:
            return .systemYellow
        case .separator:
            return .separator
        }
    }
}
