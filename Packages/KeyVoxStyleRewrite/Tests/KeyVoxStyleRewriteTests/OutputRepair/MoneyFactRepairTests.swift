import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class MoneyFactRepairTests: XCTestCase {
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

    func testRewriteRepairPreservesDecimalMoneyAmount() {
        let output = OutputRepair.repairModelOutput(
            original: "I paid five point three dollars.",
            rewritten: "I paid $5.3."
        )

        XCTAssertEqual(output, "I paid $5.3.")
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

    func testRewriteRepairRepairsMixedSpokenAndGroupedMoneyEvidence() {
        let original = "The company was making a hundred and 5,000 dollars a year."
        let rewrittenOutputs = [
            "The company was making $5,000 a year.",
            "The company was making $1,500 a year.",
            "The company was making $100 and $500 a year.",
            original,
        ]

        for rewritten in rewrittenOutputs {
            let output = OutputRepair.repairModelOutput(
                original: original,
                rewritten: rewritten
            )

            XCTAssertEqual(output, "The company was making $105,000 a year.")
        }
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
}
