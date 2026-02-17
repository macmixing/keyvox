import XCTest
@testable import KeyVox

@MainActor
final class PasteServiceExecutionTests: XCTestCase {
    private static var retainedServices: [PasteService] = []

    func testAccessibilityVerifiedSuccessRestoresClipboardAndSkipsRecovery() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let spacing = MockSpacingHeuristics()
        let injector = MockAccessibilityInjector(outcome: .verifiedSuccess)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: nil,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0.5,
            restoreDelayAfterAccessibilityInjection: 0
        )

        service.pasteText("hello")

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }

        XCTAssertEqual(recovery.cancelCalls, 1)
        XCTAssertEqual(recovery.startCalls, 0)
        XCTAssertEqual(coordinator.executeCalls, 0)
        XCTAssertEqual(clipboard.writes, ["hello"])
    }

    func testMenuFallbackSuccessRestoresClipboardAndSkipsRecovery() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let spacing = MockSpacingHeuristics()
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: true,
            menuAttempt: .actionSucceeded,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0,
            restoreDelayAfterAccessibilityInjection: 999
        )

        service.pasteText("hello")

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }

        XCTAssertEqual(recovery.startCalls, 0)
        XCTAssertEqual(coordinator.executeCalls, 1)
    }

    func testMenuFallbackFailureStartsRecoveryWhenNotSuppressed() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: .actionErrored,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            spacing: MockSpacingHeuristics(),
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0,
            restoreDelayAfterAccessibilityInjection: 0
        )

        service.pasteText("hello")

        try await waitForCondition {
            recovery.startCalls == 1
        }

        XCTAssertEqual(clipboard.restoreCalls, 0)
    }

    func testMenuFallbackFailureSuppressedRestoresClipboardWithoutRecovery() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: .actionSucceeded,
            suppressFirstWarmupFailureWarning: true
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            spacing: MockSpacingHeuristics(),
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0,
            restoreDelayAfterAccessibilityInjection: 0
        )

        service.pasteText("hello")

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }

        XCTAssertEqual(recovery.startCalls, 0)
    }

    func testSuccessfulInsertionMemoryFeedsNextSpacingDecision() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let spacing = MockSpacingHeuristics()
        let injector = MockAccessibilityInjector(outcome: .verifiedSuccess)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: nil,
            suppressFirstWarmupFailureWarning: false
        ))

        let firstTimestamp = Date(timeIntervalSince1970: 100)
        let secondTimestamp = Date(timeIntervalSince1970: 200)
        let timestamps = MutableDateSequence([firstTimestamp, secondTimestamp])

        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0,
            restoreDelayAfterAccessibilityInjection: 0,
            clockNow: { timestamps.next() }
        )

        service.pasteText("hello.")
        try await waitForCondition { clipboard.restoreCalls == 1 }

        service.pasteText("next")
        try await waitForCondition { clipboard.restoreCalls == 2 }

        XCTAssertEqual(spacing.inputs.count, 2)
        let second = spacing.inputs[1]
        XCTAssertEqual(second.lastInsertionAppIdentity?.bundleID, "com.example.app")
        XCTAssertEqual(second.lastInsertionAppIdentity?.pid, 99)
        XCTAssertEqual(second.lastInsertionAt, firstTimestamp)
        XCTAssertEqual(second.lastInsertedTrailingCharacter, ".")
    }

    func testExecutionPlanBuildsExpectedBranchOutcomes() {
        let restorePlan = PasteServiceExecutionPlan.build(
            didAccessibilityInsertText: true,
            didMenuFallbackInsert: false,
            usedMenuFallbackPath: false,
            suppressFirstWarmupFailureWarning: false,
            shouldStartFailureRecovery: false,
            restoreDelayAfterMenuFallback: 0.8,
            restoreDelayAfterAccessibilityInjection: 0.25
        )
        XCTAssertTrue(restorePlan.shouldRememberInsertion)
        XCTAssertFalse(restorePlan.shouldStartFailureRecovery)
        XCTAssertEqual(restorePlan.restoreDelay ?? -1, 0.25, accuracy: 0.0001)

        let recoveryPlan = PasteServiceExecutionPlan.build(
            didAccessibilityInsertText: false,
            didMenuFallbackInsert: false,
            usedMenuFallbackPath: true,
            suppressFirstWarmupFailureWarning: false,
            shouldStartFailureRecovery: true,
            restoreDelayAfterMenuFallback: 0.8,
            restoreDelayAfterAccessibilityInjection: 0.25
        )
        XCTAssertFalse(recoveryPlan.shouldRememberInsertion)
        XCTAssertTrue(recoveryPlan.shouldStartFailureRecovery)
        XCTAssertNil(recoveryPlan.restoreDelay)
    }

    private func makeService(
        clipboard: MockClipboardAdapter,
        recovery: MockFailureRecoveryController,
        spacing: MockSpacingHeuristics,
        injector: MockAccessibilityInjector,
        coordinator: MockMenuFallbackCoordinator,
        restoreDelayAfterMenuFallback: TimeInterval,
        restoreDelayAfterAccessibilityInjection: TimeInterval,
        clockNow: @escaping () -> Date = Date.init
    ) -> PasteService {
        let queue = DispatchQueue(label: "PasteServiceExecutionTests.queue")
        let service = PasteService(
            pasteQueue: queue,
            heuristicTTL: 10,
            restoreDelayAfterMenuFallback: restoreDelayAfterMenuFallback,
            restoreDelayAfterAccessibilityInjection: restoreDelayAfterAccessibilityInjection,
            menuFallbackVerificationTimeout: 0.01,
            menuFallbackVerificationPollInterval: 0.001,
            frontmostAppIdentityProvider: { PasteAppIdentity(bundleID: "com.example.app", pid: 99) },
            clockNow: clockNow,
            clipboardAdapter: clipboard,
            failureRecoveryController: recovery,
            axInspector: MockAXInspector(),
            accessibilityInjector: injector,
            menuFallbackExecutor: NoopFallbackExecutor(),
            menuFallbackCoordinator: coordinator,
            spacingHeuristics: spacing
        )
        Self.retainedServices.append(service)
        return service
    }
}

private final class MockClipboardAdapter: PasteClipboardAdapting {
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

private final class MockFailureRecoveryController: PasteFailureRecoveryControlling {
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

private final class MockSpacingHeuristics: PasteSpacingHeuristicApplying {
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

private final class MockAccessibilityInjector: PasteAccessibilityInjecting {
    private let outcome: PasteAccessibilityInjectionOutcome

    init(outcome: PasteAccessibilityInjectionOutcome) {
        self.outcome = outcome
    }

    func injectTextViaAccessibility(_ text: String) -> PasteAccessibilityInjectionOutcome {
        _ = text
        return outcome
    }
}

private final class MockMenuFallbackCoordinator: PasteMenuFallbackCoordinating {
    private let result: PasteMenuFallbackExecutionResult
    private(set) var executeCalls = 0

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
        _ = targetAppIdentity
        _ = menuFallbackExecutor
        _ = shouldTrustMenuSuccessWithoutAXVerification
        _ = setClipboardStringOnMainThread
        _ = typeLeadingSpacesOnMainThread
        executeCalls += 1
        return result
    }
}

private final class NoopFallbackExecutor: PasteMenuFallbackExecuting {
    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult { .unavailable }
    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? { nil }
    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        _ = context
        return false
    }
    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState? { nil }
    func verifyInsertionWithoutAXContextOnMainThread(initialUndoState: PasteMenuFallbackUndoState?) -> Bool {
        _ = initialUndoState
        return false
    }
    func startLiveValueChangeVerificationSession(processID: pid_t?) -> PasteAXLiveSessioning? {
        _ = processID
        return nil
    }
    func verifyInsertionUsingLiveValueChangeSession(_ session: PasteAXLiveSessioning?) -> Bool {
        _ = session
        return false
    }
    func finishLiveValueChangeVerificationSession(_ session: PasteAXLiveSessioning?) {
        _ = session
    }
}

private final class MockAXInspector: PasteAXInspecting {
    func focusedInsertionContext() -> PasteInsertionContext? { nil }
    func focusedUIElement() -> AXUIElement? { nil }
    func roleString(for element: AXUIElement) -> String? {
        _ = element
        return nil
    }
    func selectedRange(for element: AXUIElement) -> CFRange? {
        _ = element
        return nil
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

private final class MutableDateSequence {
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
