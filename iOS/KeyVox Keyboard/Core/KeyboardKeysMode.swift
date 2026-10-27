import CoreGraphics

enum KeyboardKeysMode: Equatable {
    case full
    case compact

    static func resolve(isCompactKeysEnabled: Bool, isCompactKeysActive: Bool) -> KeyboardKeysMode {
        isCompactKeysEnabled && isCompactKeysActive ? .compact : .full
    }

    /// The keyboard's height: the portrait height, changed by however much shorter or taller the
    /// keys are in landscape or on iPad.
    func keyboardHeight(isLandscape: Bool, display: KeyboardDisplay = .standard) -> CGFloat {
        let portraitHeight: CGFloat
        switch self {
        case .full:
            portraitHeight = KeyboardStyle.fullKeyboardHeight
        case .compact:
            portraitHeight = KeyboardStyle.compactKeyboardHeight
        }
        return portraitHeight - keyGridHeight(isLandscape: false)
            + keyGridHeight(isLandscape: isLandscape, display: display)
    }

    /// Keys are shorter in landscape, in both full and Compact Keys, though less so on an open
    /// foldable's inner display. On iPad they're taller than on iPhone in both orientations.
    func keyHeight(isLandscape: Bool, display: KeyboardDisplay = .standard) -> CGFloat {
        switch display {
        case .pad:
            return isLandscape ? KeyboardStyle.padLandscapeKeyHeight : KeyboardStyle.padKeyHeight
        case .openFoldable:
            return isLandscape ? KeyboardStyle.openFoldableLandscapeKeyHeight : KeyboardStyle.keyHeight
        case .standard:
            return isLandscape ? KeyboardStyle.landscapeKeyHeight : KeyboardStyle.keyHeight
        }
    }

    /// The height of the toolbar buttons sized from the top key row in landscape: the keys'
    /// height, except on iPad, where the toolbar stays shorter than the keys.
    func toolbarButtonHeight(isLandscape: Bool, display: KeyboardDisplay = .standard) -> CGFloat {
        guard isLandscape, display == .pad else {
            return keyHeight(isLandscape: isLandscape, display: display)
        }
        return KeyboardStyle.padLandscapeToolbarHeight
    }

    /// Key rows keep the same spacing everywhere except landscape on an open foldable's inner
    /// display, where they sit a little further apart.
    func rowSpacing(isLandscape: Bool, display: KeyboardDisplay = .standard) -> CGFloat {
        isLandscape && display == .openFoldable
            ? KeyboardStyle.openFoldableLandscapeRowSpacing
            : KeyboardStyle.keyboardRowSpacing
    }

    var visibleRowCount: Int {
        switch self {
        case .full:
            return 4
        case .compact:
            return 2
        }
    }

    func keyGridHeight(isLandscape: Bool, display: KeyboardDisplay = .standard) -> CGFloat {
        let rowCount = CGFloat(visibleRowCount)
        let spacingCount = CGFloat(max(visibleRowCount - 1, 0))
        let keyHeight = keyHeight(isLandscape: isLandscape, display: display)
        let rowSpacing = rowSpacing(isLandscape: isLandscape, display: display)
        return (keyHeight * rowCount) + (rowSpacing * spacingCount)
    }
}
