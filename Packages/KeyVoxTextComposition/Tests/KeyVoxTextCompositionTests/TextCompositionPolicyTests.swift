import XCTest
@testable import KeyVoxTextComposition

final class TextCompositionPolicyTests: XCTestCase {
    func testOpeningQuotesAttachTextAndPreserveCapitalization() {
        for quote in [Character("\""), Character("'"), Character("“"), Character("‘")] {
            let context = TextCompositionContext(
                isAtDocumentStart: false,
                previousCharacter: quote,
                characterBeforePreviousCharacter: " ",
                previousNonWhitespaceCharacter: quote
            )

            let capitalized = TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                in: "This is cool.",
                context: context,
                scope: .firstCharacter,
                preserveLeadingCapitalization: false
            )
            let spaced = TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                to: capitalized,
                context: context
            )

            XCTAssertEqual(spaced, "This is cool.")
        }
    }

    func testTerminalPunctuationBeforeClosingQuotesStartsSentence() {
        for quote in [Character("\""), Character("'"), Character("”"), Character("’")] {
            for terminalPunctuation in [Character("."), Character("?"), Character("!")] {
                let context = TextCompositionContext(
                    isAtDocumentStart: false,
                    previousCharacter: quote,
                    characterBeforePreviousCharacter: terminalPunctuation,
                    previousNonWhitespaceCharacter: quote
                )

                let capitalized = TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                    in: "We missed that.",
                    context: context,
                    scope: .firstCharacter,
                    preserveLeadingCapitalization: false
                )
                let spaced = TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                    to: capitalized,
                    context: context
                )

                XCTAssertEqual(spaced, " We missed that.")
            }
        }
    }

    func testPrecedingTextBuildsQuotedSentenceBoundaryContext() {
        let context = TextCompositionContext(precedingText: "Did you say, \"what's up?\"")

        XCTAssertEqual(context.previousCharacter, "\"")
        XCTAssertEqual(context.characterBeforePreviousCharacter, "?")
        XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: context))
    }

    func testClosingQuoteWithoutTerminalPunctuationContinuesSentence() {
        for characterBeforeQuote in [Character(","), Character("e")] {
            let context = TextCompositionContext(
                isAtDocumentStart: false,
                previousCharacter: "\"",
                characterBeforePreviousCharacter: characterBeforeQuote,
                previousNonWhitespaceCharacter: "\""
            )

            let capitalized = TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                in: "But he didn't listen.",
                context: context,
                scope: .firstCharacter,
                preserveLeadingCapitalization: false
            )
            let spaced = TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                to: capitalized,
                context: context
            )

            XCTAssertEqual(spaced, " but he didn't listen.")
        }
    }

    func testSentenceBoundariesAndNewlinesPreserveCapitalization() {
        let contexts = [
            TextCompositionContext.documentStart,
            TextCompositionContext(
                isAtDocumentStart: false,
                previousCharacter: " ",
                previousNonWhitespaceCharacter: "?"
            ),
            TextCompositionContext(
                isAtDocumentStart: false,
                previousCharacter: " ",
                previousNonWhitespaceCharacter: "e",
                isAfterNewline: true
            ),
        ]

        for context in contexts {
            XCTAssertEqual(
                TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                    in: "Hello there.",
                    context: context,
                    scope: .firstCharacter,
                    preserveLeadingCapitalization: false
                ),
                "Hello there."
            )
        }
    }

    func testContinuationCapitalizationPreservesIntentionalCasing() {
        let context = TextCompositionContext(
            isAtDocumentStart: false,
            previousCharacter: "e",
            previousNonWhitespaceCharacter: "e"
        )

        XCTAssertEqual(normalize("Hello there.", context: context), "hello there.")
        XCTAssertEqual(normalize("NASA", context: context), "NASA")
        XCTAssertEqual(normalize("OpenAI", context: context), "OpenAI")
        XCTAssertEqual(
            TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                in: "KeyVox is ready.",
                context: context,
                scope: .firstCharacter,
                preserveLeadingCapitalization: true
            ),
            "KeyVox is ready."
        )
    }

    func testCapitalizationScopesPreserveExistingPlatformBehavior() {
        let context = TextCompositionContext(
            isAtDocumentStart: false,
            previousCharacter: "e",
            previousNonWhitespaceCharacter: "e"
        )

        XCTAssertEqual(
            TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                in: "  Hello",
                context: context,
                scope: .firstCharacter,
                preserveLeadingCapitalization: false
            ),
            "  Hello"
        )
        XCTAssertEqual(
            TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
                in: "  Hello",
                context: context,
                scope: .firstLetterAfterLeadingWhitespace,
                preserveLeadingCapitalization: false
            ),
            "  hello"
        )
    }

    func testSpacingPreservesExistingDelimiterAndPunctuationBehavior() {
        XCTAssertEqual(applySpacing(to: "there", after: "o"), " there")
        XCTAssertEqual(applySpacing(to: "there", after: "."), " there")
        XCTAssertEqual(applySpacing(to: ".", after: "o"), ".")
        XCTAssertEqual(applySpacing(to: "there", after: " "), "there")
        XCTAssertEqual(applySpacing(to: "there", after: "("), "there")
    }

    private func normalize(
        _ text: String,
        context: TextCompositionContext
    ) -> String {
        TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
            in: text,
            context: context,
            scope: .firstCharacter,
            preserveLeadingCapitalization: false
        )
    }

    private func applySpacing(to text: String, after previousCharacter: Character) -> String {
        TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
            to: text,
            previousCharacter: previousCharacter
        )
    }
}
