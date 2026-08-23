import Foundation

public enum TextCompositionPolicy {
    public static func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        context: TextCompositionContext,
        scope: LeadingCapitalizationScope,
        preserveLeadingCapitalization: Bool
    ) -> String {
        let sentenceStart = isSentenceStart(in: context)
        let output = normalizedLeadingCapitalization(
            in: text,
            isSentenceStart: sentenceStart,
            scope: scope,
            preserveLeadingCapitalization: preserveLeadingCapitalization
        )
        #if DEBUG
        logNormalization(
            input: text,
            output: output,
            sentenceStart: sentenceStart,
            context: context
        )
        #endif
        return output
    }

    public static func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        isSentenceStart: Bool,
        scope: LeadingCapitalizationScope,
        preserveLeadingCapitalization: Bool
    ) -> String {
        let output = normalizedLeadingCapitalization(
            in: text,
            isSentenceStart: isSentenceStart,
            scope: scope,
            preserveLeadingCapitalization: preserveLeadingCapitalization
        )
        #if DEBUG
        logNormalization(
            input: text,
            output: output,
            sentenceStart: isSentenceStart,
            context: nil
        )
        #endif
        return output
    }

    private static func normalizedLeadingCapitalization(
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
        guard LeadingDateCapitalizationPolicy.shouldPreserveCapitalization(
            in: text,
            startingAt: capitalizationIndex
        ) == false else {
            return text
        }

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
        let output: String
        if let previousCharacter = context.previousCharacter,
           isImmediatelyAfterOpeningQuote(context) == false {
            output = applySmartLeadingSeparatorIfNeeded(
                to: text,
                previousCharacter: previousCharacter
            )
        } else {
            output = text
        }
        #if DEBUG
        logSpacing(input: text, output: output, context: context)
        #endif
        return output
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

        if isImmediatelyAfterTerminalPunctuationAndDelimiter(context) {
            return true
        }

        if isImmediatelyAfterEmojiAtSentenceBoundary(context) {
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

    public static func isImmediatelyAfterTerminalPunctuationAndDelimiter(
        _ context: TextCompositionContext
    ) -> Bool {
        guard let delimiter = context.previousNonWhitespaceCharacter ?? context.previousCharacter,
              isCapitalizationDelimiter(delimiter) else {
            return false
        }

        let characterBeforeDelimiter: Character?
        if context.previousCharacter == delimiter {
            characterBeforeDelimiter = context.characterBeforePreviousCharacter
        } else {
            characterBeforeDelimiter = context.characterBeforePreviousNonWhitespaceCharacter
        }

        guard let characterBeforeDelimiter else { return true }
        return isSentenceBoundary(characterBeforeDelimiter)
    }

    private static func isCapitalizationDelimiter(_ character: Character) -> Bool {
        character.isPunctuation || character.isSymbol
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

    private static func isImmediatelyAfterEmojiAtSentenceBoundary(
        _ context: TextCompositionContext
    ) -> Bool {
        guard let previousNonWhitespaceCharacter = context.previousNonWhitespaceCharacter,
              TextCompositionCharacterClassifier.isEmoji(previousNonWhitespaceCharacter) else {
            return false
        }

        if context.isPreviousNonWhitespaceCharacterAtLineStart {
            return true
        }

        guard let characterBeforeEmoji = context.characterBeforePreviousNonWhitespaceCharacter else {
            return true
        }

        return isSentenceBoundary(characterBeforeEmoji)
    }

    #if DEBUG
    private static func logNormalization(
        input: String,
        output: String,
        sentenceStart: Bool,
        context: TextCompositionContext?
    ) {
        guard ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1" else {
            return
        }
        let previousNonWhitespace = context.map {
            debugCharacter($0.previousNonWhitespaceCharacter)
        } ?? "-"
        let characterBeforePreviousNonWhitespace = context.map {
            debugCharacter($0.characterBeforePreviousNonWhitespaceCharacter)
        } ?? "-"
        let lineStart = context.map {
            String($0.isPreviousNonWhitespaceCharacterAtLineStart)
        } ?? "-"
        print(
            "[KVXTextComposition] leadingCapitalization "
                + "changed=\(input != output) "
                + "inputLength=\(input.count) outputLength=\(output.count) "
                + "output=\(output) "
                + "sentenceStart=\(sentenceStart) "
                + "previousNonWhitespace=\(previousNonWhitespace) "
                + "beforePreviousNonWhitespace=\(characterBeforePreviousNonWhitespace) "
                + "previousNonWhitespaceAtLineStart=\(lineStart)"
        )
    }

    private static func logSpacing(
        input: String,
        output: String,
        context: TextCompositionContext
    ) {
        guard ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1" else {
            return
        }
        print(
            "[KVXTextComposition] leadingSeparator "
                + "changed=\(input != output) "
                + "inputLength=\(input.count) outputLength=\(output.count) "
                + "output=\(output) "
                + "previousCharacter=\(debugCharacter(context.previousCharacter))"
        )
    }

    private static func debugCharacter(_ character: Character?) -> String {
        guard let character else { return "-" }
        let scalars = character.unicodeScalars
            .map { String(format: "U+%04X", $0.value) }
            .joined(separator: "+")
        return "\(String(reflecting: character))[\(scalars)]"
    }
    #endif

    private static func shouldInsertLeadingSpace(
        previousCharacter: Character,
        firstIncomingCharacter: Character
    ) -> Bool {
        if firstIncomingCharacter.isWhitespace || previousCharacter.isWhitespace {
            return false
        }

        let punctuation = CharacterSet(charactersIn: ".,!?;:)]}\\\"'”’&")
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
        return previousIsWordLike
            || previousIsTriggerPunctuation
            || TextCompositionCharacterClassifier.isEmoji(previousCharacter)
    }
}
