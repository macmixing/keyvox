import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testRepairsLeadingFDoubleAsteriskModelCensorshipBeforeK() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I swear to f**king god!",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I swear to fucking god!")
    }

    func testRepairsLeadingFTripleAsteriskModelCensorshipAsWord() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I swear to f*** God!",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I swear to fuck God!")
    }
}
