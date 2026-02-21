import Foundation
import KeyVoxWhisper
import Combine

class WhisperService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    @Published var lastResultWasLikelyNoSpeech = false

    var whisper: Whisper?
    var dictionaryHintPrompt = ""
    let noSpeechSegmentProbabilityThreshold: Float = 0.72
    let noSpeechAverageProbabilityThreshold: Float = 0.80
    let paragraphChunker = WhisperAudioParagraphChunker()
    // Enabled by default; temporarily disable locally when validating phonetic matching without hint bias.
    let isPromptHintingEnabled = true
    let suspiciousShortResultMinChunkSeconds: Double = 1.35
    let suspiciousShortResultMaxWords = 2
    let suspiciousShortResultMaxNoSpeechProbability: Float = 0.35
    let retryRelaxedLogprobThreshold: Float = -2.0

    var transcriptionTask: Task<Void, Never>?

    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        #if DEBUG
        print("WhisperService: Transcription cancelled.")
        #endif
    }

    func updateDictionaryHintPrompt(_ prompt: String) {
        let cleanedPrompt = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        dictionaryHintPrompt = cleanedPrompt
        whisper?.params.initialPrompt = isPromptHintingEnabled ? cleanedPrompt : ""
    }
}
