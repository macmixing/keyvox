import Cocoa
import Carbon.HIToolbox
import KeyVoxCore

class PasteService {
    static let shared = PasteService()

    private let pasteQueue: DispatchQueue
    private let restoreDelayAfterMenuFallback: TimeInterval
    private var lastInsertionAppIdentity: PasteAppIdentity?
    private var lastInsertionAt: Date = .distantPast
    private var lastInsertedTrailingCharacter: Character?
    private var lastInsertedTrailingNonWhitespaceCharacter: Character?

    private let axInspector: PasteAXInspecting
    private let accessibilityInjector: PasteAccessibilityInjecting
    private let untouchedInsertionReplacer: PasteUntouchedInsertionReplacing
    private let untouchedInsertionAuthorizer: PasteUntouchedInsertionAuthorizer
    private let menuFallbackExecutor: PasteMenuFallbackExecuting
    private let menuFallbackCoordinator: PasteMenuFallbackCoordinating
    private let dictionaryCasingStore: PasteDictionaryCasingStore
    private let capitalizationCoordinator: PasteCapitalizationCoordinating
    private let spacingCoordinator: PasteSpacingCoordinating
    private let clipboardAdapter: PasteClipboardAdapting
    private let failureRecoveryController: PasteFailureRecoveryControlling
    private let frontmostAppIdentityProvider: () -> PasteAppIdentity?
    private let clockNow: () -> Date

    init(
        pasteQueue: DispatchQueue = DispatchQueue(label: "com.KeyVox.paste", qos: .userInteractive),
        heuristicTTL: TimeInterval = 10,
        restoreDelayAfterMenuFallback: TimeInterval = 0.8,
        menuFallbackVerificationTimeout: TimeInterval = 0.6,
        menuFallbackVerificationPollInterval: TimeInterval = 0.05,
        frontmostAppIdentityProvider: (() -> PasteAppIdentity?)? = nil,
        clockNow: @escaping () -> Date = Date.init,
        clipboardAdapter: PasteClipboardAdapting = SystemPasteboardAdapter(),
        failureRecoveryController: PasteFailureRecoveryControlling = MainThreadPasteFailureRecoveryController(),
        axInspector: PasteAXInspecting = PasteAXInspector(),
        accessibilityInjector: PasteAccessibilityInjecting? = nil,
        menuFallbackExecutor: PasteMenuFallbackExecuting? = nil,
        menuFallbackCoordinator: PasteMenuFallbackCoordinating = PasteMenuFallbackCoordinator(),
        dictionaryCasingStore: PasteDictionaryCasingStore = PasteDictionaryCasingStore(),
        capitalizationCoordinator: PasteCapitalizationCoordinating? = nil,
        spacingCoordinator: PasteSpacingCoordinating? = nil,
        untouchedInsertionReplacer: PasteUntouchedInsertionReplacing? = nil
    ) {
        let resolvedFrontmostAppIdentityProvider = frontmostAppIdentityProvider
            ?? { PasteService.defaultFrontmostAppIdentity() }
        let resolvedUntouchedInsertionReplacer = untouchedInsertionReplacer
            ?? PasteUntouchedInsertionReplacer(axInspector: axInspector)

        self.pasteQueue = pasteQueue
        self.restoreDelayAfterMenuFallback = restoreDelayAfterMenuFallback
        self.frontmostAppIdentityProvider = resolvedFrontmostAppIdentityProvider
        self.clockNow = clockNow
        self.clipboardAdapter = clipboardAdapter
        self.failureRecoveryController = failureRecoveryController

        self.axInspector = axInspector
        self.accessibilityInjector = accessibilityInjector
            ?? PasteAccessibilityInjector(axInspector: axInspector)
        self.untouchedInsertionReplacer = resolvedUntouchedInsertionReplacer
        self.untouchedInsertionAuthorizer = PasteUntouchedInsertionAuthorizer(
            axInspector: axInspector,
            replacer: resolvedUntouchedInsertionReplacer,
            appIdentityProvider: resolvedFrontmostAppIdentityProvider,
            pendingResolutionTimeout: restoreDelayAfterMenuFallback
        )
        self.menuFallbackExecutor = menuFallbackExecutor
            ?? PasteMenuFallbackExecutor(
                axInspector: axInspector,
                verificationTimeout: menuFallbackVerificationTimeout,
                verificationPollInterval: menuFallbackVerificationPollInterval
            )
        self.menuFallbackCoordinator = menuFallbackCoordinator
        self.dictionaryCasingStore = dictionaryCasingStore
        self.capitalizationCoordinator = capitalizationCoordinator
            ?? PasteCapitalizationCoordinator(
                axInspector: axInspector,
                heuristicTTL: heuristicTTL,
                clockNow: clockNow
            )
        self.spacingCoordinator = spacingCoordinator
            ?? PasteSpacingCoordinator(
                axInspector: axInspector,
                heuristicTTL: heuristicTTL
            )
    }

    // MARK: - Entry Point
    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        cancelActiveRecoveryOnMainThread()

        let targetAppIdentity = frontmostAppIdentity()
        if let targetAppIdentity {
            axInspector.prepareApplicationAccessibility(for: targetAppIdentity.pid)
        }
        let capitalizationNormalizedText = capitalizationCoordinator.normalizeLeadingCapitalizationIfNeeded(
            in: text,
            currentIdentity: targetAppIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            lastInsertedTrailingNonWhitespaceCharacter: lastInsertedTrailingNonWhitespaceCharacter,
            identityMatcher: appIdentityMatches,
            shouldPreserveLeadingCapitalization: { [dictionaryCasingStore] incomingText in
                dictionaryCasingStore.shouldPreserveLeadingCapitalization(in: incomingText)
            }
        )
        #if DEBUG
        logNormalizationStage(
            "capitalizationNormalized",
            input: text,
            output: capitalizationNormalizedText
        )
        #endif
        let insertionText = spacingCoordinator.applySmartLeadingSeparatorIfNeeded(
            to: capitalizationNormalizedText,
            currentIdentity: targetAppIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            identityMatcher: appIdentityMatches
        )
        #if DEBUG
        logNormalizationStage(
            "spacingNormalized",
            input: capitalizationNormalizedText,
            output: insertionText
        )
        #endif

        pasteQueue.async {
            let savedSnapshot = self.beginClipboardTransactionOnMainThread(
                payload: insertionText
            )
            #if DEBUG
            print("Clipboard updated (Backup). Starting Surgical Accessibility Injection...")
            #endif
            self.untouchedInsertionAuthorizer.invalidate()
            let injectionOutcome = self.accessibilityInjector.injectTextViaAccessibility(insertionText)
            let accessibilityDecision = PasteAccessibilityExecutionDecision.from(injectionOutcome)

            #if DEBUG
            if case .verifiedSuccess = injectionOutcome {
                print("SUCCESS: Text injected surgically via Accessibility API.")
            }
            #endif

            var didMenuFallbackInsert = false
            var suppressFirstWarmupFailureWarning = false
            var menuFallbackCompletionEvidence: PasteMenuFallbackCompletionEvidence = .none
            if accessibilityDecision.needsMenuFallback {
                let menuFallbackExecution = self.menuFallbackCoordinator.executeMenuFallback(
                    insertionText: insertionText,
                    didAccessibilityInsertText: accessibilityDecision.didAccessibilityInsertText,
                    targetAppIdentity: targetAppIdentity,
                    menuFallbackExecutor: self.menuFallbackExecutor,
                    shouldTrustMenuSuccessWithoutAXVerification: { self.shouldTrustMenuSuccessWithoutAXVerification() },
                    setClipboardStringOnMainThread: { self.setClipboardStringOnMainThread($0) },
                    executeLeadingSpacePasteOnMainThread: {
                        self.executeLeadingSpacePasteOnMainThread(count: $0)
                    }
                )
                didMenuFallbackInsert = menuFallbackExecution.didMenuFallbackInsert
                suppressFirstWarmupFailureWarning = menuFallbackExecution.suppressFirstWarmupFailureWarning
                menuFallbackCompletionEvidence = menuFallbackExecution.completionEvidence
                #if DEBUG
                print("Menu fallback completion evidence: \(menuFallbackCompletionEvidence)")
                #endif
            }

            let executionPlan = PasteServiceExecutionPlan.build(
                didAccessibilityInsertText: accessibilityDecision.didAccessibilityInsertText,
                didMenuFallbackInsert: didMenuFallbackInsert,
                usedMenuFallbackPath: accessibilityDecision.needsMenuFallback,
                menuFallbackCompletionEvidence: menuFallbackCompletionEvidence,
                suppressFirstWarmupFailureWarning: suppressFirstWarmupFailureWarning,
                shouldStartFailureRecovery: Self.shouldStartFailureRecovery(
                    didAccessibilityInsertText: accessibilityDecision.didAccessibilityInsertText,
                    didMenuFallbackInsert: didMenuFallbackInsert
                ),
                restoreDelayAfterMenuFallback: self.restoreDelayAfterMenuFallback
            )

            if executionPlan.shouldRememberInsertion {
                self.rememberSuccessfulInsertion(of: insertionText, in: targetAppIdentity)
            }

            if executionPlan.shouldStartFailureRecovery {
                self.startFailureRecoveryOnMainThread(savedSnapshot: savedSnapshot)
            } else {
                self.restoreClipboardOnMainThread(
                    from: savedSnapshot,
                    policy: executionPlan.restorePolicy
                )
            }
        }
    }

    #if DEBUG
    private func logNormalizationStage(_ stage: String, input: String, output: String) {
        print("[KVXPaste] \(stage) changed=\(input != output) text=\(output)")
    }
    #endif

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

    // MARK: - Latest Insertion Replacement
    func currentTextMatchesUntouchedInsertion(_ text: String) async -> Bool {
        await performOnPasteQueue {
            self.currentTextMatchesUntouchedInsertionOnPasteQueue(text)
        }
    }

    func replaceUntouchedInsertion(_ currentText: String, with replacementText: String) async -> Bool {
        await performOnPasteQueue {
            self.replaceUntouchedInsertionOnPasteQueue(currentText, with: replacementText)
        }
    }

    private func currentTextMatchesUntouchedInsertionOnPasteQueue(_ text: String) -> Bool {
        untouchedInsertionAuthorizer.authorization(for: text) != nil
    }

    private func replaceUntouchedInsertionOnPasteQueue(
        _ currentText: String,
        with replacementText: String
    ) -> Bool {
        guard let token = untouchedInsertionAuthorizer.authorization(for: currentText) else {
            return false
        }
        let target = token.target

        switch untouchedInsertionReplacer.replace(
            currentText,
            with: replacementText,
            target: target
        ) {
        case .succeeded:
            rememberSuccessfulReplacement(of: replacementText, authorizedBy: token)
            return true
        case .menuFallbackAllowed:
            guard frontmostAppIdentity()?.pid == token.appIdentity.pid else {
                untouchedInsertionAuthorizer.invalidate()
                return false
            }
            let didReplace = replaceSelectedRangeViaMenuFallback(
                replacementText,
                targetAppIdentity: token.appIdentity
            )
            if didReplace {
                untouchedInsertionReplacer.finalizeMenuFallbackReplacement(
                    replacementText,
                    target: target
                )
                rememberSuccessfulReplacement(of: replacementText, authorizedBy: token)
                return true
            }
            untouchedInsertionReplacer.moveCaretToEnd(of: currentText, target: target)
            untouchedInsertionAuthorizer.invalidate()
            return false
        case .failed:
            untouchedInsertionAuthorizer.invalidate()
            return false
        }
    }

    private func performOnPasteQueue<T>(_ operation: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            pasteQueue.async {
                continuation.resume(returning: operation())
            }
        }
    }

    // MARK: - Heuristic Identity / Memory
    private static func defaultFrontmostAppIdentity() -> PasteAppIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let rawBundleID = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = (rawBundleID?.isEmpty == false) ? rawBundleID : nil
        return PasteAppIdentity(bundleID: bundleID, pid: app.processIdentifier)
    }

    private func frontmostAppIdentity() -> PasteAppIdentity? {
        frontmostAppIdentityProvider()
    }

    private func appIdentityMatches(_ lhs: PasteAppIdentity, _ rhs: PasteAppIdentity) -> Bool {
        if let lhsBundleID = lhs.bundleID, let rhsBundleID = rhs.bundleID {
            return lhsBundleID == rhsBundleID
        }
        return lhs.pid == rhs.pid
    }

    private func replaceSelectedRangeViaMenuFallback(
        _ replacementText: String,
        targetAppIdentity: PasteAppIdentity
    ) -> Bool {
        let savedSnapshot = clipboardAdapter.captureSnapshot()
        clipboardAdapter.setString(replacementText)

        let fallbackResult = menuFallbackCoordinator.executeMenuFallback(
            insertionText: replacementText,
            didAccessibilityInsertText: true,
            targetAppIdentity: targetAppIdentity,
            menuFallbackExecutor: menuFallbackExecutor,
            shouldTrustMenuSuccessWithoutAXVerification: {
                PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(
                    bundleID: targetAppIdentity.bundleID
                )
            },
            setClipboardStringOnMainThread: { self.setClipboardStringOnMainThread($0) },
            executeLeadingSpacePasteOnMainThread: {
                self.executeLeadingSpacePasteOnMainThread(count: $0)
            }
        )

        restoreClipboardOnMainThread(from: savedSnapshot, policy: .immediate)
        #if DEBUG
        print("[PasteService] replacement menu fallback evidence: \(fallbackResult.completionEvidence)")
        #endif
        return fallbackResult.didMenuFallbackInsert
    }

    private func rememberSuccessfulInsertion(of text: String, in appIdentity: PasteAppIdentity?) {
        lastInsertionAppIdentity = appIdentity
        lastInsertionAt = clockNow()
        lastInsertedTrailingCharacter = text.last
        lastInsertedTrailingNonWhitespaceCharacter = text.last { !$0.isWhitespace }
        untouchedInsertionAuthorizer.recordInsertion(text, appIdentity: appIdentity)
    }

    private func rememberSuccessfulReplacement(
        of text: String,
        authorizedBy token: PasteUntouchedInsertionToken
    ) {
        lastInsertionAppIdentity = token.appIdentity
        lastInsertionAt = clockNow()
        lastInsertedTrailingCharacter = text.last
        lastInsertedTrailingNonWhitespaceCharacter = text.last { !$0.isWhitespace }
        untouchedInsertionAuthorizer.recordReplacement(text, authorizedBy: token)
    }

    private func cancelActiveRecoveryOnMainThread() {
        failureRecoveryController.cancelActiveRecoveryIfNeeded()
    }

    private func startFailureRecoveryOnMainThread(
        savedSnapshot: PasteClipboardSnapshot.Snapshot
    ) {
        let restoreClosure = { [clipboardAdapter] in
            clipboardAdapter.restore(savedSnapshot)
        }

        failureRecoveryController.startRecovery(restoreClipboard: restoreClosure)
    }

    private func restoreClipboardOnMainThread(
        from savedSnapshot: PasteClipboardSnapshot.Snapshot,
        policy: PasteClipboardRestorePolicy
    ) {
        let restoreBlock = { [clipboardAdapter] in
            clipboardAdapter.restore(savedSnapshot)
        }

        switch policy {
        case .immediate:
            #if DEBUG
            print("Clipboard restore policy: immediate")
            #endif
            if Thread.isMainThread {
                restoreBlock()
            } else {
                DispatchQueue.main.sync(execute: restoreBlock)
            }
        case .afterDelay(let delay):
            #if DEBUG
            print("Clipboard restore policy: delayed \(String(format: "%.3f", delay))s")
            #endif
            if Thread.isMainThread {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreBlock)
            } else {
                Thread.sleep(forTimeInterval: delay)
                DispatchQueue.main.sync(execute: restoreBlock)
            }
        case .deferredToFailureRecovery:
            break
        }
    }

    private func beginClipboardTransactionOnMainThread(
        payload: String
    ) -> PasteClipboardSnapshot.Snapshot {
        let beginTransaction = { [clipboardAdapter] in
            let snapshot = clipboardAdapter.captureSnapshot()
            clipboardAdapter.setString(payload)
            return snapshot
        }

        if Thread.isMainThread {
            return beginTransaction()
        }

        return DispatchQueue.main.sync(execute: beginTransaction)
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
            clipboardAdapter.setString(text)
            return
        }

        DispatchQueue.main.sync {
            clipboardAdapter.setString(text)
        }
    }

    private func executeLeadingSpacePasteOnMainThread(count: Int) -> Bool {
        if Thread.isMainThread {
            return executeLeadingSpacePaste(count: count)
        }

        var didSucceed = false
        DispatchQueue.main.sync {
            didSucceed = executeLeadingSpacePaste(count: count)
        }
        return didSucceed
    }

    private func executeLeadingSpacePaste(count: Int) -> Bool {
        guard count > 0 else { return true }
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        var events: [CGEvent] = []

        for _ in 0..<count {
            guard let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Space),
                keyDown: true
            ),
                  let keyUp = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: CGKeyCode(kVK_Space),
                    keyDown: false
                  ) else {
                return false
            }
            events.append(contentsOf: [keyDown, keyUp])
        }

        guard let commandDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_Command),
            keyDown: true
        ),
              let pasteDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
              ),
              let pasteUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
              ),
              let commandUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Command),
                keyDown: false
              ) else {
            return false
        }

        commandDown.flags = .maskCommand
        pasteDown.flags = .maskCommand
        pasteUp.flags = .maskCommand
        events.append(contentsOf: [commandDown, pasteDown, pasteUp, commandUp])
        events.forEach { $0.post(tap: .cghidEventTap) }

        return true
    }
}
