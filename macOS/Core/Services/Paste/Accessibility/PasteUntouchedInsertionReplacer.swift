import Cocoa

struct PasteUntouchedInsertionTarget {
    let element: AXUIElement
    let range: CFRange
}

enum PasteUntouchedInsertionReplacementOutcome {
    case succeeded
    case menuFallbackAllowed
    case failed
}

enum PasteUntouchedInsertionWriteStrategy: Equatable {
    case selectedText
    case value
    case menuFallback
}

protocol PasteUntouchedInsertionReplacing: AnyObject {
    func target(for text: String) -> PasteUntouchedInsertionTarget?
    func replace(
        _ currentText: String,
        with replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) -> PasteUntouchedInsertionReplacementOutcome
    func finalizeMenuFallbackReplacement(
        _ replacementText: String,
        target: PasteUntouchedInsertionTarget
    )
    func moveCaretToEnd(of replacementText: String, target: PasteUntouchedInsertionTarget)
}

extension PasteUntouchedInsertionReplacing {
    func finalizeMenuFallbackReplacement(
        _ replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) {
        moveCaretToEnd(of: replacementText, target: target)
    }
}

final class PasteUntouchedInsertionReplacer: PasteUntouchedInsertionReplacing {
    private struct ValueReplacement {
        let text: String
        let replacementLength: Int
    }

    private let axInspector: PasteAXInspecting
    private let verificationTimeout: TimeInterval
    private var trackedValueTarget: PasteUntouchedInsertionTarget?

    init(
        axInspector: PasteAXInspecting,
        verificationTimeout: TimeInterval = 0.12
    ) {
        self.axInspector = axInspector
        self.verificationTimeout = verificationTimeout
    }

    func target(for text: String) -> PasteUntouchedInsertionTarget? {
        guard text.isEmpty == false,
              let element = axInspector.focusedUIElement(),
              let selectedRange = axInspector.selectedRange(for: element) else {
            return nil
        }

        let textLength = (text as NSString).length
        if selectedRange.length == 0, selectedRange.location >= textLength {
            let range = CFRange(
                location: selectedRange.location - textLength,
                length: textLength
            )
            if axInspector.stringForRange(range, element: element) == text {
                return PasteUntouchedInsertionTarget(element: element, range: range)
            }
        }

        if let normalizedTarget = accessibilityNormalizedTarget(
            for: text,
            selectedRange: selectedRange,
            element: element
        ) {
            return normalizedTarget
        }

        guard let trackedValueTarget,
              CFEqual(trackedValueTarget.element, element),
              trackedValueTarget.range.length == textLength,
              let currentValue = axInspector.valueStringForMenuVerification(element: element) else {
            return nil
        }

        let value = currentValue as NSString
        let range = NSRange(
            location: trackedValueTarget.range.location,
            length: trackedValueTarget.range.length
        )
        guard range.location + range.length == value.length,
              value.substring(with: range) == text else {
            return nil
        }

        return trackedValueTarget
    }

    private func accessibilityNormalizedTarget(
        for text: String,
        selectedRange: CFRange,
        element: AXUIElement
    ) -> PasteUntouchedInsertionTarget? {
        guard let range = Self.accessibilityNormalizedRange(
            for: text,
            selectedRange: selectedRange,
            candidateText: { range in
                self.axInspector.stringForRange(range, element: element)
            }
        ) else {
            return nil
        }

        return PasteUntouchedInsertionTarget(element: element, range: range)
    }

    static func accessibilityNormalizedRange(
        for text: String,
        selectedRange: CFRange,
        candidateText: (CFRange) -> String?
    ) -> CFRange? {
        guard selectedRange.length == 0 else { return nil }

        let expectedLength = (text as NSString).length
        let lineBreakLength = text.unicodeScalars.reduce(into: 0) { length, scalar in
            if CharacterSet.newlines.contains(scalar) {
                length += String(scalar).utf16.count
            }
        }
        guard lineBreakLength > 0 else { return nil }

        let expectedWithoutLineBreaks = text.components(separatedBy: .newlines).joined()
        guard expectedWithoutLineBreaks.isEmpty == false else { return nil }

        let shortestCandidateLength = max(1, expectedLength - lineBreakLength)
        let longestCandidateLength = min(expectedLength, selectedRange.location)
        guard longestCandidateLength >= shortestCandidateLength else { return nil }

        for candidateLength in stride(
            from: longestCandidateLength,
            through: shortestCandidateLength,
            by: -1
        ) {
            let candidateRange = CFRange(
                location: selectedRange.location - candidateLength,
                length: candidateLength
            )
            guard let candidateText = candidateText(candidateRange) else {
                continue
            }

            let candidateWithoutLineBreaks = candidateText
                .components(separatedBy: .newlines)
                .joined()
            guard candidateWithoutLineBreaks == expectedWithoutLineBreaks else {
                continue
            }

            return candidateRange
        }

        return nil
    }

    static func writeStrategy(
        hasValueReplacement: Bool,
        isSelectedTextConfirmed: Bool,
        replacementContainsLineBreaks: Bool
    ) -> PasteUntouchedInsertionWriteStrategy {
        if isSelectedTextConfirmed == false, replacementContainsLineBreaks {
            return .menuFallback
        }
        guard hasValueReplacement else {
            return .menuFallback
        }
        return isSelectedTextConfirmed ? .selectedText : .value
    }

    static func shouldPreserveMenuFallbackCaret(
        _ selectedRange: CFRange?,
        targetRange: CFRange
    ) -> Bool {
        guard let selectedRange else { return false }
        return selectedRange.length == 0 && selectedRange.location > targetRange.location
    }

    func replace(
        _ currentText: String,
        with replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) -> PasteUntouchedInsertionReplacementOutcome {
        guard setSelectedRange(target.range, for: target.element) else {
            return .failed
        }

        let valueReplacement = makeValueReplacement(
            currentText: currentText,
            replacementText: replacementText,
            target: target
        )

        let selectedText = axInspector.selectedText(for: target.element)
        let writeStrategy = Self.writeStrategy(
            hasValueReplacement: valueReplacement != nil,
            isSelectedTextConfirmed: selectedText == currentText,
            replacementContainsLineBreaks: replacementText.rangeOfCharacter(from: .newlines) != nil
        )

        if writeStrategy == .menuFallback {
            return .menuFallbackAllowed
        }

        if writeStrategy == .value {
            guard let valueReplacement else { return .failed }
            return replaceViaValue(valueReplacement, target: target)
        }

        guard let valueReplacement else { return .failed }

        guard axInspector.setSelectedText(replacementText, for: target.element) else {
            return replaceViaValue(valueReplacement, target: target)
        }

        let insertedRange = CFRange(
            location: target.range.location,
            length: (replacementText as NSString).length
        )
        if waitForRangeText(replacementText, range: insertedRange, element: target.element) {
            trackedValueTarget = nil
            moveCaretToEnd(of: replacementText, target: target)
            return .succeeded
        }

        return replaceViaValue(valueReplacement, target: target)
    }

    func finalizeMenuFallbackReplacement(
        _ replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) {
        let selectedRange = axInspector.selectedRange(for: target.element)
        if let selectedRange,
           Self.shouldPreserveMenuFallbackCaret(
               selectedRange,
               targetRange: target.range
           ) {
            return
        }

        moveCaretToEnd(of: replacementText, target: target)
    }

    func moveCaretToEnd(of replacementText: String, target: PasteUntouchedInsertionTarget) {
        let caretRange = CFRange(
            location: target.range.location + (replacementText as NSString).length,
            length: 0
        )
        _ = setSelectedRange(caretRange, for: target.element)
    }

    private func makeValueReplacement(
        currentText: String,
        replacementText: String,
        target: PasteUntouchedInsertionTarget
    ) -> ValueReplacement? {
        guard let currentValue = axInspector.valueStringForMenuVerification(element: target.element) else {
            return nil
        }

        let value = currentValue as NSString
        let range = NSRange(location: target.range.location, length: target.range.length)
        guard range.location >= 0,
              range.length >= 0,
              range.location + range.length <= value.length,
              value.substring(with: range) == currentText else {
            return nil
        }

        return ValueReplacement(
            text: value.replacingCharacters(in: range, with: replacementText),
            replacementLength: (replacementText as NSString).length
        )
    }

    private func replaceViaValue(
        _ replacement: ValueReplacement,
        target: PasteUntouchedInsertionTarget
    ) -> PasteUntouchedInsertionReplacementOutcome {
        guard axInspector.setValueString(replacement.text, for: target.element) else {
            return .failed
        }

        guard waitForValue(replacement.text, element: target.element) else {
            return .failed
        }

        let updatedTarget = PasteUntouchedInsertionTarget(
            element: target.element,
            range: CFRange(
                location: target.range.location,
                length: replacement.replacementLength
            )
        )
        trackedValueTarget = updatedTarget
        let caretRange = CFRange(
            location: updatedTarget.range.location + updatedTarget.range.length,
            length: 0
        )
        _ = setSelectedRange(caretRange, for: target.element)
        return .succeeded
    }

    private func waitForRangeText(_ text: String, range: CFRange, element: AXUIElement) -> Bool {
        waitUntil {
            self.axInspector.stringForRange(range, element: element) == text
        }
    }

    private func waitForValue(_ value: String, element: AXUIElement) -> Bool {
        waitUntil {
            self.axInspector.valueStringForMenuVerification(element: element) == value
        }
    }

    private func waitUntil(_ condition: () -> Bool) -> Bool {
        var delay: useconds_t = 1_000
        let timeout = Date().addingTimeInterval(verificationTimeout)

        while Date() < timeout {
            if condition() {
                return true
            }
            usleep(delay)
            delay = min(delay * 2, 16_000)
        }

        return condition()
    }

    private func setSelectedRange(_ range: CFRange, for element: AXUIElement) -> Bool {
        axInspector.setSelectedRange(range, for: element)
    }
}
