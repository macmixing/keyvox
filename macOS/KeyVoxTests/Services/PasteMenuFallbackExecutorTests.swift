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

    func testVerifyInsertionOutcomeObservesExpectedPayloadBeforeCaret() {
        let inspector = MockPasteAXInspector()
        let element = makeRetainedElement()
        inspector.setRange(
            for: element,
            values: [CFRange(location: 5, length: 0)]
        )
        inspector.setStringForRange("hello", location: 0, length: 5, element: element)

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

        let outcome = executor.verifyInsertionOutcome(using: context, expectedText: "hello")
        XCTAssertTrue(outcome.isExpectedPayloadObserved)
    }

    func testVerifyInsertionOutcomeKeepsRangeMovementStructuralWhenPayloadIsNotObserved() {
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

        let outcome = executor.verifyInsertionOutcome(using: context, expectedText: "hello")
        XCTAssertTrue(outcome.isStructuralInsertionObserved)
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

    func testCaptureVerificationContextIgnoresDegenerateFocusedElementAndUsesCandidateSignal() {
        let inspector = MockPasteAXInspector()
        let focusedElement = makeRetainedElement()
        let candidateElement = makeRetainedElement()
        inspector.focusedElement = focusedElement
        inspector.candidateElements = [candidateElement]
        inspector.setOptionalRanges([nil, CFRange(location: 7, length: 0)])

        let executor = makeExecutor(inspector: inspector)

        let context = executor.captureVerificationContext()

        XCTAssertEqual(context?.snapshots.count, 1)
        XCTAssertTrue(context?.snapshots.first?.element === candidateElement)
        XCTAssertEqual(context?.snapshots.first?.selectedRange?.location, 7)
        XCTAssertEqual(inspector.candidateVerificationProcessIDs.count, 1)
    }

    func testCaptureVerificationContextReturnsFocusedSignalWithoutScanningCandidates() {
        let inspector = MockPasteAXInspector()
        let focusedElement = makeRetainedElement()
        let candidateElement = makeRetainedElement()
        inspector.focusedElement = focusedElement
        inspector.candidateElements = [candidateElement]
        inspector.setOptionalRanges([CFRange(location: 3, length: 0)])

        let executor = makeExecutor(inspector: inspector)

        let context = executor.captureVerificationContext()

        XCTAssertEqual(context?.snapshots.count, 1)
        XCTAssertTrue(context?.snapshots.first?.element === focusedElement)
        XCTAssertEqual(context?.snapshots.first?.selectedRange?.location, 3)
        XCTAssertTrue(inspector.candidateVerificationProcessIDs.isEmpty)
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

private extension PasteMenuFallbackVerificationOutcome {
    var isExpectedPayloadObserved: Bool {
        guard case .expectedPayloadObserved = self else { return false }
        return true
    }

    var isStructuralInsertionObserved: Bool {
        guard case .structuralInsertionObserved = self else { return false }
        return true
    }
}

private final class MockPasteAXInspector: PasteAXInspecting {
    var focusedElement: AXUIElement?
    var candidateElements: [AXUIElement] = []
    private(set) var candidateVerificationProcessIDs: [pid_t] = []

    private var rangeSequence: [CFRange?] = [nil]
    private var rangeIndex = 0
    private var valueLengthSequence: [Int?] = [nil]
    private var valueLengthIndex = 0
    private var valueStringSequence: [String?] = [nil]
    private var valueStringIndex = 0
    private var rangeStringByLocationAndLength: [String: String] = [:]

    func setRange(for element: AXUIElement, values: [CFRange]) {
        _ = element
        rangeSequence = values.map { Optional($0) }
        rangeIndex = 0
    }

    func setOptionalRanges(_ values: [CFRange?]) {
        rangeSequence = values
        rangeIndex = 0
    }

    func setValueLengths(for element: AXUIElement, values: [Int]) {
        _ = element
        valueLengthSequence = values.map { Optional($0) }
        valueLengthIndex = 0
    }

    func setValueStrings(for element: AXUIElement, values: [String]) {
        _ = element
        valueStringSequence = values.map { Optional($0) }
        valueStringIndex = 0
    }

    func setStringForRange(_ text: String, location: Int, length: Int, element: AXUIElement) {
        _ = element
        rangeStringByLocationAndLength["\(location):\(length)"] = text
    }

    func focusedInsertionContext() -> PasteInsertionContext? { nil }
    func focusedUIElement() -> AXUIElement? { focusedElement }
    func roleString(for element: AXUIElement) -> String? { nil }
    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
        _ = element
        return rangeStringByLocationAndLength["\(range.location):\(range.length)"]
    }
    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? { nil }
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        _ = maxDepth
        _ = maxNodes
        _ = maxCandidates
        candidateVerificationProcessIDs.append(pid)
        return candidateElements
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

    func valueStringForMenuVerification(element: AXUIElement) -> String? {
        _ = element
        let value = valueStringSequence[min(valueStringIndex, valueStringSequence.count - 1)]
        valueStringIndex += 1
        return value
    }
}
