/// Looks up each theme's palette.
public enum KeyboardThemeCatalog {
    public static func palette(for theme: KeyboardThemeID) -> KeyboardThemePalette {
        switch theme {
        case .default:
            return .default
        case .classic:
            return .classic
        }
    }
}
