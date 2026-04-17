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

enum PasteMenuFallbackCompletionEvidence: Equatable {
    case none
    case noClipboardPayload
    case expectedPayloadObserved
    case structuralInsertionObserved
    case trustedWithoutVerification
}

enum PasteMenuFallbackVerificationOutcome: Equatable {
    case none
    case structuralInsertionObserved
    case expectedPayloadObserved

    var didObserveInsertion: Bool {
        switch self {
        case .none:
            return false
        case .structuralInsertionObserved, .expectedPayloadObserved:
            return true
        }
    }

    var completionEvidence: PasteMenuFallbackCompletionEvidence {
        switch self {
        case .none:
            return .none
        case .structuralInsertionObserved:
            return .structuralInsertionObserved
        case .expectedPayloadObserved:
            return .expectedPayloadObserved
        }
    }
}

struct PasteMenuFallbackVerificationContext {
    let snapshots: [PasteMenuFallbackVerificationSnapshot]
}

struct PasteMenuFallbackVerificationSnapshot {
    let element: AXUIElement
    let selectedRange: CFRange?
    let valueLength: Int?
    let valueText: String?

    init(
        element: AXUIElement,
        selectedRange: CFRange?,
        valueLength: Int?,
        valueText: String? = nil
    ) {
        self.element = element
        self.selectedRange = selectedRange
        self.valueLength = valueLength
        self.valueText = valueText
    }
}

struct PasteMenuFallbackUndoState {
    let title: String?
    let isEnabled: Bool?
}
