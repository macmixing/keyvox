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
            TextCompositionContext(precedingText: "  \t"),
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

    func testPunctuationAndSymbolsOnlyPreserveCapitalizationAfterTerminalPunctuation() {
        for delimiter in [
            Character("("),
            Character("["),
            Character("{"),
            Character("/"),
            Character("\\"),
            Character("<"),
            Character(">"),
            Character("&"),
            Character("$"),
            Character("#")
        ] {
            let continuationContext = TextCompositionContext(
                precedingText: "Existing text\(delimiter)"
            )
            XCTAssertFalse(TextCompositionPolicy.isSentenceStart(in: continuationContext))
            XCTAssertEqual(
                normalize("This is new.", context: continuationContext),
                "this is new."
            )

            let sentenceStartContext = TextCompositionContext(
                precedingText: "Existing text.\(delimiter)"
            )
            XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: sentenceStartContext))
            XCTAssertEqual(
                normalize("This is new.", context: sentenceStartContext),
                "This is new."
            )

            let trailingWhitespaceSentenceStartContext = TextCompositionContext(
                precedingText: "Existing text.\(delimiter)  "
            )
            XCTAssertTrue(
                TextCompositionPolicy.isSentenceStart(in: trailingWhitespaceSentenceStartContext)
            )
            XCTAssertEqual(
                normalize("This is new.", context: trailingWhitespaceSentenceStartContext),
                "This is new."
            )

            let documentStartContext = TextCompositionContext(
                precedingText: String(delimiter)
            )
            XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: documentStartContext))
            XCTAssertEqual(
                normalize("This is new.", context: documentStartContext),
                "This is new."
            )

            let trailingWhitespaceDocumentStartContext = TextCompositionContext(
                precedingText: "\(delimiter)  "
            )
            XCTAssertTrue(
                TextCompositionPolicy.isSentenceStart(in: trailingWhitespaceDocumentStartContext)
            )
            XCTAssertEqual(
                normalize("This is new.", context: trailingWhitespaceDocumentStartContext),
                "This is new."
            )
        }
    }

    func testColonPreservesIncomingCapitalization() {
        for precedingText in ["Existing text:", "Existing text:  "] {
            let context = TextCompositionContext(precedingText: precedingText)

            XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: context))
            XCTAssertEqual(normalize("This is new.", context: context), "This is new.")
        }
    }

    func testNumberedHyphenPreservesIncomingCapitalization() {
        for precedingText in ["5 - ", "12-", "5 - - ", "12--- "] {
            let context = TextCompositionContext(precedingText: precedingText)

            XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: context))
            XCTAssertEqual(normalize("This is cool.", context: context), "This is cool.")
        }
    }

    func testHyphenAfterTextContinuesLowercase() {
        let context = TextCompositionContext(precedingText: "Existing text - - ")

        XCTAssertFalse(TextCompositionPolicy.isSentenceStart(in: context))
        XCTAssertEqual(normalize("This is new.", context: context), "this is new.")
    }

    func testEmojiAtDocumentOrLineStartPreservesIncomingCapitalization() {
        for precedingText in ["😎 ", "Hello.\n😎 "] {
            let context = TextCompositionContext(precedingText: precedingText)

            XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: context))
            XCTAssertEqual(normalize("Hey there.", context: context), "Hey there.")
        }
    }

    func testEmojiAfterTerminalPunctuationPreservesIncomingCapitalization() {
        let context = TextCompositionContext(precedingText: "Hello. 😎 ")

        XCTAssertTrue(TextCompositionPolicy.isSentenceStart(in: context))
        XCTAssertEqual(normalize("Hey there.", context: context), "Hey there.")
    }

    func testEmojiAfterLowercaseTextContinuesLowercase() {
        let context = TextCompositionContext(precedingText: "hello 😎 ")

        XCTAssertFalse(TextCompositionPolicy.isSentenceStart(in: context))
        XCTAssertEqual(normalize("Hey there.", context: context), "hey there.")
    }

    func testEmojiContextProducesCapitalizedSpacedPayload() {
        let context = TextCompositionContext(precedingText: "😎")
        let capitalized = normalize("Hey there.", context: context)

        XCTAssertEqual(
            TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                to: capitalized,
                context: context
            ),
            " Hey there."
        )
    }

    func testEmojiVariationSelectorContextPreservesCapitalizationAndSpacing() {
        let context = TextCompositionContext(precedingText: "©️ ")

        XCTAssertEqual(context.previousNonWhitespaceCharacter, "©️")
        XCTAssertEqual(normalize("Hey there.", context: context), "Hey there.")

        XCTAssertEqual(
            TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                to: "Hey there.",
                previousCharacter: context.previousNonWhitespaceCharacter!
            ),
            " Hey there."
        )

        let noTrailingSpaceContext = TextCompositionContext(precedingText: "©️")
        XCTAssertEqual(
            TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                to: "Hey there.",
                context: noTrailingSpaceContext
            ),
            " Hey there."
        )
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

    func testDateCapitalizationPreservesCanonicalLeadingCalendarName() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM d, yyyy"

        let components = DateComponents(
            calendar: formatter.calendar,
            timeZone: formatter.timeZone,
            year: 2025,
            month: 3,
            day: 15
        )
        let date = try XCTUnwrap(components.date)
        let dateText = formatter.string(from: date)
        let capitalizationIndex = try XCTUnwrap(dateText.indices.first)

        XCTAssertTrue(
            LeadingDateCapitalizationPolicy.shouldPreserveCapitalization(
                in: dateText,
                startingAt: capitalizationIndex,
                locale: formatter.locale
            )
        )
    }

    func testDateCapitalizationPreservesStandaloneMonthName() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        let month = try XCTUnwrap(formatter.monthSymbols.first)
        let text = month + " was memorable."
        let capitalizationIndex = try XCTUnwrap(text.indices.first)

        XCTAssertTrue(
            LeadingDateCapitalizationPolicy.shouldPreserveCapitalization(
                in: text,
                startingAt: capitalizationIndex,
                locale: locale
            )
        )
    }

    func testDateCapitalizationDoesNotPreserveLocalizedRelativeDateLabel() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true

        let now = Date()
        for dayOffset in -1...1 {
            let date = try XCTUnwrap(
                formatter.calendar.date(byAdding: .day, value: dayOffset, to: now)
            )
            let dateText = formatter.string(from: date)
            let capitalizationIndex = try XCTUnwrap(dateText.firstIndex(where: \.isLetter))

            XCTAssertFalse(
                LeadingDateCapitalizationPolicy.shouldPreserveCapitalization(
                    in: dateText,
                    startingAt: capitalizationIndex,
                    locale: locale
                )
            )
        }
    }

    func testDateCapitalizationPreservesLocalizedWeekdayAtStartOfLongerText() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .full

        let components = DateComponents(
            calendar: formatter.calendar,
            timeZone: formatter.timeZone,
            year: 2025,
            month: 3,
            day: 15
        )
        let date = try XCTUnwrap(components.date)
        let dateText = formatter.string(from: date)
        let capitalizationIndex = try XCTUnwrap(dateText.indices.first)

        XCTAssertTrue(
            LeadingDateCapitalizationPolicy.shouldPreserveCapitalization(
                in: dateText,
                startingAt: capitalizationIndex,
                locale: locale
            )
        )
    }

    func testDateCapitalizationPreservesCalendarNameBeforeSpelledOutNumber() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        let month = try XCTUnwrap(dateFormatter.monthSymbols.first)

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .spellOut
        let spokenNumber = try XCTUnwrap(numberFormatter.string(from: 25))

        let dateText = month + " " + spokenNumber
        let capitalizationIndex = try XCTUnwrap(dateText.indices.first)

        XCTAssertTrue(
            LeadingDateCapitalizationPolicy.shouldPreserveCapitalization(
                in: dateText,
                startingAt: capitalizationIndex,
                locale: locale
            )
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
        XCTAssertEqual(applySpacing(to: "there", after: "&"), " there")
        XCTAssertEqual(applySpacing(to: "there", after: "😎"), " there")
        XCTAssertEqual(applySpacing(to: ".", after: "o"), ".")
        XCTAssertEqual(applySpacing(to: "there", after: " "), "there")
        XCTAssertEqual(applySpacing(to: "there", after: "("), "there")
    }

    func testHyphenInsertsSingleLeadingSpace() {
        XCTAssertEqual(applySpacing(to: "there", after: "-"), " there")
        XCTAssertEqual(applySpacing(to: " there", after: "-"), " there")
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
