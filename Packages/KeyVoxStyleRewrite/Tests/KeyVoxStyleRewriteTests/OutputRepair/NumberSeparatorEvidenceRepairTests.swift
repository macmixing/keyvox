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
}
