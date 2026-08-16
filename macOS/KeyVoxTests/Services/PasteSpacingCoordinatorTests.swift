import ApplicationServices
import XCTest
@testable import KeyVox

@MainActor
final class PasteSpacingCoordinatorTests: XCTestCase {
    private static var retainedCoordinators: [PasteSpacingCoordinator] = []

    func testDoesNotInsertLeadingSpaceWhenReplacingSelection() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 2,
                selectedText: "hi",
                caretLocation: 4,
                previousCharacter: "x"
            )
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

    func testInsertsLeadingSpaceWhenReplacingSelectionThatIncludesLeadingWhitespace() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 6,
                selectedText: " hello",
                caretLocation: 4,
                previousCharacter: "x"
            )
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

        XCTAssertEqual(output, " hello")
    }

    func testInsertsLeadingSpaceWhenSelectionBoundaryContainsPunctuationBeforeWhitespace() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 7,
                selectedText: ". hello",
                caretLocation: 4,
                previousCharacter: "x"
            )
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

        XCTAssertEqual(output, " hello")
    }

    func testInsertsLeadingSpaceWhenReplacingPunctuationOnlySelection() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 1,
                selectedText: ".",
                caretLocation: 4,
                previousCharacter: "x"
            )
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

        XCTAssertEqual(output, " hello")
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

    func testDoesNotInsertLeadingSpaceAtStartOfNewLine() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 0,
                caretLocation: 8,
                previousCharacter: "\n",
                previousNonWhitespaceCharacter: "x"
            )
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "Hello")
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

    func testInsertsLeadingSpaceFromAXContextWhenPreviousCharacterIsEmoji() {
        for previousCharacter in [Character("😎"), Character("©️"), Character("#️⃣")] {
            let inspector = MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 8,
                    previousCharacter: previousCharacter
                )
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

    func testMapsOpeningQuoteContextToSharedSpacingPolicy() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 0,
                caretLocation: 20,
                previousCharacter: "\"",
                characterBeforePreviousCharacter: " "
            )
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "This is cool.",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, "This is cool.")
    }

    func testMapsClosingQuoteContextToSharedSpacingPolicy() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: 0,
                caretLocation: 42,
                previousCharacter: "\"",
                characterBeforePreviousCharacter: ","
            )
        )
        let heuristics = makeRetainedHeuristics(axInspector: inspector, heuristicTTL: 10)

        let output = heuristics.applySmartLeadingSeparatorIfNeeded(
            to: "but he didn't listen.",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            identityMatcher: identityMatcher
        )

        XCTAssertEqual(output, " but he didn't listen.")
    }

    func testMissingAXContextDoesNotInsertLeadingSpaceFromFallbackSignal() {
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

        XCTAssertEqual(output, "next")
    }

    func testFallbackHeuristicDoesNotInsertWhenTTLExpired() {
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: nil,
                caretLocation: 8,
                previousCharacter: nil
            )
        )
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
        let inspector = MockPasteAXInspector(
            focusedContext: PasteInsertionContext(
                selectionLength: nil,
                caretLocation: 8,
                previousCharacter: nil
            )
        )
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
    ) -> PasteSpacingCoordinator {
        let coordinator = PasteSpacingCoordinator(axInspector: axInspector, heuristicTTL: heuristicTTL)
        Self.retainedCoordinators.append(coordinator)
        return coordinator
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
    func valueStringForMenuVerification(element: AXUIElement) -> String? { nil }
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        []
    }
}
