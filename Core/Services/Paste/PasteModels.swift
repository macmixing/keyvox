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

struct PasteMenuFallbackVerificationContext {
    let snapshots: [PasteMenuFallbackVerificationSnapshot]
}

struct PasteMenuFallbackVerificationSnapshot {
    let element: AXUIElement
    let selectedRange: CFRange?
    let valueLength: Int?
}
