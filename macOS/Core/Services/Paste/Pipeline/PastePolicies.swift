import Foundation
import KeyVoxCore

enum PastePolicies {
    static let multilineListOverrideBundleIDs: Set<String> = [
        "com.apple.MobileSMS"
    ]

    static let menuSuccessTrustWithoutAXVerificationBundleIDs: Set<String> = [
        "com.apple.MobileSMS",
        // Numbers accepts Paste into non-text canvas contexts (for example inserting a floating text object),
        // where AX text verifiers cannot reliably observe a value/range change.
        "com.apple.iWork.Numbers"
    ]

    static func listRenderMode(forAXRole role: String?, bundleID: String?) -> ListRenderMode {
        // Some apps expose message composers as single-line roles even when newline insertion is valid.
        if let bundleID, multilineListOverrideBundleIDs.contains(bundleID) {
            return .multiline
        }

        guard let role else { return .multiline }

        switch role {
        case "AXTextField", "AXSearchField", "AXComboBox":
            return .singleLineInline
        default:
            return .multiline
        }
    }

    static func shouldTrustMenuSuccessWithoutAXVerification(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return menuSuccessTrustWithoutAXVerificationBundleIDs.contains(bundleID)
    }

    static func shouldStartFailureRecovery(
        didAccessibilityInsertText: Bool,
        didMenuFallbackInsert: Bool
    ) -> Bool {
        !didAccessibilityInsertText && !didMenuFallbackInsert
    }
}

struct PasteServiceExecutionPlan {
    let shouldRememberInsertion: Bool
    let shouldStartFailureRecovery: Bool
    let restorePolicy: PasteClipboardRestorePolicy

    static func build(
        didAccessibilityInsertText: Bool,
        didMenuFallbackInsert: Bool,
        usedMenuFallbackPath: Bool,
        menuFallbackCompletionEvidence: PasteMenuFallbackCompletionEvidence = .none,
        suppressFirstWarmupFailureWarning: Bool,
        shouldStartFailureRecovery: Bool,
        restoreDelayAfterMenuFallback: TimeInterval
    ) -> PasteServiceExecutionPlan {
        let rememberInsertion = didAccessibilityInsertText || didMenuFallbackInsert
        let shouldRecover = !suppressFirstWarmupFailureWarning && shouldStartFailureRecovery

        if shouldRecover {
            return PasteServiceExecutionPlan(
                shouldRememberInsertion: rememberInsertion,
                shouldStartFailureRecovery: true,
                restorePolicy: .deferredToFailureRecovery
            )
        }

        let restorePolicy = Self.clipboardRestorePolicy(
            usedMenuFallbackPath: usedMenuFallbackPath,
            menuFallbackCompletionEvidence: menuFallbackCompletionEvidence,
            restoreDelayAfterMenuFallback: restoreDelayAfterMenuFallback
        )

        return PasteServiceExecutionPlan(
            shouldRememberInsertion: rememberInsertion,
            shouldStartFailureRecovery: false,
            restorePolicy: restorePolicy
        )
    }

    private static func clipboardRestorePolicy(
        usedMenuFallbackPath: Bool,
        menuFallbackCompletionEvidence: PasteMenuFallbackCompletionEvidence,
        restoreDelayAfterMenuFallback: TimeInterval
    ) -> PasteClipboardRestorePolicy {
        guard usedMenuFallbackPath else {
            return .immediate
        }

        switch menuFallbackCompletionEvidence {
        case .noClipboardPayload, .expectedPayloadObserved:
            return .immediate
        case .structuralInsertionObserved, .trustedWithoutVerification, .none:
            return .afterDelay(restoreDelayAfterMenuFallback)
        }
    }
}

enum PasteClipboardRestorePolicy: Equatable {
    case immediate
    case afterDelay(TimeInterval)
    case deferredToFailureRecovery
}

struct PasteAccessibilityExecutionDecision {
    let needsMenuFallback: Bool
    let didAccessibilityInsertText: Bool

    static func from(_ outcome: PasteAccessibilityInjectionOutcome) -> PasteAccessibilityExecutionDecision {
        switch outcome {
        case .verifiedSuccess:
            return PasteAccessibilityExecutionDecision(
                needsMenuFallback: false,
                didAccessibilityInsertText: true
            )
        case .softSuccessNeedsFallback, .failureNeedsFallback:
            return PasteAccessibilityExecutionDecision(
                needsMenuFallback: true,
                didAccessibilityInsertText: false
            )
        }
    }
}
