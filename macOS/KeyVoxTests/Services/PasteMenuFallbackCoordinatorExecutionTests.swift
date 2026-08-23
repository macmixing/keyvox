import ApplicationServices
import XCTest
@testable import KeyVox

@MainActor
final class PasteMenuFallbackCoordinatorExecutionTests: XCTestCase {
    func testEmptyClipboardPayloadTreatsTypedLeadingSpacesAsSuccess() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        var clipboardWrites: [String] = []

        let result = coordinator.executeMenuFallback(
            insertionText: "   ",
            didAccessibilityInsertText: false,
            targetAppIdentity: nil,
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { clipboardWrites.append($0) },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertNil(result.menuAttempt)
        XCTAssertFalse(result.suppressFirstWarmupFailureWarning)
        XCTAssertEqual(clipboardWrites, [""])
        XCTAssertEqual(executor.pasteViaMenuBarCalls, 0)
    }

    func testEmptyClipboardPayloadFailureWhenLeadingSpaceTypingFails() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()

        let result = coordinator.executeMenuFallback(
            insertionText: "   ",
            didAccessibilityInsertText: false,
            targetAppIdentity: nil,
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in false },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertFalse(result.didMenuFallbackInsert)
        XCTAssertNil(result.menuAttempt)
    }

    func testLeadingSpacePasteUsesOrderedKeyboardSequenceInsteadOfMenuAction() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionOutcomeResult = .expectedPayloadObserved
        var operations: [String] = []

        let result = coordinator.executeMenuFallback(
            insertionText: " hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: {
                operations.append("clipboard:\($0)")
            },
            executeLeadingSpacePasteOnMainThread: { count in
                operations.append("leadingPaste:\(count)")
                return true
            },
            typeTrailingSpacesOnMainThread: { count in
                operations.append("trailing:\(count)")
                return true
            }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(result.completionEvidence, .expectedPayloadObserved)
        XCTAssertEqual(operations, ["clipboard:hello", "leadingPaste:1"])
        XCTAssertEqual(executor.pasteViaMenuBarCalls, 0)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
    }

    func testTrailingSpacesWaitForVerifiedPasteBeforeTyping() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionOutcomeResult = .expectedPayloadObserved
        var operations: [String] = []
        executor.onPaste = { operations.append("menuPaste") }
        executor.onVerifyInsertion = { operations.append("verify") }

        let result = coordinator.executeMenuFallback(
            insertionText: "hello ",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: {
                operations.append("clipboard:\($0)")
            },
            executeLeadingSpacePasteOnMainThread: { count in
                operations.append("leadingPaste:\(count)")
                return true
            },
            typeTrailingSpacesOnMainThread: { count in
                operations.append("trailing:\(count)")
                return true
            }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(result.completionEvidence, .expectedPayloadObserved)
        XCTAssertEqual(operations, ["clipboard:hello", "menuPaste", "verify", "trailing:1"])
        XCTAssertEqual(executor.pasteViaMenuBarCalls, 1)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
    }

    func testTrailingSpaceFailureRetriesOnlyTrailingSpacesAndReportsIncompleteInsertion() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionOutcomeResult = .expectedPayloadObserved
        var trailingSpaceCounts: [Int] = []

        let result = coordinator.executeMenuFallback(
            insertionText: "hello ",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: {
                trailingSpaceCounts.append($0)
                return false
            }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertFalse(result.didCompleteInsertion)
        XCTAssertEqual(trailingSpaceCounts, [1, 1])
        XCTAssertEqual(executor.pasteViaMenuBarCalls, 1)
    }

    func testTrailingSpacesAreNotTypedWhenPasteIsNotObserved() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionOutcomeResult = PasteMenuFallbackVerificationOutcome.none
        var trailingSpaceCounts: [Int] = []

        let result = coordinator.executeMenuFallback(
            insertionText: "hello ",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: {
                trailingSpaceCounts.append($0)
                return true
            }
        )

        XCTAssertFalse(result.didMenuFallbackInsert)
        XCTAssertEqual(result.completionEvidence, .none)
        XCTAssertTrue(trailingSpaceCounts.isEmpty)
    }

    func testTrailingSpacesAreNotTypedWithoutPasteCompletionEvidence() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        var trailingSpaceCounts: [Int] = []

        let result = coordinator.executeMenuFallback(
            insertionText: "hello ",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { true },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: {
                trailingSpaceCounts.append($0)
                return true
            }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(result.completionEvidence, .trustedWithoutVerification)
        XCTAssertTrue(trailingSpaceCounts.isEmpty)
    }

    func testLeadingAndTrailingSpacesPreserveVerifiedInsertionOrder() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionOutcomeResult = .expectedPayloadObserved
        var operations: [String] = []
        executor.onVerifyInsertion = { operations.append("verify") }

        let result = coordinator.executeMenuFallback(
            insertionText: " hello ",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: {
                operations.append("clipboard:\($0)")
            },
            executeLeadingSpacePasteOnMainThread: { count in
                operations.append("leadingPaste:\(count)")
                return true
            },
            typeTrailingSpacesOnMainThread: { count in
                operations.append("trailing:\(count)")
                return true
            }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(operations, ["clipboard:hello", "leadingPaste:1", "verify", "trailing:1"])
        XCTAssertEqual(executor.pasteViaMenuBarCalls, 0)
    }

    func testUnavailableMenuAttemptReturnsNoInsertion() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .unavailable

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertFalse(result.didMenuFallbackInsert)
        assertAttempt(result.menuAttempt, equals: .unavailable)
    }

    func testActionSucceededTrustedPathSkipsVerification() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { true },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(result.menuAttempt, .actionSucceeded)
        XCTAssertEqual(executor.verifyInsertionCalls, 0)
        XCTAssertEqual(executor.verifyInsertionWithoutAXCalls, 0)
        XCTAssertEqual(executor.verifyLiveSessionCalls, 0)
    }

    func testActionSucceededUsesAXVerificationWhenContextExists() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionResult = true

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
        XCTAssertEqual(executor.verifyInsertionWithoutAXCalls, 0)
    }

    func testActionSucceededConfirmsMenuPasteWhenExactPayloadAndLiveChangeAreObserved() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionOutcomeResult = .expectedPayloadObserved
        executor.liveSessions = [MockLiveSession()]

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(result.completionEvidence, .confirmedMenuPasteObserved)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
        XCTAssertEqual(executor.verifyLiveSessionCalls, 0)
    }

    func testActionSucceededFallsBackToLiveSessionVerification() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionResult = false
        executor.verifyLiveResult = true
        executor.liveSessions = [MockLiveSession()]

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
        XCTAssertEqual(executor.verifyLiveSessionCalls, 1)
    }

    func testLiveSessionBindsToCurrentVerificationProcessIDs() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = nil
        executor.verifyInsertionWithoutAXResult = false
        executor.verifyLiveResult = true
        executor.liveSessions = [MockLiveSession()]
        executor.liveVerificationProcessIDs = [42, 43]

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 999),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.lastLiveSessionProcessIDs, [42, 43])
    }

    func testActionSucceededKeepsFailureWhenNoVerificationEvidenceIsObserved() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = nil
        executor.verifyInsertionWithoutAXResult = false
        executor.verifyLiveResult = false

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertFalse(result.didMenuFallbackInsert)
        XCTAssertEqual(result.completionEvidence, .none)
        XCTAssertEqual(executor.verifyInsertionWithoutAXCalls, 1)
        XCTAssertEqual(executor.verifyLiveSessionCalls, 1)
    }

    func testActionErroredUsesUndoVerificationWhenNoContext() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionErrored
        executor.verificationContext = nil
        executor.verifyInsertionWithoutAXResult = true

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.verifyInsertionWithoutAXCalls, 1)
        XCTAssertEqual(executor.verifyInsertionCalls, 0)
    }

    func testFirstMenuSuccessWarmupSuppressionOnlyAppliesToFirstAttemptWhenVerificationContextExists() {
        let coordinator = PasteMenuFallbackCoordinator(electronFrameworkDetector: { _ in true })
        let identity = identity("com.example.app", 999)

        let firstExecutor = MockPasteMenuFallbackExecutor()
        firstExecutor.pasteResult = .actionSucceeded
        firstExecutor.verificationContext = sampleVerificationContext()
        firstExecutor.verifyInsertionOutcomeResult = PasteMenuFallbackVerificationOutcome.none
        firstExecutor.verifyLiveResult = false

        let first = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity,
            menuFallbackExecutor: firstExecutor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        let secondExecutor = MockPasteMenuFallbackExecutor()
        secondExecutor.pasteResult = .actionSucceeded
        secondExecutor.verificationContext = sampleVerificationContext()
        secondExecutor.verifyInsertionOutcomeResult = PasteMenuFallbackVerificationOutcome.none
        secondExecutor.verifyLiveResult = false

        let second = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity,
            menuFallbackExecutor: secondExecutor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            executeLeadingSpacePasteOnMainThread: { _ in true },
            typeTrailingSpacesOnMainThread: { _ in true }
        )

        XCTAssertFalse(first.didMenuFallbackInsert)
        assertAttempt(first.menuAttempt, equals: .actionSucceeded)
        XCTAssertTrue(first.suppressFirstWarmupFailureWarning)

        XCTAssertFalse(second.didMenuFallbackInsert)
        assertAttempt(second.menuAttempt, equals: .actionSucceeded)
        XCTAssertFalse(second.suppressFirstWarmupFailureWarning)
    }

    private func identity(_ bundleID: String, _ pid: pid_t) -> PasteAppIdentity {
        PasteAppIdentity(bundleID: bundleID, pid: pid)
    }

    private func sampleVerificationContext() -> PasteMenuFallbackVerificationContext {
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        return PasteMenuFallbackVerificationContext(
            snapshots: [
                PasteMenuFallbackVerificationSnapshot(
                    element: element,
                    selectedRange: nil,
                    valueLength: nil
                )
            ]
        )
    }

    private func assertAttempt(
        _ actual: PasteMenuFallbackAttemptResult?,
        equals expected: PasteMenuFallbackAttemptResult
    ) {
        switch (actual, expected) {
        case (.some(.unavailable), .unavailable),
             (.some(.actionSucceeded), .actionSucceeded),
             (.some(.actionErrored), .actionErrored):
            XCTAssertTrue(true)
        default:
            XCTFail("Unexpected menu attempt result")
        }
    }
}

private final class MockPasteMenuFallbackExecutor: PasteMenuFallbackExecuting {
    var pasteResult: PasteMenuFallbackAttemptResult = .unavailable
    var verificationContext: PasteMenuFallbackVerificationContext?
    var undoState: PasteMenuFallbackUndoState?
    var verifyInsertionResult = false
    var verifyInsertionOutcomeResult: PasteMenuFallbackVerificationOutcome?
    var verifyInsertionWithoutAXResult = false
    var verifyLiveResult = false
    var liveSessions: [PasteAXLiveSessioning] = []
    var liveVerificationProcessIDs: [pid_t] = []
    var onPaste: (() -> Void)?
    var onVerifyInsertion: (() -> Void)?
    private(set) var lastLiveSessionProcessIDs: [pid_t] = []

    private(set) var pasteViaMenuBarCalls = 0
    private(set) var verifyInsertionCalls = 0
    private(set) var verifyInsertionWithoutAXCalls = 0
    private(set) var verifyLiveSessionCalls = 0

    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult {
        pasteViaMenuBarCalls += 1
        onPaste?()
        return pasteResult
    }

    func liveVerificationProcessIDsOnMainThread(targetProcessID: pid_t?) -> [pid_t] {
        _ = targetProcessID
        return liveVerificationProcessIDs
    }

    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? {
        verificationContext
    }

    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        _ = context
        verifyInsertionCalls += 1
        return verifyInsertionResult
    }

    func verifyInsertionOutcome(
        using context: PasteMenuFallbackVerificationContext?,
        expectedText: String
    ) -> PasteMenuFallbackVerificationOutcome {
        _ = context
        _ = expectedText
        verifyInsertionCalls += 1
        onVerifyInsertion?()
        if let verifyInsertionOutcomeResult {
            return verifyInsertionOutcomeResult
        }
        return verifyInsertionResult ? .structuralInsertionObserved : .none
    }

    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState? {
        undoState
    }

    func verifyInsertionWithoutAXContextOnMainThread(
        initialUndoState: PasteMenuFallbackUndoState?
    ) -> Bool {
        _ = initialUndoState
        verifyInsertionWithoutAXCalls += 1
        return verifyInsertionWithoutAXResult
    }

    func startLiveValueChangeVerificationSessions(processIDs: [pid_t]) -> [PasteAXLiveSessioning] {
        lastLiveSessionProcessIDs = processIDs
        return liveSessions
    }

    func verifyInsertionUsingLiveValueChangeSession(_ sessions: [PasteAXLiveSessioning]) -> Bool {
        _ = sessions
        verifyLiveSessionCalls += 1
        return verifyLiveResult
    }

    func finishLiveValueChangeVerificationSession(_ sessions: [PasteAXLiveSessioning]) {
        sessions.forEach { $0.close() }
    }
}

private final class MockLiveSession: PasteAXLiveSessioning {
    func hasSignal() -> Bool {
        true
    }

    func waitForSignal(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        _ = timeout
        _ = pollInterval
        return true
    }

    func close() {}
}
