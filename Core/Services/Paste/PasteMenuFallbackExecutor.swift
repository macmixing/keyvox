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

    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState? {
        if Thread.isMainThread {
            return captureUndoState()
        }

        var state: PasteMenuFallbackUndoState?
        DispatchQueue.main.sync {
            state = captureUndoState()
        }
        return state
    }

    func verifyInsertionWithoutAXContextOnMainThread(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool {
        if Thread.isMainThread {
            return verifyInsertionWithoutAXContext(initialUndoState: initialUndoState)
        }

        var result = false
        DispatchQueue.main.sync {
            result = verifyInsertionWithoutAXContext(initialUndoState: initialUndoState)
        }
        return result
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

    private func captureUndoState() -> PasteMenuFallbackUndoState? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let accessibilityApp = AXUIElementCreateApplication(pid)

        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(accessibilityApp, kAXMenuBarAttribute as CFString, &menuBar)
        guard result == .success, let menuBar else { return nil }
        guard CFGetTypeID(menuBar) == AXUIElementGetTypeID() else { return nil }
        let menuBarElement = unsafeBitCast(menuBar, to: AXUIElement.self)

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children)
        guard let menuItems = children as? [AXUIElement] else { return nil }

        for menu in menuItems {
            if let undoItem = findUndoMenuItem(in: menu) {
                return PasteMenuFallbackUndoState(
                    title: menuItemTitle(undoItem),
                    isEnabled: menuItemEnabled(undoItem)
                )
            }
        }

        return nil
    }

    private func verifyInsertionWithoutAXContext(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool {
        guard let initialUndoState else { return false }

        let deadline = Date().addingTimeInterval(verificationTimeout)
        while Date() < deadline {
            if let currentUndoState = captureUndoState(),
               undoStateChanged(from: initialUndoState, to: currentUndoState) {
                return true
            }

            usleep(useconds_t(verificationPollInterval * 1_000_000))
        }

        return false
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

    private func findUndoMenuItem(in menu: AXUIElement) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)
        guard let items = children as? [AXUIElement], let subMenu = items.first else { return nil }

        var subChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &subChildren)
        guard let subItems = subChildren as? [AXUIElement] else { return nil }

        for item in subItems {
            if menuItemIdentifier(item) == "undo:" {
                return item
            }

            if menuItemCmdChar(item) == "Z" {
                let modifiers = menuItemCmdModifiers(item)
                let hasShiftModifier = (modifiers ?? 0) & 1 != 0
                let hasNoCommandModifier = (modifiers ?? 0) & 8 != 0
                if !hasShiftModifier && !hasNoCommandModifier {
                    return item
                }
            }

            if let title = menuItemTitle(item), title.hasPrefix("Undo") {
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

    private func undoStateChanged(
        from oldState: PasteMenuFallbackUndoState,
        to newState: PasteMenuFallbackUndoState
    ) -> Bool {
        oldState.title != newState.title || oldState.isEnabled != newState.isEnabled
    }

    private func menuItemIdentifier(_ item: AXUIElement) -> String? {
        var idValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &idValue) == .success else { return nil }
        return idValue as? String
    }

    private func menuItemCmdChar(_ item: AXUIElement) -> String? {
        var cmdChar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar) == .success,
              let charStr = cmdChar as? String else {
            return nil
        }
        return charStr.uppercased()
    }

    private func menuItemCmdModifiers(_ item: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &value) == .success else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private func menuItemTitle(_ item: AXUIElement) -> String? {
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }

    private func menuItemEnabled(_ item: AXUIElement) -> Bool? {
        var enabled: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXEnabledAttribute as CFString, &enabled) == .success else {
            return nil
        }
        return enabled as? Bool
    }

    private func elementHash(_ element: AXUIElement) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque())
    }
}
