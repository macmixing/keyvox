import Cocoa
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
        if let targetAppIdentity {
            axInspector.prepareApplicationAccessibility(for: targetAppIdentity.pid)
        }
        let capitalizationNormalizedText = capitalizationHeuristics.normalizeLeadingCapitalizationIfNeeded(
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
            var menuFallbackCompletionEvidence: PasteMenuFallbackCompletionEvidence = .none
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
                self.restoreClipboardOnMainThread(from: savedSnapshot, policy: executionPlan.restorePolicy)
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

    // MARK: - Latest Insertion Replacement
    func currentTextMatchesUntouchedInsertion(_ text: String) -> Bool {
        focusedReplacementRange(for: text) != nil
    }

    func replaceUntouchedInsertion(_ currentText: String, with replacementText: String) -> Bool {
        guard let replacement = focusedReplacementRange(for: currentText) else {
            return false
        }

        guard setSelectedRange(replacement.range, for: replacement.element) else {
            return false
        }

        if replaceSelectedRangeViaAccessibility(
            replacement.range,
            with: replacementText,
            in: replacement.element
        ) {
            rememberSuccessfulInsertion(of: replacementText, in: frontmostAppIdentity())
            return true
        }

        if replaceSelectedRangeViaMenuFallback(replacementText) {
            let replacementEndRange = CFRange(
                location: replacement.range.location + (replacementText as NSString).length,
                length: 0
            )
            _ = setSelectedRange(replacementEndRange, for: replacement.element)
            rememberSuccessfulInsertion(of: replacementText, in: frontmostAppIdentity())
            return true
        }

        let originalCaretRange = CFRange(
            location: replacement.range.location + replacement.range.length,
            length: 0
        )
        _ = setSelectedRange(originalCaretRange, for: replacement.element)
        return false
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

    private func focusedReplacementRange(for text: String) -> (element: AXUIElement, range: CFRange)? {
        guard text.isEmpty == false,
              let focusedElement = axInspector.focusedUIElement(),
              let selectedRange = axInspector.selectedRange(for: focusedElement),
              selectedRange.length == 0 else {
            return nil
        }

        guard let currentIdentity = frontmostAppIdentity(),
              let lastInsertionAppIdentity,
              appIdentityMatches(currentIdentity, lastInsertionAppIdentity) else {
            return nil
        }

        let textLength = (text as NSString).length
        guard textLength > 0, selectedRange.location >= textLength else {
            return nil
        }

        let candidateRange = CFRange(
            location: selectedRange.location - textLength,
            length: textLength
        )
        guard axInspector.stringForRange(candidateRange, element: focusedElement) == text else {
            return nil
        }

        return (focusedElement, candidateRange)
    }

    private func replaceSelectedRangeViaAccessibility(
        _ range: CFRange,
        with replacementText: String,
        in element: AXUIElement
    ) -> Bool {
        guard AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacementText as CFTypeRef
        ) == .success else {
            return false
        }

        let replacementLength = (replacementText as NSString).length
        let insertedRange = CFRange(location: range.location, length: replacementLength)
        guard waitForAXReplacement(replacementText, in: insertedRange, element: element) else {
            #if DEBUG
            print("[PasteService] replacement ax verification failed")
            #endif
            return false
        }

        let caretRange = CFRange(location: insertedRange.location + insertedRange.length, length: 0)
        if !setSelectedRange(caretRange, for: element) {
            #if DEBUG
            print("[PasteService] replacement caret collapse failed")
            #endif
        }
        return true
    }

    private func waitForAXReplacement(
        _ replacementText: String,
        in range: CFRange,
        element: AXUIElement
    ) -> Bool {
        var delay: useconds_t = 1_000
        let timeout = Date().addingTimeInterval(0.12)

        while Date() < timeout {
            if axInspector.stringForRange(range, element: element) == replacementText {
                return true
            }
            usleep(delay)
            delay = min(delay * 2, 16_000)
        }

        return axInspector.stringForRange(range, element: element) == replacementText
    }

    private func replaceSelectedRangeViaMenuFallback(_ replacementText: String) -> Bool {
        let savedSnapshot = clipboardAdapter.captureSnapshot()
        clipboardAdapter.setString(replacementText)

        let fallbackResult = menuFallbackCoordinator.executeMenuFallback(
            insertionText: replacementText,
            didAccessibilityInsertText: true,
            targetAppIdentity: frontmostAppIdentity(),
            menuFallbackExecutor: menuFallbackExecutor,
            shouldTrustMenuSuccessWithoutAXVerification: { self.shouldTrustMenuSuccessWithoutAXVerification() },
            setClipboardStringOnMainThread: { self.setClipboardStringOnMainThread($0) },
            typeLeadingSpacesOnMainThread: { self.typeLeadingSpacesOnMainThread(count: $0) }
        )

        restoreClipboardOnMainThread(from: savedSnapshot, policy: .immediate)
        #if DEBUG
        print("[PasteService] replacement menu fallback evidence: \(fallbackResult.completionEvidence)")
        #endif
        return fallbackResult.didMenuFallbackInsert
    }

    private func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        ) == .success
    }

    private func rememberSuccessfulInsertion(of text: String, in appIdentity: PasteAppIdentity?) {
        lastInsertionAppIdentity = appIdentity
        lastInsertionAt = clockNow()
        lastInsertedTrailingCharacter = text.last
        lastInsertedTrailingNonWhitespaceCharacter = text.last { !$0.isWhitespace }
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
            DispatchQueue.main.async(execute: restoreBlock)
        case .afterDelay(let delay):
            #if DEBUG
            print("Clipboard restore policy: delayed \(String(format: "%.3f", delay))s")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreBlock)
        case .deferredToFailureRecovery:
            break
        }
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
