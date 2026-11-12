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
            String(localized: "Tap the button below to add the KeyVox shortcut.", comment: "VoiceOver label for the dictation shortcut setup video on the Add Shortcut page. KeyVox is a brand name and stays in English.")
        case .actionButtonIntro:
            String(localized: "Dictate with the Action Button.", comment: "VoiceOver label for the dictation shortcut setup video introducing the Action Button. Use Apple's official name for the Action Button in this language.")
        case .actionButtonSettings:
            String(localized: "Open iPhone Settings and tap “Action Button.”", comment: "VoiceOver label for the dictation shortcut setup video showing the Action Button page in Settings. Use Apple's official names for Settings and Action Button in this language.")
        case .actionButtonShortcutOption:
            String(localized: "Swipe through the options and find “Shortcut,” then tap “Choose a Shortcut…”", comment: "VoiceOver label for the dictation shortcut setup video showing the Action Button options. Use Apple's official names for the Shortcut option and the Choose a Shortcut… button in this language.")
        case .actionButtonShortcutSelection:
            String(localized: "Tap “Toggle KeyVox Dictation.”", comment: "VoiceOver label for the dictation shortcut setup video showing the shortcut list. “Toggle KeyVox Dictation” is the name of the bundled KeyVox shortcut and stays as written.")
        case .actionButtonDemoPaste:
            String(localized: "Press the Action Button to toggle KeyVox dictation. Press it again to transcribe your words. Paste your text into any app.", comment: "VoiceOver label for the dictation shortcut setup video demonstrating dictation with the Action Button. KeyVox is a brand name and stays in English; use Apple's official name for the Action Button in this language.")
        case .actionButtonDemoHandoff:
            String(localized: "Or start by pressing the Action Button and talking. Pull up the KeyVox keyboard and tap the dictation button. Turn your speech into text.", comment: "VoiceOver label for the dictation shortcut setup video demonstrating starting dictation with the Action Button and finishing it on the keyboard. KeyVox is a brand name and stays in English; use Apple's official name for the Action Button in this language.")
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
