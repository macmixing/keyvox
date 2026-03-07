import XCTest
@testable import KeyVoxCore

@MainActor
final class WhisperServiceParagraphAssemblyTests: XCTestCase {
    func testAssembleTranscriptionInsertsParagraphAfterSilenceBoundaryAndTerminalPunctuation() {
        let service = WhisperService()
        let text = service.assembleTranscription(
            from: [
                .init(text: "First paragraph.", trailingBoundaryFrame: 32_000),
                .init(text: "Second paragraph.", trailingBoundaryFrame: nil)
            ],
            silenceBoundaryFrames: [32_000],
            enableAutoParagraphs: true
        )

        XCTAssertEqual(text, "First paragraph.\n\nSecond paragraph.")
    }

    func testAssembleTranscriptionKeepsMidSentenceSilenceBoundaryInline() {
        let service = WhisperService()
        let text = service.assembleTranscription(
            from: [
                .init(text: "This sentence keeps going", trailingBoundaryFrame: 32_000),
                .init(text: "until it actually ends.", trailingBoundaryFrame: nil)
            ],
            silenceBoundaryFrames: [32_000],
            enableAutoParagraphs: true
        )

        XCTAssertEqual(text, "This sentence keeps going until it actually ends.")
    }

    func testAssembleTranscriptionIgnoresFallbackOnlyBoundaryEvenWithTerminalPunctuation() {
        let service = WhisperService()
        let text = service.assembleTranscription(
            from: [
                .init(text: "Sentence one.", trailingBoundaryFrame: 32_000),
                .init(text: "Sentence two.", trailingBoundaryFrame: nil)
            ],
            silenceBoundaryFrames: [],
            enableAutoParagraphs: true
        )

        XCTAssertEqual(text, "Sentence one. Sentence two.")
    }

    func testAssembleTranscriptionPreservesParagraphAcrossEmptyChunkGap() {
        let service = WhisperService()
        let text = service.assembleTranscription(
            from: [
                .init(text: "Quoted sentence!\"", trailingBoundaryFrame: 16_000),
                .init(text: "", trailingBoundaryFrame: 32_000),
                .init(text: "New paragraph.", trailingBoundaryFrame: nil)
            ],
            silenceBoundaryFrames: [16_000, 32_000],
            enableAutoParagraphs: true
        )

        XCTAssertEqual(text, "Quoted sentence!\"\n\nNew paragraph.")
    }
}
