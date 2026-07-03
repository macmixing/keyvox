import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class StyleRewriteTests: XCTestCase {
    func testNoneStyleReturnsNoRequest() {
        let request = StyleRewriteDictationConfiguration.request(
            for: .none,
            baseText: "Plain dictation."
        )

        XCTAssertNil(request)
    }

    func testPolishedRequestUsesModelTokenWindow() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note me and Sarah was talking."
        ))

        XCTAssertEqual(request.contextTokenLimit, StyleRewriteDictationConfiguration.modelContextTokenLimit)
        XCTAssertEqual(request.maximumResponseTokens, StyleRewriteDictationConfiguration.modelMaximumGenerationTokenLimit)
        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.polished.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.polishedLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testChillRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.chill.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.casualLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testCasualRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.casual.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.casualLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testStyleModelRewriteEligibility() {
        XCTAssertFalse(StyleRewriteStyle.none.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.polished.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.casual.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.chill.usesModelRewrite)
    }

    func testChillHeuristicFormatsSentenceSeparatorsWithoutEndingPeriod() {
        let output = ChillHeuristicFormatter().format(
            "Hey, this is really crazy. What are you doing tomorrow? I don't even know what I'm doing tonight, but I think this is cool."
        )

        XCTAssertEqual(
            output,
            "hey this is really crazy. what are you doing tomorrow? i dont even know what im doing tonight but i think this is cool"
        )
    }

    func testChillHeuristicKeepsFinalQuestionMark() {
        let output = ChillHeuristicFormatter().format("Hey what's up man?")

        XCTAssertEqual(output, "hey whats up man?")
    }

    func testChillHeuristicDoesNotOwnFillerRemoval() {
        let output = ChillHeuristicFormatter().format("Um hey uh this is cool.")

        XCTAssertEqual(output, "um hey uh this is cool")
    }

    func testChillHeuristicPreservesEmoji() {
        let output = ChillHeuristicFormatter().format(
            "KeyVox runs on-device and skips the subscription nonsense. 🎙️🔒"
        )

        XCTAssertEqual(
            output,
            "keyvox runs on device and skips the subscription nonsense. 🎙️🔒"
        )
    }

    func testChillHeuristicPreservesMathSymbols() {
        let output = ChillHeuristicFormatter().format("2+2=4")

        XCTAssertEqual(output, "2+2=4")
    }

    func testChillHeuristicPreservesNumericHyphens() {
        let output = ChillHeuristicFormatter().format("Call 602-555-0134 on 2026-05-12.")

        XCTAssertEqual(output, "call 602-555-0134 on 2026-05-12")
    }

    func testChillHeuristicPreservesPostProcessedMathSymbols() {
        let output = ChillHeuristicFormatter().format("Keep (2 - 2 = 0), 3^2 = 9, 8 / 2, 5 * 4, and 50%.")

        XCTAssertEqual(output, "keep (2 - 2 = 0) 3^2 = 9 8 / 2 5 * 4 and 50%")
    }

    func testChillHeuristicCollapsesColonBetweenNumbers() {
        let output = ChillHeuristicFormatter().format("Meet at 5:45 and keep the ratio 16:9, but remove this: colon.")

        XCTAssertEqual(output, "meet at 545 and keep the ratio 169 but remove this colon")
    }

    func testChillHeuristicPreservesEmailAddress() {
        let output = ChillHeuristicFormatter().format("dom@example.com")

        XCTAssertEqual(output, "dom@example.com")
    }

    func testChillHeuristicPreservesEmailAddressWithTrailingSentencePunctuation() {
        let output = ChillHeuristicFormatter().format("Email dom@example.com. Then wait.")

        XCTAssertEqual(output, "email dom@example.com. then wait")
    }

    func testChillHeuristicPreservesParagraphBreaks() {
        let output = ChillHeuristicFormatter().format(
            "Hey, this is really crazy.\n\nWhat are you doing tomorrow? I don't even know."
        )

        XCTAssertEqual(
            output,
            "hey this is really crazy\n\nwhat are you doing tomorrow? i dont even know"
        )
    }

    func testChillHeuristicPreservesOrderedListLineBreaks() {
        let output = ChillHeuristicFormatter().format(
            "I need to pick up a couple of things from the store.\n\n1. Apples\n2. Bananas"
        )

        XCTAssertEqual(
            output,
            "i need to pick up a couple of things from the store\n\n1. apples\n2. bananas"
        )
    }

    func testTerminalPunctuationBoundaryRepairRestoresSourceBoundaryExclamation() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "That is wild! Are we shipping this?",
            rewritten: "that is wild. are we shipping this?"
        )

        XCTAssertEqual(output, "that is wild! are we shipping this?")
    }

    func testTerminalPunctuationBoundaryRepairPreservesRewrittenParagraphBreak() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "That is wild! Are we shipping this?",
            rewritten: "that is wild.\n\nare we shipping this?"
        )

        XCTAssertEqual(output, "that is wild!\n\nare we shipping this?")
    }

    func testTerminalPunctuationBoundaryRepairRestoresTerminalSourceExclamation() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "Ship it!",
            rewritten: "ship it"
        )

        XCTAssertEqual(output, "ship it!")
    }

    func testTerminalPunctuationBoundaryRepairRestoresTerminalSourceQuestionExclamationCluster() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "What the hell is wrong with you?!",
            rewritten: "what the hell is wrong with you!"
        )

        XCTAssertEqual(output, "what the hell is wrong with you?!")
    }

    func testTerminalPunctuationBoundaryRepairRestoresTerminalSourceExclamationChangedToQuestion() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "Hey man? Are you okay!",
            rewritten: "Hey man? Are you okay?"
        )

        XCTAssertEqual(output, "Hey man? Are you okay!")
    }

    func testTerminalPunctuationBoundaryRepairDoesNotRestoreWithoutSourceExclamation() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "Ship it.",
            rewritten: "ship it"
        )

        XCTAssertEqual(output, "ship it")
    }

    func testRewriteRepairRemovesCommaLeftByDeletedMiddleTokens() {
        let output = OutputRepair.repairModelOutput(
            original: "Hey, um what are you doing, um tomorrow?",
            rewritten: "Hey, what are you doing, tomorrow?"
        )

        XCTAssertEqual(output, "Hey, what are you doing tomorrow?")
    }

    func testRewriteRepairRestoresSentenceOpeningCommaAroundDeletedTokens() {
        let output = OutputRepair.repairModelOutput(
            original: "Phase three. Yo, um what are you doing?",
            rewritten: "Phase three. Yo what are you doing?"
        )

        XCTAssertEqual(output, "Phase three. Yo, what are you doing?")
    }

    func testRewriteRepairAppliesAPStyleToOrdinaryLowNumbersFromSpokenInput() {
        let output = OutputRepair.repairModelOutput(
            original: "I went there two days ago. She wanted five lobsters for dinner.",
            rewritten: "I went there 2 days ago. She wanted 5 lobsters for dinner."
        )

        XCTAssertEqual(output, "I went there two days ago. She wanted five lobsters for dinner.")
    }

    func testRewriteRepairRestoresTrailingChangedNumberEvidence() {
        let output = OutputRepair.repairModelOutput(
            original: "Okay, now I want you to fix the evidence crop progress bar and then I want you to run a test on test thirty.",
            rewritten: "Okay, now I want you to fix the evidence crop progress bar and then I want you to run a test 3."
        )

        XCTAssertEqual(
            output,
            "Okay, now I want you to fix the evidence crop progress bar and then I want you to run a test on test 30."
        )
    }

    func testRewriteRepairPreservesOrderedListMarkersAroundSpokenLowNumberEvidence() {
        let cases = [
            (
                original: "I was going to pick up one thing today, but let me make a list:\n\none. Apples\n2. Bananas",
                rewritten: "I was going to pick up one thing today, but let me make a list:\n\n1. Apples\n2. Bananas",
                repaired: "I was going to pick up one thing today, but let me make a list:\n\n1. Apples\n2. Bananas"
            ),
            (
                original: "I was going to pick up two things from the store today:\n\n1. Apples\ntwo. Bananas",
                rewritten: "I was going to pick up two things from the store today:\n\n1. Apples\n2. Bananas",
                repaired: "I was going to pick up two things from the store today:\n\n1. Apples\n2. Bananas"
            ),
            (
                original: "I need to pick up one thing from the store. Wait, maybe two:\n\n1. Apples\n2. Bananas\n3. Grapes",
                rewritten: "I need to pick up one thing from the store. Wait, maybe 2:\n\n1. Apples\n2. Bananas\n3. Grapes",
                repaired: "I need to pick up one thing from the store. Wait, maybe two:\n\n1. Apples\n2. Bananas\n3. Grapes"
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairRestoresExplicitWrittenLowNumber() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm just going to leave that as the written two.",
            rewritten: "I'm just going to leave that as the written 2."
        )

        XCTAssertEqual(output, "I'm just going to leave that as the written two.")
    }

    func testRewriteRepairFormatsSpokenDecimalRun() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm shipping version two point zero tomorrow.",
            rewritten: "I'm shipping version two point zero tomorrow."
        )

        XCTAssertEqual(output, "I'm shipping version 2.0 tomorrow.")
    }

    func testRewriteRepairRestoresSpokenDecimalChangedToDifferentNumber() {
        let cases = [
            (
                original: "I swear open AI has made five point five dumber.",
                rewritten: "I swear open AI has made 10 dumber.",
                repaired: "I swear open AI has made 5.5 dumber."
            ),
            (
                original: "That's five point five.",
                rewritten: "That's five.",
                repaired: "That's 5.5."
            ),
            (
                original: "That's five point five.",
                rewritten: "That's 5 point 5.",
                repaired: "That's 5.5."
            ),
            (
                original: "I swear open AI has made five point five dumber.",
                rewritten: "I swear open AI has made 5 points 5 dumber.",
                repaired: "I swear open AI has made 5.5 dumber."
            ),
            (
                original: "five point six",
                rewritten: "5",
                repaired: "5.6"
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairRestoresSpokenDecimalFusedToPrefixToken() {
        let cases = [
            (
                original: "Call me crazy, but I literally posted this the day before GPT five point six was launched.",
                rewritten: "Call me crazy, but I literally posted this the day before GPT56 was launched.",
                repaired: "Call me crazy, but I literally posted this the day before GPT-5.6 was launched."
            ),
            (
                original: "GPT five point six was launched.",
                rewritten: "GPT56 was launched.",
                repaired: "GPT-5.6 was launched."
            ),
            (
                original: "We launched GPT five point six.",
                rewritten: "We launched GPT56.",
                repaired: "We launched GPT-5.6."
            ),
            (
                original: "GPT five point six",
                rewritten: "GPT56",
                repaired: "GPT-5.6"
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairPreservesNumericFractionWidthInSpokenDecimal() {
        let output = OutputRepair.repairModelOutput(
            original: "Version five point 05 shipped.",
            rewritten: "Version 5.5 shipped."
        )

        XCTAssertEqual(output, "Version 5.05 shipped.")
    }

    func testRewriteRepairRestoresDeletedLowNumberEvidence() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, I'll probably meet you two tomorrow.",
            rewritten: "Yeah, I'll probably meet you tomorrow."
        )

        XCTAssertEqual(output, "Yeah, I'll probably meet you two tomorrow.")
    }

    func testRewriteRepairRestoresDeletedListCueFromRawDictationVariant() {
        let cases = [
            (
                original: "I need to pick up one thing from the store. Wait, maybe two. One, apples. Two, bananas.",
                rewritten: "I need to pick up one thing from the store. Wait, maybe 2. Apples. 2, bananas.",
                repaired: "I need to pick up one thing from the store. Wait, maybe two. One, Apples. Two, bananas."
            ),
            (
                original: "I need to pick up one thing from the store. Wait, maybe two. One. Apples. Two. Bananas.",
                rewritten: "I need to pick up one thing from the store. Wait, maybe 2. Apples. 2. Bananas.",
                repaired: "I need to pick up one thing from the store. Wait, maybe two. One. Apples. Two. Bananas."
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairConvertsOrdinaryTenPlusSpokenCounts() {
        let output = OutputRepair.repairModelOutput(
            original: "That guy waited ten days total. Please order twenty two labels.",
            rewritten: "That guy waited ten days total. Please order twenty two labels."
        )

        XCTAssertEqual(output, "That guy waited 10 days total. Please order 22 labels.")
    }

    func testRewriteRepairConvertsConnectorBasedHundredsAsSingleNumber() {
        let cases = [
            (
                original: "That's seven hundred and fifty gigabytes.",
                rewritten: "That's seven hundred and fifty gigabytes.",
                repaired: "That's 750 gigabytes."
            ),
            (
                original: "That's four hundred and seventy five gigabytes.",
                rewritten: "That's four hundred and seventy five gigabytes.",
                repaired: "That's 475 gigabytes."
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairRestoresChangedConnectorBasedHundredsFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "That's seven hundred and fifty gigabytes.",
            rewritten: "That's 705 gigabytes."
        )

        XCTAssertEqual(output, "That's 750 gigabytes.")
    }

    func testRewriteRepairRestoresAPStyleForCollapsedAdjacentRatingNumbers() {
        let output = OutputRepair.repairModelOutput(
            original: "I have like twelve five star ratings right now.",
            rewritten: "I have like 125-star ratings right now."
        )

        XCTAssertEqual(output, "I have like 12 five star ratings right now.")
    }

    func testRewriteRepairPreservesProtectedNumericContexts() {
        let output = OutputRepair.repairModelOutput(
            original: "The meeting starts at two thirty. Tell John it was five dollars and five percent.",
            rewritten: "The meeting starts at 2:30. Tell John it was $5 and 5%."
        )

        XCTAssertEqual(output, "The meeting starts at 2:30. Tell John it was $5 and 5%.")
    }

    func testRewriteRepairRepairsDotSeparatedTimeShape() {
        let output = OutputRepair.repairModelOutput(
            original: "Tell John, uh, like, immediately, it starts at 5.30 and it's 10 bucks.",
            rewritten: "Tell John like immediately, it starts at 5.30 and it's $10."
        )

        XCTAssertEqual(output, "Tell John like immediately, it starts at 5:30 and it's $10.")
    }

    func testRewriteRepairRepairsDotSeparatedPastTimeShape() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, we met at 2.30 yesterday.",
            rewritten: "Yeah, we met at 2.30 yesterday."
        )

        XCTAssertEqual(output, "Yeah, we met at 2:30 yesterday.")
    }

    func testRewriteRepairRepairsDotSeparatedTimeShapeAcrossInterveningWords() {
        let output = OutputRepair.repairModelOutput(
            original: "The concert is gonna start at like um maybe 5.30.",
            rewritten: "The concert is gonna start at like um maybe 5.30."
        )

        XCTAssertEqual(output, "The concert is gonna start at like um maybe 5:30.")
    }

    func testRewriteRepairPreservesVersionNumberDecimalShape() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm shipping version five point thirty tomorrow.",
            rewritten: "I'm shipping version 5.30 tomorrow."
        )

        XCTAssertEqual(output, "I'm shipping version 5.30 tomorrow.")
    }

    func testRewriteRepairPreservesSpokenDecimalBeforePastDate() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm pretty sure we reverted five point five three last Tuesday.",
            rewritten: "I'm pretty sure we reverted 5.53 last Tuesday."
        )

        XCTAssertEqual(output, "I'm pretty sure we reverted 5.53 last Tuesday.")
    }

    func testRewriteRepairRestoresSpokenDecimalChangedToTimeShape() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm pretty sure we reverted five point five three yesterday.",
            rewritten: "I'm pretty sure we reverted 5:53 yesterday."
        )

        XCTAssertEqual(output, "I'm pretty sure we reverted 5.53 yesterday.")
    }

    func testRewriteRepairRestoresChangedNumberEvidenceFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm pretty sure we reverted five point five three yesterday.",
            rewritten: "I'm pretty sure we reverted 5.33 yesterday."
        )

        XCTAssertEqual(output, "I'm pretty sure we reverted 5.53 yesterday.")
    }

    func testRewriteRepairRestoresChangedCompositeNumberEvidenceFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm pretty sure we reverted nine hundred and two yesterday.",
            rewritten: "I'm pretty sure we reverted 912 yesterday."
        )

        XCTAssertEqual(output, "I'm pretty sure we reverted 902 yesterday.")
    }

    func testRewriteRepairRestoresChangedNumericDigitEvidenceFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm pretty sure we reverted 902 yesterday.",
            rewritten: "I'm pretty sure we reverted 912 yesterday."
        )

        XCTAssertEqual(output, "I'm pretty sure we reverted 902 yesterday.")
    }

    func testRewriteRepairRestoresOriginalGapWhenModelInsertsUnsupportedNumberEvidence() {
        let cases = [
            (
                original: "It's gonna be massive in about a few weeks.",
                rewritten: "It's going to be massive in about 5 weeks.",
                repaired: "It's going to be massive in about a few weeks."
            ),
            (
                original: "I'm pretty sure that'll happen after about a few weeks.",
                rewritten: "I'm pretty sure that'll happen after about 5 weeks.",
                repaired: "I'm pretty sure that'll happen after about a few weeks."
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairPreservesReleasedVersionDecimalShape() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, we shipped 2.23 yesterday.",
            rewritten: "Yeah, we shipped 2.23 yesterday."
        )

        XCTAssertEqual(output, "Yeah, we shipped 2.23 yesterday.")
    }

    func testRewriteRepairRestoresOriginalDecimalShapeChangedToTimeShape() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, we shipped 2.23 yesterday.",
            rewritten: "Yeah, we shipped 2:23 yesterday."
        )

        XCTAssertEqual(output, "Yeah, we shipped 2.23 yesterday.")
    }

    func testRewriteRepairPreservesReleasedVersionDecimalShapeAcrossInterveningWords() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, we shipped like um maybe 2.23 yesterday.",
            rewritten: "Yeah, we shipped like um maybe 2.23 yesterday."
        )

        XCTAssertEqual(output, "Yeah, we shipped like um maybe 2.23 yesterday.")
    }

    func testRewriteRepairDoesNotPartiallyConvertSpokenTimeClusters() {
        let output = OutputRepair.repairModelOutput(
            original: "The meeting starts at two thirty.",
            rewritten: "The meeting starts at two thirty."
        )

        XCTAssertEqual(output, "The meeting starts at two thirty.")
    }

    func testRewriteRepairDoesNotConvertAddressLikeSpokenNumberClusters() {
        let output = OutputRepair.repairModelOutput(
            original: "Meet me at eleven fifty two North Washington Street.",
            rewritten: "Meet me at eleven fifty two North Washington Street."
        )

        XCTAssertEqual(output, "Meet me at eleven fifty two North Washington Street.")
    }

    func testRewriteRepairRestoresAddressNumberConvertedToTime() {
        let output = OutputRepair.repairModelOutput(
            original: "Meet me at 1152 North Washington Street.",
            rewritten: "Meet me at 11:52 North Washington Street."
        )

        XCTAssertEqual(output, "Meet me at 1152 North Washington Street.")
    }

    func testRewriteRepairRestoresSpokenAddressNumberCollapsedByModel() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, my address is twelve fifty five North Washington Avenue.",
            rewritten: "Yeah, my address is 125 North Washington Avenue."
        )

        XCTAssertEqual(output, "Yeah, my address is 1255 North Washington Avenue.")
    }

    func testRewriteRepairRestoresDigitByDigitSpokenAddressNumberCollapsedByModel() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, my address is one two five five North Washington Avenue.",
            rewritten: "Yeah, my address is 125 North Washington Avenue."
        )

        XCTAssertEqual(output, "Yeah, my address is 1255 North Washington Avenue.")
    }

    func testRewriteRepairRestoresTimeShapedAddressBeforeOrdinalStreet() {
        let output = OutputRepair.repairModelOutput(
            original: "Meet me at seven fifty nine 7th Street.",
            rewritten: "Meet me at 7:59 7th Street."
        )

        XCTAssertEqual(output, "Meet me at 759 7th Street.")
    }

    func testRewriteRepairRestoresTimeShapedAddressAndOrdinalStreetDrift() {
        let output = OutputRepair.repairModelOutput(
            original: "She said her address was eleven thirty seven North Twelfth Street.",
            rewritten: "She said her address was 11:37 North 2nd Street."
        )

        XCTAssertEqual(output, "She said her address was 1137 North 12th Street.")
    }

    func testRewriteRepairRestoresAddressNumberWithDifferentStreetNames() {
        let output = OutputRepair.repairModelOutput(
            original: "Send it to sixteen fifty nine Whitton Avenue and then 2359 North 59th Drive.",
            rewritten: "Send it to 16:59 Whitton Avenue and then 23:59 North 59th Drive."
        )

        XCTAssertEqual(output, "Send it to 1659 Whitton Avenue and then 2359 North 59th Drive.")
    }

    func testRewriteRepairRestoresOrdinalStreetNumberDriftInAddressSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, she said her address was eleven thirty seven North Twelfth Street.",
            rewritten: "She said her address was 1137 North 2nd Street."
        )

        XCTAssertEqual(output, "She said her address was 1137 North 12th Street.")
    }

    func testRewriteRepairCanonicalizesSpokenOrdinalStreetSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "She said her address was eleven twenty five North Twelfth Street.",
            rewritten: "She said her address was 1125 North Twelfth Street."
        )

        XCTAssertEqual(output, "She said her address was 1125 North 12th Street.")
    }

    func testRewriteRepairRestoresCollapsedAddressNumberAndOrdinalStreetSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "She said her address was eleven twenty five North Twelfth Street.",
            rewritten: "She said her address was 125 North 2nd Street."
        )

        XCTAssertEqual(output, "She said her address was 1125 North 12th Street.")
    }

    func testRewriteRepairRestoresDifferentOrdinalStreetNumberDriftInAddressSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "Mail it to twenty three fifty nine West Fifty Ninth Drive.",
            rewritten: "Mail it to 2359 West 9th Drive."
        )

        XCTAssertEqual(output, "Mail it to 2359 West 59th Drive.")
    }

    func testRewriteRepairRestoresCommonOrdinalStreetNumberDriftInAddressSuffixes() {
        let cases = [
            (
                original: "Meet me at eight thirty seven North Seventh Street.",
                rewritten: "Meet me at 837 North 2nd Street.",
                repaired: "Meet me at 837 North 7th Street."
            ),
            (
                original: "Meet me at nine forty eight South Eighth Avenue.",
                rewritten: "Meet me at 948 South 1st Avenue.",
                repaired: "Meet me at 948 South 8th Avenue."
            ),
            (
                original: "Meet me at ten fifty nine West Ninth Drive.",
                rewritten: "Meet me at 1059 West 5th Drive.",
                repaired: "Meet me at 1059 West 9th Drive."
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairRepairsSplitDollarsAndCentsAmount() {
        let output = OutputRepair.repairModelOutput(
            original: "I think it was fifty seven dollars and fifty cents.",
            rewritten: "I think it was $57 and $50."
        )

        XCTAssertEqual(output, "I think it was $57.50.")
    }

    func testRewriteRepairRepairsSplitDollarsAndCentsAmountWithFillerBeforeCents() {
        let output = OutputRepair.repairModelOutput(
            original: "I think it was forty seven dollars and like fifty cents.",
            rewritten: "I think it was $47 and $47."
        )

        XCTAssertEqual(output, "I think it was $47.50.")
    }

    func testRewriteRepairDoesNotDuplicateRepairedSplitMoneyAmount() {
        let output = OutputRepair.repairModelOutput(
            original: "It's probably like forty seven dollars and like fifty cents.",
            rewritten: "It's probably like $47 and like $47."
        )

        XCTAssertEqual(output, "It's probably like $47.50.")
    }

    func testRewriteRepairRemovesRedundantMinorUnitAfterDecimalMoneyAmount() {
        let output = OutputRepair.repairModelOutput(
            original: "That was four dollars and ninety nine cents.",
            rewritten: "That was $4.99 cents."
        )

        XCTAssertEqual(output, "That was $4.99.")
    }

    func testRewriteRepairRepairsChangedMoneyAmountWhenCurrencyMatches() {
        let output = OutputRepair.repairModelOutput(
            original: "That should be fifty five euros.",
            rewritten: "That should be €5."
        )

        XCTAssertEqual(output, "That should be €55.")
    }

    func testRewriteRepairRepairsChangedCompositeMoneyAmountFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "That was nine hundred and two dollars.",
            rewritten: "That was $2."
        )

        XCTAssertEqual(output, "That was $902.")
    }

    func testRewriteRepairRepairsMultipleChangedMoneyAmountsFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.",
            rewritten: "The budget is $22,022, and the backup estimate is $22,100."
        )

        XCTAssertEqual(output, "The budget is $5,022, and the backup estimate is $6,100.")
    }

    func testRewriteRepairPreservesCommaGroupedMoneyAmountsFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "That was probably like 6,500 dollars, but I think I owed him 1,500 bucks, and he's paid me at least seventy-five dollars since then.",
            rewritten: "That was probably $6,500 but I think I owed him $1,500 and he's paid me at least $75 since then."
        )

        XCTAssertEqual(output, "That was probably $6,500 but I think I owed him $1,500 and he's paid me at least $75 since then.")
    }

    func testRewriteRepairKeepsAPStyleDayCountAfterMoneyAmount() {
        let output = OutputRepair.repairModelOutput(
            original: "I would have spent fifty dollars seven days ago.",
            rewritten: "I would have spent $50 seven days ago."
        )

        XCTAssertEqual(output, "I would have spent $50 seven days ago.")
    }

    func testRewriteRepairKeepsAPStyleMathOperandAfterMoneyAmount() {
        let output = OutputRepair.repairModelOutput(
            original: "I don't know, that's probably three dollars multiplied by four.",
            rewritten: "I don't know, that's probably $3 multiplied by four."
        )

        XCTAssertEqual(output, "I don't know, that's probably $3 multiplied by four.")
    }

    func testRewriteRepairRepairsMathMoneyOperandDrift() {
        let output = OutputRepair.repairModelOutput(
            original: "I don't know, that's probably 3 * 4 dollars.",
            rewritten: "I don't know, that's probably 3 * $34."
        )

        XCTAssertEqual(output, "I don't know, that's probably 3 * $4.")
    }

    func testRewriteRepairFixesModelPercentSentenceSplit() {
        let output = OutputRepair.repairModelOutput(
            original: "The discount is five percent if we ship today.",
            rewritten: "The discount is 5%. if we ship today."
        )

        XCTAssertEqual(output, "The discount is 5% if we ship today.")
    }

    func testChunkPlannerBudgetsInstructionsInputAndExpectedOutput() async throws {
        let request = TextTransformRequest(
            baseText: "one two three four five six seven eight",
            styleIdentifier: "test-style",
            instructions: "one two three four",
            promptPrefix: "five six",
            contextTokenLimit: 14,
            expectedOutputExpansionRatio: 1,
            safetyMarginTokens: 2
        )
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.promptOverheadTokenCount, 6)
        XCTAssertEqual(plan.maximumInputTokensPerChunk, 3)
        XCTAssertEqual(plan.chunks.map(\.text), ["one two three", "four five six", "seven eight"])
    }

    func testChunkPlannerAlsoHonorsMaximumResponseTokens() async throws {
        let request = TextTransformRequest(
            baseText: "one two three four five six seven eight nine ten",
            styleIdentifier: "test-style",
            instructions: "",
            promptPrefix: "",
            contextTokenLimit: 32_768,
            expectedOutputExpansionRatio: 1,
            safetyMarginTokens: 0,
            maximumResponseTokens: 19
        )
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.maximumInputTokensPerChunk, 3)
        XCTAssertEqual(plan.chunks.map(\.text), [
            "one two three",
            "four five six",
            "seven eight nine",
            "ten",
        ])
    }

    func testChunkPlannerPrefersSentenceBoundariesWithinBudget() async throws {
        let request = Self.request("Alpha one. Beta two. Gamma three.")
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.chunks.map(\.text), ["Alpha one.", "Beta two.", "Gamma three."])
        XCTAssertEqual(plan.chunks.map(\.separatorAfter), [" ", " ", ""])
    }

    func testChunkPlannerSplitsLongSegmentByWordsWhenNeeded() async throws {
        let request = Self.request("Alpha beta gamma delta")
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.chunks.map(\.text), ["Alpha beta", "gamma delta"])
        XCTAssertEqual(plan.chunks.map(\.separatorAfter), [" ", ""])
    }

    @MainActor
    func testChunkRunnerStitchesMultipleChunksInOrder() async throws {
        let request = Self.request("Alpha one. Beta two.")
        let responder = StubChunkResponder(responses: [
            0: "Styled alpha.",
            1: "Styled beta.",
        ])
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: WordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, "Styled alpha. Styled beta.")
        XCTAssertEqual(result.chunkCount, 2)
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.errors, [])
    }

    @MainActor
    func testChunkRunnerFallsBackOnlyFailedChunk() async throws {
        let request = Self.request("Alpha one. Beta two.")
        let responder = StubChunkResponder(
            responses: [0: "Styled alpha."],
            failingChunkIndexes: [1]
        )
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: WordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, "Styled alpha. Beta two.")
        XCTAssertEqual(result.chunkCount, 2)
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.errors.map(\.chunkIndex), [1])
        XCTAssertEqual(result.chunkTimings.map(\.usedFallbackText), [false, true])
    }

    @MainActor
    func testChunkRunnerTreatsOutputTruncationAsFallback() async throws {
        let request = Self.request("Alpha one.")
        let responder = StubChunkResponder(
            typedError: .outputTruncated("maximumTokenCount")
        )
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: WordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelOutputTruncated])
    }

    func testDictationUtteranceArtifactRoundTripsThroughJSON() throws {
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: "raw",
            baseText: "base",
            selectedText: "styled",
            selectedUncappedText: "styled before caps",
            selectedStyleIdentifier: "test-style",
            baseParagraphsEnabled: false,
            baseListsEnabled: true,
            variants: [
                DictationTextVariantArtifact(
                    styleIdentifier: "test-style",
                    text: "styled",
                    duration: 0.25,
                    chunkCount: 2,
                    applied: true,
                    errors: ["fallback"]
                )
            ],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "base"
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: true,
                    listsEnabled: true,
                    text: "base\n\nlisted"
                ),
            ],
            inferenceDuration: 0.5,
            textTransformationDuration: 0.25,
            createdAt: Date(),
            metadata: [
                "dictation_model_id": "parakeetTdtV3",
                "dictation_provider": "parakeet"
            ]
        )

        let data = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded, artifact)
        XCTAssertEqual(decoded.selectedUncappedText, "styled before caps")
        XCTAssertEqual(decoded.baseParagraphsEnabled, false)
        XCTAssertEqual(decoded.baseListsEnabled, true)
    }

    func testDictationUtteranceArtifactDecodesMissingDeterministicVariantsAsEmpty() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "rawText": "raw",
          "baseText": "base",
          "selectedText": "styled",
          "selectedStyleIdentifier": "test-style",
          "variants": [],
          "inferenceDuration": 0.5,
          "textTransformationDuration": 0.25,
          "createdAt": 0
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded.deterministicVariants, [])
        XCTAssertEqual(decoded.metadata, [:])
        XCTAssertNil(decoded.selectedUncappedText)
        XCTAssertNil(decoded.baseParagraphsEnabled)
        XCTAssertNil(decoded.baseListsEnabled)
    }

    func testTextTransformRequestRoundTripsThroughJSON() throws {
        let request = TextTransformRequest(
            baseText: "base",
            styleIdentifier: "style",
            instructions: "instructions",
            promptPrefix: "prefix",
            promptSuffix: "suffix",
            contextTokenLimit: StyleRewriteDictationConfiguration.modelContextTokenLimit,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 384,
            maximumResponseTokens: 512
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(TextTransformRequest.self, from: data)

        XCTAssertEqual(decoded, request)
    }

    func testTextTransformResultRoundTripsThroughJSON() throws {
        let result = TextTransformResult(
            originalText: "base",
            finalText: "styled",
            styleIdentifier: "style",
            duration: 0.25,
            chunkCount: 1,
            applied: true,
            chunkTimings: [
                TextTransformChunkTiming(
                    chunkIndex: 0,
                    inputTokenCount: 8,
                    duration: 0.2,
                    usedFallbackText: false
                )
            ],
            errors: [
                TextTransformErrorSummary(chunkIndex: nil, message: "warning")
            ]
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TextTransformResult.self, from: data)

        XCTAssertEqual(decoded, result)
    }

    @MainActor
    func testStyleRewriteTransformerMapsBackendFailureWithoutClaimingVibeSuccess() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note this needs cleanup."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(failingChunkIndexes: [0])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.generationFailed])
    }

    @MainActor
    func testStyleRewriteTransformerRepairsCasualDecimalDriftFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "I'm pretty sure we reverted five point five three yesterday."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "I'm pretty sure we reverted 5:53 yesterday."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "I'm pretty sure we reverted 5.53 yesterday.")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor
    func testStyleRewriteTransformerRepairsCasualTerminalPunctuationDriftFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Hey man? Are you okay!"
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "Hey man? Are you okay?"
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "Hey man? Are you okay!")
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor
    func testStyleRewriteTransformerRepairsPolishedChangedNumberEvidenceFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "I'm pretty sure we reverted five point five three yesterday."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "I'm pretty sure we reverted 5.33 yesterday."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "I'm pretty sure we reverted 5.53 yesterday.")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model")
    }

    @MainActor
    func testStyleRewriteTransformerRepairsCasualChangedMoneyEvidenceFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "That was nine hundred and two dollars."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "That was $2."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "That was $902.")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor
    func testStyleRewriteTransformerRepairsPolishedAddressOrdinalDrift() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "She said her address was eleven thirty seven North Twelfth Street."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "She said her address was 1137 North 2nd Street."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "She said her address was 1137 North 12th Street.")
        XCTAssertTrue(result.applied)
    }

    @MainActor
    func testStyleRewriteTransformerMapsTypedLocalBackendFailure() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note this needs cleanup."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(typedError: .modelNotInstalled)
            }
        )

        let result = await transformer.transform(request)

        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelNotInstalled])
    }

    @MainActor
    func testStyleRewriteTransformerFallsBackWhenModelLeaksPromptInstructions() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Okay, so I guess we're gonna have to just record this dictated text."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "Okay Okay, so I guess we're gonna have to just record this dictated text. \(StyleRewriteDictationConfiguration.casualLoRASystemPrompt)"
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.promptLeakDetected])
        XCTAssertEqual(result.processingMode, "local-model-prompt-leak-fallback")
    }

    @MainActor
    func testChillUsesHeuristicTextButDoesNotClaimFullVibeSuccessWhenCleanupFails() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Um hey, this is cool."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(typedError: .modelLoadFailed("missing"))
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "um hey this is cool")
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelLoadFailed])
        XCTAssertEqual(result.processingMode, "local-model-cleanup-failed+heuristic")
    }

    @MainActor
    func testChillRestoresSourceExclamationBoundaryAfterHeuristicFormatting() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "That is wild!"
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "That is wild."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "that is wild!")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup+heuristic")
    }

    @MainActor
    func testChillRestoresSourceQuestionExclamationClusterAfterHeuristicFormatting() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "What the hell is wrong with you?!"
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(responses: [
                    0: "What the hell is wrong with you!"
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "what the hell is wrong with you?!")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup+heuristic")
    }

    private static func request(_ baseText: String) -> TextTransformRequest {
        TextTransformRequest(
            baseText: baseText,
            styleIdentifier: "test-style",
            instructions: "Instructions",
            promptPrefix: "Prompt:",
            contextTokenLimit: 6,
            expectedOutputExpansionRatio: 1,
            safetyMarginTokens: 0
        )
    }
}

private struct WordTokenCounter: TextTransformTokenCounting {
    func tokenCount(for text: String) async throws -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

@MainActor
private final class StubChunkResponder: TextTransformChunkResponding {
    enum StubError: Error {
        case failed
    }

    let responses: [Int: String]
    let failingChunkIndexes: Set<Int>
    let typedError: StyleRewriteBackendError?

    init(
        responses: [Int: String] = [:],
        failingChunkIndexes: Set<Int> = [],
        typedError: StyleRewriteBackendError? = nil
    ) {
        self.responses = responses
        self.failingChunkIndexes = failingChunkIndexes
        self.typedError = typedError
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        if let typedError {
            throw typedError
        }
        if failingChunkIndexes.contains(chunk.index) {
            throw StubError.failed
        }
        return responses[chunk.index] ?? chunk.text
    }
}
