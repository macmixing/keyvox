import Foundation
import KeyVoxWhisper
import Combine

public class WhisperService: ObservableObject {
    @Published public internal(set) var isTranscribing = false
    @Published public internal(set) var transcriptionText = ""
    @Published public internal(set) var lastResultWasLikelyNoSpeech = false

    private let modelPathResolver: () -> String?

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

    public func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
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
}
