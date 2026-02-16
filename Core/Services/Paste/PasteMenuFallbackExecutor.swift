import Cocoa

final class PasteMenuFallbackExecutor {
    private let axInspector: PasteAXInspector
    private let verificationTimeout: TimeInterval
    private let verificationPollInterval: TimeInterval

    init(
        axInspector: PasteAXInspector,
        verificationTimeout: TimeInterval,
        verificationPollInterval: TimeInterval
    ) {
        self.axInspector = axInspector
        self.verificationTimeout = verificationTimeout
        self.verificationPollInterval = verificationPollInterval
    }

    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult {
        if Thread.isMainThread {
            return pasteViaMenuBar()
        }

        var outcome: PasteMenuFallbackAttemptResult = .unavailable
        DispatchQueue.main.sync {
            outcome = pasteViaMenuBar()
        }
        return outcome
    }

    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? {
        guard let element = axInspector.focusedUIElement() else { return nil }
        return PasteMenuFallbackVerificationContext(
            element: element,
            selectedRange: axInspector.selectedRange(for: element),
            valueLength: axInspector.valueLengthForMenuVerification(element: element)
        )
    }

    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        // If we cannot inspect AX state at all, avoid false "paste failed" overlays.
        guard let context else { return true }

        let initialRange = context.selectedRange
        let initialLength = context.valueLength

        var sawObservableAXState = (initialRange != nil || initialLength != nil)
        let deadline = Date().addingTimeInterval(verificationTimeout)

        while Date() < deadline {
            let currentRange = axInspector.selectedRange(for: context.element)
            let currentLength = axInspector.valueLengthForMenuVerification(element: context.element)

            if currentRange != nil || currentLength != nil {
                sawObservableAXState = true
            }

            if let oldRange = initialRange, let currentRange {
                if oldRange.location != currentRange.location || oldRange.length != currentRange.length {
                    return true
                }
            }

            if let oldLength = initialLength, let currentLength, oldLength != currentLength {
                return true
            }

            usleep(useconds_t(verificationPollInterval * 1_000_000))
        }

        // AX metadata is often unavailable in some editors; treat inconclusive checks as success
        // to prevent false recovery prompts after a successful visible paste.
        return !sawObservableAXState
    }

    private func pasteViaMenuBar() -> PasteMenuFallbackAttemptResult {
        // 1. Get the frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return .unavailable }
        let pid = frontApp.processIdentifier
        let accessibilityApp = AXUIElementCreateApplication(pid)

        // 2. Find the Menu Bar
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(accessibilityApp, kAXMenuBarAttribute as CFString, &menuBar)

        guard result == .success, menuBar != nil else {
            #if DEBUG
            print("Fallback Failed: Could not find Menu Bar.")
            #endif
            return .unavailable
        }

        let menuBarElement = menuBar as! AXUIElement

        // Find "Paste" in any menu so this remains locale/layout resilient.
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children)
        guard let menuItems = children as? [AXUIElement] else { return .unavailable }

        for menu in menuItems {
            if let pasteItem = findPasteMenuItem(in: menu) {
                // Skip contexts where Paste exists but is currently disabled.
                var enabled: CFTypeRef?
                if AXUIElementCopyAttributeValue(pasteItem, kAXEnabledAttribute as CFString, &enabled) == .success,
                   let isEnabled = enabled as? Bool, !isEnabled {
                    #if DEBUG
                    print("Fallback Skipped: 'Paste' menu item is disabled (Context doesn't support pasting).")
                    #endif
                    return .unavailable
                }

                #if DEBUG
                print("Found 'Paste' menu item. Triggering AXPress...")
                #endif
                let error = AXUIElementPerformAction(pasteItem, kAXPressAction as CFString)
                if error == .success {
                    #if DEBUG
                    print("Fallback Success: AXPress triggered on Paste menu.")
                    #endif
                    return .actionSucceeded
                } else {
                    #if DEBUG
                    print("Fallback Warning: AXPress returned error \(error.rawValue). Verifying resulting text state...")
                    #endif
                    return .actionErrored
                }
            }
        }

        #if DEBUG
        print("Fallback Failed: Could not find 'Paste' menu item in any menu.")
        #endif
        return .unavailable
    }

    private func findPasteMenuItem(in menu: AXUIElement) -> AXUIElement? {
        // Expected structure: menu bar item -> submenu -> actionable menu entries.

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }

        var subChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
        guard let subItems = subChildren as? [AXUIElement] else { return nil }

        for item in subItems {
            // 1) AXIdentifier is the most stable signal when present.
            var idValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &idValue) == .success,
               let idStr = idValue as? String, idStr == "paste:" {
                return item
            }

            // 2) Cmd+V shortcut is locale-independent.
            var cmdChar: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar) == .success,
               let charStr = cmdChar as? String, charStr == "V" {
                return item
            }

            // 3) Title fallback for environments without identifier/shortcut metadata.
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
            if let titleStr = title as? String, titleStr == "Paste" {
                return item
            }
        }
        return nil
    }
}
