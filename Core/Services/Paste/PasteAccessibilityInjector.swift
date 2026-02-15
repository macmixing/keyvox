import Cocoa

final class PasteAccessibilityInjector {
    private let axInspector: PasteAXInspector

    init(axInspector: PasteAXInspector) {
        self.axInspector = axInspector
    }

    func injectTextViaAccessibility(_ text: String) -> PasteAccessibilityInjectionOutcome {
        guard let element = axInspector.focusedUIElement() else {
            return .failureNeedsFallback
        }

        // Role gate: AXWebArea/AXGroup commonly ignore direct selected-text writes.
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        var roleStr = "Unknown"
        if let roleVal = role as? String {
            roleStr = roleVal
            #if DEBUG
            print("DEBUG: Focused Element Role: \(roleStr)")
            #endif
            if roleStr == "AXWebArea" || roleStr == "AXGroup" {
                // Generic fallback, not app-specific branching.
                return .failureNeedsFallback
            }
        }

        // Attempt direct selected-text write and verify range movement when available.
        let originalRange = axInspector.selectedRange(for: element)

        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if status != .success {
            return .failureNeedsFallback
        }

        // Verify whether the caret/selection range changed after write.
        usleep(1000) // 1ms

        let newRange = axInspector.selectedRange(for: element)

        // Identical ranges imply probable no-op; keep soft success and still fallback.
        if let old = originalRange, let new = newRange {
            if old.location == new.location && old.length == new.length {
                #if DEBUG
                print("DEBUG: Silent Failure Detected! Range didn't move. Role: \(roleStr)")
                #endif
                return .softSuccessNeedsFallback
            }
            return .verifiedSuccess
        }

        // Inconclusive verification: keep soft success and still run fallback path.
        return .softSuccessNeedsFallback
    }
}
