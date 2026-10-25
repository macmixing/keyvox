extension KeyboardThemePalette {
    /// KeyVox's lavender and indigo keys on iOS, tinting the keyboard backdrop in both appearances.
    public static let iOSDefault = KeyboardThemePalette(
        keyFill: .fixed(KeyboardThemeRGBA(red: 0.67, green: 0.67, blue: 0.92)),
        keyPressedFill: .fixed(KeyboardThemeRGBA(red: 0.29, green: 0.31, blue: 0.55)),
        specialKeyFill: .fixed(KeyboardThemeRGBA(red: 0.35, green: 0.36, blue: 0.66)),
        specialKeyPressedFill: .fixed(KeyboardThemeRGBA(red: 0.19, green: 0.20, blue: 0.36)),
        keyFillOpacity: KeyboardThemeKeyOpacity(light: 0.3, dark: 0.3),
        popupFill: .appearance(
            light: KeyboardThemeRGBA(red: 1, green: 1, blue: 1),
            dark: KeyboardThemeRGBA(red: 0.62, green: 0.63, blue: 0.78)
        ),
        popupBorder: KeyboardThemeColor(
            light: .system(.separator, alpha: 0.45),
            dark: .rgba(KeyboardThemeRGBA(red: 1, green: 1, blue: 1, alpha: 0.5))
        ),
        popupLabel: .fixed(KeyboardThemeRGBA(red: 0, green: 0, blue: 0)),
        heldKeyPopupHighlight: .fixed(KeyboardThemeRGBA(red: 0, green: 0, blue: 0, alpha: 0.106)),
        activeKeyForeground: KeyboardThemeColor(
            light: .rgba(KeyboardThemeRGBA(red: 0.72, green: 0.50, blue: 0)),
            dark: .system(.yellow)
        ),
        cancelKeyBorder: .system(.indigo)
    )
}
