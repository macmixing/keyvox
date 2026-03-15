import Cocoa
import KeyVoxCore

class PasteService {
    static let shared = PasteService()

    private let pasteQueue: DispatchQueue
    private let restoreDelayAfterMenuFallback: TimeInterval
    private let restoreDelayAfterAccessibilityInjection: TimeInterval
    private var lastInsertionAppIdentity: PasteAppIdentity?
    private var lastInsertionAt: Date = .distantPast
    private var lastInsertedTrailingCharacter: Character?

    private let axInspector: PasteAXInspecting
    private let accessibilityInjector: PasteAccessibilityInjecting
    private let menuFallbackExecutor: PasteMenuFallbackExecuting
    private let menuFallbackCoordinator: PasteMenuFallbackCoordinating
    private let dictionaryCasingStore: PasteDictionaryCasingStore
    private let capitalizationHeuristics: PasteCapitalizationHeuristicApplying
    private let spacingHeuristics: PasteSpacingHeuristicApplying
    private let clipboardAdapter: PasteClipboardAdapting
    private let failureRecoveryController: PasteFailureRecoveryControlling
    private let frontmostAppIdentityProvider: () -> PasteAppIdentity?
    private let clockNow: () -> Date

    init(
        pasteQueue: DispatchQueue = DispatchQueue(label: "com.KeyVox.paste", qos: .userInteractive),
        heuristicTTL: TimeInterval = 10,
        restoreDelayAfterMenuFallback: TimeInterval = 0.8,
        restoreDelayAfterAccessibilityInjection: TimeInterval = 0.25,
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
        capitalizationHeuristics: PasteCapitalizationHeuristicApplying? = nil,
        spacingHeuristics: PasteSpacingHeuristicApplying? = nil
    ) {
        self.pasteQueue = pasteQueue
        self.restoreDelayAfterMenuFallback = restoreDelayAfterMenuFallback
        self.restoreDelayAfterAccessibilityInjection = restoreDelayAfterAccessibilityInjection
        self.frontmostAppIdentityProvider = frontmostAppIdentityProvider
            ?? { PasteService.defaultFrontmostAppIdentity() }
        self.clockNow = clockNow
        self.clipboardAdapter = clipboardAdapter
        self.failureRecoveryController = failureRecoveryController

        self.axInspector = axInspector
        self.accessibilityInjector = accessibilityInjector
            ?? PasteAccessibilityInjector(axInspector: axInspector)
        self.menuFallbackExecutor = menuFallbackExecutor
            ?? PasteMenuFallbackExecutor(
                axInspector: axInspector,
                verificationTimeout: menuFallbackVerificationTimeout,
                verificationPollInterval: menuFallbackVerificationPollInterval
            )
        self.menuFallbackCoordinator = menuFallbackCoordinator
        self.dictionaryCasingStore = dictionaryCasingStore
        self.capitalizationHeuristics = capitalizationHeuristics
            ?? PasteCapitalizationHeuristics(
                axInspector: axInspector,
                heuristicTTL: heuristicTTL,
                clockNow: clockNow
            )
        self.spacingHeuristics = spacingHeuristics
            ?? PasteSpacingHeuristics(
                axInspector: axInspector,
                heuristicTTL: heuristicTTL
            )
    }

    // MARK: - Entry Point
    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        cancelActiveRecoveryOnMainThread()

        let targetAppIdentity = frontmostAppIdentity()
        let capitalizationNormalizedText = capitalizationHeuristics.normalizeLeadingCapitalizationIfNeeded(
            in: text,
            currentIdentity: targetAppIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            identityMatcher: appIdentityMatches,
            shouldPreserveLeadingCapitalization: { [dictionaryCasingStore] incomingText in
                dictionaryCasingStore.shouldPreserveLeadingCapitalization(in: incomingText)
            }
        )
        let insertionText = spacingHeuristics.applySmartLeadingSeparatorIfNeeded(
            to: capitalizationNormalizedText,
            currentIdentity: targetAppIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            identityMatcher: appIdentityMatches
        )

        // Preserve full clipboard fidelity before writing insertion payload.
        let savedSnapshot = clipboardAdapter.captureSnapshot()

        // Menu fallback uses Cmd+V semantics, so payload must be in the clipboard.
        clipboardAdapter.setString(insertionText)

        #if DEBUG
        print("Clipboard updated (Backup). Starting Surgical Accessibility Injection...")
        #endif

        pasteQueue.async {
            let injectionOutcome = self.accessibilityInjector.injectTextViaAccessibility(insertionText)
            let accessibilityDecision = PasteAccessibilityExecutionDecision.from(injectionOutcome)

            #if DEBUG
            if case .verifiedSuccess = injectionOutcome {
                print("SUCCESS: Text injected surgically via Accessibility API.")
            }
            #endif

            var didMenuFallbackInsert = false
            var suppressFirstWarmupFailureWarning = false
            if accessibilityDecision.needsMenuFallback {
                let menuFallbackExecution = self.menuFallbackCoordinator.executeMenuFallback(
                    insertionText: insertionText,
                    didAccessibilityInsertText: accessibilityDecision.didAccessibilityInsertText,
                    targetAppIdentity: targetAppIdentity,
                    menuFallbackExecutor: self.menuFallbackExecutor,
                    shouldTrustMenuSuccessWithoutAXVerification: { self.shouldTrustMenuSuccessWithoutAXVerification() },
                    setClipboardStringOnMainThread: { self.setClipboardStringOnMainThread($0) },
                    typeLeadingSpacesOnMainThread: { self.typeLeadingSpacesOnMainThread(count: $0) }
                )
                didMenuFallbackInsert = menuFallbackExecution.didMenuFallbackInsert
                suppressFirstWarmupFailureWarning = menuFallbackExecution.suppressFirstWarmupFailureWarning
            }

            let executionPlan = PasteServiceExecutionPlan.build(
                didAccessibilityInsertText: accessibilityDecision.didAccessibilityInsertText,
                didMenuFallbackInsert: didMenuFallbackInsert,
                usedMenuFallbackPath: accessibilityDecision.needsMenuFallback,
                suppressFirstWarmupFailureWarning: suppressFirstWarmupFailureWarning,
                shouldStartFailureRecovery: Self.shouldStartFailureRecovery(
                    didAccessibilityInsertText: accessibilityDecision.didAccessibilityInsertText,
                    didMenuFallbackInsert: didMenuFallbackInsert
                ),
                restoreDelayAfterMenuFallback: self.restoreDelayAfterMenuFallback,
                restoreDelayAfterAccessibilityInjection: self.restoreDelayAfterAccessibilityInjection
            )

            if executionPlan.shouldRememberInsertion {
                self.rememberSuccessfulInsertion(of: insertionText, in: targetAppIdentity)
            }

            if executionPlan.shouldStartFailureRecovery {
                self.startFailureRecoveryOnMainThread(savedSnapshot: savedSnapshot)
            } else {
                let delay = executionPlan.restoreDelay ?? self.restoreDelayAfterAccessibilityInjection
                self.restoreClipboardOnMainThread(from: savedSnapshot, delay: delay)
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

    private func rememberSuccessfulInsertion(of text: String, in appIdentity: PasteAppIdentity?) {
        lastInsertionAppIdentity = appIdentity
        lastInsertionAt = clockNow()
        lastInsertedTrailingCharacter = text.last
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
        delay: TimeInterval
    ) {
        let restoreBlock = { [clipboardAdapter] in
            clipboardAdapter.restore(savedSnapshot)
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
            clipboardAdapter.setString(text)
            return
        }

        DispatchQueue.main.sync {
            clipboardAdapter.setString(text)
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
