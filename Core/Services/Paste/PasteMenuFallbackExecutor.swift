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
        guard let element = axInspector.focusedUIElement() else {
            #if DEBUG
            print("PASTE_VERIFY_CTX: focusedUIElement=nil")
            #endif
            return nil
        }

        let context = PasteMenuFallbackVerificationContext(
            element: element,
            selectedRange: axInspector.selectedRange(for: element),
            valueLength: axInspector.valueLengthForMenuVerification(element: element)
        )

        #if DEBUG
        let role = axInspector.roleString(for: element) ?? "nil"
        print(
            "PASTE_VERIFY_CTX: role=\(role) selectedRange=\(String(describing: context.selectedRange)) " +
            "valueLength=\(String(describing: context.valueLength))"
        )
        #endif

        return context
    }

    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        // Strict mode: no verification context means no evidence of success.
        guard let context else {
            #if DEBUG
            print("PASTE_VERIFY_RESULT: result=false reason=missing_context_strict")
            #endif
            return false
        }

        let initialRange = context.selectedRange
        let initialLength = context.valueLength

        #if DEBUG
        print(
            "PASTE_VERIFY_START: initialRange=\(String(describing: initialRange)) " +
            "initialLength=\(String(describing: initialLength))"
        )
        #endif

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
                    #if DEBUG
                    print("PASTE_VERIFY_RESULT: result=true reason=range_delta old=\(oldRange) new=\(currentRange)")
                    #endif
                    return true
                }
            }

            if let oldLength = initialLength, let currentLength, oldLength != currentLength {
                #if DEBUG
                print("PASTE_VERIFY_RESULT: result=true reason=length_delta old=\(oldLength) new=\(currentLength)")
                #endif
                return true
            }

            usleep(useconds_t(verificationPollInterval * 1_000_000))
        }

        // Timeout without a range/value delta means no verified insertion.
        let result = false
        #if DEBUG
        print(
            "PASTE_VERIFY_RESULT: result=\(result) reason=timeout " +
            "sawObservableAXState=\(sawObservableAXState)"
        )
        #endif
        return result
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
        guard let menuBarElement = frontmostMenuBarElement() else {
            #if DEBUG
            print("Fallback Failed: Could not find Menu Bar.")
            #endif
            return .unavailable
        }

        guard let pasteItem = findPasteMenuItem(inMenuBar: menuBarElement) else {
            #if DEBUG
            print("Fallback Failed: Could not find 'Paste' menu item in any menu.")
            #endif
            return .unavailable
        }

        // Skip contexts where Paste exists but is currently disabled.
        if let isEnabled = menuItemEnabled(pasteItem), !isEnabled {
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

    private func captureUndoState() -> PasteMenuFallbackUndoState? {
        guard let menuBarElement = frontmostMenuBarElement(),
              let undoItem = findUndoMenuItem(inMenuBar: menuBarElement) else {
            #if DEBUG
            print("PASTE_UNDO_CTX: unavailable")
            #endif
            return nil
        }

        let state = PasteMenuFallbackUndoState(
            title: menuItemTitle(undoItem),
            isEnabled: menuItemEnabled(undoItem)
        )

        #if DEBUG
        print(
            "PASTE_UNDO_CTX: title=\(state.title ?? "nil") enabled=\(String(describing: state.isEnabled))"
        )
        #endif
        return state
    }

    private func verifyInsertionWithoutAXContext(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool {
        guard let initialUndoState else {
            #if DEBUG
            print("PASTE_VERIFY_RESULT: result=false reason=missing_undo_baseline")
            #endif
            return false
        }

        let deadline = Date().addingTimeInterval(verificationTimeout)
        while Date() < deadline {
            if let currentUndoState = captureUndoState(),
               undoStateChanged(from: initialUndoState, to: currentUndoState) {
                #if DEBUG
                print(
                    "PASTE_VERIFY_RESULT: result=true reason=undo_state_delta " +
                    "oldTitle=\(initialUndoState.title ?? "nil") oldEnabled=\(String(describing: initialUndoState.isEnabled)) " +
                    "newTitle=\(currentUndoState.title ?? "nil") newEnabled=\(String(describing: currentUndoState.isEnabled))"
                )
                #endif
                return true
            }

            usleep(useconds_t(verificationPollInterval * 1_000_000))
        }

        #if DEBUG
        print(
            "PASTE_VERIFY_RESULT: result=false reason=undo_state_unchanged_timeout " +
            "initialTitle=\(initialUndoState.title ?? "nil") initialEnabled=\(String(describing: initialUndoState.isEnabled))"
        )
        #endif
        return false
    }

    private func undoStateChanged(
        from oldState: PasteMenuFallbackUndoState,
        to newState: PasteMenuFallbackUndoState
    ) -> Bool {
        oldState.title != newState.title || oldState.isEnabled != newState.isEnabled
    }

    private func frontmostMenuBarElement() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let accessibilityApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var menuBarRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            accessibilityApp,
            kAXMenuBarAttribute as CFString,
            &menuBarRef
        )
        guard result == .success, let menuBarRef else { return nil }
        guard CFGetTypeID(menuBarRef) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(menuBarRef, to: AXUIElement.self)
    }

    private func findPasteMenuItem(inMenuBar menuBar: AXUIElement) -> AXUIElement? {
        findMenuItem(inMenuBar: menuBar) { item in
            if menuItemIdentifier(item) == "paste:" { return true }
            if menuItemCmdChar(item) == "V" { return true }
            if menuItemTitle(item) == "Paste" { return true }
            return false
        }
    }

    private func findUndoMenuItem(inMenuBar menuBar: AXUIElement) -> AXUIElement? {
        findMenuItem(inMenuBar: menuBar) { item in
            if menuItemIdentifier(item) == "undo:" { return true }

            if menuItemCmdChar(item) == "Z" {
                let modifiers = menuItemCmdModifiers(item)
                let hasShiftModifier = (modifiers ?? 0) & 1 != 0
                let hasNoCommandModifier = (modifiers ?? 0) & 8 != 0
                if !hasShiftModifier && !hasNoCommandModifier {
                    return true
                }
            }

            if let title = menuItemTitle(item), title.hasPrefix("Undo") {
                return true
            }

            return false
        }
    }

    private func findMenuItem(
        inMenuBar menuBar: AXUIElement,
        matching predicate: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        var topLevelChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &topLevelChildren)
        guard let menuBarItems = topLevelChildren as? [AXUIElement] else { return nil }

        for menuBarItem in menuBarItems {
            var barItemChildren: CFTypeRef?
            AXUIElementCopyAttributeValue(menuBarItem, kAXChildrenAttribute as CFString, &barItemChildren)
            guard let children = barItemChildren as? [AXUIElement], let subMenu = children.first else { continue }

            var menuChildren: CFTypeRef?
            AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &menuChildren)
            guard let menuItems = menuChildren as? [AXUIElement] else { continue }

            for item in menuItems where predicate(item) {
                return item
            }
        }

        return nil
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
}
