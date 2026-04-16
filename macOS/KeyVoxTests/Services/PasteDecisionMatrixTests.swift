import XCTest
@testable import KeyVox

@MainActor
final class PasteDecisionMatrixTests: XCTestCase {
    func testNoWarningWhenAccessibilityInsertionSucceeds() {
        XCTAssertFalse(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: true,
                didMenuFallbackInsert: false
            )
        )
    }

    func testNoWarningWhenMenuFallbackTrustedSuccess() {
        let didMenuInsert = PasteService.didMenuFallbackInsertForMenuAttempt(
            attempt: .actionSucceeded,
            trustMenuSuccessWithoutAXVerification: true,
            verificationPassed: false
        )

        XCTAssertTrue(didMenuInsert)
        XCTAssertFalse(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: didMenuInsert
            )
        )
    }

    func testNoWarningWhenMenuFallbackVerifiedSuccess() {
        let didMenuInsert = PasteService.didMenuFallbackInsertForMenuAttempt(
            attempt: .actionSucceeded,
            trustMenuSuccessWithoutAXVerification: false,
            verificationPassed: true
        )

        XCTAssertTrue(didMenuInsert)
        XCTAssertFalse(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: didMenuInsert
            )
        )
    }

    func testMenuCompletionEvidenceDistinguishesVerifiedAndTrustedSuccess() {
        XCTAssertEqual(
            PasteMenuFallbackCoordinator.completionEvidenceForMenuAttempt(
                attempt: .actionSucceeded,
                didMenuFallbackInsert: true,
                trustMenuSuccessWithoutAXVerification: false,
                verificationPassed: true
            ),
            .verifiedInsertion
        )

        XCTAssertEqual(
            PasteMenuFallbackCoordinator.completionEvidenceForMenuAttempt(
                attempt: .actionSucceeded,
                didMenuFallbackInsert: true,
                trustMenuSuccessWithoutAXVerification: true,
                verificationPassed: false
            ),
            .trustedWithoutVerification
        )

        XCTAssertEqual(
            PasteMenuFallbackCoordinator.completionEvidenceForMenuAttempt(
                attempt: .actionSucceeded,
                didMenuFallbackInsert: false,
                trustMenuSuccessWithoutAXVerification: true,
                verificationPassed: false
            ),
            .none
        )
    }

    func testWarningWhenMenuFallbackSucceededButVerificationFailed() {
        let didMenuInsert = PasteService.didMenuFallbackInsertForMenuAttempt(
            attempt: .actionSucceeded,
            trustMenuSuccessWithoutAXVerification: false,
            verificationPassed: false
        )

        XCTAssertFalse(didMenuInsert)
        XCTAssertTrue(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: didMenuInsert
            )
        )
    }

    func testNoWarningWhenErroredMenuActionStillVerifiesInsertion() {
        let didMenuInsert = PasteService.didMenuFallbackInsertForMenuAttempt(
            attempt: .actionErrored,
            trustMenuSuccessWithoutAXVerification: false,
            verificationPassed: true
        )

        XCTAssertTrue(didMenuInsert)
        XCTAssertFalse(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: didMenuInsert
            )
        )
    }

    func testWarningWhenMenuActionErrorsAndVerificationFails() {
        let didMenuInsert = PasteService.didMenuFallbackInsertForMenuAttempt(
            attempt: .actionErrored,
            trustMenuSuccessWithoutAXVerification: false,
            verificationPassed: false
        )

        XCTAssertFalse(didMenuInsert)
        XCTAssertTrue(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: didMenuInsert
            )
        )
    }

    func testWarningWhenMenuActionUnavailableAndAccessibilityFailed() {
        let didMenuInsert = PasteService.didMenuFallbackInsertForMenuAttempt(
            attempt: .unavailable,
            trustMenuSuccessWithoutAXVerification: false,
            verificationPassed: false
        )

        XCTAssertFalse(didMenuInsert)
        XCTAssertTrue(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: didMenuInsert
            )
        )
    }

    func testEmptyClipboardPayloadUsesLeadingSpaceTypingResult() {
        let typedSpaces = PasteService.didMenuFallbackInsertForEmptyClipboardPayload(didTypeLeadingSpaces: true)
        let failedTypingSpaces = PasteService.didMenuFallbackInsertForEmptyClipboardPayload(didTypeLeadingSpaces: false)

        XCTAssertTrue(typedSpaces)
        XCTAssertFalse(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: typedSpaces
            )
        )

        XCTAssertFalse(failedTypingSpaces)
        XCTAssertTrue(
            PasteService.shouldStartFailureRecovery(
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: failedTypingSpaces
            )
        )
    }

    func testFirstMenuSuccessAttemptSuppressesWarmupFalseWarning() {
        XCTAssertTrue(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: .actionSucceeded,
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false,
                isFirstMenuSuccessAttemptForProcess: true
            )
        )
    }

    func testLaterMenuSuccessAttemptsDoNotSuppressWarning() {
        XCTAssertFalse(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: .actionSucceeded,
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false,
                isFirstMenuSuccessAttemptForProcess: false
            )
        )
    }
}
