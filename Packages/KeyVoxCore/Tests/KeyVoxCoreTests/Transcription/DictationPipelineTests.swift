import XCTest
@testable import KeyVoxCore

@MainActor
final class DictationPipelineTests: XCTestCase {
    func testPipelineProcessesAndPastesFormattedText() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "project notes one cue board two cue board", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [DictionaryEntry(phrase: "Cueboard")] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: true
        )

        XCTAssertEqual(result.rawText, "project notes one cue board two cue board")
        XCTAssertEqual(result.finalText, "Project notes:\n\n1. Cueboard\n2. Cueboard")
        XCTAssertFalse(result.wasLikelyNoSpeech)
        XCTAssertEqual(provider.receivedAudioFrames, audioFrames)
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, true)
        XCTAssertEqual(provider.receivedEnableAutoParagraphs, true)
        XCTAssertEqual(recorded, ["Project notes:\n\n1. Cueboard\n2. Cueboard"])
        XCTAssertEqual(pasted, ["Project notes:\n\n1. Cueboard\n2. Cueboard"])
    }

    func testPipelineAppliesBuiltInDictionaryEntryAndRefreshesProviderPrompt() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "my app is called key box", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: true
        )

        XCTAssertEqual(provider.receivedDictionaryHintPrompt, "Domain vocabulary: KeyVox, KeyVox Speak")
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, true)
        XCTAssertEqual(result.finalText, "My app is called KeyVox")
        XCTAssertEqual(recorded, ["My app is called KeyVox"])
        XCTAssertEqual(pasted, ["My app is called KeyVox"])
    }

    func testPipelineKeepsProviderHintDisabledWhenAudioGateDisallowsHinting() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "my app is called key box", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )

        _ = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(provider.receivedDictionaryHintPrompt, "Domain vocabulary: KeyVox, KeyVox Speak")
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, false)
    }

    func testPipelineSuppressesLikelyNoSpeechResults() async throws {
        let provider = StubTranscriptionProvider(
            result: nil,
            lastResultWasLikelyNoSpeech: true
        )
        let audioFrames = Array(repeating: Float(0.0), count: 32)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { _ in XCTFail("Should not record") },
            pasteText: { _ in XCTFail("Should not paste") }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(result.rawText, "")
        XCTAssertEqual(result.finalText, "")
        XCTAssertTrue(result.wasLikelyNoSpeech)
        XCTAssertEqual(provider.receivedAudioFrames, audioFrames)
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, false)
        XCTAssertEqual(provider.receivedEnableAutoParagraphs, true)
    }

    func testPipelineCompletesAfterExternalPipelineReferenceIsReleased() async throws {
        let provider = DeferredTranscriptionProvider()
        let audioFrames = Array(repeating: Float(0.1), count: 64)
        var pipeline: DictationPipeline? = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { false },
            listFormattingEnabledProvider: { false },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )
        let expectation = expectation(description: "Pipeline completion")
        var result: DictationPipelineResult?

        pipeline?.run(audioFrames: audioFrames, useDictionaryHintPrompt: false) {
            result = $0
            expectation.fulfill()
        }

        pipeline = nil
        provider.complete(with: .init(text: "hello world", languageCode: "en"))
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(result?.rawText, "hello world")
        XCTAssertEqual(result?.finalText, "Hello world")
        XCTAssertEqual(result?.wasLikelyNoSpeech, false)
    }

    private var recorded: [String] = []
    private var pasted: [String] = []

    override func setUp() {
        super.setUp()
        recorded = []
        pasted = []
    }

    private func runPipeline(
        _ pipeline: DictationPipeline,
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool
    ) async -> DictationPipelineResult {
        await withCheckedContinuation { continuation in
            pipeline.run(audioFrames: audioFrames, useDictionaryHintPrompt: useDictionaryHintPrompt) {
                continuation.resume(returning: $0)
            }
        }
    }
}

@MainActor
private final class StubTranscriptionProvider: DictationTranscriptionProviding, DictationTranscriptionControlling {
    let result: TranscriptionProviderResult?
    let lastResultWasLikelyNoSpeech: Bool
    private(set) var receivedAudioFrames: [Float]?
    private(set) var receivedUseDictionaryHintPrompt: Bool?
    private(set) var receivedEnableAutoParagraphs: Bool?
    private(set) var receivedDictionaryHintPrompt: String?

    init(
        result: TranscriptionProviderResult?,
        lastResultWasLikelyNoSpeech: Bool = false
    ) {
        self.result = result
        self.lastResultWasLikelyNoSpeech = lastResultWasLikelyNoSpeech
    }

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        receivedAudioFrames = audioFrames
        receivedUseDictionaryHintPrompt = useDictionaryHintPrompt
        receivedEnableAutoParagraphs = enableAutoParagraphs
        completion(result)
    }

    func cancelTranscription() {}

    func updateDictionaryHintPrompt(_ prompt: String) {
        receivedDictionaryHintPrompt = prompt
    }
}

@MainActor
private final class DeferredTranscriptionProvider: DictationTranscriptionProviding, DictationTranscriptionControlling {
    let lastResultWasLikelyNoSpeech = false
    private var completion: ((TranscriptionProviderResult?) -> Void)?

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        self.completion = completion
    }

    func complete(with result: TranscriptionProviderResult?) {
        completion?(result)
        completion = nil
    }

    func cancelTranscription() {}

    func updateDictionaryHintPrompt(_ prompt: String) {}
}
