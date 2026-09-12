import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testEllipsisContinuationCasing() async {
        let processor = TranscriptionPostProcessor()
        let stylizedToken = "KvX"
        let cases: [(String, [DictionaryEntry], String)] = [
            ("Okay, now... Split up the work.", [], "Okay, now… split up the work."),
            ("We paused… Then continued.", [], "We paused… then continued."),
            ("We paused dot dot dot. Then continued.", [], "We paused… then continued."),
            ("We paused... “Then continued.”", [], "We paused… “then continued.”"),
            ("We paused... (Then continued.)", [], "We paused… (then continued.)"),
            ("We paused... \(stylizedToken) responded.", [], "We paused… \(stylizedToken) responded."),
            ("We paused... GPT 5.6 responded.", [], "We paused… GPT 5.6 responded."),
            ("We paused... U.S. officials responded.", [], "We paused… U.S. officials responded."),
            ("We paused... I agreed.", [], "We paused… I agreed."),
            ("Hello. . . .", [], "Hello…"),
            (
                "We paused... Dom Esposito responded.",
                [DictionaryEntry(phrase: "Dom Esposito")],
                "We paused… Dom Esposito responded."
            ),
            ("We paused...\n\nthen continued.", [], "We paused…\n\nThen continued."),
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
