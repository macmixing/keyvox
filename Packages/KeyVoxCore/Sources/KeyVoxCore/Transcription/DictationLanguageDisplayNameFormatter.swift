import Foundation

public enum DictationLanguageDisplayNameFormatter {
    public static func displayName(
        for language: DictationLanguage,
        locale: Locale = .current
    ) -> String {
        guard !language.isAutomatic else {
            return NSLocalizedString("Auto Detect", bundle: KeyVoxCoreResources.bundle, comment: "Dictation language option that lets the dictation model detect the spoken language automatically.")
        }

        return locale.localizedString(forLanguageCode: language.rawValue)
            ?? locale.localizedString(forIdentifier: language.rawValue)
            ?? language.rawValue.uppercased()
    }
}
