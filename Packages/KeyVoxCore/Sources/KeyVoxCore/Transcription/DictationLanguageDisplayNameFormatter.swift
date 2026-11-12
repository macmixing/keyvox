import Foundation

public enum DictationLanguageDisplayNameFormatter {
    public static func displayName(
        for language: DictationLanguage,
        locale: Locale = .current
    ) -> String {
        guard !language.isAutomatic else {
            return NSLocalizedString("Auto Detect", bundle: KeyVoxCoreResources.bundle, comment: "Dictation language option that lets the dictation model detect the spoken language automatically.")
        }

        guard let name = locale.localizedString(forLanguageCode: language.rawValue)
            ?? locale.localizedString(forIdentifier: language.rawValue) else {
            return language.rawValue.uppercased()
        }
        return standaloneCapitalized(name, locale: locale)
    }

    /// Language names stand alone in pickers and lists, so they start with a capital letter
    /// even in languages whose locale data writes them in lowercase.
    private static func standaloneCapitalized(_ name: String, locale: Locale) -> String {
        guard let first = name.first else { return name }
        return String(first).uppercased(with: locale) + name.dropFirst()
    }
}
