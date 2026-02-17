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

    func startLiveValueChangeVerificationSession(
        processID: pid_t?
    ) -> PasteMenuFallbackLiveVerificationSession? {
        guard let processID else { return nil }
        return PasteMenuFallbackLiveVerificationSession(processID: processID)
    }

    func verifyInsertionUsingLiveValueChangeSession(
        _ session: PasteMenuFallbackLiveVerificationSession?
    ) -> Bool {
        guard let session else { return false }
        return session.waitForSignal(
            timeout: verificationTimeout,
            pollInterval: verificationPollInterval
        )
    }

    func finishLiveValueChangeVerificationSession(
        _ session: PasteMenuFallbackLiveVerificationSession?
    ) {
        session?.close()
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

final class PasteMenuFallbackLiveVerificationSession {
    private let processID: pid_t
    private var observer: AXObserver?
    private let runLoopSource: CFRunLoopSource
    private let runLoop: CFRunLoop
    private var isClosed = false
    private let state = State()

    private static let notifications: [String] = [
        kAXFocusedUIElementChangedNotification as String,
        kAXSelectedTextChangedNotification as String,
        kAXValueChangedNotification as String
    ]

    init?(processID: pid_t) {
        self.processID = processID
        self.runLoop = CFRunLoopGetCurrent()

        var createdObserver: AXObserver?
        let error = AXObserverCreate(processID, { _, element, notification, refcon in
            guard let refcon else { return }
            let session = Unmanaged<PasteMenuFallbackLiveVerificationSession>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            session.handle(notification: notification as String, element: element)
        }, &createdObserver)

        guard error == .success, let createdObserver else { return nil }
        self.observer = createdObserver
        self.runLoopSource = AXObserverGetRunLoopSource(createdObserver)
        CFRunLoopAddSource(runLoop, runLoopSource, .defaultMode)

        let appElement = AXUIElementCreateApplication(processID)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        for notification in Self.notifications {
            _ = AXObserverAddNotification(createdObserver, appElement, notification as CFString, refcon)
        }
    }

    deinit {
        close()
    }

    func waitForSignal(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.hasSignal() {
                close()
                return true
            }
            let until = Date().addingTimeInterval(max(0.01, pollInterval))
            RunLoop.current.run(mode: .default, before: until)
        }

        let hadSignal = state.hasSignal()
        close()
        return hadSignal
    }

    func close() {
        if isClosed { return }
        isClosed = true

        if let observer {
            let appElement = AXUIElementCreateApplication(processID)
            for notification in Self.notifications {
                _ = AXObserverRemoveNotification(observer, appElement, notification as CFString)
            }
            CFRunLoopRemoveSource(runLoop, runLoopSource, .defaultMode)
        }

        observer = nil
    }

    private func handle(notification: String, element: AXUIElement) {
        guard notification == kAXValueChangedNotification as String ||
                notification == kAXSelectedTextChangedNotification as String else {
            return
        }

        guard boolAttribute(element, attribute: kAXFocusedAttribute as String) == true else {
            return
        }

        guard isTextTarget(element) else { return }
        state.markSignal()
    }

    private func isTextTarget(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(element, attribute: kAXRoleAttribute as String)
        if role == "AXTextField" ||
            role == "AXSearchField" ||
            role == "AXTextArea" ||
            role == "AXTextView" ||
            role == "AXComboBox" {
            return true
        }
        return boolAttribute(element, attribute: "AXEditable") == true
    }

    private func boolAttribute(_ element: AXUIElement, attribute: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? Bool
    }

    private func stringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }

    private final class State {
        private let lock = NSLock()
        private var observedSignal = false

        func markSignal() {
            lock.lock()
            observedSignal = true
            lock.unlock()
        }

        func hasSignal() -> Bool {
            lock.lock()
            let value = observedSignal
            lock.unlock()
            return value
        }
    }
}
