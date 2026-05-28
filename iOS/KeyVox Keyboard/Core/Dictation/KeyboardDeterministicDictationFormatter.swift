import Foundation

enum KeyboardDeterministicControlKind {
    case paragraphs
    case lists

    var debugLabel: String {
        switch self {
        case .paragraphs:
            return "paragraphs"
        case .lists:
            return "lists"
        }
    }
}

struct KeyboardDeterministicDictationState: Hashable {
    let paragraphsEnabled: Bool
    let listsEnabled: Bool

    var debugDescription: String {
        "paragraphs=\(paragraphsEnabled),lists=\(listsEnabled)"
    }
}

struct KeyboardDeterministicDictationFormatter {
    func targetState(
        from state: KeyboardDeterministicDictationState,
        kind: KeyboardDeterministicControlKind
    ) -> KeyboardDeterministicDictationState {
        switch kind {
        case .paragraphs:
            return KeyboardDeterministicDictationState(
                paragraphsEnabled: !state.paragraphsEnabled,
                listsEnabled: state.listsEnabled
            )
        case .lists:
            return KeyboardDeterministicDictationState(
                paragraphsEnabled: state.paragraphsEnabled,
                listsEnabled: !state.listsEnabled
            )
        }
    }

    func isParagraphFormattingVisiblyApplied(
        currentState: KeyboardDeterministicDictationState,
        deterministicVariants: [KeyboardDeterministicDictationState: String]
    ) -> Bool {
        guard currentState.paragraphsEnabled else {
            return false
        }

        let paragraphsOffState = KeyboardDeterministicDictationState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let paragraphsOnState = KeyboardDeterministicDictationState(
            paragraphsEnabled: true,
            listsEnabled: false
        )

        guard let paragraphsOffText = deterministicVariants[paragraphsOffState],
              let paragraphsOnText = deterministicVariants[paragraphsOnState] else {
            return currentState.paragraphsEnabled
        }

        return paragraphsOnText != paragraphsOffText
    }

    func sourceText(
        for targetState: KeyboardDeterministicDictationState,
        deterministicText: String,
        currentState: KeyboardDeterministicDictationState,
        currentSourceText: String,
        renderedTextForTargetState: String? = nil
    ) -> String {
        let targetText = renderedTextForTargetState ?? deterministicText
        guard targetState.paragraphsEnabled == false,
              currentState.listsEnabled,
              targetState.listsEnabled else {
            return targetText
        }

        return textWithParagraphBreaksCollapsedPreservingLists(currentSourceText)
    }

    func textAdjustedForDeterministicState(
        _ text: String,
        state: KeyboardDeterministicDictationState
    ) -> String {
        guard state.paragraphsEnabled == false else {
            return text
        }

        if state.listsEnabled {
            return textWithParagraphBreaksCollapsedPreservingLists(text)
        }

        return text
            .replacingOccurrences(of: "\\s*\\n+\\s*", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func textWithParagraphBreaksCollapsedPreservingLists(_ text: String) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var output = ""
        var previousLineWasListItem = false
        var hasPendingBlankLine = false

        for line in lines {
            let trimmedLine = line
                .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.isEmpty == false else {
                hasPendingBlankLine = output.isEmpty == false
                continue
            }

            let currentLineIsListItem = isOrderedListItemLine(trimmedLine)
            if output.isEmpty {
                output = trimmedLine
            } else if currentLineIsListItem || previousLineWasListItem {
                output += hasPendingBlankLine ? "\n\n\(trimmedLine)" : "\n\(trimmedLine)"
            } else {
                output += " \(trimmedLine)"
            }

            previousLineWasListItem = currentLineIsListItem
            hasPendingBlankLine = false
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isOrderedListItemLine(_ line: String) -> Bool {
        var index = line.startIndex
        var foundDigit = false

        while index < line.endIndex,
              line[index].wholeNumberValue != nil {
            foundDigit = true
            index = line.index(after: index)
        }

        guard foundDigit,
              index < line.endIndex,
              line[index] == "." else {
            return false
        }

        index = line.index(after: index)
        return index < line.endIndex && line[index].isWhitespace
    }
}
