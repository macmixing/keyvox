extension KeyboardThemePalette {
    /// KeyVox's lavender and indigo keys on iOS, tinting the keyboard backdrop in both appearances.
    public static let iOSKeyVox = KeyboardThemePalette(
        keyFill: .fixed(KeyboardThemeRGBA(red: 0.67, green: 0.67, blue: 0.92)),
        keyPressedFill: keyVoxKeyPressedFill,
        specialKeyFill: .fixed(KeyboardThemeRGBA(red: 0.35, green: 0.36, blue: 0.66)),
        specialKeyPressedFill: .fixed(KeyboardThemeRGBA(red: 0.19, green: 0.20, blue: 0.36)),
        keyDisabledFill: .system(.tertiaryFill),
        specialKeyDisabledFill: .system(.quaternaryFill),
        activeKeyFill: keyVoxKeyPressedFill,
        keyFillOpacity: KeyboardThemeKeyOpacity(light: 0.3, dark: 0.3),
        keyBorder: .iOSKeyBorder,
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
        cancelKeyBorder: .system(.indigo),
        // In light, the letter key color at the keys' strength over white.
        microphoneBackground: .appearance(
            light: KeyboardThemeRGBA(red: 0.901, green: 0.901, blue: 0.976),
            dark: KeyboardThemeRGBA(red: 0, green: 0, blue: 0, alpha: 0.82)
        ),
        // Indigo in light and the letter keys' lavender in dark, with a lighter head dot in dark, over
        // three nested glow layers of the same hue.
        swipeTrail: KeyboardThemeSwipeTrail(
            color: .appearance(
                light: KeyboardThemeRGBA(red: 0x5B / 255, green: 0x5F / 255, blue: 0xD6 / 255, alpha: 0.85),
                dark: KeyboardThemeRGBA(red: 0xAB / 255, green: 0xAB / 255, blue: 0xEB / 255)
            ),
            headColor: .appearance(
                light: KeyboardThemeRGBA(red: 0x5B / 255, green: 0x5F / 255, blue: 0xD6 / 255, alpha: 0.85),
                dark: KeyboardThemeRGBA(red: 0xC9 / 255, green: 0xC9 / 255, blue: 0xFF / 255)
            ),
            glowColor: .appearance(
                light: KeyboardThemeRGBA(red: 0x5B / 255, green: 0x5F / 255, blue: 0xD6 / 255),
                dark: KeyboardThemeRGBA(red: 0xAB / 255, green: 0xAB / 255, blue: 0xEB / 255)
            ),
            glows: KeyboardThemeSwipeTrail.standardGlows,
            width: KeyboardThemeSwipeTrail.Measure(light: 6.5, dark: 7),
            tailWidthScale: KeyboardThemeSwipeTrail.standardTailWidthScale,
            tailDuration: KeyboardThemeSwipeTrail.standardTailDuration,
            opacityFalloffExponent: KeyboardThemeSwipeTrail.standardOpacityFalloffExponent,
            headScale: KeyboardThemeSwipeTrail.standardHeadScale,
            liftDuration: KeyboardThemeSwipeTrail.standardLiftDuration,
            bloomScale: KeyboardThemeSwipeTrail.standardBloomScale,
            bloomDuration: KeyboardThemeSwipeTrail.standardBloomDuration
        )
    )

    private static let keyVoxKeyPressedFill = KeyboardThemeColor.fixed(
        KeyboardThemeRGBA(red: 0.29, green: 0.31, blue: 0.55)
    )
}
