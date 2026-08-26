import CoreGraphics

enum KeyboardKeysMode: Equatable {
    case full
    case compact

    static func resolve(isCompactKeysEnabled: Bool, isCompactKeysActive: Bool) -> KeyboardKeysMode {
        isCompactKeysEnabled && isCompactKeysActive ? .compact : .full
    }

    var keyboardHeight: CGFloat {
        switch self {
        case .full:
            return KeyboardStyle.fullKeyboardHeight
        case .compact:
            return KeyboardStyle.compactKeyboardHeight
        }
    }

    var visibleRowCount: Int {
        switch self {
        case .full:
            return 4
        case .compact:
            return 2
        }
    }

    var keyGridHeight: CGFloat {
        let rowCount = CGFloat(visibleRowCount)
        let spacingCount = CGFloat(max(visibleRowCount - 1, 0))
        return (KeyboardStyle.keyHeight * rowCount) + (KeyboardStyle.keyboardRowSpacing * spacingCount)
    }
}
