import Foundation

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
