import CoreGraphics

enum KeyboardKeysMode: Equatable {
    case full
    case compact

    static func resolve(isCompactKeysEnabled: Bool, isCompactKeysActive: Bool) -> KeyboardKeysMode {
        isCompactKeysEnabled && isCompactKeysActive ? .compact : .full
    }

    /// The keyboard's height: the portrait height, shortened by however much shorter the
    /// keys are in landscape.
    func keyboardHeight(isLandscape: Bool, isOpenFoldableDisplay: Bool = false) -> CGFloat {
        let portraitHeight: CGFloat
        switch self {
        case .full:
            portraitHeight = KeyboardStyle.fullKeyboardHeight
        case .compact:
            portraitHeight = KeyboardStyle.compactKeyboardHeight
        }
        return portraitHeight - keyGridHeight(isLandscape: false)
            + keyGridHeight(isLandscape: isLandscape, isOpenFoldableDisplay: isOpenFoldableDisplay)
    }

    /// Keys are shorter in landscape, in both full and Compact Keys, though less so on an open
    /// foldable's inner display.
    func keyHeight(isLandscape: Bool, isOpenFoldableDisplay: Bool = false) -> CGFloat {
        guard isLandscape else { return KeyboardStyle.keyHeight }
        return isOpenFoldableDisplay ? KeyboardStyle.openFoldableLandscapeKeyHeight : KeyboardStyle.landscapeKeyHeight
    }

    /// Key rows keep the same spacing everywhere except landscape on an open foldable's inner
    /// display, where they sit a little further apart.
    func rowSpacing(isLandscape: Bool, isOpenFoldableDisplay: Bool = false) -> CGFloat {
        isLandscape && isOpenFoldableDisplay
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

    func keyGridHeight(isLandscape: Bool, isOpenFoldableDisplay: Bool = false) -> CGFloat {
        let rowCount = CGFloat(visibleRowCount)
        let spacingCount = CGFloat(max(visibleRowCount - 1, 0))
        let keyHeight = keyHeight(isLandscape: isLandscape, isOpenFoldableDisplay: isOpenFoldableDisplay)
        let rowSpacing = rowSpacing(isLandscape: isLandscape, isOpenFoldableDisplay: isOpenFoldableDisplay)
        return (keyHeight * rowCount) + (rowSpacing * spacingCount)
    }
}
