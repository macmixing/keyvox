extension KeyboardThemePalette {
    /// KeyVox's lavender and indigo keys, tinting the keyboard backdrop in both appearances.
    public static let `default` = KeyboardThemePalette(
        keyFill: .fixed(KeyboardThemeRGBA(red: 0.67, green: 0.67, blue: 0.92)),
        keyPressedFill: .fixed(KeyboardThemeRGBA(red: 0.29, green: 0.31, blue: 0.55)),
        specialKeyFill: .fixed(KeyboardThemeRGBA(red: 0.35, green: 0.36, blue: 0.66)),
        specialKeyPressedFill: .fixed(KeyboardThemeRGBA(red: 0.19, green: 0.20, blue: 0.36)),
        keyFillOpacity: KeyboardThemeKeyOpacity(light: 0.3, dark: 0.3),
        popupFill: .appearance(
            light: KeyboardThemeRGBA(red: 1, green: 1, blue: 1),
            dark: KeyboardThemeRGBA(red: 0.62, green: 0.63, blue: 0.78)
        ),
        cancelKeyBorder: .system(.indigo)
    )
}
