import Foundation
import KeyVoxWhisper
import Combine

@MainActor
public class WhisperService: ObservableObject, DictationProvider {
    @Published public internal(set) var isTranscribing = false
    @Published public internal(set) var transcriptionText = ""
    @Published public internal(set) var lastResultWasLikelyNoSpeech = false

    private let modelPathResolver: () -> String?
    private var activeTranscriptionRequestID = UUID()

    var whisper: Whisper?
    var dictionaryHintPrompt = ""
    let noSpeechSegmentProbabilityThreshold: Float = 0.72
    let noSpeechAverageProbabilityThreshold: Float = 0.80
    let paragraphChunker = WhisperAudioParagraphChunker()
    // Enabled by default; temporarily disable locally when validating phonetic matching without hint bias.
    let isPromptHintingEnabled = true
    let suspiciousShortResultMinChunkSeconds: Double = 1.35
    let suspiciousShortResultMaxWords = 2
    let suspiciousShortResultDensityMinChunkSeconds: Double = 8.0
    let suspiciousShortResultMaxWordsPerSecond: Double = 0.20
    let emptyResultRetryMinChunkSeconds: Double = 6.0
    let suspiciousShortResultMaxNoSpeechProbability: Float = 0.35
    let retryRelaxedLogprobThreshold: Float = -2.0

    var transcriptionTask: Task<Void, Never>?

    public init(modelPathResolver: @escaping () -> String? = { nil }) {
        self.modelPathResolver = modelPathResolver
    }

    public var isModelReady: Bool {
        guard let modelPath = resolvedModelPath()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !modelPath.isEmpty else {
            return false
        }

        return FileManager.default.fileExists(atPath: modelPath)
    }

    public func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        activeTranscriptionRequestID = UUID()
        isTranscribing = false
        whisper?.params.initialPrompt = isPromptHintingEnabled ? dictionaryHintPrompt : ""
        #if DEBUG
        print("WhisperService: Transcription cancelled.")
        #endif
    }

    public func updateDictionaryHintPrompt(_ prompt: String) {
        let cleanedPrompt = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        dictionaryHintPrompt = cleanedPrompt
        whisper?.params.initialPrompt = isPromptHintingEnabled ? cleanedPrompt : ""
    }

    func resolvedModelPath() -> String? {
        modelPathResolver()
    }

    func beginTranscriptionRequest() -> UUID {
        let requestID = UUID()
        activeTranscriptionRequestID = requestID
        return requestID
    }

    func isCurrentRequest(_ requestID: UUID) -> Bool {
        activeTranscriptionRequestID == requestID
    }

    func restoreDictionaryHintPromptIfNeeded(
        requestID: UUID,
        usedDictionaryHintPrompt: Bool
    ) {
        guard isCurrentRequest(requestID), !usedDictionaryHintPrompt else { return }
        whisper?.params.initialPrompt = isPromptHintingEnabled ? dictionaryHintPrompt : ""
    }

    func finishCancelledRequest(
        _ requestID: UUID,
        usedDictionaryHintPrompt: Bool
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        restoreDictionaryHintPromptIfNeeded(
            requestID: requestID,
            usedDictionaryHintPrompt: usedDictionaryHintPrompt
        )
    }

    func finishEmptyRequest(
        _ requestID: UUID,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        lastResultWasLikelyNoSpeech = true
        transcriptionText = ""
        completion(TranscriptionProviderResult(text: "", languageCode: nil))
    }

    func finishSuccessfulRequest(
        _ requestID: UUID,
        usedDictionaryHintPrompt: Bool,
        finalText: String,
        likelyNoSpeech: Bool,
        detectedLanguageCode: String?,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        restoreDictionaryHintPromptIfNeeded(
            requestID: requestID,
            usedDictionaryHintPrompt: usedDictionaryHintPrompt
        )
        lastResultWasLikelyNoSpeech = likelyNoSpeech
        transcriptionText = finalText
        completion(TranscriptionProviderResult(text: finalText, languageCode: detectedLanguageCode))
    }

    func finishFailedRequest(
        _ requestID: UUID,
        usedDictionaryHintPrompt: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        restoreDictionaryHintPromptIfNeeded(
            requestID: requestID,
            usedDictionaryHintPrompt: usedDictionaryHintPrompt
        )
        lastResultWasLikelyNoSpeech = false
            completion(nil)
    }
}
