import Foundation
import KeyVoxCore

@MainActor
protocol DictationService: DictationTranscriptionProviding {
    func warmup()
    func cancelTranscription()
    func updateDictionaryHintPrompt(_ prompt: String)
}

extension WhisperService: DictationService {}
