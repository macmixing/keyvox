import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class PercentRepairTests: XCTestCase {
    func testRewriteRepairFixesModelPercentSentenceSplit() {
        let output = OutputRepair.repairModelOutput(
            original: "The discount is five percent if we ship today.",
            rewritten: "The discount is 5%. if we ship today."
        )

        XCTAssertEqual(output, "The discount is 5% if we ship today.")
    }
}
