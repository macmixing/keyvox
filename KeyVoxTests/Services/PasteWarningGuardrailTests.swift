import XCTest
@testable import KeyVox

final class PasteWarningGuardrailTests: XCTestCase {
    func testFirstMenuSuccessSuppressionRequiresActionSucceeded() {
        XCTAssertFalse(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: .actionErrored,
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false,
                isFirstMenuSuccessAttemptForProcess: true
            )
        )

        XCTAssertFalse(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: .unavailable,
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false,
                isFirstMenuSuccessAttemptForProcess: true
            )
        )

        XCTAssertFalse(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: nil,
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: false,
                isFirstMenuSuccessAttemptForProcess: true
            )
        )
    }

    func testFirstMenuSuccessSuppressionDisabledWhenInsertionAlreadyRecorded() {
        XCTAssertFalse(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: .actionSucceeded,
                didAccessibilityInsertText: true,
                didMenuFallbackInsert: false,
                isFirstMenuSuccessAttemptForProcess: true
            )
        )

        XCTAssertFalse(
            PasteService.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
                attempt: .actionSucceeded,
                didAccessibilityInsertText: false,
                didMenuFallbackInsert: true,
                isFirstMenuSuccessAttemptForProcess: true
            )
        )
    }

    func testMenuAttemptDecisionDoesNotTrustErroredAttemptsWithoutVerification() {
        XCTAssertFalse(
            PasteService.didMenuFallbackInsertForMenuAttempt(
                attempt: .actionErrored,
                trustMenuSuccessWithoutAXVerification: true,
                verificationPassed: false
            )
        )
    }

    func testMenuAttemptDecisionDoesNotTrustUnavailableAttempts() {
        XCTAssertFalse(
            PasteService.didMenuFallbackInsertForMenuAttempt(
                attempt: .unavailable,
                trustMenuSuccessWithoutAXVerification: true,
                verificationPassed: true
            )
        )
    }

    func testMenuAttemptDecisionRequiresVerificationWhenNotTrusted() {
        XCTAssertFalse(
            PasteService.didMenuFallbackInsertForMenuAttempt(
                attempt: .actionSucceeded,
                trustMenuSuccessWithoutAXVerification: false,
                verificationPassed: false
            )
        )
        XCTAssertTrue(
            PasteService.didMenuFallbackInsertForMenuAttempt(
                attempt: .actionSucceeded,
                trustMenuSuccessWithoutAXVerification: false,
                verificationPassed: true
            )
        )
    }
}
