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

    /// The pages shown on this device. iPad has no Action Button, so it skips those pages and
    /// its setup ends once the shortcut is added.
    static var available: [Self] {
        AppDevice.isPad ? allCases.filter { $0.isActionButtonPage == false } : allCases
    }

    /// The last page shown on this device.
    static var finalPage: Self {
        available[available.count - 1]
    }

    /// Whether this page teaches the Action Button.
    var isActionButtonPage: Bool {
        switch self {
        case .shortcutIntro, .addShortcut:
            false
        case .actionButtonIntro, .actionButtonSettings, .actionButtonShortcutOption,
             .actionButtonShortcutSelection, .actionButtonDemoPaste, .actionButtonDemoHandoff:
            true
        }
    }

    /// Where this page sits among the pages shown on this device.
    var availableIndex: Int {
        Self.available.firstIndex(of: self) ?? 0
    }

    var next: Self? {
        let index = availableIndex + 1
        return index < Self.available.count ? Self.available[index] : nil
    }

    var previous: Self? {
        let index = availableIndex - 1
        return index >= 0 ? Self.available[index] : nil
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
