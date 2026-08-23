import ApplicationServices
import XCTest
@testable import KeyVox

@MainActor
final class PasteTerminalPunctuationCoordinatorTests: XCTestCase {
    func testRemovesModelPeriodBeforeFollowingLowercaseWordAcrossWhitespace() {
        let element = AXUIElementCreateApplication(getpid())
        let inspector = TerminalPunctuationAXInspector(
            context: PasteInsertionContext(
                selectionLength: 0,
                caretLocation: 16,
                previousCharacter: "g",
                followingCharacter: " ",
                followingNonWhitespaceCharacter: "m"
            ),
            element: element
        )
        let coordinator = PasteTerminalPunctuationCoordinator(axInspector: inspector)

        let output = coordinator.resolveAdjacentTerminalPunctuation(in: "really awesome.")

        XCTAssertEqual(output.text, "really awesome")
        XCTAssertTrue(output.targetElement === element)
        XCTAssertTrue(inspector.expandedSelections.isEmpty)
    }

    func testRemovesModelPeriodBeforeExistingPunctuation() {
        let element = AXUIElementCreateApplication(getpid())
        for existingPunctuation in [
            Character("."), Character("?"), Character("!"),
            Character(","), Character(";"), Character(":"),
            Character(")"), Character("—"), Character("…"),
        ] {
            let inspector = TerminalPunctuationAXInspector(
                context: context(followingCharacter: existingPunctuation),
                element: element
            )
            let coordinator = PasteTerminalPunctuationCoordinator(axInspector: inspector)

            let output = coordinator.resolveAdjacentTerminalPunctuation(in: "working.")

            XCTAssertEqual(output.text, "working")
            XCTAssertTrue(output.targetElement === element)
            XCTAssertTrue(inspector.expandedSelections.isEmpty)
        }
    }

    func testIncomingQuestionAndExclamationReplaceDifferentPunctuationAndReuseMatchingMark() {
        let element = AXUIElementCreateApplication(getpid())
        for incomingPunctuation in [Character("?"), Character("!")] {
            for existingPunctuation in [
                Character("."), Character("?"), Character("!"),
                Character(","), Character(";"), Character(":"),
                Character(")"), Character("—"), Character("…"),
            ] {
                let inspector = TerminalPunctuationAXInspector(
                    context: context(followingCharacter: existingPunctuation),
                    element: element
                )
                let coordinator = PasteTerminalPunctuationCoordinator(axInspector: inspector)

                let output = coordinator.resolveAdjacentTerminalPunctuation(
                    in: "working\(incomingPunctuation)"
                )

                if incomingPunctuation == existingPunctuation {
                    XCTAssertEqual(output.text, "working")
                    XCTAssertTrue(inspector.expandedSelections.isEmpty)
                } else {
                    XCTAssertEqual(output.text, "working\(incomingPunctuation)")
                    XCTAssertEqual(
                        inspector.expandedSelections,
                        [.init(location: 16, length: 5)]
                    )
                    XCTAssertTrue(inspector.expandedElements.allSatisfy { $0 === element })
                }
                XCTAssertTrue(output.targetElement === element)
            }
        }
    }

    func testFailedSelectionExpansionPreservesExistingPunctuationWithoutConflict() {
        let element = AXUIElementCreateApplication(getpid())
        let inspector = TerminalPunctuationAXInspector(
            context: context(followingCharacter: ","),
            element: element,
            selectionExpansionSucceeds: false
        )
        let coordinator = PasteTerminalPunctuationCoordinator(axInspector: inspector)

        let output = coordinator.resolveAdjacentTerminalPunctuation(in: "working?")

        XCTAssertEqual(output.text, "working")
        XCTAssertTrue(output.targetElement === element)
        XCTAssertEqual(inspector.expandedSelections, [.init(location: 16, length: 5)])
        XCTAssertTrue(inspector.expandedElements.allSatisfy { $0 === element })
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
    let element: AXUIElement
    let selectionExpansionSucceeds: Bool
    var expandedSelections: [ExpandedSelection] = []
    var expandedElements: [AXUIElement] = []

    init(
        context: PasteInsertionContext,
        element: AXUIElement,
        selectionExpansionSucceeds: Bool = true
    ) {
        self.context = context
        self.element = element
        self.selectionExpansionSucceeds = selectionExpansionSucceeds
    }

    func focusedInsertionContext() -> PasteInsertionContext? { context }
    func insertionContext(for element: AXUIElement) -> PasteInsertionContext? {
        guard element === self.element else { return nil }
        return context
    }
    func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool {
        expandedElements.append(element)
        expandedSelections.append(
            ExpandedSelection(location: range.location, length: range.length)
        )
        return selectionExpansionSucceeds
    }
    func focusedUIElement() -> AXUIElement? { element }
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
