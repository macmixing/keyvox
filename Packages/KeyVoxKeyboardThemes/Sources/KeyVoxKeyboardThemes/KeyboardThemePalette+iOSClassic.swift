extension KeyboardThemePalette {
    /// Neutral keys that follow the iOS system keyboard's measured grays: over the keyboard backdrop,
    /// light keys read nearly white and dark keys land on the system keyboard's key gray, while
    /// both still let the backdrop through. Every key shares one color, as the system keyboard's do.
    public static let iOSClassic = KeyboardThemePalette(
        keyFill: iOSClassicKeyFill,
        keyPressedFill: iOSClassicKeyPressedFill,
        specialKeyFill: iOSClassicKeyFill,
        specialKeyPressedFill: iOSClassicKeyPressedFill,
        keyFillOpacity: KeyboardThemeKeyOpacity(light: 0.75, dark: 0.3),
        popupFill: .appearance(
            light: KeyboardThemeRGBA(red: 1, green: 1, blue: 1),
            dark: KeyboardThemeRGBA(red: 0.64, green: 0.64, blue: 0.66)
        ),
        cancelKeyBorder: .system(.gray)
    )

    private static let iOSClassicKeyFill = KeyboardThemeColor.appearance(
        light: KeyboardThemeRGBA(red: 1, green: 1, blue: 1),
        dark: KeyboardThemeRGBA(red: 0.73, green: 0.73, blue: 0.73)
    )

    private static let iOSClassicKeyPressedFill = KeyboardThemeColor.appearance(
        light: KeyboardThemeRGBA(red: 0.67, green: 0.67, blue: 0.69),
        dark: KeyboardThemeRGBA(red: 0.29, green: 0.29, blue: 0.29)
    )
}
