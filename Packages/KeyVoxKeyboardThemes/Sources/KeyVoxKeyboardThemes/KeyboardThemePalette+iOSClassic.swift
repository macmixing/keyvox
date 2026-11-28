extension KeyboardThemePalette {
    /// Neutral keys that follow the iOS system keyboard's measured grays: over the keyboard backdrop,
    /// light keys read nearly white and dark keys land on the system keyboard's key gray, while
    /// both still let the backdrop through. Every key shares one color, as the system keyboard's do,
    /// and a toolbar key that is on uses a deeper gold in light so it stays readable on near-white keys.
    /// In light, disabled keys sit a step below the keyboard backdrop so they stay apart from it, and a
    /// toolbar key that is on steps down from the near-white keys as gently as it does in the KeyVox theme.
    /// Key popups and the highlight under a held key's selected character follow the system keyboard's
    /// measured popups: white with black characters in light, dark gray with white characters in dark,
    /// with the keys' own outline in dark. In light, the microphone button's background is drawn as the
    /// keys are, their fill at their strength over the backdrop, instead of a tint.
    public static let iOSClassic = KeyboardThemePalette(
        keyFill: iOSClassicKeyFill,
        keyPressedFill: iOSClassicKeyPressedFill,
        specialKeyFill: iOSClassicKeyFill,
        specialKeyPressedFill: iOSClassicKeyPressedFill,
        keyDisabledFill: KeyboardThemeColor(
            light: .rgba(KeyboardThemeRGBA(red: 0.82, green: 0.82, blue: 0.84)),
            dark: .system(.tertiaryFill)
        ),
        specialKeyDisabledFill: KeyboardThemeColor(
            light: .rgba(KeyboardThemeRGBA(red: 0.85, green: 0.85, blue: 0.87)),
            dark: .system(.quaternaryFill)
        ),
        activeKeyFill: KeyboardThemeColor(
            light: .rgba(KeyboardThemeRGBA(red: 0.837, green: 0.837, blue: 0.857)),
            dark: iOSClassicKeyPressedFill.dark
        ),
        keyFillOpacity: iOSClassicKeyFillOpacity,
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
        cancelKeyBorder: .system(.gray),
        microphoneBackground: .appearance(
            light: KeyboardThemeRGBA(
                red: iOSClassicLightKeyFill.red,
                green: iOSClassicLightKeyFill.green,
                blue: iOSClassicLightKeyFill.blue,
                alpha: iOSClassicKeyFillOpacity.light
            ),
            dark: KeyboardThemeRGBA(red: 0, green: 0, blue: 0, alpha: 0.82)
        ),
        microphoneForeground: .iOSMicrophone,
        // The microphone's own color in light and white in dark, with a nearly solid white head dot in
        // dark so no ring shows over the letters, over five nested glow layers of the same shade,
        // fainter in dark.
        swipeTrail: KeyboardThemeSwipeTrail(
            color: KeyboardThemeColor(light: KeyboardThemeColor.iOSMicrophone.light, dark: .rgba(KeyboardThemeRGBA(red: 1, green: 1, blue: 1, alpha: 0.7))),
            headColor: KeyboardThemeColor(light: KeyboardThemeColor.iOSMicrophone.light, dark: .rgba(KeyboardThemeRGBA(red: 1, green: 1, blue: 1, alpha: 0.95))),
            glowColor: KeyboardThemeColor(light: KeyboardThemeColor.iOSMicrophone.light, dark: .rgba(KeyboardThemeRGBA(red: 1, green: 1, blue: 1))),
            glows: [
                KeyboardThemeSwipeTrail.Glow(widthScale: 1.3, opacity: KeyboardThemeSwipeTrail.Measure(light: 0.10, dark: 0.07)),
                KeyboardThemeSwipeTrail.Glow(widthScale: 1.7, opacity: KeyboardThemeSwipeTrail.Measure(light: 0.07, dark: 0.05)),
                KeyboardThemeSwipeTrail.Glow(widthScale: 2.2, opacity: KeyboardThemeSwipeTrail.Measure(light: 0.05, dark: 0.04)),
                KeyboardThemeSwipeTrail.Glow(widthScale: 2.8, opacity: KeyboardThemeSwipeTrail.Measure(light: 0.03, dark: 0.02)),
                KeyboardThemeSwipeTrail.Glow(widthScale: 3.5, opacity: KeyboardThemeSwipeTrail.Measure(light: 0.02, dark: 0.01)),
            ],
            width: KeyboardThemeSwipeTrail.Measure(light: 5.5, dark: 6),
            tailWidthScale: KeyboardThemeSwipeTrail.standardTailWidthScale,
            tailDuration: KeyboardThemeSwipeTrail.standardTailDuration,
            opacityFalloffExponent: KeyboardThemeSwipeTrail.standardOpacityFalloffExponent,
            bandOverlap: KeyboardThemeSwipeTrail.standardBandOverlap,
            headScale: KeyboardThemeSwipeTrail.standardHeadScale,
            liftDuration: KeyboardThemeSwipeTrail.standardLiftDuration,
            liftTiming: KeyboardThemeSwipeTrail.standardLiftTiming,
            bloomScale: KeyboardThemeSwipeTrail.standardBloomScale,
            bloomDuration: KeyboardThemeSwipeTrail.standardBloomDuration,
            bloomFadeDuration: KeyboardThemeSwipeTrail.standardBloomFadeDuration
        )
    )

    private static let iOSClassicLightKeyFill = KeyboardThemeRGBA(red: 1, green: 1, blue: 1)

    private static let iOSClassicKeyFill = KeyboardThemeColor.appearance(
        light: iOSClassicLightKeyFill,
        dark: KeyboardThemeRGBA(red: 0.64, green: 0.64, blue: 0.64)
    )

    private static let iOSClassicKeyFillOpacity = KeyboardThemeKeyOpacity(light: 0.75, dark: 0.3)

    private static let iOSClassicKeyPressedFill = KeyboardThemeColor.appearance(
        light: KeyboardThemeRGBA(red: 0.67, green: 0.67, blue: 0.69),
        dark: KeyboardThemeRGBA(red: 0.29, green: 0.29, blue: 0.29)
    )
}
