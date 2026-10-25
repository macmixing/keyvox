import KeyVoxKeyboardThemes
import UIKit

/// Carries the keyboard's chosen theme down its views, so themed colors resolve with it the way
/// they resolve with the light or dark appearance.
struct KeyboardThemeTrait: UITraitDefinition {
    static let defaultValue = KeyboardThemeID.keyVox
    static let affectsColorAppearance = true
}

extension UITraitCollection {
    var keyboardTheme: KeyboardThemeID {
        self[KeyboardThemeTrait.self]
    }

    /// The iOS colors of the theme these traits carry.
    var keyboardThemePalette: KeyboardThemePalette {
        KeyboardThemeCatalog.palette(for: keyboardTheme, on: .iOS)
    }
}

extension UIMutableTraits {
    var keyboardTheme: KeyboardThemeID {
        get { self[KeyboardThemeTrait.self] }
        set { self[KeyboardThemeTrait.self] = newValue }
    }
}
