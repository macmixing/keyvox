import Foundation
import Testing
@testable import KeyVox

struct PasteFailureRecoveryPolicyTests {
    @Test
    func startsRecoveryOnlyWhenBothPathsFail() {
        #expect(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false
            )
        )

        #expect(
            !PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: true,
                didMenuFallbackInsert: false
            )
        )

        #expect(
            !PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: true
            )
        )

        #expect(
            !PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: true,
                didMenuFallbackInsert: true
            )
        )
    }
}
