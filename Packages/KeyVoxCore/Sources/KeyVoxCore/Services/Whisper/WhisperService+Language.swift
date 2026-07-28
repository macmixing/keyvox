import KeyVoxWhisper

extension WhisperService {
    public func updateLanguage(_ language: DictationLanguage) {
        configuredLanguage = WhisperBaseLanguageCatalog.supports(language) ? language : .automatic
    }

    func applyConfiguredLanguage() {
        whisper?.params.language = WhisperLanguage(rawValue: configuredLanguage.rawValue) ?? .auto
    }
}
