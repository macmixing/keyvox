import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class DecimalNumberEvidenceRepairTests: XCTestCase {
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

    func testRewriteRepairRestoresOriginalDecimalShapeChangedToTimeShape() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, we shipped 2.23 yesterday.",
            rewritten: "Yeah, we shipped 2:23 yesterday."
        )

        XCTAssertEqual(output, "Yeah, we shipped 2.23 yesterday.")
    }

    func testRewriteRepairDoesNotPartiallyConvertSpokenTimeClusters() {
        let output = OutputRepair.repairModelOutput(
            original: "The meeting starts at two thirty.",
            rewritten: "The meeting starts at two thirty."
        )

        XCTAssertEqual(output, "The meeting starts at two thirty.")
    }
}
