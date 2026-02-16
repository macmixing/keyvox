import Foundation
import XCTest
@testable import KeyVox

final class PasteFailureRecoveryPolicyTests: XCTestCase {
    func testStartsRecoveryOnlyWhenBothPathsFail() {
        XCTAssertTrue(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false
            )
        )

        XCTAssertTrue(
            !PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: true,
                didMenuFallbackInsert: false
            )
        )

        XCTAssertTrue(
            !PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: true
            )
        )

        XCTAssertTrue(
            !PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: true,
                didMenuFallbackInsert: true
            )
        )
    }
}
