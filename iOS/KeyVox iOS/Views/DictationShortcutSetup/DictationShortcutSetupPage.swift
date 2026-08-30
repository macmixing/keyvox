import Foundation

enum DictationShortcutSetupPage: Int, CaseIterable, Hashable {
    case one = 1
    case two
    case three
    case four
    case five
    case six
    case seven

    var next: Self? {
        Self(rawValue: rawValue + 1)
    }

    var previous: Self? {
        Self(rawValue: rawValue - 1)
    }

    var includesVideoPlaceholder: Bool {
        self != .one
    }

    var videoAsset: DictationShortcutSetupVideoAsset? {
        switch self {
        case .four:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonSettings-Page4",
                pixelWidth: 1170,
                pixelHeight: 1850
            )
        case .five:
            DictationShortcutSetupVideoAsset(
                name: "AddShortcut-Page5",
                pixelWidth: 1170,
                pixelHeight: 2450
            )
        case .one, .two, .three, .six, .seven:
            nil
        }
    }
}
