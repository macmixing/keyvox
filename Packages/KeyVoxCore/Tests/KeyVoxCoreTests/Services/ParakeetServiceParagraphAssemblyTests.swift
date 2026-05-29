import XCTest
@testable import KeyVoxCore

@MainActor
final class ParakeetServiceParagraphAssemblyTests: XCTestCase {
    func testAssembleTranscriptionCanRenderInlineAndParagraphFormsFromSameBoundaries() {
        let service = ParakeetService()
        let chunks: [ParakeetService.TranscribedChunk] = [
            .init(text: "First paragraph.", trailingBoundaryFrame: 32_000),
            .init(text: "Second paragraph.", trailingBoundaryFrame: nil)
        ]

        let paragraphText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [32_000],
            enableAutoParagraphs: true
        )
        let inlineText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [32_000],
            enableAutoParagraphs: false
        )

        XCTAssertEqual(paragraphText, "First paragraph.\n\nSecond paragraph.")
        XCTAssertEqual(inlineText, "First paragraph. Second paragraph.")
    }

    func testAssembleTranscriptionKeepsMidSentenceBoundaryInline() {
        let service = ParakeetService()
        let chunks: [ParakeetService.TranscribedChunk] = [
            .init(text: "This sentence keeps going", trailingBoundaryFrame: 32_000),
            .init(text: "until it actually ends.", trailingBoundaryFrame: nil)
        ]

        let paragraphText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [32_000],
            enableAutoParagraphs: true
        )
        let inlineText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [32_000],
            enableAutoParagraphs: false
        )

        XCTAssertEqual(paragraphText, "This sentence keeps going until it actually ends.")
        XCTAssertEqual(inlineText, "This sentence keeps going until it actually ends.")
    }

    func testAssembleTranscriptionIgnoresFallbackOnlyBoundaries() {
        let service = ParakeetService()
        let chunks: [ParakeetService.TranscribedChunk] = [
            .init(text: "Sentence one.", trailingBoundaryFrame: 32_000),
            .init(text: "Sentence two.", trailingBoundaryFrame: nil)
        ]

        let paragraphText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [],
            enableAutoParagraphs: true
        )
        let inlineText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [],
            enableAutoParagraphs: false
        )

        XCTAssertEqual(paragraphText, "Sentence one. Sentence two.")
        XCTAssertEqual(inlineText, "Sentence one. Sentence two.")
    }

    func testAssembleTranscriptionPreservesParagraphAcrossEmptyChunkGaps() {
        let service = ParakeetService()
        let chunks: [ParakeetService.TranscribedChunk] = [
            .init(text: "Quoted sentence!\"", trailingBoundaryFrame: 16_000),
            .init(text: "", trailingBoundaryFrame: 32_000),
            .init(text: "New paragraph.", trailingBoundaryFrame: nil)
        ]

        let paragraphText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [16_000, 32_000],
            enableAutoParagraphs: true
        )
        let inlineText = service.assembleTranscription(
            from: chunks,
            silenceBoundaryFrames: [16_000, 32_000],
            enableAutoParagraphs: false
        )

        XCTAssertEqual(paragraphText, "Quoted sentence!\"\n\nNew paragraph.")
        XCTAssertEqual(inlineText, "Quoted sentence!\" New paragraph.")
    }
}
