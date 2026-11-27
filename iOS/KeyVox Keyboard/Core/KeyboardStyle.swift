import KeyVoxKeyboardThemes
import UIKit

enum KeyboardStyle {
    struct Shadow {
        let color: UIColor
        let opacity: Float
        let radius: CGFloat
        let offset: CGSize
    }

    static let fullKeyboardHeight: CGFloat = 286
    static let compactKeyboardHeight: CGFloat = 174
    static let horizontalPadding: CGFloat = 4
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 4
    static let sectionSpacing: CGFloat = 14
    static let stackSpacing: CGFloat = 12
    static let keyboardRowSpacing: CGFloat = 8
    static let keySpacing: CGFloat = 6
    static let buttonSize: CGFloat = 44
    /// The toolbar's row and the space under it, above the keys.
    static let toolbarRowHeight: CGFloat = buttonSize + sectionSpacing
    /// The space the number pad leaves empty at each side of the screen in landscape, measured from
    /// the system's number pad on iOS 27 (225 points on iPhone, 227 on iPhone Duo folded and open).
    static let numberPadLandscapeScreenSideInset: CGFloat = 226
    static let buttonCornerRadius: CGFloat = 14

    static let keyHeight: CGFloat = 48
    /// Key height in landscape, matching Apple's landscape iPhone keyboard.
    static let landscapeKeyHeight: CGFloat = 32
    /// Key height in landscape on an open foldable's inner display, which has room for taller
    /// keys while keeping the keys' usual spacing.
    static let openFoldableLandscapeKeyHeight: CGFloat = 37
    /// Space between key rows in landscape on an open foldable's inner display.
    static let openFoldableLandscapeRowSpacing: CGFloat = 11
    /// Key height in portrait on iPad, a little taller than on iPhone.
    static let padKeyHeight: CGFloat = 56
    /// Key height in landscape on iPad.
    static let padLandscapeKeyHeight: CGFloat = 54
    /// Toolbar button height in landscape on iPad, which stays shorter than the keys there, as the
    /// toolbar does in portrait.
    static let padLandscapeToolbarHeight: CGFloat = 37
    static let keyUnitWidth: CGFloat = 34
    static let keyCornerRadius: CGFloat = 8
    static let popupWidthMultiplier: CGFloat = 1.15
    static let popupHeightMultiplier: CGFloat = 1.25
    static let popupContentInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    static let popupMinEdgeInset: CGFloat = 2
    static let popupCornerRadius: CGFloat = 10
    static let popupBorderWidth: CGFloat = 0.6
    static let popupShadowColor = UIColor.black
    static let popupShadowOpacity: Float = 0.25
    static let popupShadowRadius: CGFloat = 4
    static let popupShadowOffset = CGSize(width: 0, height: 3)
    static let popupFillColor = UIColor.keyboardTheme(\.popupFill)
    static let popupBorderColor = UIColor.keyboardTheme(\.popupBorder)
    static let popupLabelColor = UIColor.keyboardTheme(\.popupLabel)
    static let popupFont = UIFont.systemFont(ofSize: 32, weight: .medium)

    // A held key's popup, as the system keyboard draws it on an iPhone: the same height upright
    // and on its side, with cells a little narrower than the keys' spacing.
    /// How long a finger stays on a key before its popup opens.
    static let heldKeyPopupHoldDuration: TimeInterval = 0.34
    /// How much narrower a cell is than the distance from one key to the next.
    static let heldKeyPopupCellWidthReduction: CGFloat = 2.1
    static let heldKeyPopupCellHeight: CGFloat = 47
    static let heldKeyPopupPadding: CGFloat = 10.2
    static let heldKeyPopupGapAboveKey: CGFloat = 4.4
    static let landscapeHeldKeyPopupGapAboveKey: CGFloat = 3.3
    /// How far below the popup the finger goes before the popup closes without typing.
    static let heldKeyPopupClosingDistance: CGFloat = 87.8
    static let landscapeHeldKeyPopupClosingDistance: CGFloat = 93.3
    static let heldKeyPopupCornerRadius: CGFloat = 20
    static let heldKeyPopupHighlightCornerRadius: CGFloat = 9
    static let heldKeyPopupHighlightInset: CGFloat = 0.2
    /// Marks the selected character in a held key's popup, as the system keyboard's highlight does.
    static let heldKeyPopupHighlightColor = UIColor.keyboardTheme(\.heldKeyPopupHighlight)
    /// How large the popup's characters are next to the same characters on the keys.
    static let heldKeyPopupFontScale: CGFloat = 0.88
    /// How much wider than the held key a cell of the web endings popup is, as the system keyboard
    /// draws them: about 19 points wider on every key that offers them.
    static let heldKeyPopupWebEndingCellWidthAddition: CGFloat = 19

    static let backgroundColor = UIColor.clear
    /// Invisible, but not fully transparent: keyboard extensions only receive touches on
    /// pixels that are not fully clear, so areas that must take taps use this.
    static let touchableClearColor = UIColor.white.withAlphaComponent(0.001)
    static let borderColor = UIColor.clear
    static let labelColor = UIColor.label
    static let secondaryLabelColor = UIColor.secondaryLabel
    static let buttonFillColor = UIColor.secondarySystemBackground
    static let cancelButtonSize: CGFloat = 32
    static let cancelButtonBorderColor = UIColor.keyboardTheme(\.cancelKeyBorder)
    static let cancelButtonIconColor = UIColor.systemRed
    /// The circle behind the microphone in the dictation button.
    static let microphoneBackgroundColor = UIColor.keyboardTheme(\.microphoneBackground)
    /// The microphone in the dictation button.
    static let microphoneForegroundColor = UIColor.keyboardTheme(\.microphoneForeground)
    static let cancelButtonBorderWidth: CGFloat = 0.5
    static let keyBorderWidth: CGFloat = 0.5

    static let keyFillColor = UIColor.keyboardTheme(\.keyFill)
    static let keyPressedFillColor = UIColor.keyboardTheme(\.keyPressedFill)
    static let specialKeyFillColor = UIColor.keyboardTheme(\.specialKeyFill)
    static let specialKeyPressedFillColor = UIColor.keyboardTheme(\.specialKeyPressedFill)
    static let keyDisabledFillColor = UIColor.keyboardTheme(\.keyDisabledFill)
    /// A toolbar key that is on, such as Caps Lock while it is locked.
    static let activeKeyFillColor = UIColor.keyboardTheme(\.activeKeyFill)
    /// The solid blue key that finishes a field, the emoji search's done key and an action return
    /// key, as the system keyboard draws it, light and dark, measured with
    /// Tools/AppleKeyboardBaseline (`EmojiFrequentlyUsedProbeTests`).
    static let actionKeyFillColor = UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 1)
    static let actionKeyLabelColor = UIColor.white
    static let specialKeyDisabledFillColor = UIColor.keyboardTheme(\.specialKeyDisabledFill)
    static let keyBorderColor = UIColor.keyboardTheme(\.keyBorder)
    static let keyPressedBorderColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.separator.withAlphaComponent(0.20)
            : UIColor.white.withAlphaComponent(0.04)
    }
    static let keyDisabledBorderColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.separator.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.08)
    }
    static let keyLabelColor = UIColor.label
    static let keyDisabledLabelColor = UIColor.secondaryLabel.withAlphaComponent(0.7)

    /// What stands in for the keyboard backdrop when a key's visible color is worked out: the
    /// system draws the backdrop itself and the keyboard cannot read it, so the appearance's own
    /// background is used.
    static let keyBackdropStandInColor = UIColor.systemBackground

    /// A key's fill as it tints the keyboard backdrop behind it, as strongly as the theme sets for
    /// the appearance.
    static func keyTintColor(_ fill: UIColor) -> UIColor {
        UIColor { traits in
            let opacity = traits.keyboardThemePalette.keyFillOpacity
            let alpha = traits.userInterfaceStyle == .dark ? opacity.dark : opacity.light
            return fill.resolvedColor(with: traits).withAlphaComponent(alpha)
        }
    }

    static func activeForegroundColor(for traitCollection: UITraitCollection) -> UIColor {
        traitCollection.keyboardThemePalette.activeKeyForeground.resolvedColor(with: traitCollection)
    }

    static func pressedActiveForegroundColor(for traitCollection: UITraitCollection) -> UIColor {
        guard traitCollection.userInterfaceStyle == .light else {
            return UIColor(red: 0.78, green: 0.58, blue: 0, alpha: 1)
        }

        let increasedContrastLightTraits = UITraitCollection { traits in
            traits.userInterfaceStyle = .light
            traits.accessibilityContrast = .high
        }
        return UIColor.systemYellow.resolvedColor(with: increasedContrastLightTraits)
    }

    static let keyFont = UIFont.systemFont(ofSize: 22, weight: .regular)
    static let numberPadKeyFont = UIFont.systemFont(ofSize: 26, weight: .regular)
    /// The letters under a number pad digit.
    static let numberPadSubtitleFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
    static let numberPadSubtitleKerning: CGFloat = 2
    /// The shortest number pad key that shows its letters under the digit.
    static let numberPadSubtitleMinimumKeyHeight: CGFloat = 40
    /// How far above the key's middle a digit with letters sits, as a share of the key's height.
    static let numberPadTitleRaise: CGFloat = 0.12
    /// How far below the key's middle the letters sit, as a share of the key's height.
    static let numberPadSubtitleDrop: CGFloat = 0.24
    static let specialKeyFont = UIFont.systemFont(ofSize: 17)
    static let buttonSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    static let keySymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
    static let cancelButtonSymbolPointSize: CGFloat = 20
    static let cancelButtonSymbolWeight = UIImage.SymbolWeight.bold

    static let keyShadow = Shadow(
        color: UIColor.black,
        opacity: 0.12,
        radius: 0.8,
        offset: CGSize(width: 0, height: 1)
    )
    static let pressedKeyShadow = Shadow(
        color: UIColor.black,
        opacity: 0.18,
        radius: 2,
        offset: CGSize(width: 0, height: 2)
    )
}
