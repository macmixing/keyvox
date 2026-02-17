import Cocoa

class PasteService {
    static let shared = PasteService()
    // Serialize insertion side effects (AX writes, menu fallback, clipboard restore scheduling).
    private let pasteQueue = DispatchQueue(label: "com.KeyVox.paste", qos: .userInteractive)

    // Heuristic memory for consecutive dictation when AX metadata is incomplete.
    private let heuristicTTL: TimeInterval = 10
    private let restoreDelayAfterMenuFallback: TimeInterval = 0.8
    private let restoreDelayAfterAccessibilityInjection: TimeInterval = 0.25
    private let menuFallbackVerificationTimeout: TimeInterval = 0.6
    private let menuFallbackVerificationPollInterval: TimeInterval = 0.05
    private var lastInsertionAppIdentity: PasteAppIdentity?
    private var lastInsertionAt: Date = .distantPast
    private var lastInsertedTrailingCharacter: Character?

    private let axInspector = PasteAXInspector()
    private lazy var accessibilityInjector = PasteAccessibilityInjector(axInspector: axInspector)
    private lazy var menuFallbackExecutor = PasteMenuFallbackExecutor(
        axInspector: axInspector,
        verificationTimeout: menuFallbackVerificationTimeout,
        verificationPollInterval: menuFallbackVerificationPollInterval
    )
    private lazy var menuFallbackCoordinator = PasteMenuFallbackCoordinator()
    private lazy var spacingHeuristics = PasteSpacingHeuristics(
        axInspector: axInspector,
        heuristicTTL: heuristicTTL
    )

    // MARK: - Entry Point
    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        cancelActiveRecoveryOnMainThread()

        let targetAppIdentity = frontmostAppIdentity()
        let insertionText = spacingHeuristics.applySmartLeadingSeparatorIfNeeded(
            to: text,
            currentIdentity: targetAppIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            identityMatcher: appIdentityMatches
        )

        // Preserve full clipboard fidelity before writing insertion payload.
        let pasteboard = NSPasteboard.general
        let savedSnapshot = PasteClipboardSnapshot.captureCurrentPasteboardItems(pasteboard)

        // Menu fallback uses Cmd+V semantics, so payload must be in the clipboard.
        pasteboard.clearContents()
        pasteboard.setString(insertionText, forType: .string)

        #if DEBUG
        print("Clipboard updated (Backup). Starting Surgical Accessibility Injection...")
        #endif

        pasteQueue.async {
            let injectionOutcome = self.accessibilityInjector.injectTextViaAccessibility(insertionText)
            let needsMenuPasteFallback: Bool
            let didAccessibilityInsertText: Bool

            switch injectionOutcome {
            case .verifiedSuccess:
                needsMenuPasteFallback = false
                didAccessibilityInsertText = true
                #if DEBUG
                print("SUCCESS: Text injected surgically via Accessibility API.")
                #endif
            case .softSuccessNeedsFallback:
                needsMenuPasteFallback = true
                didAccessibilityInsertText = false
            case .failureNeedsFallback:
                needsMenuPasteFallback = true
                didAccessibilityInsertText = false
            }

            var didMenuFallbackInsert = false
            var suppressFirstWarmupFailureWarning = false
            if needsMenuPasteFallback {
                let menuFallbackExecution = self.menuFallbackCoordinator.executeMenuFallback(
                    insertionText: insertionText,
                    didAccessibilityInsertText: didAccessibilityInsertText,
                    targetAppIdentity: targetAppIdentity,
                    menuFallbackExecutor: self.menuFallbackExecutor,
                    shouldTrustMenuSuccessWithoutAXVerification: { self.shouldTrustMenuSuccessWithoutAXVerification() },
                    setClipboardStringOnMainThread: { self.setClipboardStringOnMainThread($0) },
                    typeLeadingSpacesOnMainThread: { self.typeLeadingSpacesOnMainThread(count: $0) }
                )
                didMenuFallbackInsert = menuFallbackExecution.didMenuFallbackInsert
                suppressFirstWarmupFailureWarning = menuFallbackExecution.suppressFirstWarmupFailureWarning
            }

            if didAccessibilityInsertText || didMenuFallbackInsert {
                self.rememberSuccessfulInsertion(of: insertionText, in: targetAppIdentity)
            }

            if suppressFirstWarmupFailureWarning || !Self.shouldStartFailureRecovery(
                didAccessibilityInsertText: didAccessibilityInsertText,
                didMenuFallbackInsert: didMenuFallbackInsert
            ) {
                // Menu-driven paste can complete slightly after AX calls.
                let restoreDelay: TimeInterval = needsMenuPasteFallback ? self.restoreDelayAfterMenuFallback : self.restoreDelayAfterAccessibilityInjection
                self.restoreClipboardOnMainThread(from: savedSnapshot, delay: restoreDelay)
            } else {
                self.startFailureRecoveryOnMainThread(savedSnapshot: savedSnapshot)
            }
        }
    }

    // MARK: - List Formatting Target
    func preferredListRenderModeForFocusedElement() -> ListRenderMode {
        guard let focusedElement = axInspector.focusedUIElement(),
              let role = axInspector.roleString(for: focusedElement) else {
            return .multiline
        }

        let bundleID = frontmostAppIdentity()?.bundleID
        return Self.listRenderMode(forAXRole: role, bundleID: bundleID)
    }

    static func listRenderMode(forAXRole role: String?) -> ListRenderMode {
        listRenderMode(forAXRole: role, bundleID: nil)
    }

    static func listRenderMode(forAXRole role: String?, bundleID: String?) -> ListRenderMode {
        PastePolicies.listRenderMode(forAXRole: role, bundleID: bundleID)
    }

    private func shouldTrustMenuSuccessWithoutAXVerification() -> Bool {
        PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: frontmostAppIdentity()?.bundleID)
    }

    // MARK: - Heuristic Identity / Memory
    private func frontmostAppIdentity() -> PasteAppIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let rawBundleID = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = (rawBundleID?.isEmpty == false) ? rawBundleID : nil
        return PasteAppIdentity(bundleID: bundleID, pid: app.processIdentifier)
    }

    private func appIdentityMatches(_ lhs: PasteAppIdentity, _ rhs: PasteAppIdentity) -> Bool {
        if let lhsBundleID = lhs.bundleID, let rhsBundleID = rhs.bundleID {
            return lhsBundleID == rhsBundleID
        }
        return lhs.pid == rhs.pid
    }

    private func rememberSuccessfulInsertion(of text: String, in appIdentity: PasteAppIdentity?) {
        lastInsertionAppIdentity = appIdentity
        lastInsertionAt = Date()
        lastInsertedTrailingCharacter = text.last
    }

    private func cancelActiveRecoveryOnMainThread() {
        if Thread.isMainThread {
            Task { @MainActor in
                PasteFailureRecoveryCoordinator.shared.cancelActiveRecoveryIfNeeded()
            }
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            Task { @MainActor in
                PasteFailureRecoveryCoordinator.shared.cancelActiveRecoveryIfNeeded()
                semaphore.signal()
            }
        }
        semaphore.wait()
    }

    private func startFailureRecoveryOnMainThread(
        savedSnapshot: PasteClipboardSnapshot.Snapshot
    ) {
        let restoreClosure = { [savedSnapshot] in
            PasteClipboardSnapshot.restore(savedSnapshot)
        }

        if Thread.isMainThread {
            Task { @MainActor in
                PasteFailureRecoveryCoordinator.shared.startRecovery(restoreClipboard: restoreClosure)
            }
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            Task { @MainActor in
                PasteFailureRecoveryCoordinator.shared.startRecovery(restoreClipboard: restoreClosure)
                semaphore.signal()
            }
        }
        semaphore.wait()
    }

    private func restoreClipboardOnMainThread(
        from savedSnapshot: PasteClipboardSnapshot.Snapshot,
        delay: TimeInterval
    ) {
        let restoreBlock = { [savedSnapshot] in
            PasteClipboardSnapshot.restore(savedSnapshot)
        }

        if Thread.isMainThread {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreBlock)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreBlock)
    }

    static func shouldStartFailureRecovery(
        didAccessibilityInsertText: Bool,
        didMenuFallbackInsert: Bool
    ) -> Bool {
        PastePolicies.shouldStartFailureRecovery(
            didAccessibilityInsertText: didAccessibilityInsertText,
            didMenuFallbackInsert: didMenuFallbackInsert
        )
    }

    // MARK: - Testable Decision Helpers
    static func didMenuFallbackInsertForEmptyClipboardPayload(
        didTypeLeadingSpaces: Bool
    ) -> Bool {
        PasteMenuFallbackCoordinator.didMenuFallbackInsertForEmptyClipboardPayload(
            didTypeLeadingSpaces: didTypeLeadingSpaces
        )
    }

    static func didMenuFallbackInsertForMenuAttempt(
        attempt: PasteMenuFallbackAttemptResult,
        trustMenuSuccessWithoutAXVerification: Bool,
        verificationPassed: Bool
    ) -> Bool {
        PasteMenuFallbackCoordinator.didMenuFallbackInsertForMenuAttempt(
            attempt: attempt,
            trustMenuSuccessWithoutAXVerification: trustMenuSuccessWithoutAXVerification,
            verificationPassed: verificationPassed
        )
    }

    static func shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
        attempt: PasteMenuFallbackAttemptResult?,
        didAccessibilityInsertText: Bool,
        didMenuFallbackInsert: Bool,
        isFirstMenuSuccessAttemptForProcess: Bool
    ) -> Bool {
        PasteMenuFallbackCoordinator.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
            attempt: attempt,
            didAccessibilityInsertText: didAccessibilityInsertText,
            didMenuFallbackInsert: didMenuFallbackInsert,
            isFirstMenuSuccessAttemptForProcess: isFirstMenuSuccessAttemptForProcess
        )
    }

    static func hasElectronFramework(processID: pid_t) -> Bool {
        PasteMenuFallbackCoordinator.hasElectronFramework(processID: processID)
    }

    static func containsElectronFramework(frameworkNames: [String]) -> Bool {
        PasteMenuFallbackCoordinator.containsElectronFramework(frameworkNames: frameworkNames)
    }

    private func setClipboardStringOnMainThread(_ text: String) {
        if Thread.isMainThread {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return
        }

        DispatchQueue.main.sync {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }

    private func typeLeadingSpacesOnMainThread(count: Int) -> Bool {
        if Thread.isMainThread {
            return typeLeadingSpaces(count: count)
        }

        var didSucceed = false
        DispatchQueue.main.sync {
            didSucceed = typeLeadingSpaces(count: count)
        }
        return didSucceed
    }

    private func typeLeadingSpaces(count: Int) -> Bool {
        guard count > 0 else { return true }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        for _ in 0..<count {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false) else {
                return false
            }
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }
}
