import Cocoa

protocol PasteMenuFallbackExecuting {
    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult
    func frontmostProcessIDOnMainThread() -> pid_t?
    func captureVerificationContext() -> PasteMenuFallbackVerificationContext?
    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool
    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState?
    func verifyInsertionWithoutAXContextOnMainThread(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool
    func startLiveValueChangeVerificationSession(
        processID: pid_t?
    ) -> PasteAXLiveSessioning?
    func verifyInsertionUsingLiveValueChangeSession(
        _ session: PasteAXLiveSessioning?
    ) -> Bool
    func finishLiveValueChangeVerificationSession(
        _ session: PasteAXLiveSessioning?
    )
}

final class PasteMenuFallbackExecutor: PasteMenuFallbackExecuting {
    private let axInspector: PasteAXInspecting
    private let menuScanner: PasteMenuScanner
    private let verificationTimeout: TimeInterval
    private let verificationPollInterval: TimeInterval

    init(
        axInspector: PasteAXInspecting,
        verificationTimeout: TimeInterval,
        verificationPollInterval: TimeInterval,
        menuScanner: PasteMenuScanner = PasteMenuScanner()
    ) {
        self.axInspector = axInspector
        self.menuScanner = menuScanner
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

    func frontmostProcessIDOnMainThread() -> pid_t? {
        if Thread.isMainThread {
            return frontmostProcessID()
        }

        var processID: pid_t?
        DispatchQueue.main.sync {
            processID = frontmostProcessID()
        }
        return processID
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
    ) -> PasteAXLiveSessioning? {
        guard let processID else { return nil }
        return PasteAXLiveSession(processID: processID)
    }

    func verifyInsertionUsingLiveValueChangeSession(
        _ session: PasteAXLiveSessioning?
    ) -> Bool {
        guard let session else { return false }
        return session.waitForSignal(
            timeout: verificationTimeout,
            pollInterval: verificationPollInterval
        )
    }

    func finishLiveValueChangeVerificationSession(
        _ session: PasteAXLiveSessioning?
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

        switch menuScanner.findPasteItem(in: menuItems) {
        case .enabled(let pasteItem):
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
        case .disabled:
            #if DEBUG
            print("Fallback Skipped: 'Paste' menu item is disabled (Context doesn't support pasting).")
            #endif
            return .unavailable
        case .notFound:
            #if DEBUG
            print("Fallback Failed: Could not find 'Paste' menu item in any menu.")
            #endif
            return .unavailable
        }
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

        if let undoItem = menuScanner.findUndoItem(in: menuItems) {
            return PasteMenuFallbackUndoState(
                title: menuScanner.menuItemTitle(undoItem),
                isEnabled: menuScanner.menuItemEnabled(undoItem)
            )
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

    private func elementHash(_ element: AXUIElement) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque())
    }

    private func frontmostProcessID() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }
}
