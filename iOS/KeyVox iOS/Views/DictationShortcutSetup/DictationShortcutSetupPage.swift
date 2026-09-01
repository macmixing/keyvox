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

    var videoAccessibilityLabel: String? {
        switch self {
        case .one:
            nil
        case .two:
            "Tap the button below to add the KeyVox shortcut."
        case .three:
            "Dictate with the Action Button."
        case .four:
            "Open iPhone Settings and tap “Action Button.”"
        case .five:
            "Swipe through the options and find “Shortcut,” then tap “Choose a Shortcut…”"
        case .six:
            "Tap “Toggle KeyVox Dictation.”"
        case .seven:
            "Press the Action Button to toggle KeyVox dictation. Press it again to transcribe your words. Paste your text into any app."
        case .eight:
            "Or start by pressing the Action Button and talking. Pull up the KeyVox keyboard and tap the dictation button. Turn your speech into text."
        }
    }

    var videoAsset: DictationShortcutSetupVideoAsset? {
        switch self {
        case .one:
            DictationShortcutSetupVideoAsset(
                name: "Page-1",
                pixelWidth: 600,
                pixelHeight: 600
            )
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
        case .eight:
            DictationShortcutSetupVideoAsset(
                name: "Page-8",
                pixelWidth: 2150,
                pixelHeight: 2450,
                viewportPixelWidth: 1170
            )
        }
    }
}
