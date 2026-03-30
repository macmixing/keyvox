import XCTest
@testable import KeyVoxCore

@MainActor
final class SwitchableDictationProviderTests: XCTestCase {
    func testReplaceActiveProviderDelegatesFutureCallsToNewProvider() {
        let whisper = RecordingDictationProvider()
        whisper.isModelReadyValue = true
        let parakeet = RecordingDictationProvider()
        parakeet.isModelReadyValue = true

        let provider = SwitchableDictationProvider(initialProvider: whisper)

        provider.updateDictionaryHintPrompt("first")
        provider.replaceActiveProvider(with: parakeet)
        provider.updateDictionaryHintPrompt("second")
        provider.warmup()
        provider.cancelTranscription()

        XCTAssertEqual(whisper.recordedPrompts, ["first"])
        XCTAssertEqual(parakeet.recordedPrompts, ["second"])
        XCTAssertEqual(whisper.cancelCalls, 1)
        XCTAssertEqual(whisper.unloadCalls, 1)
        XCTAssertEqual(parakeet.warmupCalls, 2)
        XCTAssertEqual(parakeet.cancelCalls, 1)
    }

    func testLastNoSpeechAndReadinessTrackActiveProvider() {
        let whisper = RecordingDictationProvider()
        whisper.isModelReadyValue = true
        whisper.lastResultWasLikelyNoSpeechValue = false

        let parakeet = RecordingDictationProvider()
        parakeet.isModelReadyValue = false
        parakeet.lastResultWasLikelyNoSpeechValue = true

        let provider = SwitchableDictationProvider(initialProvider: whisper)
        XCTAssertTrue(provider.isModelReady)
        XCTAssertFalse(provider.lastResultWasLikelyNoSpeech)

        provider.replaceActiveProvider(with: parakeet, warmNewProviderIfReady: false)
        XCTAssertFalse(provider.isModelReady)
        XCTAssertTrue(provider.lastResultWasLikelyNoSpeech)
    }

    func testReplaceActiveProviderCanSkipCancelUnloadAndWarmup() {
        let whisper = RecordingDictationProvider()
        whisper.isModelReadyValue = true

        let parakeet = RecordingDictationProvider()
        parakeet.isModelReadyValue = true

        let provider = SwitchableDictationProvider(initialProvider: whisper)

        provider.replaceActiveProvider(
            with: parakeet,
            cancelCurrentWork: false,
            unloadPreviousModel: false,
            warmNewProviderIfReady: false
        )

        XCTAssertEqual(whisper.cancelCalls, 0)
        XCTAssertEqual(whisper.unloadCalls, 0)
        XCTAssertEqual(parakeet.warmupCalls, 0)
    }
}

@MainActor
private final class RecordingDictationProvider: DictationProvider {
    var lastResultWasLikelyNoSpeechValue = false
    var isModelReadyValue = false
    var recordedPrompts: [String] = []
    var warmupCalls = 0
    var unloadCalls = 0
    var cancelCalls = 0

    var lastResultWasLikelyNoSpeech: Bool {
        lastResultWasLikelyNoSpeechValue
    }

    var isModelReady: Bool {
        isModelReadyValue
    }

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        completion(nil)
    }

    func cancelTranscription() {
        cancelCalls += 1
    }

    func updateDictionaryHintPrompt(_ prompt: String) {
        recordedPrompts.append(prompt)
    }

    func warmup() {
        warmupCalls += 1
    }

    func unloadModel() {
        unloadCalls += 1
    }
}
