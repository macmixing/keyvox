import XCTest
@testable import KeyVox

@MainActor
final class PasteUntouchedInsertionReplacerTests: XCTestCase {
    func testNormalizedRangeAcceptsOnlyOmittedAccessibilityLineBreaks() {
        let expectedText = ["α", "", "β", "γ"].joined(separator: "\n")
        let accessibleText = ["αβ", "γ"].joined(separator: "\n")
        let accessibleLength = (accessibleText as NSString).length
        let prefixLength = ("π" as NSString).length
        let expectedRange = CFRange(location: prefixLength, length: accessibleLength)
        let selectedRange = CFRange(
            location: expectedRange.location + expectedRange.length,
            length: 0
        )

        let resolvedRange = PasteUntouchedInsertionReplacer.accessibilityNormalizedRange(
            for: expectedText,
            selectedRange: selectedRange,
            candidateText: { range in
                guard range.location == expectedRange.location,
                      range.length == expectedRange.length else {
                    return nil
                }
                return accessibleText
            }
        )

        XCTAssertEqual(resolvedRange?.location, expectedRange.location)
        XCTAssertEqual(resolvedRange?.length, expectedRange.length)
    }

    func testNormalizedRangeRejectsChangedNonLineBreakContent() {
        let expectedText = ["α", "", "β", "γ"].joined(separator: "\n")
        let changedAccessibleText = ["αδ", "γ"].joined(separator: "\n")
        let candidateLength = (changedAccessibleText as NSString).length
        let selectedRange = CFRange(location: candidateLength, length: 0)

        let resolvedRange = PasteUntouchedInsertionReplacer.accessibilityNormalizedRange(
            for: expectedText,
            selectedRange: selectedRange,
            candidateText: { range in
                range.length == candidateLength ? changedAccessibleText : nil
            }
        )

        XCTAssertNil(resolvedRange)
    }

    func testNormalizedRangeRequiresCollapsedSelection() {
        let expectedText = ["α", "β"].joined(separator: "\n")
        let selectedRange = CFRange(
            location: (expectedText as NSString).length,
            length: ("β" as NSString).length
        )

        let resolvedRange = PasteUntouchedInsertionReplacer.accessibilityNormalizedRange(
            for: expectedText,
            selectedRange: selectedRange,
            candidateText: { _ in expectedText }
        )

        XCTAssertNil(resolvedRange)
    }

    func testUnconfirmedMultilineReplacementUsesCleanMenuFallback() {
        let strategy = PasteUntouchedInsertionReplacer.writeStrategy(
            hasValueReplacement: true,
            isSelectedTextConfirmed: false,
            replacementContainsLineBreaks: true
        )

        XCTAssertEqual(strategy, .menuFallback)
    }

    func testUnconfirmedSingleLineReplacementRetainsValueRepairPath() {
        let strategy = PasteUntouchedInsertionReplacer.writeStrategy(
            hasValueReplacement: true,
            isSelectedTextConfirmed: false,
            replacementContainsLineBreaks: false
        )

        XCTAssertEqual(strategy, .value)
    }

    func testConfirmedSelectionRetainsSelectedTextPath() {
        let strategy = PasteUntouchedInsertionReplacer.writeStrategy(
            hasValueReplacement: true,
            isSelectedTextConfirmed: true,
            replacementContainsLineBreaks: true
        )

        XCTAssertEqual(strategy, .selectedText)
    }

    func testMissingValueRepairUsesMenuFallbackBeforeMutation() {
        let strategy = PasteUntouchedInsertionReplacer.writeStrategy(
            hasValueReplacement: false,
            isSelectedTextConfirmed: true,
            replacementContainsLineBreaks: false
        )

        XCTAssertEqual(strategy, .menuFallback)
    }

    func testMenuFallbackPreservesCollapsedCaretProducedAfterTargetStart() {
        let targetRange = CFRange(
            location: ("α" as NSString).length,
            length: ("βγ" as NSString).length
        )
        let selectedRange = CFRange(
            location: targetRange.location + targetRange.length,
            length: 0
        )

        XCTAssertTrue(
            PasteUntouchedInsertionReplacer.shouldPreserveMenuFallbackCaret(
                selectedRange,
                targetRange: targetRange
            )
        )
    }

    func testMenuFallbackDoesNotPreserveSelectionOrUnmovedCaret() {
        let targetRange = CFRange(
            location: ("α" as NSString).length,
            length: ("βγ" as NSString).length
        )
        let unmovedCaret = CFRange(location: targetRange.location, length: 0)
        let activeSelection = CFRange(
            location: targetRange.location,
            length: targetRange.length
        )

        XCTAssertFalse(
            PasteUntouchedInsertionReplacer.shouldPreserveMenuFallbackCaret(
                unmovedCaret,
                targetRange: targetRange
            )
        )
        XCTAssertFalse(
            PasteUntouchedInsertionReplacer.shouldPreserveMenuFallbackCaret(
                activeSelection,
                targetRange: targetRange
            )
        )
    }
}
