import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testFormatsStandaloneFourDigitQuantitiesBelowTenThousand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "5600 2000 4000 9300 2100",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "5,600 2,000 4,000 9,300 2,100")
    }

    func testFormatsFourDigitQuantitiesInSentenceWhilePreservingYearReferences() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I shipped 5600 units in 2025 and 9300 units in 2026",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I shipped 5,600 units in 2025 and 9,300 units in 2026.")
    }

    func testPreservesYearModifiersWhileFormattingFourDigitQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The 2025 roadmap replaced the 2026 plan after 2100 tickets came in",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The 2025 roadmap replaced the 2026 plan after 2,100 tickets came in.")
    }

    func testFormatsPartitiveFourDigitQuantitiesWithoutTreatingThemAsYears() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Can you give me about 2000 of them? I need 1000 of them.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Can you give me about 2,000 of them? I need 1,000 of them.")
    }

    func testPreservesYearAfterPartitivePrepositionWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I spent most of 2020 by myself.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I spent most of 2020 by myself.")
    }

    func testPreservesYearInQuestionBeforeTerminalPrepositionalPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Did you spend 2020 by yourself?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Did you spend 2020 by yourself?")
    }

    func testPreservesYearReferenceBeforeConfirmationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Yeah, that came out in 2001, right?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yeah, that came out in 2001, right?")
    }

    func testPreservesYearAfterSimplePrepositionWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I met her in 2015.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I met her in 2015.")
    }

    func testPreservesSpokenSinceYearWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Yo, I haven't seen her since two thousand twelve.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yo, I haven't seen her since 2012.")
    }

    func testPreservesSpokenSinceLikeYearWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I haven't seen her since like two thousand twelve.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I haven't seen her since like 2012.")
    }

    func testPreservesSentenceFinalYearAfterAdjectiveModifier() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I haven't done that since at least 2012.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I haven't done that since at least 2012.")
    }

    func testPreservesYearAfterLikeAndAtLeastWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Since like at least 2005.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Since like at least 2005.")
    }

    func testPreservesYearAfterSinceLikeAndAtLeastWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I haven't been there since like at least 2018.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I haven't been there since like at least 2018.")
    }

    func testPreservesCoordinatedYearsAfterFromWithoutGroupingSeparators() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "And I'm going to have Facebook data from 2008 as well as X data from 2011 combined in this.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "And I'm going to have Facebook data from 2008 as well as X data from 2011 combined in this."
        )
    }

    func testPreservesCoordinatedYearsBeforeSentenceFinalLocationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "And I'm going to have Facebook data from 2008 as well as X data from 2011 in this.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "And I'm going to have Facebook data from 2008 as well as X data from 2011 in this."
        )
    }

    func testPreservesYearReferencesBeforeTerminalQualifiersAcrossNumericPaths() {
        let processor = TranscriptionPostProcessor()
        let samples = [
            ("Do you think that happened in 2012 maybe?", "Do you think that happened in 2012 maybe?"),
            ("That happened in at least 2015, right?", "That happened in at least 2015, right?"),
            ("Do you think that happened in two thousand twelve maybe?", "Do you think that happened in 2012 maybe?"),
            ("That happened in at least two thousand fifteen, right?", "That happened in at least 2015, right?"),
            ("I bought tickets in maybe 2015, right?", "I bought tickets in maybe 2015, right?"),
            ("I bought tickets in maybe two thousand fifteen, right?", "I bought tickets in maybe 2015, right?"),
        ]

        for (input, expected) in samples {
            let output = processor.process(
                input,
                dictionaryEntries: [],
                renderMode: .singleLineInline
            )

            XCTAssertEqual(output, expected)
        }
    }

    func testFormatsSentenceFinalDigitQuantitiesAfterAdjectiveModifiers() {
        let processor = TranscriptionPostProcessor()
        let samples = [
            "I need at least 2000.",
            "I need the last 2000.",
        ]

        for sample in samples {
            let output = processor.process(
                sample,
                dictionaryEntries: [],
                renderMode: .singleLineInline
            )

            XCTAssertEqual(output, sample.replacingOccurrences(of: "2000", with: "2,000"))
        }
    }

    func testFormatsSentenceFinalSpokenQuantitiesAfterAdjectiveModifiers() {
        let processor = TranscriptionPostProcessor()
        let samples = [
            "I need at least two thousand.",
            "I need the last two thousand.",
        ]

        for sample in samples {
            let output = processor.process(
                sample,
                dictionaryEntries: [],
                renderMode: .singleLineInline
            )

            XCTAssertEqual(output, sample.replacingOccurrences(of: "two thousand", with: "2,000"))
        }
    }

    func testPreservesSpokenYearBeforeConfirmationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm pretty sure that movie came out in two thousand twelve. What do you think?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I'm pretty sure that movie came out in 2012. What do you think?")
    }

    func testPreservesAdjacentSpokenYearsWithoutGroupingSeparators() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The audit started in two thousand eighteen and wrapped up in two thousand nineteen.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The audit started in 2018 and wrapped up in 2019.")
    }

    func testFormatsQuantityBeforeConfirmationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need 1000, right?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I need 1,000, right?")
    }

    func testFormatsQuantityBeforeImmediateTimeQualifier() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I have about 2000 right now.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I have about 2,000 right now.")
    }

    func testPreservesPinNumberWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "My pin number is 5786.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "My pin number is 5786.")
    }

    func testPreservesExplicitYearBeyondCommonRangeWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Somebody's going to leave me a one star review in the year 3000 and I'm gonna roll in my fucking grave.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "Somebody's going to leave me a one star review in the year 3000 and I'm gonna roll in my fucking grave."
        )
    }

    func testFormatsUnqualifiedQuantityBeyondCommonYearRange() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I love you 3000",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I love you 3,000.")
    }

    func testFormatsNounBasedCountQuantityBeyondCommonYearRange() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The count 5786 is too high.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The count 5,786 is too high.")
    }

    func testFormatsTotalNumberQuantityBeyondCommonYearRange() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The total number 5786 is too high.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The total number 5,786 is too high.")
    }

    func testPreservesYearsQuantitiesAndPinNumberAcrossLongNumericGauntlet() {
        let processor = TranscriptionPostProcessor()
        let input = "I started collecting Ninja Turtle Action figures in 2018 and I thought it was pretty cool, but I never knew that I would have over 2000 of them by 2026. It's just crazy because if you think about it, I was born about 1985 and I wanted to get everything as a child growing up. I had about 1000 action figures and about 3500 more that looked like tiny little turtles. So it just goes to show you that by 2017 I was thoroughly into the hobby. Oh, by the way, I love you, 3000, but if you want to see how much money I've made from selling my Ninja Turtles, my pin number is 5786. Look at how much money is in there. Check it around the year 3000."
        let expected = "I started collecting Ninja Turtle Action figures in 2018 and I thought it was pretty cool, but I never knew that I would have over 2,000 of them by 2026. It's just crazy because if you think about it, I was born about 1985 and I wanted to get everything as a child growing up. I had about 1,000 action figures and about 3,500 more that looked like tiny little turtles. So it just goes to show you that by 2017 I was thoroughly into the hobby. Oh, by the way, I love you, 3,000, but if you want to see how much money I've made from selling my Ninja Turtles, my pin number is 5786. Look at how much money is in there. Check it around the year 3000."

        let output = processor.process(
            input,
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, expected)
    }

    func testFormatsSpokenQuantityWithYearLikeValueWhenContextIsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need two thousand twelve tickets and one thousand five labels.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I need 2,012 tickets and 1,005 labels.")
    }

    func testFormatsSpokenQuantityAfterFillerLikeWhenContextIsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need like two thousand twelve tickets.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I need like 2,012 tickets.")
    }

    func testPreservesSpokenYearWhileFormattingNearbySpokenQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I haven't seen her since two thousand twelve, but I still need five thousand tickets.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I haven't seen her since 2012, but I still need 5,000 tickets.")
    }

    func testPreservesUncertainSentenceFinalYearReference() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I can't remember when that was. I think it was maybe 1993.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I can't remember when that was. I think it was maybe 1993.")
    }

    func testPreservesYearFirstSlashedDatesWhileFormattingQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The deadline is 2026/02/19 and we shipped 5600 units.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The deadline is 2026/02/19 and we shipped 5,600 units.")
    }

    func testFormatsQuantityLikePluralNounPhrasesAtSentenceStartAndAfterDeterminer() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2000 units shipped yesterday. The 2000 units were backordered.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "2,000 units shipped yesterday. The 2,000 units were backordered."
        )
    }

    func testDoesNotGroupLocalPhoneNumberTailAfterHyphenSpacing() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "555-1234",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "555-1234")
    }

    func testPreservesMonthLedDatesAfterDateNormalization() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "May 15, 1992 and 5000 units.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "May 15, 1992 and 5,000 units.")
    }

    func testPreservesMonthYearReferencesWhileFormattingFourDigitQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "November 2025 had 5000 signups.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "November 2025 had 5,000 signups.")
    }

    func testPreservesFourDigitAddressNumbersWithoutGroupingSeparators() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Meet me at 1152 North Washington Street. Drop it at 1925 South Franklin Boulevard.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "Meet me at 1152 North Washington Street. Drop it at 1925 South Franklin Boulevard."
        )
    }

    func testPreservesAddressNumbersWhileFormattingNearbyQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Send 5600 flyers to 1034 West General Street by 3:30.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Send 5,600 flyers to 1034 West General Street by 3:30.")
    }

    func testNormalizesStandaloneSpokenThousandsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Five thousand seven hundred and ninety one.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "5,791")
    }

    func testNormalizesSpokenThousandsAndHundredsWithoutTriggeringListFormatting() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand seventy one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071")
    }

    func testNormalizesSpokenThousandsWithConjunctionAndTeenTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand and seventy one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071")
    }

    func testNormalizesSpokenThousandsWithConjunctionAndUnitTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand and seventy two.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,072")
    }

    func testNormalizesLowercasedSpokenThousandsWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "three thousand seventy one",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071")
    }

    func testNormalizesSpokenThousandsWithFiftyOneTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Five thousand fifty one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "5,051")
    }

    func testNormalizesSpokenHundredsOverOneThousand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Thirty five hundred.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "3,500")
    }

    func testNormalizesSpokenThousandWithAndRemainder() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "One thousand and five.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "1,005")
    }

    func testNormalizesSpokenThousandsInsideSentenceWithoutTouchingDates() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need five thousand tickets by May 15, 1992 and three thousand seventy one units after that.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "I need 5,000 tickets by May 15, 1992 and 3,071 units after that."
        )
    }
}
