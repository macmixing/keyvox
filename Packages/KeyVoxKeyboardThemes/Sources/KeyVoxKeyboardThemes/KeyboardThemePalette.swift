/// The colors a theme gives the keyboard's keys: letter, special, and toolbar keys, their
/// popups and their characters and highlight, the symbol of a toolbar key that is on, and the
/// cancel key's border.
public struct KeyboardThemePalette: Equatable, Sendable {
    /// Letter keys, and the toolbar keys drawn like them.
    public let keyFill: KeyboardThemeColor
    public let keyPressedFill: KeyboardThemeColor
    /// Shift, delete, the page keys, space, and return.
    public let specialKeyFill: KeyboardThemeColor
    public let specialKeyPressedFill: KeyboardThemeColor
    public let keyFillOpacity: KeyboardThemeKeyOpacity
    /// The popups that show above a tapped or held key.
    public let popupFill: KeyboardThemeColor
    /// The characters in those popups.
    public let popupLabel: KeyboardThemeColor
    /// The highlight under the selected character in a held key's popup.
    public let heldKeyPopupHighlight: KeyboardThemeColor
    /// The symbol and title of a toolbar key that is on.
    public let activeKeyForeground: KeyboardThemeColor
    public let cancelKeyBorder: KeyboardThemeColor

    public init(
        keyFill: KeyboardThemeColor,
        keyPressedFill: KeyboardThemeColor,
        specialKeyFill: KeyboardThemeColor,
        specialKeyPressedFill: KeyboardThemeColor,
        keyFillOpacity: KeyboardThemeKeyOpacity,
        popupFill: KeyboardThemeColor,
        popupLabel: KeyboardThemeColor,
        heldKeyPopupHighlight: KeyboardThemeColor,
        activeKeyForeground: KeyboardThemeColor,
        cancelKeyBorder: KeyboardThemeColor
    ) {
        self.keyFill = keyFill
        self.keyPressedFill = keyPressedFill
        self.specialKeyFill = specialKeyFill
        self.specialKeyPressedFill = specialKeyPressedFill
        self.keyFillOpacity = keyFillOpacity
        self.popupFill = popupFill
        self.popupLabel = popupLabel
        self.heldKeyPopupHighlight = heldKeyPopupHighlight
        self.activeKeyForeground = activeKeyForeground
        self.cancelKeyBorder = cancelKeyBorder
    }
}
