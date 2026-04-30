import Foundation

public struct ChillHeuristicFormatter: Sendable {
    public init() {}

    public func format(_ text: String) -> String {
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
            if isProtectedInlineToken(token) {
                current.append(token)
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
