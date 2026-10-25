/// A themed color: either explicit values for the light and dark appearances, or a color from the
/// platform's system palette.
public enum KeyboardThemeColor: Equatable, Sendable {
    case appearance(light: KeyboardThemeRGBA, dark: KeyboardThemeRGBA)
    case system(KeyboardThemeSystemColor)

    /// The same color in both appearances.
    public static func fixed(_ color: KeyboardThemeRGBA) -> KeyboardThemeColor {
        .appearance(light: color, dark: color)
    }
}
