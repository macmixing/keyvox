import Foundation
import KeyVoxSpeechRuntime

public enum WhisperSamplingStrategy: Int32, Sendable {
    case greedy = 0
    case beamSearch = 1
}

@dynamicMemberLookup
public final class WhisperParams {
    public static var `default`: WhisperParams {
        WhisperParams(strategy: .greedy)
    }

    private let storageLock = NSLock()
    private var storedParams: whisper_full_params

    var whisperParams: whisper_full_params {
        get { storageLock.withLock { storedParams } }
        set { storageLock.withLock { storedParams = newValue } }
    }

    func snapshot() -> WhisperParamsSnapshot {
        storageLock.withLock { WhisperParamsSnapshot(raw: storedParams) }
    }
    private var languageCString: UnsafeMutablePointer<CChar>?
    private var initialPromptCString: UnsafeMutablePointer<CChar>?

    public init(strategy: WhisperSamplingStrategy = .greedy) {
        let cStrategy: whisper_sampling_strategy = strategy == .greedy
            ? WHISPER_SAMPLING_GREEDY
            : WHISPER_SAMPLING_BEAM_SEARCH

        self.storedParams = whisper_full_default_params(cStrategy)
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
        get { storageLock.withLock { storedParams[keyPath: keyPath] } }
        set { storageLock.withLock { storedParams[keyPath: keyPath] = newValue } }
    }

    public var language: WhisperLanguage {
        get {
            storageLock.lock()
            defer { storageLock.unlock() }
            guard let cLanguage = storedParams.language else {
                return .auto
            }

            let raw = String(cString: cLanguage)
            return WhisperLanguage(rawValue: raw) ?? .auto
        }
        set {
            storageLock.lock()
            defer { storageLock.unlock() }
            guard let duplicated = strdup(newValue.rawValue) else { return }
            if let languageCString {
                free(languageCString)
            }

            languageCString = duplicated
            storedParams.language = UnsafePointer(duplicated)
        }
    }

    public var initialPrompt: String {
        get {
            storageLock.lock()
            defer { storageLock.unlock() }
            guard let cPrompt = storedParams.initial_prompt else { return "" }
            return String(cString: cPrompt)
        }
        set {
            storageLock.lock()
            defer { storageLock.unlock() }
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicated: UnsafeMutablePointer<CChar>?
            if cleaned.isEmpty {
                duplicated = nil
            } else {
                guard let copy = strdup(cleaned) else { return }
                duplicated = copy
            }
            if let initialPromptCString {
                free(initialPromptCString)
            }
            initialPromptCString = duplicated
            storedParams.initial_prompt = duplicated.map { UnsafePointer($0) }
        }
    }

    // Backward-compatible alias for older whisper.cpp headers.
    public var suppress_non_speech_tokens: Bool {
        get { storageLock.withLock { storedParams.suppress_nst } }
        set { storageLock.withLock { storedParams.suppress_nst = newValue } }
    }
}
