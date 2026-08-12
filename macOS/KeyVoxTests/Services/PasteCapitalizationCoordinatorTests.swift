import ApplicationServices
import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class PasteCapitalizationCoordinatorTests: XCTestCase {
    private static var retainedCoordinators: [PasteCapitalizationCoordinator] = []

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

    func testKeepsCapitalizationWhenEmptyFieldContainsInvisibleFormatCharacter() {
        let invisibleFormatCharacter = Character("\u{FEFF}")
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 1,
                    previousCharacter: invisibleFormatCharacter,
                    previousNonWhitespaceCharacter: invisibleFormatCharacter
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

    func testKeepsCapitalizationAfterPeriod() {
        assertSentenceBoundaryPreservesCapitalization(previousCharacter: ".")
    }

    func testKeepsCapitalizationAfterQuestionMark() {
        assertSentenceBoundaryPreservesCapitalization(previousCharacter: "?")
    }

    func testKeepsCapitalizationAfterExclamationPoint() {
        assertSentenceBoundaryPreservesCapitalization(previousCharacter: "!")
    }

    func testEmojiCapitalizationUsesCharacterBeforeEmojiBoundary() {
        let cases = [
            (characterBeforeEmoji: Character("l"), expected: "hello"),
            (characterBeforeEmoji: Character("."), expected: "Hello")
        ]

        for testCase in cases {
            let heuristics = makeRetainedHeuristics(
                axInspector: MockPasteAXInspector(
                    focusedContext: PasteInsertionContext(
                        selectionLength: 0,
                        caretLocation: 8,
                        previousCharacter: Character("😎"),
                        characterBeforePreviousCharacter: Character(" "),
                        previousNonWhitespaceCharacter: Character("😎"),
                        characterBeforePreviousNonWhitespaceCharacter: testCase.characterBeforeEmoji
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

            XCTAssertEqual(output, testCase.expected)
        }
    }

    func testMapsOpeningQuoteContextToSharedCapitalizationPolicy() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 20,
                    previousCharacter: "\"",
                    characterBeforePreviousCharacter: " ",
                    previousNonWhitespaceCharacter: "\""
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "This is cool.",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "This is cool.")
    }

    func testMapsClosingQuoteContinuationToSharedCapitalizationPolicy() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 42,
                    previousCharacter: "\"",
                    characterBeforePreviousCharacter: ",",
                    previousNonWhitespaceCharacter: "\""
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "But he didn't listen.",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "but he didn't listen.")
    }

    func testMapsQuotedSentenceBoundaryToSharedCapitalizationPolicy() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 24,
                    previousCharacter: "\"",
                    characterBeforePreviousCharacter: "?",
                    previousNonWhitespaceCharacter: "\""
                )
            )
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "We missed that.",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: nil,
            lastInsertionAt: .distantPast,
            lastInsertedTrailingCharacter: nil,
            lastInsertedTrailingNonWhitespaceCharacter: nil,
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "We missed that.")
    }

    func testKeepsCapitalizationAtStartOfNewLine() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 5,
                    previousCharacter: "\n",
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

        XCTAssertEqual(output, "Hello")
    }

    func testKeepsCapitalizationAfterSingleIndentedNewLine() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 0,
                    caretLocation: 6,
                    previousCharacter: " ",
                    characterBeforePreviousCharacter: "\n",
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

        XCTAssertEqual(output, "Hello")
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

    func testSelectionReplacementUsesLocalSentenceBoundary() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: 3,
                    caretLocation: 4,
                    previousCharacter: " ",
                    previousNonWhitespaceCharacter: "."
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

        XCTAssertEqual(output, "Hello")
    }

    func testMissingAXContextKeepsCapitalizationWithFallbackSignal() {
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

        XCTAssertEqual(output, "Hello")
    }

    func testFallbackHeuristicKeepsCapitalizationAfterTrailingNewLine() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: nil,
                    caretLocation: 8,
                    previousCharacter: nil
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
            lastInsertedTrailingCharacter: "\n",
            lastInsertedTrailingNonWhitespaceCharacter: "x",
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
    }

    func testPartialAXContextKeepsCapitalizationWhenTTLExpired() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: nil,
                    caretLocation: 8,
                    previousCharacter: nil
                )
            ),
            heuristicTTL: 1
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.example.app", 1),
            lastInsertionAt: Date().addingTimeInterval(-5),
            lastInsertedTrailingCharacter: "x",
            lastInsertedTrailingNonWhitespaceCharacter: "x",
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
    }

    func testPartialAXContextKeepsCapitalizationWhenIdentityDoesNotMatch() {
        let heuristics = makeRetainedHeuristics(
            axInspector: MockPasteAXInspector(
                focusedContext: PasteInsertionContext(
                    selectionLength: nil,
                    caretLocation: 8,
                    previousCharacter: nil
                )
            ),
            heuristicTTL: 10
        )

        let output = heuristics.normalizeLeadingCapitalizationIfNeeded(
            in: "Hello",
            currentIdentity: identity("com.example.app", 1),
            lastInsertionAppIdentity: identity("com.other.app", 2),
            lastInsertionAt: Date().addingTimeInterval(-1),
            lastInsertedTrailingCharacter: "x",
            lastInsertedTrailingNonWhitespaceCharacter: "x",
            identityMatcher: identityMatcher,
            shouldPreserveLeadingCapitalization: { _ in false }
        )

        XCTAssertEqual(output, "Hello")
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
    ) -> PasteCapitalizationCoordinator {
        let coordinator = PasteCapitalizationCoordinator(
            axInspector: axInspector,
            heuristicTTL: heuristicTTL
        )
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
