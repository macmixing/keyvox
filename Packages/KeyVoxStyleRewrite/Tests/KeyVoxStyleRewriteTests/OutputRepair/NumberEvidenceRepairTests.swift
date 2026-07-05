import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class NumberEvidenceRepairTests: XCTestCase {
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

    func testRewriteRepairRestoresChangedConnectorBasedHundredsFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "That's seven hundred and fifty gigabytes.",
            rewritten: "That's 705 gigabytes."
        )

        XCTAssertEqual(output, "That's 750 gigabytes.")
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

    func testRewriteRepairRestoresSpokenOhDigitSequenceFromOriginalDictation() {
        let output = OutputRepair.repairModelOutput(
            original: "Stay on this branch and review PR one oh seven.",
            rewritten: "Stay on this branch and review PR 17."
        )

        XCTAssertEqual(output, "Stay on this branch and review PR 107.")
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
}
