import Foundation

enum DictationShortcutSetupPage: Int, CaseIterable, Hashable {
    case shortcutIntro = 1
    case addShortcut
    case actionButtonIntro
    case actionButtonSettings
    case actionButtonShortcutOption
    case actionButtonShortcutSelection
    case actionButtonDemoPaste
    case actionButtonDemoHandoff

    var next: Self? {
        Self(rawValue: rawValue + 1)
    }

    var previous: Self? {
        Self(rawValue: rawValue - 1)
    }

    var videoAccessibilityLabel: String? {
        switch self {
        case .shortcutIntro:
            nil
        case .addShortcut:
            "Tap the button below to add the KeyVox shortcut."
        case .actionButtonIntro:
            "Dictate with the Action Button."
        case .actionButtonSettings:
            "Open iPhone Settings and tap “Action Button.”"
        case .actionButtonShortcutOption:
            "Swipe through the options and find “Shortcut,” then tap “Choose a Shortcut…”"
        case .actionButtonShortcutSelection:
            "Tap “Toggle KeyVox Dictation.”"
        case .actionButtonDemoPaste:
            "Press the Action Button to toggle KeyVox dictation. Press it again to transcribe your words. Paste your text into any app."
        case .actionButtonDemoHandoff:
            "Or start by pressing the Action Button and talking. Pull up the KeyVox keyboard and tap the dictation button. Turn your speech into text."
        }
    }

    var videoAsset: DictationShortcutSetupVideoAsset? {
        switch self {
        case .shortcutIntro:
            DictationShortcutSetupVideoAsset(
                name: "ShortcutHero",
                pixelWidth: 600,
                pixelHeight: 600
            )
        case .addShortcut:
            DictationShortcutSetupVideoAsset(
                name: "AddShortcutPage",
                pixelWidth: 1170,
                pixelHeight: 2100
            )
        case .actionButtonIntro:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonIntro",
                pixelWidth: 2150,
                pixelHeight: 2450,
                viewportPixelWidth: 1170
            )
        case .actionButtonSettings:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonSettings",
                pixelWidth: 1170,
                pixelHeight: 1850
            )
        case .actionButtonShortcutOption:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonShortcutOption",
                pixelWidth: 1170,
                pixelHeight: 2450
            )
        case .actionButtonShortcutSelection:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonShortcutSelection",
                pixelWidth: 1170,
                pixelHeight: 2450
            )
        case .actionButtonDemoPaste:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonDemoPaste",
                pixelWidth: 2150,
                pixelHeight: 2450,
                viewportPixelWidth: 1170
            )
        case .actionButtonDemoHandoff:
            DictationShortcutSetupVideoAsset(
                name: "ActionButtonDemoHandoff",
                pixelWidth: 2150,
                pixelHeight: 2450,
                viewportPixelWidth: 1170
            )
        }
    }
}
