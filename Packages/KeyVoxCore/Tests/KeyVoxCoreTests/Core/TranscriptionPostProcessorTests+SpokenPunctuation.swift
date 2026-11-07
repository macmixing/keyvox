import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testCapitalizesSentenceAfterSpokenPeriod() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm home period we leave at noon",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )

        XCTAssertEqual(output, "I'm home. We leave at noon.")
    }

    func testSpokenPeriodBeforeTranscribedPeriodLeavesOnePeriod() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm home period.",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )

        XCTAssertEqual(output, "I'm home.")
    }

    func testKeepsSpokenPeriodForOneWordDictation() async {
        let processor = TranscriptionPostProcessor()

        let periodOutput = processor.process(
            "thanks period",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )
        let transcribedPeriodOutput = processor.process(
            "Thanks.",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )

        XCTAssertEqual(periodOutput, "Thanks.")
        XCTAssertEqual(transcribedPeriodOutput, "Thanks")
    }

    func testTrailingSpokenCommaDoesNotGainTerminalPeriod() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Keep going comma",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )

        XCTAssertEqual(output, "Keep going,")
    }

    func testSpokenCommaKeepsFollowingSentenceLowercase() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hi John comma. How are you?",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )

        XCTAssertEqual(output, "Hi John, how are you?")
    }

    func testSpokenPeriodAloneProducesPeriod() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "period",
            dictionaryEntries: [],
            renderMode: .singleLineInline,
            languageCode: "en"
        )

        XCTAssertEqual(output, ".")
    }

    func testKeepsCapitalsThatBelongToTheWordAfterSpokenEllipsis() async {
        let processor = TranscriptionPostProcessor()
        let cases = [
            (input: "We paused dot dot dot Monday works.", expected: "We paused… Monday works."),
            (input: "We paused dot dot dot Sarah called.", expected: "We paused… Sarah called."),
            (input: "We paused dot dot dot Then continued.", expected: "We paused… then continued."),
        ]

        for testCase in cases {
            XCTAssertEqual(
                processor.process(
                    testCase.input,
                    dictionaryEntries: [],
                    renderMode: .singleLineInline,
                    languageCode: "en"
                ),
                testCase.expected
            )
        }
    }
}
