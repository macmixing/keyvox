import Foundation

enum DictationShortcutSetupPage: Int, CaseIterable, Hashable {
    case one = 1
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight

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
        case .two:
            DictationShortcutSetupVideoAsset(
                name: "Page-2",
                pixelWidth: 1170,
                pixelHeight: 2100
            )
        case .three:
            DictationShortcutSetupVideoAsset(
                name: "Page-3",
                pixelWidth: 2150,
                pixelHeight: 2450,
                viewportPixelWidth: 1170
            )
        case .four:
            DictationShortcutSetupVideoAsset(
                name: "Page-4",
                pixelWidth: 1170,
                pixelHeight: 1850
            )
        case .five:
            DictationShortcutSetupVideoAsset(
                name: "Page-5",
                pixelWidth: 1170,
                pixelHeight: 2450
            )
        case .six:
            DictationShortcutSetupVideoAsset(
                name: "Page-6",
                pixelWidth: 1170,
                pixelHeight: 2450
            )
        case .seven:
            DictationShortcutSetupVideoAsset(
                name: "Page-7",
                pixelWidth: 2150,
                pixelHeight: 2450,
                viewportPixelWidth: 1170
            )
        case .one, .eight:
            nil
        }
    }
}
