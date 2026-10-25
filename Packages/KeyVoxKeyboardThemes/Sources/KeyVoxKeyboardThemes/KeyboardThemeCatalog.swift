/// Looks up each theme's palette on each platform.
public enum KeyboardThemeCatalog {
    public static func palette(for theme: KeyboardThemeID, on platform: KeyboardThemePlatform) -> KeyboardThemePalette {
        switch (platform, theme) {
        case (.iOS, .keyVox):
            return .iOSKeyVox
        case (.iOS, .classic):
            return .iOSClassic
        }
    }
}
