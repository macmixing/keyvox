import Foundation
import ApplicationServices

struct PasteAppIdentity {
    let bundleID: String?
    let pid: pid_t
}

struct PasteInsertionContext {
    let selectionLength: Int?
    let caretLocation: Int?
    let previousCharacter: Character?
    let previousNonWhitespaceCharacter: Character?

    init(
        selectionLength: Int?,
        caretLocation: Int?,
        previousCharacter: Character?,
        previousNonWhitespaceCharacter: Character? = nil
    ) {
        self.selectionLength = selectionLength
        self.caretLocation = caretLocation
        self.previousCharacter = previousCharacter
        self.previousNonWhitespaceCharacter = previousNonWhitespaceCharacter
    }
}

enum PasteAccessibilityInjectionOutcome {
    case verifiedSuccess
    case softSuccessNeedsFallback
    case failureNeedsFallback
}

struct PasteMenuFallbackTransport {
    let leadingSpacesToType: Int
    let textToPaste: String
}

enum PasteMenuFallbackAttemptResult {
    case unavailable
    case actionSucceeded
    case actionErrored
}

enum PasteMenuFallbackCompletionEvidence {
    case none
    case noClipboardPayload
    case verifiedInsertion
    case trustedWithoutVerification
}

struct PasteMenuFallbackVerificationContext {
    let snapshots: [PasteMenuFallbackVerificationSnapshot]
}

struct PasteMenuFallbackVerificationSnapshot {
    let element: AXUIElement
    let selectedRange: CFRange?
    let valueLength: Int?
}

struct PasteMenuFallbackUndoState {
    let title: String?
    let isEnabled: Bool?
}
