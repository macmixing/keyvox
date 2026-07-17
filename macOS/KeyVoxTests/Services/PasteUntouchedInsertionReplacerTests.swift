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

    func testTargetUsesExactAccessibilityRangeBeforeFallbacks() {
        let inspector = MockUntouchedInsertionAXInspector()
        let currentText = "βγ"
        let currentLength = (currentText as NSString).length
        let targetRange = CFRange(location: 1, length: currentLength)
        inspector.selectedRangeValue = CFRange(
            location: targetRange.location + targetRange.length,
            length: 0
        )
        inspector.stringForRangeHandler = { range in
            guard range.location == targetRange.location,
                  range.length == targetRange.length else {
                return nil
            }
            return currentText
        }
        let replacer = PasteUntouchedInsertionReplacer(axInspector: inspector)

        let target = replacer.target(for: currentText)

        XCTAssertEqual(target?.range.location, targetRange.location)
        XCTAssertEqual(target?.range.length, targetRange.length)
        XCTAssertEqual(
            inspector.calls,
            [
                .focusedUIElement,
                .selectedRange,
                .stringForRange(NSRange(location: targetRange.location, length: targetRange.length)),
            ]
        )
    }

    func testTargetFallsBackToLineBreakNormalizedRangeAfterExactRangeMisses() {
        let inspector = MockUntouchedInsertionAXInspector()
        let currentText = ["a", "", "b"].joined(separator: "\n")
        inspector.selectedRangeValue = CFRange(location: 4, length: 0)
        inspector.stringForRangeHandler = { range in
            switch (range.location, range.length) {
            case (0, 4):
                return "zzab"
            case (2, 2):
                return "ab"
            default:
                return nil
            }
        }
        let replacer = PasteUntouchedInsertionReplacer(axInspector: inspector)

        let target = replacer.target(for: currentText)

        XCTAssertEqual(target?.range.location, 2)
        XCTAssertEqual(target?.range.length, 2)
        XCTAssertEqual(
            inspector.calls,
            [
                .focusedUIElement,
                .selectedRange,
                .stringForRange(NSRange(location: 0, length: 4)),
                .stringForRange(NSRange(location: 0, length: 4)),
                .stringForRange(NSRange(location: 1, length: 3)),
                .stringForRange(NSRange(location: 2, length: 2)),
            ]
        )
    }

    func testReplaceUsesConfirmedSelectedTextAndVerifiesBeforeMovingCaret() {
        let inspector = MockUntouchedInsertionAXInspector()
        let currentText = "αβ"
        let replacementText = ["γ", "δ"].joined(separator: "\n")
        let target = PasteUntouchedInsertionTarget(
            element: inspector.element,
            range: CFRange(location: 1, length: (currentText as NSString).length)
        )
        inspector.valueStringResponses = ["παβω"]
        inspector.selectedTextValue = currentText
        inspector.stringForRangeHandler = { range in
            let replacementRange = CFRange(
                location: target.range.location,
                length: (replacementText as NSString).length
            )
            guard range.location == replacementRange.location,
                  range.length == replacementRange.length else {
                return nil
            }
            return replacementText
        }
        let replacer = PasteUntouchedInsertionReplacer(axInspector: inspector)

        let outcome = replacer.replace(currentText, with: replacementText, target: target)

        guard case .succeeded = outcome else {
            return XCTFail("Expected selected-text replacement to succeed")
        }
        XCTAssertEqual(
            inspector.calls,
            [
                .setSelectedRange(NSRange(location: 1, length: 2)),
                .valueString,
                .selectedText,
                .setSelectedText(replacementText),
                .stringForRange(NSRange(location: 1, length: 3)),
                .setSelectedRange(NSRange(location: 4, length: 0)),
            ]
        )
    }

    func testReplaceUsesValuePathWhenSelectedTextCannotBeConfirmed() {
        let inspector = MockUntouchedInsertionAXInspector()
        let currentText = "αβ"
        let replacementText = "γδ"
        let target = PasteUntouchedInsertionTarget(
            element: inspector.element,
            range: CFRange(location: 1, length: (currentText as NSString).length)
        )
        inspector.valueStringResponses = ["παβω", "πγδω"]
        let replacer = PasteUntouchedInsertionReplacer(axInspector: inspector)

        let outcome = replacer.replace(currentText, with: replacementText, target: target)

        guard case .succeeded = outcome else {
            return XCTFail("Expected value replacement to succeed")
        }
        XCTAssertEqual(
            inspector.calls,
            [
                .setSelectedRange(NSRange(location: 1, length: 2)),
                .valueString,
                .selectedText,
                .setValueString("πγδω"),
                .valueString,
                .setSelectedRange(NSRange(location: 3, length: 0)),
            ]
        )
    }

    func testReplaceFallsBackToValueAfterSelectedTextVerificationFails() {
        let inspector = MockUntouchedInsertionAXInspector()
        let currentText = "αβ"
        let replacementText = "γδ"
        let target = PasteUntouchedInsertionTarget(
            element: inspector.element,
            range: CFRange(location: 1, length: (currentText as NSString).length)
        )
        inspector.valueStringResponses = ["παβω", "πγδω"]
        inspector.selectedTextValue = currentText
        inspector.stringForRangeHandler = { _ in nil }
        let replacer = PasteUntouchedInsertionReplacer(
            axInspector: inspector,
            verificationTimeout: 0
        )

        let outcome = replacer.replace(currentText, with: replacementText, target: target)

        guard case .succeeded = outcome else {
            return XCTFail("Expected value fallback to succeed")
        }
        let selectedTextMutation = inspector.calls.firstIndex(of: .setSelectedText(replacementText))
        let valueMutation = inspector.calls.firstIndex(of: .setValueString("πγδω"))
        XCTAssertNotNil(selectedTextMutation)
        XCTAssertNotNil(valueMutation)
        if let selectedTextMutation, let valueMutation {
            XCTAssertLessThan(selectedTextMutation, valueMutation)
        }
    }

    func testReplaceFailsWhenValueMutationCannotBeVerified() {
        let inspector = MockUntouchedInsertionAXInspector()
        let currentText = "αβ"
        let replacementText = "γδ"
        let target = PasteUntouchedInsertionTarget(
            element: inspector.element,
            range: CFRange(location: 1, length: (currentText as NSString).length)
        )
        inspector.valueStringResponses = ["παβω", "παβω"]
        let replacer = PasteUntouchedInsertionReplacer(
            axInspector: inspector,
            verificationTimeout: 0
        )

        let outcome = replacer.replace(currentText, with: replacementText, target: target)

        guard case .failed = outcome else {
            return XCTFail("Expected unverified value replacement to fail")
        }
        XCTAssertEqual(
            inspector.calls.filter {
                if case .setSelectedRange = $0 { return true }
                return false
            },
            [.setSelectedRange(NSRange(location: 1, length: 2))]
        )
    }
}

private final class MockUntouchedInsertionAXInspector: PasteAXInspecting {
    enum Call: Equatable {
        case focusedUIElement
        case selectedRange
        case selectedText
        case setSelectedRange(NSRange)
        case setSelectedText(String)
        case setValueString(String)
        case stringForRange(NSRange)
        case valueString
    }

    let element = AXUIElementCreateApplication(getpid())
    var selectedRangeValue: CFRange?
    var selectedTextValue: String?
    var valueStringResponses: [String?] = []
    var stringForRangeHandler: (CFRange) -> String? = { _ in nil }
    var setSelectedRangeResult = true
    var setSelectedTextResult = true
    var setValueStringResult = true
    private(set) var calls: [Call] = []

    func focusedInsertionContext() -> PasteInsertionContext? { nil }

    func focusedUIElement() -> AXUIElement? {
        calls.append(.focusedUIElement)
        return element
    }

    func roleString(for element: AXUIElement) -> String? {
        _ = element
        return nil
    }

    func selectedRange(for element: AXUIElement) -> CFRange? {
        _ = element
        calls.append(.selectedRange)
        return selectedRangeValue
    }

    func selectedText(for element: AXUIElement) -> String? {
        _ = element
        calls.append(.selectedText)
        return selectedTextValue
    }

    func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool {
        _ = element
        calls.append(.setSelectedRange(NSRange(location: range.location, length: range.length)))
        return setSelectedRangeResult
    }

    func setSelectedText(_ text: String, for element: AXUIElement) -> Bool {
        _ = element
        calls.append(.setSelectedText(text))
        return setSelectedTextResult
    }

    func setValueString(_ text: String, for element: AXUIElement) -> Bool {
        _ = element
        calls.append(.setValueString(text))
        return setValueStringResult
    }

    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
        _ = element
        calls.append(.stringForRange(NSRange(location: range.location, length: range.length)))
        return stringForRangeHandler(range)
    }

    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? {
        _ = element
        _ = caretLocation
        return nil
    }

    func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        _ = element
        return nil
    }

    func valueStringForMenuVerification(element: AXUIElement) -> String? {
        _ = element
        calls.append(.valueString)
        guard valueStringResponses.isEmpty == false else { return nil }
        return valueStringResponses.removeFirst()
    }

    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        _ = pid
        _ = maxDepth
        _ = maxNodes
        _ = maxCandidates
        return []
    }
}
