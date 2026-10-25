/// A themed color, with its shade in the light and dark appearances.
public struct KeyboardThemeColor: Equatable, Sendable {
    public let light: KeyboardThemeShade
    public let dark: KeyboardThemeShade

    public init(light: KeyboardThemeShade, dark: KeyboardThemeShade) {
        self.light = light
        self.dark = dark
    }

    /// Explicit values for the light and dark appearances.
    public static func appearance(light: KeyboardThemeRGBA, dark: KeyboardThemeRGBA) -> KeyboardThemeColor {
        KeyboardThemeColor(light: .rgba(light), dark: .rgba(dark))
    }

    /// The same values in both appearances.
    public static func fixed(_ color: KeyboardThemeRGBA) -> KeyboardThemeColor {
        .appearance(light: color, dark: color)
    }

    /// A system palette color, which follows the platform's own shade in each appearance.
    public static func system(_ color: KeyboardThemeSystemColor) -> KeyboardThemeColor {
        KeyboardThemeColor(light: .system(color), dark: .system(color))
    }
}
