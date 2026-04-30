import Foundation

public struct ChillHeuristicFormatter: Sendable {
    public init() {}

    public func format(_ text: String) -> String {
        var segments: [(text: String, terminator: Character?)] = []
        var current: [String] = []

        for character in text.lowercased() {
            if isSentenceBoundary(character) {
                appendSegment(current.joined(), terminator: character == "?" ? "?" : ".", to: &segments)
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(replacement(for: character))
            }
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

        return " "
    }

    private func isSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?"
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
}
