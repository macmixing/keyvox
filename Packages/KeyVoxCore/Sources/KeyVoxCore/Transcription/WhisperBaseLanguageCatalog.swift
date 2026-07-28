import KeyVoxWhisper

public enum WhisperBaseLanguageCatalog {
    public static let supportedLanguages: [DictationLanguage] = WhisperLanguage.allCases
        .filter { $0 != .cantonese }
        .map { DictationLanguage(rawValue: $0.rawValue) }

    public static func supports(_ language: DictationLanguage) -> Bool {
        supportedLanguages.contains(language)
    }
}
