import ApplicationServices
import XCTest
@testable import KeyVox

final class PasteMenuFallbackExecutorTests: XCTestCase {
    // Crash reports show deallocation of PasteMenuFallbackExecutor aborting inside Swift task-local teardown
    // under XCTest host. Keep instances alive for process lifetime to avoid exercising that teardown path.
    private static var leakedExecutors: [PasteMenuFallbackExecutor] = []

    func testVerifyInsertionReturnsFalseWhenContextMissing() {
        let inspector = MockPasteAXInspector()
        let executor = makeExecutor(inspector: inspector)

        XCTAssertFalse(executor.verifyInsertion(using: nil))
    }

    func testVerifyInsertionReturnsFalseWhenContextHasNoSnapshots() {
        let inspector = MockPasteAXInspector()
        let executor = makeExecutor(inspector: inspector)

        XCTAssertFalse(
            executor.verifyInsertion(
                using: PasteMenuFallbackVerificationContext(snapshots: [])
            )
        )
    }

    func testVerifyInsertionReturnsTrueWhenSelectedRangeMoves() {
        let inspector = MockPasteAXInspector()
        let element = makeRetainedElement()
        inspector.setRange(
            for: element,
            values: [CFRange(location: 5, length: 0)]
        )

        let executor = makeExecutor(inspector: inspector)

        let context = PasteMenuFallbackVerificationContext(
            snapshots: [
                PasteMenuFallbackVerificationSnapshot(
                    element: element,
                    selectedRange: CFRange(location: 0, length: 0),
                    valueLength: nil
                )
            ]
        )

        XCTAssertTrue(executor.verifyInsertion(using: context))
    }

    func testVerifyInsertionReturnsTrueWhenValueLengthChanges() {
        let inspector = MockPasteAXInspector()
        let element = makeRetainedElement()
        inspector.setValueLengths(for: element, values: [22])

        let executor = makeExecutor(inspector: inspector)

        let context = PasteMenuFallbackVerificationContext(
            snapshots: [
                PasteMenuFallbackVerificationSnapshot(
                    element: element,
                    selectedRange: nil,
                    valueLength: 0
                )
            ]
        )

        XCTAssertTrue(executor.verifyInsertion(using: context))
    }

    func testVerifyInsertionReturnsFalseForDegenerateUnchangedSignals() {
        let inspector = MockPasteAXInspector()
        let element = makeRetainedElement()
        inspector.setRange(
            for: element,
            values: [CFRange(location: 0, length: 0), CFRange(location: 0, length: 0)]
        )
        inspector.setValueLengths(for: element, values: [0, 0])

        let executor = makeExecutor(inspector: inspector)

        let context = PasteMenuFallbackVerificationContext(
            snapshots: [
                PasteMenuFallbackVerificationSnapshot(
                    element: element,
                    selectedRange: CFRange(location: 0, length: 0),
                    valueLength: 0
                )
            ]
        )

        XCTAssertFalse(executor.verifyInsertion(using: context))
    }

    private func makeRetainedElement() -> AXUIElement {
        AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    }

    private func makeExecutor(inspector: MockPasteAXInspector) -> PasteMenuFallbackExecutor {
        let executor = PasteMenuFallbackExecutor(
            axInspector: inspector,
            verificationTimeout: 0.01,
            verificationPollInterval: 0.001
        )
        Self.leakedExecutors.append(executor)
        return executor
    }
}

private final class MockPasteAXInspector: PasteAXInspecting {
    private var rangeSequence: [CFRange?] = [nil]
    private var rangeIndex = 0
    private var valueLengthSequence: [Int?] = [nil]
    private var valueLengthIndex = 0

    func setRange(for element: AXUIElement, values: [CFRange]) {
        _ = element
        rangeSequence = values.map { Optional($0) }
        rangeIndex = 0
    }

    func setValueLengths(for element: AXUIElement, values: [Int]) {
        _ = element
        valueLengthSequence = values.map { Optional($0) }
        valueLengthIndex = 0
    }

    func focusedInsertionContext() -> PasteInsertionContext? { nil }
    func focusedUIElement() -> AXUIElement? { nil }
    func roleString(for element: AXUIElement) -> String? { nil }
    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? { nil }
    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? { nil }
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        []
    }

    func selectedRange(for element: AXUIElement) -> CFRange? {
        _ = element
        let value = rangeSequence[min(rangeIndex, rangeSequence.count - 1)]
        rangeIndex += 1
        return value
    }

    func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        _ = element
        let value = valueLengthSequence[min(valueLengthIndex, valueLengthSequence.count - 1)]
        valueLengthIndex += 1
        return value
    }
}
