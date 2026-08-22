import ApplicationServices
import XCTest
@testable import KeyVox

@MainActor
final class PasteTerminalPunctuationCoordinatorTests: XCTestCase {
    func testRemovesModelPeriodBeforeExistingPunctuation() {
        for existingPunctuation in [
            Character("."), Character("?"), Character("!"),
            Character(","), Character(";"), Character(":"),
            Character(")"), Character("—"), Character("…"),
        ] {
            let inspector = TerminalPunctuationAXInspector(
                context: context(followingCharacter: existingPunctuation)
            )
            let coordinator = PasteTerminalPunctuationCoordinator(axInspector: inspector)

            let output = coordinator.resolveAdjacentTerminalPunctuation(in: "working.")

            XCTAssertEqual(output, "working")
            XCTAssertTrue(inspector.expandedSelections.isEmpty)
        }
    }

    func testIncomingQuestionAndExclamationReplaceDifferentPunctuationAndReuseMatchingMark() {
        for incomingPunctuation in [Character("?"), Character("!")] {
            for existingPunctuation in [
                Character("."), Character("?"), Character("!"),
                Character(","), Character(";"), Character(":"),
                Character(")"), Character("—"), Character("…"),
            ] {
                let inspector = TerminalPunctuationAXInspector(
                    context: context(followingCharacter: existingPunctuation)
                )
                let coordinator = PasteTerminalPunctuationCoordinator(axInspector: inspector)

                let output = coordinator.resolveAdjacentTerminalPunctuation(
                    in: "working\(incomingPunctuation)"
                )

                if incomingPunctuation == existingPunctuation {
                    XCTAssertEqual(output, "working")
                    XCTAssertTrue(inspector.expandedSelections.isEmpty)
                } else {
                    XCTAssertEqual(output, "working\(incomingPunctuation)")
                    XCTAssertEqual(
                        inspector.expandedSelections,
                        [.init(location: 16, length: 5)]
                    )
                }
            }
        }
    }

    private func context(followingCharacter: Character) -> PasteInsertionContext {
        PasteInsertionContext(
            selectionLength: 4,
            selectedText: "fine",
            caretLocation: 16,
            previousCharacter: " ",
            followingCharacter: followingCharacter
        )
    }
}

private final class TerminalPunctuationAXInspector: PasteAXInspecting {
    struct ExpandedSelection: Equatable {
        let location: Int
        let length: Int
    }

    let context: PasteInsertionContext
    var expandedSelections: [ExpandedSelection] = []

    init(context: PasteInsertionContext) {
        self.context = context
    }

    func focusedInsertionContext() -> PasteInsertionContext? { context }
    func includeFollowingCharacterInSelection(at location: Int, selectionLength: Int) -> Bool {
        expandedSelections.append(
            ExpandedSelection(location: location, length: selectionLength + 1)
        )
        return true
    }
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
