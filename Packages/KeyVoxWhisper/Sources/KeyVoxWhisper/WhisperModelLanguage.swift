import KeyVoxSpeechRuntime

/// Model-family contract of the pinned whisper.cpp runtime, not a host language default.
enum WhisperModelLanguage {
    static func fixedLanguageID(context: OpaquePointer) -> Int32? {
        guard whisper_is_multilingual(context) == 0 else { return nil }
        // In whisper.cpp 1.7.6 the non-multilingual family uses the runtime's
        // built-in language. Its automatic language scores are not meaningful.
        guard let language = whisper_full_default_params(WHISPER_SAMPLING_GREEDY).language else { return -1 }
        return whisper_lang_id(language)
    }
}
