import CoreGraphics

enum KeyboardKeysMode: Equatable {
    case full
    case compact

    static func resolve(isCompactKeysEnabled: Bool, isCompactKeysActive: Bool) -> KeyboardKeysMode {
        isCompactKeysEnabled && isCompactKeysActive ? .compact : .full
    }

    /// The keyboard's height: the portrait height, shortened by however much shorter the
    /// keys are in landscape.
    func keyboardHeight(isLandscape: Bool) -> CGFloat {
        let portraitHeight: CGFloat
        switch self {
        case .full:
            portraitHeight = KeyboardStyle.fullKeyboardHeight
        case .compact:
            portraitHeight = KeyboardStyle.compactKeyboardHeight
        }
        return portraitHeight - keyGridHeight(isLandscape: false) + keyGridHeight(isLandscape: isLandscape)
    }

    /// Keys are shorter in landscape, in both full and Compact Keys.
    func keyHeight(isLandscape: Bool) -> CGFloat {
        isLandscape ? KeyboardStyle.landscapeKeyHeight : KeyboardStyle.keyHeight
    }

    var visibleRowCount: Int {
        switch self {
        case .full:
            return 4
        case .compact:
            return 2
        }
    }

    func keyGridHeight(isLandscape: Bool) -> CGFloat {
        let rowCount = CGFloat(visibleRowCount)
        let spacingCount = CGFloat(max(visibleRowCount - 1, 0))
        return (keyHeight(isLandscape: isLandscape) * rowCount) + (KeyboardStyle.keyboardRowSpacing * spacingCount)
    }
}
