import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class VersionNumberEvidenceRepairTests: XCTestCase {
    func testRewriteRepairPreservesVersionNumberDecimalShape() {
        let output = OutputRepair.repairModelOutput(
            original: "I'm shipping version five point thirty tomorrow.",
            rewritten: "I'm shipping version 5.30 tomorrow."
        )

        XCTAssertEqual(output, "I'm shipping version 5.30 tomorrow.")
    }

    func testRewriteRepairRestoresMixedVersionSeparatorShape() {
        let cases = [
            (
                original: "I need you to create a macOS changelog entry for version one point one point one three.",
                rewritten: "I need you to create a macOS changelog entry for version 1.1 point 13.",
                repaired: "I need you to create a macOS changelog entry for version 1.1.13."
            ),
            (
                original: "That's version one dot five dot one three.",
                rewritten: "That's version one dot five.13.",
                repaired: "That's version 1.5.13."
            ),
            (
                original: "That's version one point one point one five.",
                rewritten: "That's version 1 point 15.",
                repaired: "That's version 1.1.15."
            ),
            (
                original: "Download version sixteen point eleven point five.",
                rewritten: "Download version 16 point 15.",
                repaired: "Download version 16.11.5."
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

    func testRewriteRepairPreservesReleasedVersionDecimalShapeAcrossInterveningWords() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, we shipped like um maybe 2.23 yesterday.",
            rewritten: "Yeah, we shipped like um maybe 2.23 yesterday."
        )

        XCTAssertEqual(output, "Yeah, we shipped like um maybe 2.23 yesterday.")
    }
}
