import ApplicationServices
import XCTest
@testable import KeyVox

@MainActor
final class PasteSpacingHeuristicsTests: XCTestCase {
    private static var retainedHeuristics: [PasteSpacingHeuristics] = []

    func testDoesNotInsertLeadingSpaceWhenReplacingSelection() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(selectionLength: 2, caretLocation: 4, previousCharacter: "x")
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: Date(),
            lastInsertedTrailingCharacter: "x",
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "hello")
    }

    func testDoesNotInsertLeadingSpaceWhenCaretAtStart() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(selectionLength: 0, caretLocation: 0, previousCharacter: nil)
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: Date(),
            lastInsertedTrailingCharacter: "x",
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "hello")
    }

    func testInsertsLeadingSpaceFromAXContextWhenPreviousCharacterIsWordLike() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(selectionLength: 0, caretLocation: 8, previousCharacter: "x")
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, " hello")
    }

    func testDoesNotInsertLeadingSpaceWhenIncomingStartsWithPunctuation() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(selectionLength: 0, caretLocation: 8, previousCharacter: "x")
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: ",hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, ",hello")
    }

    func testDoesNotInsertLeadingSpaceAfterOpeningDelimiter() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(selectionLength: 0, caretLocation: 8, previousCharacter: "(")
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "hello")
    }

    func testFallbackHeuristicInsertsLeadingSpaceWithinTTLForMatchingIdentity() {
        let inspector = MockPasteAXInspector(focusedContext: nil)
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)
        let now = Date()

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "next",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: now.addingTimeInterval(-1),
            lastInsertedTrailingCharacter: ".",
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, " next")
    }

    func testFallbackHeuristicDoesNotInsertWhenTTLExpired() {
        let inspector = MockPasteAXInspector(focusedContext: nil)
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 1)
        let now = Date()

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "next",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: now.addingTimeInterval(-5),
            lastInsertedTrailingCharacter: ".",
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "next")
    }

    func testFallbackHeuristicDoesNotInsertWhenIdentityDoesNotMatch() {
        let inspector = MockPasteAXInspector(focusedContext: nil)
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)
        let now = Date()

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "next",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.other.app", 2),
            lastInsertionAt: now.addingTimeInterval(-1),
            lastInsertedTrailingCharacter: ".",
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "next")
    }

    private func identity(_ bundleID: String, _ pid: pid_t) -> PasteAppIdentity {
        PasteAppIdentity(bundleID: bundleID, pid: pid)
    }

    private var identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool {
        { lhs, rhs in
            lhs.bundleID == rhs.bundleID && lhs.pid == rhs.pid
        }
    }

    private func makeRetainedHeuristics(
        axInspector: PasteAXInspecting,
        heuristicTTL: TimeInterval
    ) -> PasteSpacingHeuristics {
        let heuristics = PasteSpacingHeuristics(axInspector: axInspector, heuristicTTL: heuristicTTL)
        Self.retainedHeuristics.append(heuristics)
        return heuristics
    }
}

private final class MockPasteAXInspector: PasteAXInspecting {
    var focusedContext: PasteInsertionContext?

    init(focusedContext: PasteInsertionContext?) {
        self.focusedContext = focusedContext
    }

    func focusedInsertionContext() -> PasteInsertionContext? { focusedContext }
    func focusedUIElement() -> AXUIElement? { nil }
    func roleString(for element: AXUIElement) -> String? { nil }
    func selectedRange(for element: AXUIElement) -> CFRange? { nil }
    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? { nil }
    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? { nil }
    func valueLengthForMenuVerification(element: AXUIElement) -> Int? { nil }
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        []
    }
}
