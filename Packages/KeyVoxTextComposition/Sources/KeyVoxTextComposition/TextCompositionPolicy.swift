import Foundation

public enum TextCompositionPolicy {
    public static func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        context: TextCompositionContext,
        scope: LeadingCapitalizationScope,
        preserveLeadingCapitalization: Bool
    ) -> String {
        normalizeLeadingCapitalizationIfNeeded(
            in: text,
            isSentenceStart: isSentenceStart(in: context),
            scope: scope,
            preserveLeadingCapitalization: preserveLeadingCapitalization
        )
    }

    public static func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        isSentenceStart: Bool,
        scope: LeadingCapitalizationScope,
        preserveLeadingCapitalization: Bool
    ) -> String {
        guard text.isEmpty == false else { return text }
        guard preserveLeadingCapitalization == false else { return text }
        guard let capitalizationIndex = capitalizationIndex(in: text, scope: scope) else {
            return text
        }

        let leadingWord = text[capitalizationIndex...].prefix(while: \.isLetter)
        guard isDefaultSentenceCase(word: leadingWord) else { return text }
        guard isSentenceStart == false else { return text }

        var output = text
        let firstCharacter = output[capitalizationIndex]
        output.replaceSubrange(
            capitalizationIndex...capitalizationIndex,
            with: String(firstCharacter).lowercased()
        )
        return output
    }

    public static func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        context: TextCompositionContext
    ) -> String {
        guard let previousCharacter = context.previousCharacter else { return text }
        guard isImmediatelyAfterOpeningQuote(context) == false else { return text }
        return applySmartLeadingSeparatorIfNeeded(
            to: text,
            previousCharacter: previousCharacter
        )
    }

    public static func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        previousCharacter: Character
    ) -> String {
        guard let firstIncomingCharacter = text.first else { return text }
        guard shouldInsertLeadingSpace(
            previousCharacter: previousCharacter,
            firstIncomingCharacter: firstIncomingCharacter
        ) else {
            return text
        }
        return " " + text
    }

    public static func isSentenceStart(in context: TextCompositionContext) -> Bool {
        if context.isAtDocumentStart || context.isAfterNewline {
            return true
        }

        if isImmediatelyAfterOpeningQuote(context) {
            return true
        }

        if isImmediatelyAfterTerminalPunctuationAndClosingQuote(context) {
            return true
        }

        guard let previousNonWhitespaceCharacter = context.previousNonWhitespaceCharacter else {
            return false
        }
        return isSentenceBoundary(previousNonWhitespaceCharacter)
    }

    public static func isSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "?" || character == "!"
    }

    public static func isImmediatelyAfterOpeningQuote(
        _ context: TextCompositionContext
    ) -> Bool {
        guard let quote = context.previousCharacter else { return false }

        switch quote {
        case "“", "‘":
            return true
        case "”", "’":
            return false
        case "\"", "'":
            guard let characterBeforeQuote = context.characterBeforePreviousCharacter else {
                return true
            }
            return characterBeforeQuote.isWhitespace
                || "([{".contains(characterBeforeQuote)
                || characterBeforeQuote == "“"
                || characterBeforeQuote == "‘"
        default:
            return false
        }
    }

    public static func isImmediatelyAfterTerminalPunctuationAndClosingQuote(
        _ context: TextCompositionContext
    ) -> Bool {
        guard let quote = context.previousCharacter,
              [Character("\""), Character("'"), Character("”"), Character("’")].contains(quote),
              let characterBeforeQuote = context.characterBeforePreviousCharacter else {
            return false
        }
        return isSentenceBoundary(characterBeforeQuote)
    }

    private static func capitalizationIndex(
        in text: String,
        scope: LeadingCapitalizationScope
    ) -> String.Index? {
        switch scope {
        case .firstCharacter:
            guard let firstIndex = text.indices.first, text[firstIndex].isLetter else {
                return nil
            }
            return firstIndex
        case .firstLetterAfterLeadingWhitespace:
            guard let firstLetterIndex = text.firstIndex(where: \.isLetter) else {
                return nil
            }
            guard text[..<firstLetterIndex].allSatisfy(\.isWhitespace) else {
                return nil
            }
            return firstLetterIndex
        }
    }

    private static func isDefaultSentenceCase<S: StringProtocol>(word: S) -> Bool {
        guard let firstCharacter = word.first, firstCharacter.isUppercase else {
            return false
        }

        let remainder = word.dropFirst()
        guard remainder.isEmpty == false else { return false }
        return remainder.allSatisfy { $0.isUppercase == false }
    }

    private static func shouldInsertLeadingSpace(
        previousCharacter: Character,
        firstIncomingCharacter: Character
    ) -> Bool {
        if firstIncomingCharacter.isWhitespace || previousCharacter.isWhitespace {
            return false
        }

        let punctuation = CharacterSet(charactersIn: ".,!?;:)]}\\\"'”’")
        if firstIncomingCharacter.unicodeScalars.allSatisfy(punctuation.contains) {
            return false
        }

        if "([{".contains(previousCharacter) {
            return false
        }

        let previousIsWordLike = previousCharacter.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0)
        }
        let previousIsTriggerPunctuation = previousCharacter.unicodeScalars.contains(
            where: punctuation.contains
        )
        return previousIsWordLike || previousIsTriggerPunctuation
    }
}
