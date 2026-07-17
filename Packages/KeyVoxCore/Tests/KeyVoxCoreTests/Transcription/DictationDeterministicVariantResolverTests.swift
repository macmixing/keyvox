import XCTest
@testable import KeyVoxCore

final class DictationDeterministicVariantResolverTests: XCTestCase {
    private let resolver = DictationDeterministicVariantResolver()
    private let formatter = DictationDeterministicTextFormatter()

    func testParagraphTargetTogglesOnlyParagraphState() {
        let state = DictationDeterministicState(paragraphsEnabled: true, listsEnabled: true)

        let target = resolver.targetState(from: state, kind: .paragraphs)

        XCTAssertEqual(target, DictationDeterministicState(paragraphsEnabled: false, listsEnabled: true))
    }

    func testListTargetTogglesOnlyListState() {
        let state = DictationDeterministicState(paragraphsEnabled: false, listsEnabled: false)

        let target = resolver.targetState(from: state, kind: .lists)

        XCTAssertEqual(target, DictationDeterministicState(paragraphsEnabled: false, listsEnabled: true))
    }

    func testRenderedTargetTextTakesPriorityOverDeterministicText() {
        let target = DictationDeterministicState(paragraphsEnabled: false, listsEnabled: true)
        let current = DictationDeterministicState(paragraphsEnabled: false, listsEnabled: false)

        let text = resolver.sourceText(
            for: target,
            deterministicText: "Tasks: 1. Alpha; 2. Beta",
            currentState: current,
            currentSourceText: "Tasks one Alpha two Beta",
            renderedTextForTargetState: "Tasks:\n\n1. Alpha\n2. Beta"
        )

        XCTAssertEqual(text, "Tasks:\n\n1. Alpha\n2. Beta")
    }

    func testDeterministicTextIsUsedWhenNoRenderedTargetExists() {
        let target = DictationDeterministicState(paragraphsEnabled: true, listsEnabled: false)
        let current = DictationDeterministicState(paragraphsEnabled: false, listsEnabled: false)

        let text = resolver.sourceText(
            for: target,
            deterministicText: "First paragraph.\n\nSecond paragraph.",
            currentState: current,
            currentSourceText: "First paragraph. Second paragraph."
        )

        XCTAssertEqual(text, "First paragraph.\n\nSecond paragraph.")
    }

    func testDisablingParagraphsPreservesListLineBreaks() {
        let target = DictationDeterministicState(paragraphsEnabled: false, listsEnabled: true)
        let current = DictationDeterministicState(paragraphsEnabled: true, listsEnabled: true)

        let text = resolver.sourceText(
            for: target,
            deterministicText: "unused",
            currentState: current,
            currentSourceText: "Intro paragraph.\n\nAnother thought.\n\n1. Alpha\n2. Beta"
        )

        XCTAssertEqual(text, "Intro paragraph. Another thought.\n\n1. Alpha\n2. Beta")
    }

    func testFormatterCollapsesAllLineBreaksWhenListsAreDisabled() {
        let state = DictationDeterministicState(paragraphsEnabled: false, listsEnabled: false)

        let text = formatter.textAdjustedForDeterministicState(
            "First paragraph.\n\nSecond paragraph.",
            state: state
        )

        XCTAssertEqual(text, "First paragraph. Second paragraph.")
    }

    func testFormatterLeavesParagraphTextUnchangedWhenParagraphsAreEnabled() {
        let state = DictationDeterministicState(paragraphsEnabled: true, listsEnabled: false)
        let original = "First paragraph.\n\nSecond paragraph."

        XCTAssertEqual(formatter.textAdjustedForDeterministicState(original, state: state), original)
    }

    func testPostRewriteFormattingCoversAllFourDeterministicStates() {
        let rewritten = "Intro.\n\nMore context.\n\n1. First\n2. Second"
        let expectations: [(DictationDeterministicState, String)] = [
            (
                DictationDeterministicState(paragraphsEnabled: false, listsEnabled: false),
                "Intro. More context. 1. First 2. Second"
            ),
            (
                DictationDeterministicState(paragraphsEnabled: false, listsEnabled: true),
                "Intro. More context.\n\n1. First\n2. Second"
            ),
            (
                DictationDeterministicState(paragraphsEnabled: true, listsEnabled: false),
                rewritten
            ),
            (
                DictationDeterministicState(paragraphsEnabled: true, listsEnabled: true),
                rewritten
            ),
        ]

        for (state, expectedText) in expectations {
            XCTAssertEqual(
                formatter.textAdjustedForDeterministicState(rewritten, state: state),
                expectedText,
                "Unexpected post-rewrite layout for \(state)"
            )
        }
    }
}
