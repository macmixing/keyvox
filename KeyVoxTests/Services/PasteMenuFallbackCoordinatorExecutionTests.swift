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
            typeLeadingSpacesOnMainThread: { _ in true }
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
            typeLeadingSpacesOnMainThread: { _ in false }
        )

        XCTAssertFalse(result.didMenuFallbackInsert)
        XCTAssertNil(result.menuAttempt)
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
            typeLeadingSpacesOnMainThread: { _ in true }
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
            typeLeadingSpacesOnMainThread: { _ in true }
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
            typeLeadingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
        XCTAssertEqual(executor.verifyInsertionWithoutAXCalls, 0)
    }

    func testActionSucceededFallsBackToLiveSessionVerification() {
        let coordinator = PasteMenuFallbackCoordinator()
        let executor = MockPasteMenuFallbackExecutor()
        executor.pasteResult = .actionSucceeded
        executor.verificationContext = sampleVerificationContext()
        executor.verifyInsertionResult = false
        executor.verifyLiveResult = true
        executor.liveSession = MockLiveSession()

        let result = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity("com.example.app", 1),
            menuFallbackExecutor: executor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            typeLeadingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.verifyInsertionCalls, 1)
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
            typeLeadingSpacesOnMainThread: { _ in true }
        )

        XCTAssertTrue(result.didMenuFallbackInsert)
        XCTAssertEqual(executor.verifyInsertionWithoutAXCalls, 1)
        XCTAssertEqual(executor.verifyInsertionCalls, 0)
    }

    func testFirstMenuSuccessWarmupSuppressionOnlyAppliesToFirstAttempt() {
        let coordinator = PasteMenuFallbackCoordinator(electronFrameworkDetector: { _ in true })
        let identity = identity("com.example.app", 999)

        let firstExecutor = MockPasteMenuFallbackExecutor()
        firstExecutor.pasteResult = .actionSucceeded
        firstExecutor.verifyInsertionWithoutAXResult = false
        firstExecutor.verifyLiveResult = false

        let first = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity,
            menuFallbackExecutor: firstExecutor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            typeLeadingSpacesOnMainThread: { _ in true }
        )

        let secondExecutor = MockPasteMenuFallbackExecutor()
        secondExecutor.pasteResult = .actionSucceeded
        secondExecutor.verifyInsertionWithoutAXResult = false
        secondExecutor.verifyLiveResult = false

        let second = coordinator.executeMenuFallback(
            insertionText: "hello",
            didAccessibilityInsertText: false,
            targetAppIdentity: identity,
            menuFallbackExecutor: secondExecutor,
            shouldTrustMenuSuccessWithoutAXVerification: { false },
            setClipboardStringOnMainThread: { _ in },
            typeLeadingSpacesOnMainThread: { _ in true }
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
    var verifyInsertionWithoutAXResult = false
    var verifyLiveResult = false
    var liveSession: PasteAXLiveSessioning?

    private(set) var pasteViaMenuBarCalls = 0
    private(set) var verifyInsertionCalls = 0
    private(set) var verifyInsertionWithoutAXCalls = 0
    private(set) var verifyLiveSessionCalls = 0

    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult {
        pasteViaMenuBarCalls += 1
        return pasteResult
    }

    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? {
        verificationContext
    }

    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        _ = context
        verifyInsertionCalls += 1
        return verifyInsertionResult
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

    func startLiveValueChangeVerificationSession(processID: pid_t?) -> PasteAXLiveSessioning? {
        _ = processID
        return liveSession
    }

    func verifyInsertionUsingLiveValueChangeSession(_ session: PasteAXLiveSessioning?) -> Bool {
        _ = session
        verifyLiveSessionCalls += 1
        return verifyLiveResult
    }

    func finishLiveValueChangeVerificationSession(_ session: PasteAXLiveSessioning?) {
        session?.close()
    }
}

private final class MockLiveSession: PasteAXLiveSessioning {
    func waitForSignal(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        _ = timeout
        _ = pollInterval
        return true
    }

    func close() {}
}
