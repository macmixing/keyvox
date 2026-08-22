import Cocoa

protocol PasteAccessibilityInjecting {
    func injectTextViaAccessibility(_ text: String) -> PasteAccessibilityInjectionOutcome
    func injectTextViaAccessibility(
        _ text: String,
        into targetElement: AXUIElement?
    ) -> PasteAccessibilityInjectionOutcome
}

extension PasteAccessibilityInjecting {
    func injectTextViaAccessibility(
        _ text: String,
        into targetElement: AXUIElement?
    ) -> PasteAccessibilityInjectionOutcome {
        _ = targetElement
        return injectTextViaAccessibility(text)
    }
}

final class PasteAccessibilityInjector {
    private enum MainThreadInjection {
        static let timeout: DispatchTimeInterval = .milliseconds(250)
    }

    private let axInspector: PasteAXInspecting

    init(axInspector: PasteAXInspecting) {
        self.axInspector = axInspector
    }

    func injectTextViaAccessibility(_ text: String) -> PasteAccessibilityInjectionOutcome {
        injectTextViaAccessibility(text, into: axInspector.focusedUIElement())
    }

    func injectTextViaAccessibility(
        _ text: String,
        into targetElement: AXUIElement?
    ) -> PasteAccessibilityInjectionOutcome {
        guard let targetElement else {
            return .failureNeedsFallback
        }

        if isCurrentProcessElement(targetElement) {
            return performOnMainThread {
                self.injectText(text, into: targetElement)
            }
        }

        return injectText(text, into: targetElement)
    }

    private func injectText(
        _ text: String,
        into element: AXUIElement
    ) -> PasteAccessibilityInjectionOutcome {

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

    private func isCurrentProcessElement(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return false
        }

        return pid == getpid()
    }

    private func performOnMainThread(
        _ operation: @escaping () -> PasteAccessibilityInjectionOutcome
    ) -> PasteAccessibilityInjectionOutcome {
        if Thread.isMainThread {
            return operation()
        }

        let completion = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var didTimeOut = false
        var outcome: PasteAccessibilityInjectionOutcome = .failureNeedsFallback

        // Self-targeted AX writes must run on the main thread, but the paste queue
        // cannot wait forever if the main thread is synchronously waiting on it.
        DispatchQueue.main.async {
            lock.lock()
            let shouldRun = !didTimeOut
            lock.unlock()

            guard shouldRun else {
                completion.signal()
                return
            }

            let operationOutcome = operation()

            lock.lock()
            outcome = operationOutcome
            lock.unlock()
            completion.signal()
        }

        guard completion.wait(timeout: .now() + MainThreadInjection.timeout) == .success else {
            lock.lock()
            didTimeOut = true
            lock.unlock()
            return .failureNeedsFallback
        }

        lock.lock()
        let completedOutcome = outcome
        lock.unlock()
        return completedOutcome
    }
}

extension PasteAccessibilityInjector: PasteAccessibilityInjecting {}
