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
            if needsMenuPasteFallback {
                #if DEBUG
                print("Accessibility injection failed/skipped. Triggering Menu Bar Paste...")
                #endif
                let verificationContext = self.menuFallbackExecutor.captureVerificationContext()
                let initialUndoState = self.menuFallbackExecutor.captureUndoStateOnMainThread()
                var textForMenuPaste = insertionText
                var didTypeLeadingSpaces = false

                // Some apps normalize leading spaces on paste. If AX injection fully failed,
                // type leading spaces as key events, then paste the remaining text.
                if !didAccessibilityInsertText {
                    let transport = self.menuFallbackTransport(for: insertionText)
                    textForMenuPaste = transport.textToPaste

                    if transport.leadingSpacesToType > 0 {
                        didTypeLeadingSpaces = self.typeLeadingSpacesOnMainThread(count: transport.leadingSpacesToType)
                    }
                }

                if textForMenuPaste != insertionText {
                    self.setClipboardStringOnMainThread(textForMenuPaste)
                }

                if textForMenuPaste.isEmpty {
                    didMenuFallbackInsert = didTypeLeadingSpaces
                } else {
                    switch self.menuFallbackExecutor.pasteViaMenuBarOnMainThread() {
                    case .unavailable:
                        didMenuFallbackInsert = false
                    case .actionSucceeded:
                        let trustWithoutAXVerification = self.shouldTrustMenuSuccessWithoutAXVerification()
                        #if DEBUG
                        print(
                            "PASTE_TRUST_POLICY: bundleID=\(targetAppIdentity?.bundleID ?? "nil") " +
                            "trustWithoutAX=\(trustWithoutAXVerification)"
                        )
                        #endif
                        if trustWithoutAXVerification {
                            // Some apps (notably iMessage) can retarget Paste to the composer even
                            // when the currently focused AX element is not the final insertion target.
                            didMenuFallbackInsert = true
                        } else if verificationContext != nil {
                            // Prefer direct AX delta verification when available.
                            didMenuFallbackInsert = self.menuFallbackExecutor.verifyInsertion(using: verificationContext)
                        } else {
                            // AX focus can be unavailable in some editors (notably Electron on Ventura).
                            // In that case, use Undo state transition as a deterministic insertion signal.
                            didMenuFallbackInsert = self.menuFallbackExecutor.verifyInsertionWithoutAXContextOnMainThread(
                                initialUndoState: initialUndoState
                            )
                        }
                    case .actionErrored:
                        if verificationContext != nil {
                            didMenuFallbackInsert = self.menuFallbackExecutor.verifyInsertion(using: verificationContext)
                        } else {
                            didMenuFallbackInsert = self.menuFallbackExecutor.verifyInsertionWithoutAXContextOnMainThread(
                                initialUndoState: initialUndoState
                            )
                        }
                    }
                }
            }

            if didAccessibilityInsertText || didMenuFallbackInsert {
                self.rememberSuccessfulInsertion(of: insertionText, in: targetAppIdentity)
            }

            let shouldStartFailureRecovery = Self.shouldStartFailureRecovery(
                didAccessibilityInsertText: didAccessibilityInsertText,
                didMenuFallbackInsert: didMenuFallbackInsert
            )

            #if DEBUG
            print(
                "PASTE_DECISION: axInsert=\(didAccessibilityInsertText) menuInsert=\(didMenuFallbackInsert) " +
                "needsMenuFallback=\(needsMenuPasteFallback) shouldStartRecovery=\(shouldStartFailureRecovery)"
            )
            #endif

            if !shouldStartFailureRecovery {
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

    // MARK: - Menu Transport
    private func menuFallbackTransport(for text: String) -> PasteMenuFallbackTransport {
        let leadingSpaces = text.prefix { $0 == " " }.count
        guard leadingSpaces > 0 else {
            return PasteMenuFallbackTransport(leadingSpacesToType: 0, textToPaste: text)
        }

        let remainingText = String(text.dropFirst(leadingSpaces))
        return PasteMenuFallbackTransport(leadingSpacesToType: leadingSpaces, textToPaste: remainingText)
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
