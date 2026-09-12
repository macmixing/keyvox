import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testEllipsisContinuationCasing() async {
        let processor = TranscriptionPostProcessor()
        let stylizedToken = "KvX"
        let cases: [(String, [DictionaryEntry], String)] = [
            ("A... B.", [], "A... b."),
            ("C… D.", [], "C… d."),
            ("E... \(stylizedToken).", [DictionaryEntry(phrase: stylizedToken)], "E... \(stylizedToken)."),
            ("F...\n\ng.", [], "F...\n\nG."),
        ]

        for (input, dictionaryEntries, expected) in cases {
            let output = processor.process(
                input,
                dictionaryEntries: dictionaryEntries,
                renderMode: .multiline
            )

            XCTAssertEqual(output, expected)
        }
    }
}
