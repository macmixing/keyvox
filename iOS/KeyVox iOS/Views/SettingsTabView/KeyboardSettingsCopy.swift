import Foundation

/// The wording for the KeyVox keyboard's settings screen and the Keyboard row that opens it.
enum KeyboardSettingsCopy {
    static let screenTitle = String(localized: "Keyboard", comment: "Title of the KeyVox keyboard settings screen and of the Settings row that opens it.")
    static let screenDescription = String(localized: "Corrections, predictions, and layout for the KeyVox keyboard.", comment: "Description under the Keyboard row in Settings.")
    static let autoCapitalizationTitle = String(localized: "Auto-Capitalization", comment: "Keyboard settings toggle. Use the term the system keyboard settings use in this language.")
    static let autoCorrectionTitle = String(localized: "Auto-Correction", comment: "Keyboard settings toggle. Use the term the system keyboard settings use in this language.")
    static let capsLockTitle = String(localized: "Enable Caps Lock", comment: "Keyboard settings toggle. Use the term the system keyboard settings use in this language.")
    static let predictiveTextTitle = String(localized: "Predictive Text", comment: "Keyboard settings toggle. Use the term the system keyboard settings use in this language.")
    static let emojiKeyboardTitle = String(localized: "Emoji Keyboard", comment: "Keyboard settings toggle that shows or hides the emoji keyboard.")
    static let periodShortcutTitle = String(localized: "“.” Shortcut", comment: "Keyboard settings toggle for typing a period by double-tapping the space bar. Use the term the system keyboard settings use in this language.")
    static let periodShortcutDescription = String(localized: "Double tap the space bar to type a period followed by a space.", comment: "Description under the period shortcut toggle in keyboard settings.")
    static let hapticsTitle = String(localized: "Keyboard Haptics", comment: "Keyboard settings toggle for vibration feedback on key taps.")
    static let hapticsDescription = String(localized: "Get haptic feedback from KeyVox keyboard.", comment: "Description under the Keyboard Haptics toggle.")
    static let leftHandedLayoutTitle = String(localized: "Left-Handed Layout", comment: "Keyboard settings toggle that mirrors the keyboard's control buttons for left-hand use.")
    static let leftHandedLayoutDescription = String(localized: "Mirror KeyVox controls for easier left-hand access.", comment: "Description under the Left-Handed Layout toggle.")
    static let classicThemeTitle = String(localized: "Classic Theme", comment: "Keyboard settings toggle that switches the keyboard to neutral key colors.")
    static let classicThemeDescription = String(localized: "Use neutral keys instead of KeyVox colors.", comment: "Description under the Classic Theme toggle.")
    static let compactKeysTitle = "Compact Keys"
    static let compactKeysDescription = String(localized: "Long-press #+= to use a shorter keyboard.", comment: "Description under the Compact Keys toggle. Compact Keys is a KeyVox feature name and stays in English. #+= is the keyboard's symbols key label and stays as written.")
    static let openOnNumberPageTitle = String(localized: "Open on 123", comment: "Keyboard settings toggle. 123 is the keyboard's numbers key label and stays as written.")
    static let openOnNumberPageDescription = String(localized: "Show numbers and symbols when the keyboard opens. Tap ABC for letters.", comment: "Description under the Open on 123 toggle. ABC is the keyboard's letters key label and stays as written.")
    static let resetLearnedWordsTitle = String(localized: "Reset Learned Words", comment: "Keyboard settings button that clears words the keyboard has learned.")
    static let resetLearnedWordsHint = String(localized: "To forget a single word, press and hold it in the suggestion bar.", comment: "Hint under the Reset Learned Words button.")
    static let englishOnlyNote = String(localized: "Auto-Correction and Predictive Text currently support English only.", comment: "Note in keyboard settings explaining which typing features are limited to English.")
}
