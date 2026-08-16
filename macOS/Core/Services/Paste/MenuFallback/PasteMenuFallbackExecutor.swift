import Cocoa
import Darwin

protocol PasteMenuFallbackExecuting {
    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult
    func liveVerificationProcessIDsOnMainThread(targetProcessID: pid_t?) -> [pid_t]
    func captureVerificationContext() -> PasteMenuFallbackVerificationContext?
    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool
    func verifyInsertionOutcome(
        using context: PasteMenuFallbackVerificationContext?,
        expectedText: String
    ) -> PasteMenuFallbackVerificationOutcome
    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState?
    func verifyInsertionWithoutAXContextOnMainThread(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool
    func startLiveValueChangeVerificationSessions(
        processIDs: [pid_t]
    ) -> [PasteAXLiveSessioning]
    func hasLiveValueChangeSignal(_ sessions: [PasteAXLiveSessioning]) -> Bool
    func verifyInsertionUsingLiveValueChangeSession(
        _ sessions: [PasteAXLiveSessioning]
    ) -> Bool
    func finishLiveValueChangeVerificationSession(
        _ sessions: [PasteAXLiveSessioning]
    )
}

extension PasteMenuFallbackExecuting {
    func hasLiveValueChangeSignal(_ sessions: [PasteAXLiveSessioning]) -> Bool {
        sessions.contains(where: { $0.hasSignal() })
    }
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

    func liveVerificationProcessIDsOnMainThread(targetProcessID: pid_t?) -> [pid_t] {
        if Thread.isMainThread {
            return liveVerificationProcessIDs(targetProcessID: targetProcessID)
        }

        var processIDs: [pid_t] = []
        DispatchQueue.main.sync {
            processIDs = liveVerificationProcessIDs(targetProcessID: targetProcessID)
        }
        return processIDs
    }

    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        var snapshots: [PasteMenuFallbackVerificationSnapshot] = []
        var seen = Set<UInt>()

        if let focused = axInspector.focusedUIElement() {
            let focusedSnapshot = snapshot(for: focused)
            let key = elementHash(focused)
            if !seen.contains(key),
               focusedSnapshot.hasVerificationSignal {
                seen.insert(key)
                snapshots.append(focusedSnapshot)
            }
        }

        if !snapshots.isEmpty {
            return PasteMenuFallbackVerificationContext(snapshots: snapshots)
        }

        for processID in verificationProcessIDs(for: frontApp) {
            let discovered = axInspector.candidateVerificationElements(
                for: processID,
                maxDepth: 14,
                maxNodes: 8_000,
                maxCandidates: 16
            )

            for element in discovered {
                let candidateSnapshot = snapshot(for: element)
                guard candidateSnapshot.hasVerificationSignal else { continue }
                let key = elementHash(element)
                if seen.contains(key) { continue }
                seen.insert(key)
                snapshots.append(candidateSnapshot)
            }

            if !snapshots.isEmpty {
                return PasteMenuFallbackVerificationContext(snapshots: snapshots)
            }
        }

        guard !snapshots.isEmpty else { return nil }
        return PasteMenuFallbackVerificationContext(snapshots: snapshots)
    }

    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        verifyInsertionOutcome(using: context, expectedText: "").didObserveInsertion
    }

    func verifyInsertionOutcome(
        using context: PasteMenuFallbackVerificationContext?,
        expectedText: String
    ) -> PasteMenuFallbackVerificationOutcome {
        guard let context, !context.snapshots.isEmpty else { return .none }
        let deadline = Date().addingTimeInterval(verificationTimeout)
        var didObserveStructuralInsertion = false

        while Date() < deadline {
            for snapshot in context.snapshots {
                let currentRange = axInspector.selectedRange(for: snapshot.element)
                let currentLength = axInspector.valueLengthForMenuVerification(element: snapshot.element)
                let currentValue = axInspector.valueStringForMenuVerification(element: snapshot.element)

                if expectedPayloadObserved(
                    expectedText,
                    snapshot: snapshot,
                    currentRange: currentRange,
                    currentValue: currentValue
                ) {
                    return .expectedPayloadObserved
                }

                if let oldRange = snapshot.selectedRange, let currentRange {
                    if oldRange.location != currentRange.location || oldRange.length != currentRange.length {
                        didObserveStructuralInsertion = true
                    }
                }

                if let oldLength = snapshot.valueLength, let currentLength, oldLength != currentLength {
                    didObserveStructuralInsertion = true
                }
            }

            usleep(useconds_t(verificationPollInterval * 1_000_000))
        }

        return didObserveStructuralInsertion ? .structuralInsertionObserved : .none
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

        return verifyInsertionWithoutAXContextFromBackground(initialUndoState: initialUndoState)
    }

    func startLiveValueChangeVerificationSessions(
        processIDs: [pid_t]
    ) -> [PasteAXLiveSessioning] {
        processIDs.compactMap { PasteAXLiveSession(processID: $0) }
    }

    func verifyInsertionUsingLiveValueChangeSession(
        _ sessions: [PasteAXLiveSessioning]
    ) -> Bool {
        guard !sessions.isEmpty else { return false }

        let deadline = Date().addingTimeInterval(verificationTimeout)
        while Date() < deadline {
            if sessions.contains(where: { $0.hasSignal() }) {
                return true
            }
            waitForNextVerificationPoll()
        }

        return sessions.contains(where: { $0.hasSignal() })
    }

    func finishLiveValueChangeVerificationSession(
        _ sessions: [PasteAXLiveSessioning]
    ) {
        sessions.forEach { $0.close() }
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

            waitForNextVerificationPoll()
        }

        return false
    }

    private func verifyInsertionWithoutAXContextFromBackground(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool {
        guard let initialUndoState else { return false }

        let deadline = Date().addingTimeInterval(verificationTimeout)
        while Date() < deadline {
            if let currentUndoState = captureUndoStateOnMainThread(),
               undoStateChanged(from: initialUndoState, to: currentUndoState) {
                return true
            }

            waitForNextVerificationPoll()
        }

        return false
    }

    private func snapshot(for element: AXUIElement) -> PasteMenuFallbackVerificationSnapshot {
        PasteMenuFallbackVerificationSnapshot(
            element: element,
            selectedRange: axInspector.selectedRange(for: element),
            valueLength: axInspector.valueLengthForMenuVerification(element: element),
            valueText: axInspector.valueStringForMenuVerification(element: element)
        )
    }

    private func expectedPayloadObserved(
        _ expectedText: String,
        snapshot: PasteMenuFallbackVerificationSnapshot,
        currentRange: CFRange?,
        currentValue: String?
    ) -> Bool {
        guard !expectedText.isEmpty else { return false }
        let expectedLength = (expectedText as NSString).length

        if let currentRange,
           currentRange.location >= expectedLength,
           let rangeText = axInspector.stringForRange(
                CFRange(location: currentRange.location - expectedLength, length: expectedLength),
                element: snapshot.element
           ),
           rangeText == expectedText {
            return true
        }

        guard let currentValue else { return false }
        let currentNSString = currentValue as NSString

        if let currentRange,
           currentRange.location >= expectedLength {
            let insertedRange = NSRange(
                location: currentRange.location - expectedLength,
                length: expectedLength
            )
            if NSMaxRange(insertedRange) <= currentNSString.length,
               currentNSString.substring(with: insertedRange) == expectedText {
                return true
            }
        }

        guard let originalValue = snapshot.valueText else { return false }
        if let selectedRange = snapshot.selectedRange {
            let replacementRange = NSRange(location: selectedRange.location, length: selectedRange.length)
            let originalNSString = originalValue as NSString
            if replacementRange.location >= 0,
               NSMaxRange(replacementRange) <= originalNSString.length {
                let expectedValue = originalNSString.replacingCharacters(
                    in: replacementRange,
                    with: expectedText
                )
                if currentValue == expectedValue {
                    return true
                }
            }
        }

        return currentValue != originalValue
            && !originalValue.contains(expectedText)
            && currentValue.contains(expectedText)
    }

    private func undoStateChanged(
        from oldState: PasteMenuFallbackUndoState,
        to newState: PasteMenuFallbackUndoState
    ) -> Bool {
        oldState.title != newState.title || oldState.isEnabled != newState.isEnabled
    }

    private func waitForNextVerificationPoll() {
        let interval = max(0.001, verificationPollInterval)
        if Thread.isMainThread {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(interval))
        } else {
            usleep(useconds_t(interval * 1_000_000))
        }
    }

    private func elementHash(_ element: AXUIElement) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque())
    }

    private func liveVerificationProcessIDs(targetProcessID: pid_t?) -> [pid_t] {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            return verificationProcessIDs(for: frontApp)
        }

        if let targetProcessID {
            return [targetProcessID]
        }

        return []
    }

    private func verificationProcessIDs(for frontApp: NSRunningApplication) -> [pid_t] {
        var processIDs = [frontApp.processIdentifier]
        var seenProcessIDs = Set(processIDs)
        guard let frontBundleURL = frontApp.bundleURL else { return processIDs }

        let frontBundlePath = frontBundleURL.standardizedFileURL.path
        let supportPrefix = frontBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Support", isDirectory: true)
            .standardizedFileURL
            .path + "/"
        let bundlePrefix = frontBundlePath + "/"

        let relatedSupportProcessIDs = NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.processIdentifier != frontApp.processIdentifier,
                      let bundlePath = app.bundleURL?.standardizedFileURL.path else {
                    return false
                }
                return bundlePath.hasPrefix(supportPrefix)
            }
            .map(\.processIdentifier)
            .sorted()

        for processID in relatedSupportProcessIDs
            where seenProcessIDs.insert(processID).inserted && hasAccessibilitySurface(processID: processID) {
            processIDs.append(processID)
        }

        for processID in executableProcessIDs(withPathPrefix: bundlePrefix)
            where seenProcessIDs.insert(processID).inserted && hasAccessibilitySurface(processID: processID) {
            processIDs.append(processID)
        }

        return processIDs
    }

    private func hasAccessibilitySurface(processID: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(processID)
        var focusedWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
           focusedWindowRef != nil {
            return true
        }

        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           !windows.isEmpty {
            return true
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement],
           !children.isEmpty {
            return true
        }

        return false
    }

    private func executableProcessIDs(withPathPrefix pathPrefix: String) -> [pid_t] {
        let processCount = proc_listallpids(nil, 0)
        guard processCount > 0 else { return [] }

        var processIDs = [pid_t](repeating: 0, count: Int(processCount) + 64)
        let bytes = proc_listallpids(&processIDs, Int32(processIDs.count * MemoryLayout<pid_t>.stride))
        guard bytes > 0 else { return [] }

        let returnedCount = Int(bytes) / MemoryLayout<pid_t>.stride
        return processIDs
            .prefix(returnedCount)
            .filter { processID in
                guard processID > 0,
                      let executablePath = executablePath(for: processID) else {
                    return false
                }
                return executablePath.hasPrefix(pathPrefix)
            }
            .sorted()
    }

    private func executablePath(for processID: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4_096)
        let byteCount = proc_pidpath(processID, &buffer, UInt32(buffer.count))
        guard byteCount > 0 else { return nil }
        return String(cString: buffer)
    }
}
