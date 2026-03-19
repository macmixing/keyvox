import Foundation

enum KeyboardInsertionSpacingHeuristics {
    static func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        documentContextBeforeInput: String?
    ) -> String {
        guard let firstIncoming = text.first else { return text }
        guard !firstIncoming.isWhitespace else { return text }
        guard let previous = documentContextBeforeInput?.last else { return text }
        guard shouldInsertLeadingSpace(previous: previous, firstIncoming: firstIncoming) else {
            return text
        }
        return " " + text
    }

    private static func shouldInsertLeadingSpace(previous: Character, firstIncoming: Character) -> Bool {
        if previous.isWhitespace { return false }

        let incomingPunctuation = CharacterSet(charactersIn: ".,!?;:)]}\\\"'”’")
        if firstIncoming.unicodeScalars.allSatisfy({ incomingPunctuation.contains($0) }) {
            return false
        }

        if "([{".contains(previous) {
            return false
        }

        let spacingTriggerPunctuation = CharacterSet(charactersIn: ".,!?;:)]}\\\"'”’")
        let previousIsWordLike = previous.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        let previousIsTriggerPunctuation = previous.unicodeScalars.contains {
            spacingTriggerPunctuation.contains($0)
        }

        return previousIsWordLike || previousIsTriggerPunctuation
    }
}
