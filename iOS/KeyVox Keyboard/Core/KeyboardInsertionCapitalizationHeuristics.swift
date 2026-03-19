import Foundation

enum KeyboardInsertionCapitalizationHeuristics {
    static func normalizeLeadingCapitalizationIfNeeded(
        text: String,
        documentContextBeforeInput: String?,
        shouldPreserveLeadingCapitalization: (String) -> Bool = { _ in false }
    ) -> String {
        guard let firstCharacter = text.first else { return text }
        guard firstCharacter.isLetter else { return text }

        guard shouldPreserveLeadingCapitalizationForContext(
            in: text,
            documentContextBeforeInput: documentContextBeforeInput,
            shouldPreserveLeadingCapitalization: shouldPreserveLeadingCapitalization
        ) == false else {
            return text
        }

        let loweredFirstCharacter = String(firstCharacter).lowercased()
        return loweredFirstCharacter + text.dropFirst()
    }

    private static func shouldPreserveLeadingCapitalizationForContext(
        in text: String,
        documentContextBeforeInput: String?,
        shouldPreserveLeadingCapitalization: (String) -> Bool
    ) -> Bool {
        if shouldPreserveLeadingCapitalization(text) {
            return true
        }

        guard let leadingToken = leadingWordRun(in: text) else {
            return true
        }

        guard isDefaultSentenceCaseToken(leadingToken) else {
            return true
        }

        return isSentenceStart(documentContextBeforeInput: documentContextBeforeInput)
    }

    private static func isSentenceStart(documentContextBeforeInput: String?) -> Bool {
        guard let context = documentContextBeforeInput?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let previousCharacter = context.last else {
            return true
        }

        return previousCharacter == "." || previousCharacter == "?" || previousCharacter == "!"
    }

    private static func leadingWordRun(in text: String) -> Substring? {
        let leadingRun = text.prefix(while: \.isLetter)
        return leadingRun.isEmpty ? nil : leadingRun[...]
    }

    private static func isDefaultSentenceCaseToken(_ token: Substring) -> Bool {
        guard let firstCharacter = token.first, firstCharacter.isUppercase else {
            return false
        }

        let remainingCharacters = token.dropFirst()
        guard remainingCharacters.isEmpty == false else {
            return false
        }

        return remainingCharacters.allSatisfy(\.isLowercase)
    }
}
