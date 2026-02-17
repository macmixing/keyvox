import Foundation

final class PasteSpacingHeuristics {
    private let axInspector: PasteAXInspecting
    private let heuristicTTL: TimeInterval

    init(axInspector: PasteAXInspecting, heuristicTTL: TimeInterval) {
        self.axInspector = axInspector
        self.heuristicTTL = heuristicTTL
    }

    func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> String {
        guard let firstIncoming = text.first else { return text }
        let context = axInspector.focusedInsertionContext()

        // Replacements should not auto-prefix a separator.
        if let context {
            if let selectionLength = context.selectionLength, selectionLength > 0 {
                return text
            }

            if let caretLocation = context.caretLocation, caretLocation == 0 {
                return text
            }

            if let previous = context.previousCharacter {
                guard shouldInsertLeadingSpace(previous: previous, firstIncoming: firstIncoming) else {
                    return text
                }
                return " " + text
            }
        }

        guard shouldInsertLeadingSpaceFromHeuristic(
            firstIncoming: firstIncoming,
            currentIdentity: currentIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            identityMatcher: identityMatcher
        ) else {
            return text
        }

        // Best-effort fallback when AX context cannot provide a previous character.
        return " " + text
    }

    private func shouldInsertLeadingSpaceFromHeuristic(
        firstIncoming: Character,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> Bool {
        guard let previous = lastInsertedTrailingCharacter else { return false }
        guard Date().timeIntervalSince(lastInsertionAt) <= heuristicTTL else { return false }
        guard let currentIdentity,
              let lastInsertionAppIdentity,
              identityMatcher(currentIdentity, lastInsertionAppIdentity) else {
            return false
        }

        return shouldInsertLeadingSpace(previous: previous, firstIncoming: firstIncoming)
    }

    private func shouldInsertLeadingSpace(previous: Character, firstIncoming: Character) -> Bool {
        if firstIncoming.isWhitespace { return false }
        if previous.isWhitespace { return false }

        // If incoming text starts with punctuation, do not prefix a space.
        let incomingPunctuation = CharacterSet(charactersIn: ".,!?;:)]}\\\"'”’")
        if firstIncoming.unicodeScalars.allSatisfy({ incomingPunctuation.contains($0) }) {
            return false
        }

        // If we are immediately after an opening delimiter, do not prefix.
        if "([{".contains(previous) {
            return false
        }

        let spacingTriggerPunctuation = CharacterSet(charactersIn: ".,!?;:)]}\\\"'”’")
        let previousIsWordLike = previous.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        let previousIsTriggerPunctuation = previous.unicodeScalars.contains { spacingTriggerPunctuation.contains($0) }

        // Start a new dictation segment after a word/sentence boundary.
        return previousIsWordLike || previousIsTriggerPunctuation
    }
}
