public struct TerminalPunctuationCompositionResult: Equatable, Sendable {
    public let text: String
    public let shouldReplaceFollowingPunctuation: Bool

    public init(text: String, shouldReplaceFollowingPunctuation: Bool) {
        self.text = text
        self.shouldReplaceFollowingPunctuation = shouldReplaceFollowingPunctuation
    }
}

public enum TerminalPunctuationCompositionPolicy {
    public static func resolve(
        text: String,
        followingCharacter: Character?,
        followingNonWhitespaceCharacter: Character? = nil
    ) -> TerminalPunctuationCompositionResult {
        guard let followingCharacter,
              let incomingPunctuation = text.last,
              TextCompositionPolicy.isSentenceBoundary(incomingPunctuation) else {
            return TerminalPunctuationCompositionResult(
                text: text,
                shouldReplaceFollowingPunctuation: false
            )
        }

        let nextContentCharacter = followingCharacter.isWhitespace
            ? followingNonWhitespaceCharacter
            : followingCharacter
        if incomingPunctuation == ".", nextContentCharacter?.isLowercase == true {
            return TerminalPunctuationCompositionResult(
                text: String(text.dropLast()),
                shouldReplaceFollowingPunctuation: false
            )
        }

        guard followingCharacter.isPunctuation,
              isQuotationMark(followingCharacter) == false else {
            return TerminalPunctuationCompositionResult(
                text: text,
                shouldReplaceFollowingPunctuation: false
            )
        }

        if incomingPunctuation == "." {
            return TerminalPunctuationCompositionResult(
                text: String(text.dropLast()),
                shouldReplaceFollowingPunctuation: false
            )
        }

        if incomingPunctuation == followingCharacter {
            return TerminalPunctuationCompositionResult(
                text: String(text.dropLast()),
                shouldReplaceFollowingPunctuation: false
            )
        }

        return TerminalPunctuationCompositionResult(
            text: text,
            shouldReplaceFollowingPunctuation: true
        )
    }

    private static func isQuotationMark(_ character: Character) -> Bool {
        switch character {
        case "\"", "'", "“", "”", "‘", "’":
            return true
        default:
            return false
        }
    }
}
