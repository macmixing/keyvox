import Foundation

public struct ChillHeuristicFormatter: Sendable {
    public init() {}

    public func format(_ text: String) -> String {
        paragraphTexts(in: text)
            .map(formatParagraph)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func formatParagraph(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        if lines.allSatisfy({ orderedListLine(in: $0) != nil }) {
            return lines
                .compactMap(formatOrderedListLine)
                .joined(separator: "\n")
        }

        return formatInlineText(text)
    }

    private func formatInlineText(_ text: String) -> String {
        var segments: [(text: String, terminator: Character?)] = []
        var current: [String] = []
        let characters = Array(text.lowercased())
        var index = characters.startIndex

        while index < characters.endIndex {
            let character = characters[index]

            if character.isWhitespace {
                current.append(String(character))
                index = characters.index(after: index)
                continue
            }

            let tokenEnd = characters[index...].firstIndex(where: \.isWhitespace) ?? characters.endIndex
            let token = String(characters[index..<tokenEnd])
            if let protectedInlineToken = protectedInlineToken(in: token) {
                current.append(protectedInlineToken.text)
                if let trailingPunctuation = protectedInlineToken.trailingPunctuation {
                    if isSentenceBoundary(trailingPunctuation) {
                        appendSegment(current.joined(), terminator: trailingPunctuation == "?" ? "?" : ".", to: &segments)
                        current.removeAll(keepingCapacity: true)
                    } else {
                        current.append(replacement(for: trailingPunctuation))
                    }
                }
                index = tokenEnd
                continue
            }

            for character in characters[index..<tokenEnd] {
                if isSentenceBoundary(character) {
                    appendSegment(current.joined(), terminator: character == "?" ? "?" : ".", to: &segments)
                    current.removeAll(keepingCapacity: true)
                } else {
                    current.append(replacement(for: character))
                }
            }
            index = tokenEnd
        }

        appendSegment(current.joined(), terminator: nil, to: &segments)

        return segments.enumerated().map { index, segment in
            let isLast = index == segments.count - 1
            if isLast {
                return segment.terminator == "?" ? segment.text + "?" : segment.text
            }
            return segment.text + (segment.terminator == "?" ? "? " : ". ")
        }.joined()
    }

    private func formatOrderedListLine(_ line: String) -> String? {
        guard let orderedListLine = orderedListLine(in: line) else { return nil }
        let formattedText = formatInlineText(orderedListLine.text)
        guard !formattedText.isEmpty else { return "\(orderedListLine.marker)." }
        return "\(orderedListLine.marker). \(formattedText)"
    }

    private func orderedListLine(in line: String) -> (marker: String, text: String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let markerEnd = trimmedLine.firstIndex(where: { !$0.isNumber }) else {
            return nil
        }

        let marker = String(trimmedLine[..<markerEnd])
        guard !marker.isEmpty,
              trimmedLine[markerEnd] == "." else {
            return nil
        }

        let textStart = trimmedLine.index(after: markerEnd)
        let text = String(trimmedLine[textStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (marker, text)
    }

    private func paragraphTexts(in text: String) -> [String] {
        var paragraphs: [String] = []
        var currentLines: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendParagraph(currentLines.joined(separator: "\n"), to: &paragraphs)
                currentLines.removeAll(keepingCapacity: true)
            } else {
                currentLines.append(line)
            }
        }

        appendParagraph(currentLines.joined(separator: "\n"), to: &paragraphs)
        return paragraphs
    }

    private func appendParagraph(_ text: String, to paragraphs: inout [String]) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        paragraphs.append(text)
    }

    private func appendSegment(
        _ text: String,
        terminator: Character?,
        to segments: inout [(text: String, terminator: Character?)]
    ) {
        let normalized = normalizedSegment(text)
        guard !normalized.isEmpty else { return }
        segments.append((normalized, terminator))
    }

    private func normalizedSegment(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
    }

    private func replacement(for character: Character) -> String {
        if character.isLetter || character.isNumber || character.isWhitespace {
            return String(character)
        }

        if character == "'" || character == "’" || character == "‘" {
            return ""
        }

        if character.isEmojiLike {
            return String(character)
        }

        if character.isSymbolLike {
            return String(character)
        }

        return " "
    }

    private func isSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?"
    }

    private func protectedInlineToken(in token: String) -> (text: String, trailingPunctuation: Character?)? {
        if let trailingPunctuation = token.last,
           isProtectedTrailingPunctuation(trailingPunctuation) {
            let candidate = String(token.dropLast())
            if isProtectedInlineToken(candidate) {
                return (candidate, trailingPunctuation)
            }
        }

        guard isProtectedInlineToken(token) else { return nil }
        return (token, nil)
    }

    private func isProtectedInlineToken(_ token: String) -> Bool {
        let parts = token.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let local = parts.first,
              let domain = parts.last,
              !local.isEmpty,
              !domain.isEmpty,
              domain.contains(".") else {
            return false
        }

        return token.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || CharacterSet(charactersIn: "._%+-@").contains(scalar)
        }
    }

    private func isProtectedTrailingPunctuation(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character == ","
    }

}

private extension Character {
    var isEmojiLike: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmoji
                || scalar.properties.isEmojiPresentation
                || scalar.properties.isEmojiModifier
                || scalar.properties.isEmojiModifierBase
        }
    }

    var isSymbolLike: Bool {
        unicodeScalars.allSatisfy { scalar in
            CharacterSet.symbols.contains(scalar)
        }
    }
}
