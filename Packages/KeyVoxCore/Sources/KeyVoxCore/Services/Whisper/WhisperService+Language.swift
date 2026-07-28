import KeyVoxWhisper

extension WhisperService {
    public func updateLanguage(_ language: DictationLanguage) {
        configuredLanguage = WhisperBaseLanguageCatalog.supports(language) ? language : .automatic
    }

    func applyConfiguredLanguage() {
        guard let params = whisper?.params else { return }
        applyConfiguredLanguage(to: params)
    }

    func applyConfiguredLanguage(to params: WhisperParams) {
        params.language = WhisperLanguage(rawValue: configuredLanguage.rawValue) ?? .auto
    }
}
