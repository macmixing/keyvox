import Foundation

protocol PasteCapitalizationHeuristicApplying {
    func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool,
        shouldPreserveLeadingCapitalization: (String) -> Bool
    ) -> String
}

final class PasteCapitalizationHeuristics: PasteCapitalizationHeuristicApplying {
    private let axInspector: PasteAXInspecting
    private let heuristicTTL: TimeInterval
    private let clockNow: () -> Date

    init(
        axInspector: PasteAXInspecting,
        heuristicTTL: TimeInterval,
        clockNow: @escaping () -> Date = Date.init
    ) {
        self.axInspector = axInspector
        self.heuristicTTL = heuristicTTL
        self.clockNow = clockNow
    }

    func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool,
        shouldPreserveLeadingCapitalization: (String) -> Bool
    ) -> String {
        guard !text.isEmpty else { return text }
        guard let firstLetterIndex = text.firstIndex(where: \.isLetter) else { return text }
        guard text[..<firstLetterIndex].allSatisfy(\.isWhitespace) else { return text }
        guard !shouldPreserveLeadingCapitalization(text) else { return text }

        let leadingWord = text[firstLetterIndex...].prefix(while: \.isLetter)
        guard isDefaultSentenceCase(word: leadingWord) else { return text }
        guard !isSentenceStart(
            currentIdentity: currentIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            identityMatcher: identityMatcher
        ) else {
            return text
        }

        var output = text
        let firstCharacter = output[firstLetterIndex]
        output.replaceSubrange(
            firstLetterIndex...firstLetterIndex,
            with: String(firstCharacter).lowercased()
        )
        return output
    }

    private func isSentenceStart(
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> Bool {
        if let context = axInspector.focusedInsertionContext() {
            if context.caretLocation == 0 {
                return true
            }

            guard context.selectionLength == 0 else { return false }
            return context.previousCharacter.map(isSentenceBoundary) ?? false
        }

        guard let currentIdentity,
              let lastInsertionAppIdentity,
              identityMatcher(currentIdentity, lastInsertionAppIdentity),
              clockNow().timeIntervalSince(lastInsertionAt) <= heuristicTTL else {
            return true
        }

        return lastInsertedTrailingCharacter.map(isSentenceBoundary) ?? false
    }

    private func isSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "?" || character == "!"
    }

    private func isDefaultSentenceCase<S: StringProtocol>(word: S) -> Bool {
        guard let firstCharacter = word.first else { return false }
        guard firstCharacter.isUppercase else { return false }

        let remainder = word.dropFirst()
        guard !remainder.isEmpty else { return false }
        return remainder.allSatisfy { !$0.isUppercase }
    }
}
