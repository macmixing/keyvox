import Cocoa

final class PasteMenuFallbackExecutor {
    private let axInspector: PasteAXInspecting
    private let verificationTimeout: TimeInterval
    private let verificationPollInterval: TimeInterval

    init(
        axInspector: PasteAXInspecting,
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
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        var snapshots: [PasteMenuFallbackVerificationSnapshot] = []
        var seen = Set<UInt>()

        if let focused = axInspector.focusedUIElement() {
            let key = elementHash(focused)
            if !seen.contains(key) {
                seen.insert(key)
                snapshots.append(snapshot(for: focused))
            }
        }

        let discovered = axInspector.candidateVerificationElements(
            for: frontApp.processIdentifier,
            maxDepth: 14,
            maxNodes: 8_000,
            maxCandidates: 16
        )

        for element in discovered {
            let key = elementHash(element)
            if seen.contains(key) { continue }
            seen.insert(key)
            snapshots.append(snapshot(for: element))
        }

        guard !snapshots.isEmpty else { return nil }
        return PasteMenuFallbackVerificationContext(snapshots: snapshots)
    }

    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        guard let context, !context.snapshots.isEmpty else { return false }
        let deadline = Date().addingTimeInterval(verificationTimeout)

        while Date() < deadline {
            for snapshot in context.snapshots {
                let currentRange = axInspector.selectedRange(for: snapshot.element)
                let currentLength = axInspector.valueLengthForMenuVerification(element: snapshot.element)

                if let oldRange = snapshot.selectedRange, let currentRange {
                    if oldRange.location != currentRange.location || oldRange.length != currentRange.length {
                        return true
                    }
                }

                if let oldLength = snapshot.valueLength, let currentLength, oldLength != currentLength {
                    return true
                }
            }

            usleep(useconds_t(verificationPollInterval * 1_000_000))
        }

        return false
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

    private func snapshot(for element: AXUIElement) -> PasteMenuFallbackVerificationSnapshot {
        PasteMenuFallbackVerificationSnapshot(
            element: element,
            selectedRange: axInspector.selectedRange(for: element),
            valueLength: axInspector.valueLengthForMenuVerification(element: element)
        )
    }

    private func elementHash(_ element: AXUIElement) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque())
    }
}
