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
private final class StubTranscriptionProvider: DictationTranscriptionProviding {
    let result: TranscriptionProviderResult?
    let lastResultWasLikelyNoSpeech: Bool
    private(set) var receivedAudioFrames: [Float]?
    private(set) var receivedUseDictionaryHintPrompt: Bool?
    private(set) var receivedEnableAutoParagraphs: Bool?

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
}
