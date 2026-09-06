import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class NumberSeparatorEvidenceRepairTests: XCTestCase {
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

    func testRewriteRepairRepairsObservedWhisperTimeBeforeInterjection() {
        let output = OutputRepair.repairModelOutput(
            original: "Can you meet me there at 5.30 please?",
            rewritten: "Can you meet me there at 5.30 please?"
        )

        XCTAssertEqual(output, "Can you meet me there at 5:30 please?")
    }

    func testRewriteRepairRepairsObservedWhisperTerminalTime() {
        let output = OutputRepair.repairModelOutput(
            original: "Can you meet me there at 5.30?",
            rewritten: "Can you meet me there at 5.30?"
        )

        XCTAssertEqual(output, "Can you meet me there at 5:30?")
    }

    func testRewriteRepairRepairsObservedWhisperTimeAtAnySentencePosition() {
        let cases = [
            (
                original: "Can you meet me there at 5.30? I will send the address next.",
                repaired: "Can you meet me there at 5:30? I will send the address next."
            ),
            (
                original: "I will send the address next. Can you meet me there at 5.30? Let me know.",
                repaired: "I will send the address next. Can you meet me there at 5:30? Let me know."
            ),
            (
                original: "I will send the address next. Let me know. Can you meet me there at 5.30?",
                repaired: "I will send the address next. Let me know. Can you meet me there at 5:30?"
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.original
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }

    func testRewriteRepairPreservesObservedWhisperVersion() {
        let output = OutputRepair.repairModelOutput(
            original: "Please install version 5.30.",
            rewritten: "Please install version 5.30."
        )

        XCTAssertEqual(output, "Please install version 5.30.")
    }

    func testRewriteRepairPreservesObservedWhisperDecimal() {
        let output = OutputRepair.repairModelOutput(
            original: "The measurement is 5.30.",
            rewritten: "The measurement is 5.30."
        )

        XCTAssertEqual(output, "The measurement is 5.30.")
    }

    func testRewriteRepairPreservesObservedWhisperPercentDecimal() {
        let output = OutputRepair.repairModelOutput(
            original: "The rate is 5.30%.",
            rewritten: "The rate is 5.30%."
        )

        XCTAssertEqual(output, "The rate is 5.30%.")
    }
}
