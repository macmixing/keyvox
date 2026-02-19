import Foundation
import XCTest
@testable import KeyVox

@MainActor
extension TranscriptionPostProcessorTests {
    func testNormalizesSpokenEmailAddressToLowercaseLiteral() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "kathy@example.com")]

        let output = processor.process(
            "Kathy at example.com",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "kathy@example.com")
    }
    func testNormalizesSpokenEmailAndRespectsDictionaryMatch() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "dom@example.com")]

        let output = processor.process(
            "Dom at example.com",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "dom@example.com")
    }
    func testNormalizesStandaloneUrlLikeUtteranceToDictionaryEmail() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "dom.esposito@example.net")]

        let output = processor.process(
            "www. Domesposito. Net",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "dom.esposito@example.net")
    }
    func testStripsTerminalPunctuationForStandaloneLiteralEmailUtterance() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "dom@example.com")]

        let output = processor.process(
            "dom@example.com.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "dom@example.com")
    }
    func testStripsTerminalPunctuationForStandaloneWebsiteUtterance() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "www.example.com.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "www.example.com")
    }
    func testNormalizesSpokenEmailInsideSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "kathy@example.com")]

        let output = processor.process(
            "Yeah, my name is Dom Esposito and my email address is kathy at example.com.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yeah, my name is Dom Esposito and my email address is kathy@example.com.")
    }
    func testNormalizesCompactSpokenEmailAndAppliesDictionaryLikelyMatch() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "anthony@example.com")]

        let output = processor.process(
            "Yeah, my name is Dom Esposito and my email address is anthonyatexample.com.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yeah, my name is Dom Esposito and my email address is anthony@example.com.")
    }
    func testNormalizesSpokenEmailInsideSentenceWithMixedCasingDomain() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "dom@example.com")]

        let output = processor.process(
            "Yeah, my name is Dom Esposito and my email address is Dom at example.com.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yeah, my name is Dom Esposito and my email address is dom@example.com.")
    }
    func testNormalizesMultipleEmailAddressesInSingleSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            "You can reach me at Dom at example.com or kathy@example.com, either of those are fine.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "You can reach me at dom@example.com or kathy@example.com, either of those are fine.")
    }
    func testNormalizesTwoSpokenEmailAddressesInSingleSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            "You can reach me at Dom at example.com or kathy at example.com, either of those are fine.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "You can reach me at dom@example.com or kathy@example.com, either of those are fine.")
    }
    func testPreservesLiteralEmailWithDotLocalPartWithoutInjectedSpace() {
        let processor = TranscriptionPostProcessor()
        let email = "dom.esposito@example.com"
        let entries = [DictionaryEntry(phrase: email)]

        let output = processor.process(
            "My email is \(email).",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "My email is \(email).")
    }
    func testNormalizesSpokenEmailAddressesInsideNumberedList() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            """
            I have a couple of email addresses. I'll give them to you:

            1. Dom at example.com
            2. Kathy at example.com
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I have a couple of email addresses. I'll give them to you:

            1. dom@example.com
            2. kathy@example.com
            """
        )
    }
    func testNormalizesSpokenEmailAddressesInsideNumberedListWithTrailingParagraph() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            """
            I have a couple of email addresses. Let me give them to you:

            1. Dom at example.com
            2. Kathy at example.com

            You can reach out to me anytime next week. That would be fine.
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I have a couple of email addresses. Let me give them to you:

            1. dom@example.com
            2. kathy@example.com

            You can reach out to me anytime next week. That would be fine.
            """
        )
    }
    
    func testNormalizesSpokenEmailAddressesInsideNumberedListWithTrailingParagraphUserPhrase() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            """
            I have a couple of email addresses. Let me give them to you:

            1. Dom at example.com
            2. Kathy at example.com

            You can reach me anytime. That would be fine.
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I have a couple of email addresses. Let me give them to you:

            1. dom@example.com
            2. kathy@example.com

            You can reach me anytime. That would be fine.
            """
        )
    }
    func testNormalizesSpokenEmailsWhenNumberedMarkersHaveNoPostMarkerSpace() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            """
            I have a couple of email addresses. Let me give them to you:

            1.Dom at example.com
            2.Kathy at example.com

            You can reach me anytime. That would be fine.
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I have a couple of email addresses. Let me give them to you:

            1. dom@example.com
            2. kathy@example.com

            You can reach me anytime. That would be fine.
            """
        )
    }
    func testNormalizesSpokenEmailAddressesInsideNumberedListWithCommaTrailingSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            """
            I have a couple of email addresses, let me give them to you:

            1. Dom at example.com
            2. Kathy at example.com

            You can reach out to me anytime, that would be fine.
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I have a couple of email addresses, let me give them to you:

            1. dom@example.com
            2. kathy@example.com

            You can reach out to me anytime, that would be fine.
            """
        )
    }
    func testNormalizesSpokenEmailAddressesWithOhYeahLeadInAndTrailingSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            "I forgot to give you my email addresses. What are they? Oh yeah, one, dom at example.com. Two, kathy at example.com. Be sure to hit me up next week around Thursday.",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I forgot to give you my email addresses. What are they? Oh yeah:

            1. dom@example.com
            2. kathy@example.com

            Be sure to hit me up next week around Thursday.
            """
        )
    }
    func testFormatsLongEmailListWhenSecondMarkerUsesToHomophone() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.net"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            "Okay, so I wanted to talk to you about a couple of things and make sure that we were on the same page because I know you talked to someone the other day and he told me that you wanted to send me an email. So if you do, here's how you can reach me. I have a play if you know, there's a couple of places you could reach me at one dom at example.net to kathy at example.com. You can reach out anytime next week, maybe around 4:15 PM I don't know, in New York, something like that. Just let me know.",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            Okay, so I wanted to talk to you about a couple of things and make sure that we were on the same page because I know you talked to someone the other day and he told me that you wanted to send me an email. So if you do, here's how you can reach me. I have a play if you know, there's a couple of places you could reach me at:

            1. dom@example.net
            2. kathy@example.com

            You can reach out anytime next week, maybe around 4:15 PM I don't know, in New York, something like that. Just let me know.
            """
        )
    }
    func testNormalizesCompactEmailWithNearMatchDomainInsideNumberedList() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.net"),
            DictionaryEntry(phrase: "contact@sample.org"),
        ]

        let output = processor.process(
            """
            Okay, so I wanted to talk to you real quick because I heard you were having some issues and I wanted to make sure everything was going okay. If you want to reach out to me, you can do so here.

            And don't forget that I have an email address, both of them actually:

            1. Domatexampel.net
            2. contact@sample.org

            You can reach out to me like next Thursday, maybe 2:30 PM if that works good for you.
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            Okay, so I wanted to talk to you real quick because I heard you were having some issues and I wanted to make sure everything was going okay. If you want to reach out to me, you can do so here.

            And don't forget that I have an email address, both of them actually:

            1. dom@example.net
            2. contact@sample.org

            You can reach out to me like next Thursday, maybe 2:30 PM if that works good for you.
            """
        )
    }
    func testSplitsTrailingSentenceAfterLiteralEmailListItemWithoutPunctuation() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ]

        let output = processor.process(
            """
            I forgot to give you my email addresses. What are they? Oh yeah:

            1. dom@example.com
            2. kathy@example.com Be sure to hit me up next week around Thursday
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I forgot to give you my email addresses. What are they? Oh yeah:

            1. dom@example.com
            2. kathy@example.com

            Be sure to hit me up next week around Thursday
            """
        )
    }
    func testSplitsTrailingSentenceAfterLiteralEmailListItemWithCommaContinuation() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
            DictionaryEntry(phrase: "anthony@example.com"),
        ]

        let output = processor.process(
            """
            I need to give you some email addresses so you can reach out to me at a later time:

            1. dom@example.com
            2. kathy@example.com
            3. anthony@example.com, be sure to reach out to me next week.
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            I need to give you some email addresses so you can reach out to me at a later time:

            1. dom@example.com
            2. kathy@example.com
            3. anthony@example.com

            Be sure to reach out to me next week.
            """
        )
    }
    func testEmailListTrailingSplitWithDictionaryNoiseDeterministic() {
        let processor = TranscriptionPostProcessor()
        let firstEmail = "dom@example.com"
        let secondEmail = "kathy@example.com"
        let entries = [
            DictionaryEntry(phrase: firstEmail),
            DictionaryEntry(phrase: secondEmail),
            DictionaryEntry(phrase: "anthony@example.com"),
            DictionaryEntry(phrase: "contact@example.org"),
            DictionaryEntry(phrase: "support@example.com"),
            DictionaryEntry(phrase: "NorthBridge Systems"),
            DictionaryEntry(phrase: "ClearPath Labs"),
            DictionaryEntry(phrase: "SummitField Cloud"),
        ]

        let output = processor.process(
            """
            I forgot to give you my email addresses. What are they? Oh yeah:

            1. \(firstEmail)
            2. \(secondEmail) Be sure to hit me up next week around Thursday
            """,
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        let expected = """
        I forgot to give you my email addresses. What are they? Oh yeah:

        1. \(firstEmail)
        2. \(secondEmail)

        Be sure to hit me up next week around Thursday
        """

        XCTAssertEqual(output, expected)
    }
    func testAddsSpacingAndCapitalizationAfterCollapsedEmailSentenceBoundary() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "kathy@example.com")]

        let output = processor.process(
            "Oh yeah, itskathy@example.com.you can email me there.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Oh yeah, its kathy@example.com. You can email me there.")
    }
    func testDoesNotAttachLeadingWordsToEmailAndFixesFollowingSentenceBoundary() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Oh yeah, itsuh...dom@example.com.that's my email address.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Oh yeah, itsuh... dom@example.com. That's my email address.")
    }
    func testSeparatesCollapsedPrefixFromKnownDictionaryEmail() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "kathy@example.com")]

        let output = processor.process(
            "Oh yeah, myemailaddressiskathy@example.com.you can email me there.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Oh yeah, myemailaddressis kathy@example.com. You can email me there.")
    }
    func testCapitalizesLowercaseTextStartAndAfterBlankLineInEmailSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "zackmorbi@rider.com")]

        let output = processor.process(
            "please contact me at zackmorbi@rider.com, please.\n\ncontact me at zackmorbi@rider.com, please.",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            "Please contact me at zackmorbi@rider.com, please.\n\nContact me at zackmorbi@rider.com, please."
        )
    }
    func testDoesNotCapitalizeLowercaseEmailAtLineStart() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "dom@example.com")]

        let output = processor.process(
            "Reach me here:\ndom@example.com",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Reach me here:\ndom@example.com")
    }
    func testDoesNotCapitalizeLowercaseWebsiteAtLineStart() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Use this site:\nwww.example.com",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Use this site:\nwww.example.com")
    }

    func testFormatsAttachedNumericDomainMarkersAsList() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "1google.com, 2example.com",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            1. google.com
            2. example.com
            """
        )
    }

    func testLowercasesDomainItemsInExplicitNumberedList() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            """
            1. Google.com
            2. Example.com
            3. KeyVox.app
            """,
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            1. google.com
            2. example.com
            3. keyvox.app
            """
        )
    }

    func testFormatsAttachedWebsiteMarkersUsingToHomophoneAndSpokenThree() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "1google.com, to alien.com, threekeyvox.app.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            1. google.com
            2. alien.com
            3. keyvox.app
            """
        )
    }
}
