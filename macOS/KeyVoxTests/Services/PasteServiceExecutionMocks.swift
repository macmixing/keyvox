import XCTest
@testable import KeyVox

final class MockClipboardAdapter: PasteClipboardAdapting {
    let snapshot: PasteClipboardSnapshot.Snapshot
    private(set) var writes: [String] = []
    private(set) var restoreCalls = 0

    init(snapshot: PasteClipboardSnapshot.Snapshot) {
        self.snapshot = snapshot
    }

    func captureSnapshot() -> PasteClipboardSnapshot.Snapshot {
        snapshot
    }

    func setString(_ text: String) {
        writes.append(text)
    }

    func restore(_ snapshot: PasteClipboardSnapshot.Snapshot) {
        _ = snapshot
        restoreCalls += 1
    }
}

final class MockFailureRecoveryController: PasteFailureRecoveryControlling {
    private(set) var cancelCalls = 0
    private(set) var startCalls = 0

    func cancelActiveRecoveryIfNeeded() {
        cancelCalls += 1
    }

    func startRecovery(restoreClipboard: @escaping () -> Void) {
        _ = restoreClipboard
        startCalls += 1
    }
}

final class MockSpacingHeuristics: PasteSpacingHeuristicApplying {
    struct Input {
        let text: String
        let currentIdentity: PasteAppIdentity?
        let lastInsertionAppIdentity: PasteAppIdentity?
        let lastInsertionAt: Date
        let lastInsertedTrailingCharacter: Character?
    }

    private(set) var inputs: [Input] = []

    func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> String {
        _ = identityMatcher
        inputs.append(
            Input(
                text: text,
                currentIdentity: currentIdentity,
                lastInsertionAppIdentity: lastInsertionAppIdentity,
                lastInsertionAt: lastInsertionAt,
                lastInsertedTrailingCharacter: lastInsertedTrailingCharacter
            )
        )
        return text
    }
}

final class MockCapitalizationHeuristics: PasteCapitalizationHeuristicApplying {
    struct Input {
        let text: String
        let currentIdentity: PasteAppIdentity?
        let lastInsertionAppIdentity: PasteAppIdentity?
        let lastInsertionAt: Date
        let lastInsertedTrailingCharacter: Character?
        let lastInsertedTrailingNonWhitespaceCharacter: Character?
    }

    private let outputText: String
    private(set) var inputs: [Input] = []
    private(set) var preserveChecks: [String] = []

    init(outputText: String) {
        self.outputText = outputText
    }

    func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        lastInsertedTrailingNonWhitespaceCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool,
        shouldPreserveLeadingCapitalization: (String) -> Bool
    ) -> String {
        _ = identityMatcher
        inputs.append(
            Input(
                text: text,
                currentIdentity: currentIdentity,
                lastInsertionAppIdentity: lastInsertionAppIdentity,
                lastInsertionAt: lastInsertionAt,
                lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
                lastInsertedTrailingNonWhitespaceCharacter: lastInsertedTrailingNonWhitespaceCharacter
            )
        )
        preserveChecks.append(text)
        _ = shouldPreserveLeadingCapitalization(text)
        return outputText
    }
}

final class MockAccessibilityInjector: PasteAccessibilityInjecting {
    private let outcome: PasteAccessibilityInjectionOutcome

    init(outcome: PasteAccessibilityInjectionOutcome) {
        self.outcome = outcome
    }

    func injectTextViaAccessibility(_ text: String) -> PasteAccessibilityInjectionOutcome {
        _ = text
        return outcome
    }
}

final class MockMenuFallbackCoordinator: PasteMenuFallbackCoordinating {
    private let result: PasteMenuFallbackExecutionResult
    private(set) var executeCalls = 0
    private(set) var executionThreadWasMain: [Bool] = []
    private(set) var targetAppIdentities: [PasteAppIdentity?] = []

    init(result: PasteMenuFallbackExecutionResult) {
        self.result = result
    }

    func executeMenuFallback(
        insertionText: String,
        didAccessibilityInsertText: Bool,
        targetAppIdentity: PasteAppIdentity?,
        menuFallbackExecutor: PasteMenuFallbackExecuting,
        shouldTrustMenuSuccessWithoutAXVerification: () -> Bool,
        setClipboardStringOnMainThread: (String) -> Void,
        typeLeadingSpacesOnMainThread: (Int) -> Bool
    ) -> PasteMenuFallbackExecutionResult {
        _ = insertionText
        _ = didAccessibilityInsertText
        _ = menuFallbackExecutor
        _ = shouldTrustMenuSuccessWithoutAXVerification
        _ = setClipboardStringOnMainThread
        _ = typeLeadingSpacesOnMainThread
        executeCalls += 1
        executionThreadWasMain.append(Thread.isMainThread)
        targetAppIdentities.append(targetAppIdentity)
        return result
    }
}

final class QueueRecordingUntouchedInsertionReplacer: PasteUntouchedInsertionReplacing {
    let replacementOutcome: PasteUntouchedInsertionReplacementOutcome
    private let element = AXUIElementCreateApplication(getpid())
    private let stateLock = NSLock()
    private var targetRangeLocation = 0
    private let onReplace: (() -> Void)?
    private(set) var targetThreadWasMain: [Bool] = []
    private(set) var replaceThreadWasMain: [Bool] = []
    private(set) var finalizeThreadWasMain: [Bool] = []
    private(set) var moveCaretThreadWasMain: [Bool] = []

    init(
        replacementOutcome: PasteUntouchedInsertionReplacementOutcome,
        onReplace: (() -> Void)? = nil
    ) {
        self.replacementOutcome = replacementOutcome
        self.onReplace = onReplace
    }

    func updateTargetRangeLocation(_ location: Int) {
        stateLock.lock()
        targetRangeLocation = location
        stateLock.unlock()
    }

    func target(for text: String) -> PasteUntouchedInsertionTarget? {
        targetThreadWasMain.append(Thread.isMainThread)
        stateLock.lock()
        let location = targetRangeLocation
        stateLock.unlock()
        return PasteUntouchedInsertionTarget(
            element: element,
            range: CFRange(location: location, length: (text as NSString).length)
        )
    }

    func replace(
        _ currentText: String,
        with replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) -> PasteUntouchedInsertionReplacementOutcome {
        _ = currentText
        _ = replacementText
        _ = target
        replaceThreadWasMain.append(Thread.isMainThread)
        onReplace?()
        return replacementOutcome
    }

    func finalizeMenuFallbackReplacement(
        _ replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) {
        _ = replacementText
        _ = target
        finalizeThreadWasMain.append(Thread.isMainThread)
    }

    func moveCaretToEnd(of replacementText: String, target: PasteUntouchedInsertionTarget) {
        _ = replacementText
        _ = target
        moveCaretThreadWasMain.append(Thread.isMainThread)
    }
}

final class PasteServiceNoopFallbackExecutor: PasteMenuFallbackExecuting {
    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult { .unavailable }
    func liveVerificationProcessIDsOnMainThread(targetProcessID: pid_t?) -> [pid_t] {
        _ = targetProcessID
        return []
    }
    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? { nil }
    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        _ = context
        return false
    }
    func verifyInsertionOutcome(
        using context: PasteMenuFallbackVerificationContext?,
        expectedText: String
    ) -> PasteMenuFallbackVerificationOutcome {
        _ = context
        _ = expectedText
        return .none
    }
    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState? { nil }
    func verifyInsertionWithoutAXContextOnMainThread(initialUndoState: PasteMenuFallbackUndoState?) -> Bool {
        _ = initialUndoState
        return false
    }
    func startLiveValueChangeVerificationSessions(processIDs: [pid_t]) -> [PasteAXLiveSessioning] {
        _ = processIDs
        return []
    }
    func verifyInsertionUsingLiveValueChangeSession(_ sessions: [PasteAXLiveSessioning]) -> Bool {
        _ = sessions
        return false
    }
    func finishLiveValueChangeVerificationSession(_ sessions: [PasteAXLiveSessioning]) {
        _ = sessions
    }
}

final class MockAXInspector: PasteAXInspecting {
    private let stateLock = NSLock()
    private var selectedRangeValue = CFRange(location: 0, length: 0)

    func updateSelectedRange(_ range: CFRange) {
        stateLock.lock()
        selectedRangeValue = range
        stateLock.unlock()
    }

    func focusedInsertionContext() -> PasteInsertionContext? { nil }
    func focusedUIElement() -> AXUIElement? { nil }
    func roleString(for element: AXUIElement) -> String? {
        _ = element
        return nil
    }
    func selectedRange(for element: AXUIElement) -> CFRange? {
        _ = element
        stateLock.lock()
        let range = selectedRangeValue
        stateLock.unlock()
        return range
    }
    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
        _ = range
        _ = element
        return nil
    }
    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? {
        _ = element
        _ = caretLocation
        return nil
    }
    func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        _ = element
        return nil
    }
    func valueStringForMenuVerification(element: AXUIElement) -> String? {
        _ = element
        return nil
    }
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        _ = pid
        _ = maxDepth
        _ = maxNodes
        _ = maxCandidates
        return []
    }
}

final class MutableDateSequence {
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func next() -> Date {
        if dates.isEmpty {
            return Date()
        }
        return dates.removeFirst()
    }
}

final class MutablePasteAppIdentityProvider {
    private let stateLock = NSLock()
    private var identity: PasteAppIdentity?

    init(_ identity: PasteAppIdentity?) {
        self.identity = identity
    }

    func current() -> PasteAppIdentity? {
        stateLock.lock()
        let currentIdentity = identity
        stateLock.unlock()
        return currentIdentity
    }

    func update(_ identity: PasteAppIdentity?) {
        stateLock.lock()
        self.identity = identity
        stateLock.unlock()
    }
}
