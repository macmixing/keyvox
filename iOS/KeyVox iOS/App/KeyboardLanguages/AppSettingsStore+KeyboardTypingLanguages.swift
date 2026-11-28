import Foundation

extension AppSettingsStore {
    /// The languages the keyboard types in and the layout of each, resolved from what the user
    /// saved and the languages the keyboard bundles.
    var keyboardTypingLanguageSelection: KeyboardTypingLanguageSelection {
        KeyboardTypingLanguageSelection(
            savedLanguages: keyboardTypingLanguages,
            savedLetterLayouts: keyboardLetterLayouts,
            catalog: KeyboardBundledTypingLanguages.catalog,
            fallbackLanguage: Bundle.main.developmentLocalization
        )
    }
}
