import Foundation

public enum DictationLanguageDisplayNameFormatter {
    public static func displayName(
        for language: DictationLanguage,
        locale: Locale = .current
    ) -> String {
        guard !language.isAutomatic else {
            return "Auto Detect"
        }

        return locale.localizedString(forLanguageCode: language.rawValue)
            ?? locale.localizedString(forIdentifier: language.rawValue)
            ?? language.rawValue.uppercased()
    }
}
