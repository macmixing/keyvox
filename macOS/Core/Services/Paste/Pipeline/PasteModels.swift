import Foundation
import ApplicationServices

struct PasteAppIdentity {
    let bundleID: String?
    let pid: pid_t
}

struct PasteInsertionContext {
    let selectionLength: Int?
    let selectedText: String?
    let caretLocation: Int?
    let previousCharacter: Character?
    let followingCharacter: Character?
    let characterBeforePreviousCharacter: Character?
    let previousNonWhitespaceCharacter: Character?
    let characterBeforePreviousNonWhitespaceCharacter: Character?
    let isPreviousNonWhitespaceCharacterAtLineStart: Bool

    init(
        selectionLength: Int?,
        selectedText: String? = nil,
        caretLocation: Int?,
        previousCharacter: Character?,
        followingCharacter: Character? = nil,
        characterBeforePreviousCharacter: Character? = nil,
        previousNonWhitespaceCharacter: Character? = nil,
        characterBeforePreviousNonWhitespaceCharacter: Character? = nil,
        isPreviousNonWhitespaceCharacterAtLineStart: Bool = false
    ) {
        self.selectionLength = selectionLength
        self.selectedText = selectedText
        self.caretLocation = caretLocation
        self.previousCharacter = previousCharacter
        self.followingCharacter = followingCharacter
        self.characterBeforePreviousCharacter = characterBeforePreviousCharacter
        self.previousNonWhitespaceCharacter = previousNonWhitespaceCharacter
        self.characterBeforePreviousNonWhitespaceCharacter = characterBeforePreviousNonWhitespaceCharacter
        self.isPreviousNonWhitespaceCharacterAtLineStart = isPreviousNonWhitespaceCharacterAtLineStart
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
    let trailingSpacesToType: Int
}

enum PasteMenuFallbackAttemptResult {
    case unavailable
    case actionSucceeded
    case actionErrored
}

enum PasteMenuFallbackCompletionEvidence: Equatable {
    case none
    case noClipboardPayload
    case confirmedMenuPasteObserved
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

    var hasVerificationSignal: Bool {
        selectedRange != nil || valueLength != nil || valueText != nil
    }
}

struct PasteMenuFallbackUndoState {
    let title: String?
    let isEnabled: Bool?
}
