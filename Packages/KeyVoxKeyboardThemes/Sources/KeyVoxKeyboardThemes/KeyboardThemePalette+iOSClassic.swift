extension KeyboardThemePalette {
    /// Neutral keys that follow the iOS system keyboard's measured grays: over the keyboard backdrop,
    /// light keys read nearly white and dark keys land on the system keyboard's key gray, while
    /// both still let the backdrop through. Every key shares one color, as the system keyboard's do,
    /// and a toolbar key that is on uses a deeper gold in light so it stays readable on near-white keys.
    /// Key popups and the highlight under a held key's selected character follow the system keyboard's
    /// measured popups: white with black characters in light, dark gray with white characters in dark,
    /// with the keys' own outline in dark.
    public static let iOSClassic = KeyboardThemePalette(
        keyFill: iOSClassicKeyFill,
        keyPressedFill: iOSClassicKeyPressedFill,
        specialKeyFill: iOSClassicKeyFill,
        specialKeyPressedFill: iOSClassicKeyPressedFill,
        keyFillOpacity: KeyboardThemeKeyOpacity(light: 0.75, dark: 0.3),
        keyBorder: .iOSKeyBorder,
        popupFill: .appearance(
            light: KeyboardThemeRGBA(red: 1, green: 1, blue: 1),
            dark: KeyboardThemeRGBA(red: 0.224, green: 0.224, blue: 0.224)
        ),
        popupBorder: KeyboardThemeColor(
            light: .system(.separator, alpha: 0.45),
            dark: KeyboardThemeColor.iOSKeyBorder.dark
        ),
        popupLabel: .appearance(
            light: KeyboardThemeRGBA(red: 0, green: 0, blue: 0),
            dark: KeyboardThemeRGBA(red: 1, green: 1, blue: 1)
        ),
        heldKeyPopupHighlight: .appearance(
            light: KeyboardThemeRGBA(red: 0.898, green: 0.898, blue: 0.906),
            dark: KeyboardThemeRGBA(red: 0.306, green: 0.306, blue: 0.318)
        ),
        activeKeyForeground: KeyboardThemeColor(
            light: .rgba(KeyboardThemeRGBA(red: 0.66, green: 0.46, blue: 0)),
            dark: .system(.yellow)
        ),
        cancelKeyBorder: .system(.gray)
    )

    private static let iOSClassicKeyFill = KeyboardThemeColor.appearance(
        light: KeyboardThemeRGBA(red: 1, green: 1, blue: 1),
        dark: KeyboardThemeRGBA(red: 0.64, green: 0.64, blue: 0.64)
    )

    private static let iOSClassicKeyPressedFill = KeyboardThemeColor.appearance(
        light: KeyboardThemeRGBA(red: 0.67, green: 0.67, blue: 0.69),
        dark: KeyboardThemeRGBA(red: 0.29, green: 0.29, blue: 0.29)
    )
}
