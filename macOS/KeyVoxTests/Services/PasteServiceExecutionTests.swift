import XCTest
@testable import KeyVox
import Foundation

@MainActor
final class PasteServiceExecutionTests: XCTestCase {
    private static var retainedServices: [PasteService] = []

    func testAccessibilityVerifiedSuccessRestoresClipboardAndSkipsRecovery() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let spacing = MockSpacingHeuristics()
        let injector = MockAccessibilityInjector(outcome: .verifiedSuccess)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: nil,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0.5
        )

        service.pasteText("hello")

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }

        XCTAssertEqual(recovery.cancelCalls, 1)
        XCTAssertEqual(recovery.startCalls, 0)
        XCTAssertEqual(coordinator.executeCalls, 0)
        XCTAssertEqual(capitalization.inputs.map(\.text), ["hello"])
        XCTAssertEqual(clipboard.writes, ["hello"])
    }

    func testCapitalizationNormalizationFeedsSpacingHeuristics() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let spacing = MockSpacingHeuristics()
        let injector = MockAccessibilityInjector(outcome: .verifiedSuccess)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: nil,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0.5
        )

        service.pasteText("Hello")

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }

        XCTAssertEqual(capitalization.inputs.map(\.text), ["Hello"])
        XCTAssertEqual(spacing.inputs.map(\.text), ["hello"])
        XCTAssertEqual(clipboard.writes, ["hello"])
    }

    func testMenuFallbackSuccessRestoresClipboardAndSkipsRecovery() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let spacing = MockSpacingHeuristics()
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: true,
            menuAttempt: .actionSucceeded,
            completionEvidence: .expectedPayloadObserved,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 10
        )

        service.pasteText("hello")

        try await waitForCondition(timeout: 0.2) {
            clipboard.restoreCalls == 1
        }

        XCTAssertEqual(recovery.startCalls, 0)
        XCTAssertEqual(coordinator.executeCalls, 1)
    }

    func testStructuralMenuFallbackKeepsGraceDelayBeforeRestoringClipboard() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: true,
            menuAttempt: .actionSucceeded,
            completionEvidence: .structuralInsertionObserved,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: MockSpacingHeuristics(),
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0.15
        )

        service.pasteText("hello")

        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(clipboard.restoreCalls, 0)

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }
        XCTAssertEqual(recovery.startCalls, 0)
    }

    func testTrustedMenuFallbackKeepsGraceDelayBeforeRestoringClipboard() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: true,
            menuAttempt: .actionSucceeded,
            completionEvidence: .trustedWithoutVerification,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: MockSpacingHeuristics(),
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0.15
        )

        service.pasteText("hello")

        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(clipboard.restoreCalls, 0)

        try await waitForCondition {
            clipboard.restoreCalls == 1
        }
        XCTAssertEqual(recovery.startCalls, 0)
    }

    func testMenuFallbackFailureStartsRecoveryWhenNotSuppressed() async throws {
        let clipboard = MockClipboardAdapter(snapshot: [[:]])
        let recovery = MockFailureRecoveryController()
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: .actionErrored,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: MockSpacingHeuristics(),
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0
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
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: .actionSucceeded,
            suppressFirstWarmupFailureWarning: true
        ))
        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: MockSpacingHeuristics(),
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0
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
        let capitalization = MockCapitalizationHeuristics(outputText: "hello.")
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

        let service = try makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0,
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
            restoreDelayAfterMenuFallback: 0.8
        )
        XCTAssertTrue(restorePlan.shouldRememberInsertion)
        XCTAssertFalse(restorePlan.shouldStartFailureRecovery)
        XCTAssertEqual(restorePlan.restorePolicy, .immediate)

        let verifiedMenuRestorePlan = PasteServiceExecutionPlan.build(
            didAccessibilityInsertText: false,
            didMenuFallbackInsert: true,
            usedMenuFallbackPath: true,
            menuFallbackCompletionEvidence: .expectedPayloadObserved,
            suppressFirstWarmupFailureWarning: false,
            shouldStartFailureRecovery: false,
            restoreDelayAfterMenuFallback: 0.8
        )
        XCTAssertTrue(verifiedMenuRestorePlan.shouldRememberInsertion)
        XCTAssertFalse(verifiedMenuRestorePlan.shouldStartFailureRecovery)
        XCTAssertEqual(verifiedMenuRestorePlan.restorePolicy, .immediate)

        let structuralMenuRestorePlan = PasteServiceExecutionPlan.build(
            didAccessibilityInsertText: false,
            didMenuFallbackInsert: true,
            usedMenuFallbackPath: true,
            menuFallbackCompletionEvidence: .structuralInsertionObserved,
            suppressFirstWarmupFailureWarning: false,
            shouldStartFailureRecovery: false,
            restoreDelayAfterMenuFallback: 0.8
        )
        XCTAssertTrue(structuralMenuRestorePlan.shouldRememberInsertion)
        XCTAssertFalse(structuralMenuRestorePlan.shouldStartFailureRecovery)
        XCTAssertEqual(structuralMenuRestorePlan.restorePolicy, .afterDelay(0.8))

        let trustedMenuRestorePlan = PasteServiceExecutionPlan.build(
            didAccessibilityInsertText: false,
            didMenuFallbackInsert: true,
            usedMenuFallbackPath: true,
            menuFallbackCompletionEvidence: .trustedWithoutVerification,
            suppressFirstWarmupFailureWarning: false,
            shouldStartFailureRecovery: false,
            restoreDelayAfterMenuFallback: 0.8
        )
        XCTAssertTrue(trustedMenuRestorePlan.shouldRememberInsertion)
        XCTAssertFalse(trustedMenuRestorePlan.shouldStartFailureRecovery)
        XCTAssertEqual(trustedMenuRestorePlan.restorePolicy, .afterDelay(0.8))

        let recoveryPlan = PasteServiceExecutionPlan.build(
            didAccessibilityInsertText: false,
            didMenuFallbackInsert: false,
            usedMenuFallbackPath: true,
            suppressFirstWarmupFailureWarning: false,
            shouldStartFailureRecovery: true,
            restoreDelayAfterMenuFallback: 0.8
        )
        XCTAssertFalse(recoveryPlan.shouldRememberInsertion)
        XCTAssertTrue(recoveryPlan.shouldStartFailureRecovery)
        XCTAssertEqual(recoveryPlan.restorePolicy, .deferredToFailureRecovery)
    }

    private func makeService(
        clipboard: MockClipboardAdapter,
        recovery: MockFailureRecoveryController,
        capitalization: MockCapitalizationHeuristics,
        spacing: MockSpacingHeuristics,
        injector: MockAccessibilityInjector,
        coordinator: MockMenuFallbackCoordinator,
        restoreDelayAfterMenuFallback: TimeInterval,
        clockNow: @escaping () -> Date = Date.init
    ) throws -> PasteService {
        let queue = DispatchQueue(label: "PasteServiceExecutionTests.queue")
        let dictionaryFileURL = try makeIsolatedDictionaryFileURL()
        let service = PasteService(
            pasteQueue: queue,
            heuristicTTL: 10,
            restoreDelayAfterMenuFallback: restoreDelayAfterMenuFallback,
            menuFallbackVerificationTimeout: 0.01,
            menuFallbackVerificationPollInterval: 0.001,
            frontmostAppIdentityProvider: { PasteAppIdentity(bundleID: "com.example.app", pid: 99) },
            clockNow: clockNow,
            clipboardAdapter: clipboard,
            failureRecoveryController: recovery,
            axInspector: MockAXInspector(),
            accessibilityInjector: injector,
            menuFallbackExecutor: PasteServiceNoopFallbackExecutor(),
            menuFallbackCoordinator: coordinator,
            dictionaryCasingStore: PasteDictionaryCasingStore(dictionaryFileURL: dictionaryFileURL),
            capitalizationHeuristics: capitalization,
            spacingHeuristics: spacing
        )
        Self.retainedServices.append(service)
        return service
    }

    private func makeIsolatedDictionaryFileURL() throws -> URL {
        PasteDictionaryCasingStore.resetCaches()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            PasteDictionaryCasingStore.resetCaches()
            try? FileManager.default.removeItem(at: directoryURL)
        }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("dictionary.json")
        let payload = """
        {
          "version": 1,
          "entries": []
        }
        """
        try Data(payload.utf8).write(to: fileURL)
        return fileURL
    }
}
