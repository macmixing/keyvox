import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class TranscriptionPostProcessorTests: XCTestCase {
    func testAppliesDictionaryCasingBeforeListFormatting() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "Cueboard"),
        ]

        let output = processor.process(
            "Okay one cueboard two cueboard",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertTrue(output.contains("1. Cueboard"))
        XCTAssertTrue(output.contains("2. Cueboard"))
    }

    func testListFormattingDisabledKeepsProseAndOtherNormalizations() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "Cueboard")]

        let output = processor.process(
            "Need to do this one cue board two cue board ha ha 415 pm",
            dictionaryEntries: entries,
            renderMode: .multiline,
            listFormattingEnabled: false
        )

        XCTAssertEqual(output, "Need to do this one Cueboard two Cueboard haha 4:15 PM.")
    }

    func testListFormattingEnabledStillFormatsWhenExplicitlyTrue() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "Cueboard")]

        let output = processor.process(
            "Need to do this one cue board two cue board",
            dictionaryEntries: entries,
            renderMode: .multiline,
            listFormattingEnabled: true
        )

        XCTAssertTrue(output.contains("1. Cueboard"))
        XCTAssertTrue(output.contains("2. Cueboard"))
    }

    func testCollapsesExcessiveLaughterSpamRuns() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "haha haha haha haha haha haha haha haha haha haha ha",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Haha haha haha haha")
    }

    func testPreservesShortLaughterRunsWithoutSpamCollapse() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "haha haha haha",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Haha haha haha")
    }

    func testExpandsHahaHaTripletShorthand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "haha ha",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Ha ha ha")
    }

    func testSingleLineModeCollapsesWhitespace() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hello     world",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Hello world")
    }

    func testMultilineModePreservesSingleParagraphBreak() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\nSecond paragraph.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.")
    }

    func testMultilineModeCollapsesExtraBlankLines() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\n\n\nSecond paragraph.\n\n\nThird paragraph.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
    }

    func testMultilineModeTrimsLeadingAndTrailingBlankLines() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "\n\nFirst paragraph.\n\nSecond paragraph.\n\n",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.")
    }

    func testSingleLineModeFlattensParagraphBreaks() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\nSecond paragraph.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "First paragraph. Second paragraph.")
    }

    func testEmptyInputReturnsEmpty() {
        let processor = TranscriptionPostProcessor()
        let output = processor.process("", dictionaryEntries: [], renderMode: .multiline)
        XCTAssertTrue(output.isEmpty)
    }

    func testNormalizesCompactAndDottedTimesWithMeridiem() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "315 a.m. 317AM 4.19pm",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "3:15 AM 3:17 AM 4:19 PM")
    }

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

    func testDoesNotFormatQuestionWithStepNumberAsListWhenTwoIsTranscribedAsDigit() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Where did you say 2. pause in step 3. where you talked about it?",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Where did you say 2. pause in step 3. where you talked about it?")
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

    func testPreservesDaypartPhrasingWhileFixingTimeShape() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I got there at 418 in the morning and left at 4.19 in the evening",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I got there at 4:18 in the morning and left at 4:19 in the evening")
    }

    func testAddsPeriodWhenSentenceEndsWithFormattedTime() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Go ahead and send me an email next week at 2:35 PM",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Go ahead and send me an email next week at 2:35 PM.")
    }

    func testCapitalizesLowercaseWordAfterSentenceBoundaryPunctuation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Can you send me the notes? and then follow up tomorrow! then cc the team.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Can you send me the notes? And then follow up tomorrow! Then cc the team.")
    }

    func testCapitalizesAndAfterPeriodInUserPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think you're so cool. and honestly, I wish I could be like you.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I think you're so cool. And honestly, I wish I could be like you.")
    }

    func testCapitalizesAndAfterPeriodInFollowUpUserPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think you're so cool. and honestly, we should hang out.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I think you're so cool. And honestly, we should hang out.")
    }

    func testCapitalizesLeadingAndAtChunkStart() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "and honestly, we should hang out.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "And honestly, we should hang out.")
    }

    func testCapitalizesAndAfterPeriodWhenRestartHasNoSpace() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think you're so cool.and honestly, I wish I could be like you.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I think you're so cool. And honestly, I wish I could be like you.")
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

    func testPreservesDaypartPhrasingForHyphenSeparatedTimes() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think maybe 3-15 in the evening?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I think maybe 3:15 in the evening?")
    }

    func testNormalizesTerminalAndAsFuzzyAm() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "415-AND. 315 and",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "4:15 AM. 3:15 AM")
    }

    func testDoesNotTreatConjunctionAndAsMeridiem() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I said 415 and 530 in the afternoon",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I said 415 and 5:30 in the afternoon")
    }

    func testNormalizesHaHaToHaha() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Ha ha that was funny",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Haha that was funny")
    }

    func testKeepsBetweenColonPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Let's pick between colon McDonalds or Burger King",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Let's pick between colon McDonalds or Burger King")
    }

    func testKeepsBetweenColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Let's pick between Colin McDonalds or Burger King",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Let's pick between Colin McDonalds or Burger King")
    }

    func testKeepsCommaDelimitedColonPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, colon, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, colon, to buy some groceries.")
    }

    func testKeepsCommaDelimitedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, Colin, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, Colin, to buy some groceries.")
    }

    func testKeepsStandaloneColonWordWithoutContext() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The word colon appears here",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "The word colon appears here")
    }

    func testKeepsTerminalCommaDelimitedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Next task, Colin.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Next task, Colin.")
    }

    func testDoesNotRewriteSingleWordGreetingColin() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hi, Colin.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Hi, Colin.")
    }

    func testNormalizesHoleInOneIdiom() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I was golfing last week and I got a hole in one because there were opponents ahead of me",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output == "I was golfing last week and I got a hole-in-one because there were opponents ahead of me")
    }

    func testStillFormatsRealListsWhenUsingInOneInTwoPattern() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I want to summarize this in one first item in two second item",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output.contains("1. First item"))
        XCTAssertTrue(output.contains("2. Second item"))
    }

    func testHoleInOneWithTwoInProseDoesNotTriggerListFormatting() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I was golfing last week and I got a hole in one because there were two opponents ahead of me",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output == "I was golfing last week and I got a hole-in-one because there were two opponents ahead of me")
        XCTAssertFalse(output.contains("\n1. "))
        XCTAssertFalse(output.contains("\n2. "))
    }
}
