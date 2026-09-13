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
            ("We paused... I'm ready.", [], "We paused… I'm ready."),
            ("We paused... I’ll handle it.", [], "We paused… I’ll handle it."),
            ("We paused... I'd agree.", [], "We paused… I'd agree."),
            ("We paused... I've finished.", [], "We paused… I've finished."),
            ("Hello. . . .", [], "Hello…"),
            // Regression coverage for Parakeet EncoderInt4 artifact …36367d9.
            ("This is creepy.dot.dot. What's wrong with you?", [], "This is creepy… what's wrong with you?"),
            ("I'm annoying.dot.dot. That's okay.", [], "I'm annoying… that's okay."),
            ("This is funny.dot.dot. I'm laughing so hard right now.", [], "This is funny… I'm laughing so hard right now."),
            (
                "This is absolutely crazy. Dot dot dot. San Francisco is the best.",
                [],
                "This is absolutely crazy… San Francisco is the best."
            ),
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
