import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class APStyleNumberRepairTests: XCTestCase {
    func testRewriteRepairAppliesAPStyleToOrdinaryLowNumbersFromSpokenInput() {
        let output = OutputRepair.repairModelOutput(
            original: "I went there two days ago. She wanted five lobsters for dinner.",
            rewritten: "I went there 2 days ago. She wanted 5 lobsters for dinner."
        )

        XCTAssertEqual(output, "I went there two days ago. She wanted five lobsters for dinner.")
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

    func testRewriteRepairDoesNotCollapseSeparatedVideoFactsIntoOneNumber() {
        let output = OutputRepair.repairModelOutput(
            original: "At the end of the day, that was a nine minute four gigabyte video that was compressed down into thirty one megabytes, retaining full semantic understanding.",
            rewritten: "At the end of the day, that was a 9 minute 4 gigabyte video that was compressed down into 31 megabytes, retaining full semantic understanding."
        )

        XCTAssertEqual(
            output,
            "At the end of the day, that was a nine minute four gigabyte video that was compressed down into 31 megabytes, retaining full semantic understanding."
        )
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
}
