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
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
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
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
            spacing: spacing,
            injector: injector,
            coordinator: coordinator,
            restoreDelayAfterMenuFallback: 0.5,
            restoreDelayAfterAccessibilityInjection: 0
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
            suppressFirstWarmupFailureWarning: false
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
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
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: .actionErrored,
            suppressFirstWarmupFailureWarning: false
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
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
        let capitalization = MockCapitalizationHeuristics(outputText: "hello")
        let injector = MockAccessibilityInjector(outcome: .failureNeedsFallback)
        let coordinator = MockMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: .actionSucceeded,
            suppressFirstWarmupFailureWarning: true
        ))
        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
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

        let service = makeService(
            clipboard: clipboard,
            recovery: recovery,
            capitalization: capitalization,
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
        capitalization: MockCapitalizationHeuristics,
        spacing: MockSpacingHeuristics,
        injector: MockAccessibilityInjector,
        coordinator: MockMenuFallbackCoordinator,
        restoreDelayAfterMenuFallback: TimeInterval,
        restoreDelayAfterAccessibilityInjection: TimeInterval,
        clockNow: @escaping () -> Date = Date.init
    ) -> PasteService {
        let queue = DispatchQueue(label: "PasteServiceExecutionTests.queue")
        let dictionaryFileURL = makeIsolatedDictionaryFileURL()
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
            menuFallbackExecutor: PasteServiceNoopFallbackExecutor(),
            menuFallbackCoordinator: coordinator,
            dictionaryCasingStore: PasteDictionaryCasingStore(dictionaryFileURL: dictionaryFileURL),
            capitalizationHeuristics: capitalization,
            spacingHeuristics: spacing
        )
        Self.retainedServices.append(service)
        return service
    }

    private func makeIsolatedDictionaryFileURL() -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("dictionary.json")
        let payload = """
        {
          "version": 1,
          "entries": []
        }
        """
        try? Data(payload.utf8).write(to: fileURL)
        return fileURL
    }
}
