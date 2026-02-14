import Foundation
import whisper

public enum WhisperSamplingStrategy: Int32, Sendable {
    case greedy = 0
    case beamSearch = 1
}

@dynamicMemberLookup
public final class WhisperParams {
    public static var `default`: WhisperParams {
        WhisperParams(strategy: .greedy)
    }

    var whisperParams: whisper_full_params
    private var languageCString: UnsafeMutablePointer<CChar>?
    private var initialPromptCString: UnsafeMutablePointer<CChar>?

    public init(strategy: WhisperSamplingStrategy = .greedy) {
        let cStrategy: whisper_sampling_strategy = strategy == .greedy
            ? WHISPER_SAMPLING_GREEDY
            : WHISPER_SAMPLING_BEAM_SEARCH

        self.whisperParams = whisper_full_default_params(cStrategy)
        self.language = .auto
    }

    deinit {
        if let languageCString {
            free(languageCString)
        }
        if let initialPromptCString {
            free(initialPromptCString)
        }
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<whisper_full_params, T>) -> T {
        get { whisperParams[keyPath: keyPath] }
        set { whisperParams[keyPath: keyPath] = newValue }
    }

    public var language: WhisperLanguage {
        get {
            guard let cLanguage = whisperParams.language else {
                return .auto
            }

            let raw = String(cString: cLanguage)
            return WhisperLanguage(rawValue: raw) ?? .auto
        }
        set {
            if let languageCString {
                free(languageCString)
            }

            guard let duplicated = strdup(newValue.rawValue) else { return }
            languageCString = duplicated
            whisperParams.language = UnsafePointer(duplicated)
        }
    }

    public var initialPrompt: String {
        get {
            guard let cPrompt = whisperParams.initial_prompt else {
                return ""
            }
            return String(cString: cPrompt)
        }
        set {
            if let initialPromptCString {
                free(initialPromptCString)
                self.initialPromptCString = nil
            }

            let cleaned = newValue
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleaned.isEmpty else {
                whisperParams.initial_prompt = nil
                return
            }

            guard let duplicated = strdup(cleaned) else { return }
            initialPromptCString = duplicated
            whisperParams.initial_prompt = UnsafePointer(duplicated)
        }
    }

    // Backward-compatible alias for older whisper.cpp headers.
    public var suppress_non_speech_tokens: Bool {
        get { whisperParams.suppress_nst }
        set { whisperParams.suppress_nst = newValue }
    }
}
