/// The colors a theme gives the keyboard's keys: letter, special, and toolbar keys and their
/// outline, their popups with their outline, characters, and highlight, the symbol of a toolbar
/// key that is on, and the cancel key's border.
public struct KeyboardThemePalette: Equatable, Sendable {
    /// Letter keys, and the toolbar keys drawn like them.
    public let keyFill: KeyboardThemeColor
    public let keyPressedFill: KeyboardThemeColor
    /// Shift, delete, the page keys, space, and return.
    public let specialKeyFill: KeyboardThemeColor
    public let specialKeyPressedFill: KeyboardThemeColor
    public let keyFillOpacity: KeyboardThemeKeyOpacity
    /// The outline around keys.
    public let keyBorder: KeyboardThemeColor
    /// The popups that show above a tapped or held key.
    public let popupFill: KeyboardThemeColor
    /// The outline around those popups.
    public let popupBorder: KeyboardThemeColor
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
        keyBorder: KeyboardThemeColor,
        popupFill: KeyboardThemeColor,
        popupBorder: KeyboardThemeColor,
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
        self.keyBorder = keyBorder
        self.popupFill = popupFill
        self.popupBorder = popupBorder
        self.popupLabel = popupLabel
        self.heldKeyPopupHighlight = heldKeyPopupHighlight
        self.activeKeyForeground = activeKeyForeground
        self.cancelKeyBorder = cancelKeyBorder
    }
}
