import Foundation
import KeyVoxCore

@MainActor
protocol iOSDictationService: DictationTranscriptionProviding {
    func warmup()
    func cancelTranscription()
    func updateDictionaryHintPrompt(_ prompt: String)
}

extension WhisperService: iOSDictationService {}
