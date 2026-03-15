import ApplicationServices
import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class PasteCapitalizationHeuristicsTests: XCTestCase {
    private static var retainedHeuristics: [PasteCapitalizationHeuristics] = []

    func testKeepsCapitalizationAtFieldStart() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(selectionLength: 0, caretLocation: 0, previousCharacter: nil)
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
    }

    func testKeepsCapitalizationAfterPeriod() {
        assertSentenceBoundaryPreservesCapitalization(previousCharacter: ".")
    }

    func testKeepsCapitalizationAfterQuestionMark() {
        assertSentenceBoundaryPreservesCapitalization(previousCharacter: "?")
    }

    func testKeepsCapitalizationAfterExclamationPoint() {
        assertSentenceBoundaryPreservesCapitalization(previousCharacter: "!")
    }

    func testKeepsCapitalizationAfterPunctuationAndSpace() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 5,
                    previousCharacter: " ",
                    previousNonWhitespaceCharacter: "."
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
    }

    func testLowercasesDefaultSentenceCaseMidSentence() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 4,
                    previousCharacter: "x",
                    previousNonWhitespaceCharacter: "x"
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "hello")
    }

    func testLowercasesDefaultSentenceCaseWithLeadingWhitespace() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 4,
                    previousCharacter: "x",
                    previousNonWhitespaceCharacter: "x"
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "  Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "  hello")
    }

    func testPreservesAllCapsMidSentence() {
        let output = normalizeMidSentence("NASA")
        XCTAssertEqual(output, "NASA")
    }

    func testPreservesMixedCaseMidSentence() {
        let output = normalizeMidSentence("OpenAI")
        XCTAssertEqual(output, "OpenAI")
    }

    func testPreservesLeadingNonLetterMidSentence() {
        let output = normalizeMidSentence("(Hello")
        XCTAssertEqual(output, "(Hello")
    }

    func testSelectionReplacementStillNormalizesMidSentence() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 3,
                    caretLocation: 4,
                    previousCharacter: "x",
                    previousNonWhitespaceCharacter: "x"
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: Date().addingTimeInterval(-1),
            lastInsertedTrailingCharacter: "x",
            lastInsertedTrailingNonWhitespaceCharacter: "x",
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "hello")
    }

    func testFallbackHeuristicLowercasesWithinTTLForMatchingIdentity() {
        let heuristics = makeRetainedHeuristics(axInspector: MockPasteAXInspector(focusedContext: nil), heuristicTTL: 10)
        let now = Date()

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: now.addingTimeInterval(-1),
            lastInsertedTrailingCharacter: "x",
            lastInsertedTrailingNonWhitespaceCharacter: "x",
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "hello")
    }

    func testUnknownContextKeepsCapitalizationWithoutFallbackSignal() {
        let heuristics = makeRetainedHeuristics(axInspector: MockPasteAXInspector(focusedContext: nil), heuristicTTL: 10)

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
    }

    func testPartialAXContextFallsBackToTTLSignal() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: nil,
                    caretLocation: 8,
                    previousCharacter: nil,
                    previousNonWhitespaceCharacter: nil
                )
            ),
            heuristicTTL: 10
        )
        let now = Date()

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: now.addingTimeInterval(-1),
            lastInsertedTrailingCharacter: "x",
            lastInsertedTrailingNonWhitespaceCharacter: "x",
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "hello")
    }

    func testPreservesDictionaryCasedNameMidSentence() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 4,
                    previousCharacter: "x",
                    previousNonWhitespaceCharacter: "x"
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Dom Esposito.",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { $0.hasPrefix("Dom Esposito") }
        )

        XCTAssertEqual(output, "Dom Esposito.")
    }

    func testDictionaryCasingStoreReadsPersistedDictionaryPayload() throws {
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
          "entries": [
            {
              "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
              "phrase": "Dom Esposito"
            }
          ]
        }
        """
        try Data(payload.utf8).write(to: fileURL)

        let store = PasteDictionaryCasingStore(dictionaryFileURL: fileURL)

        XCTAssertTrue(store.shouldPreserveLeadingCapitalization(in: "Dom Esposito."))
        XCTAssertFalse(store.shouldPreserveLeadingCapitalization(in: "Hello world"))
    }

    private func assertSentenceBoundaryPreservesCapitalization(previousCharacter: Character) {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 4,
                    previousCharacter: previousCharacter,
                    previousNonWhitespaceCharacter: previousCharacter
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
    }

    private func normalizeMidSentence(_ text: String) -> String {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 4,
                    previousCharacter: "x",
                    previousNonWhitespaceCharacter: "x"
                )
            )
        )

        return heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: text,
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )
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
        heuristicTTL: TimeInterval = 10
    ) -> PasteCapitalizationHeuristics {
        let heuristics = PasteCapitalizationHeuristics(
            axInspector: axInspector,
            heuristicTTL: heuristicTTL
        )
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
