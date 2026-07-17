import Foundation

public struct DictationDeterministicTextFormatter: Sendable {
    public init() {}

    public func textAdjustedForDeterministicState(
        _ text: String,
        state: DictationDeterministicState
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

    public func textWithParagraphBreaksCollapsedPreservingLists(_ text: String) -> String {
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
