import Foundation
import KeyVoxLinguistics

/// Decides whether a capital that opens a continuation, such as the word after an inline
/// ellipsis or a spoken comma, belongs to the word itself or only to a sentence start the
/// continuation removed.
struct ContinuationCasingPolicy {
    private static let capitalizedSpellings = try? CapitalizedSpellings()

    func preservesCapital(
        of token: String,
        at tokenRange: NSRange,
        in text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        isFirstPersonPronoun(token)
            || token.unicodeScalars.dropFirst().contains { $0.properties.isUppercase }
            || Self.capitalizedSpellings?.spelling(of: token) != nil
            || isRecognizedName(at: tokenRange, in: text)
            || beginsRecognizedNamePhrase(at: tokenRange, in: text)
            || isDottedAcronym(startingAt: tokenRange, in: text)
            || beginsDictionaryEntry(at: tokenRange, in: text, dictionaryEntries: dictionaryEntries)
    }

    private func isFirstPersonPronoun(_ token: String) -> Bool {
        guard token.first == "I" else { return false }
        let remainder = token.dropFirst()
        guard !remainder.isEmpty else { return true }
        guard remainder.first == "'" || remainder.first == "’" else { return false }
        let contraction = remainder.dropFirst()
        return !contraction.isEmpty && contraction.allSatisfy { $0.isLetter }
    }

    /// A word the analyzer calls a name, and that still reads as a content word once it is
    /// written in lowercase, so a capital that only marked a sentence start is not mistaken
    /// for a name.
    private func isRecognizedName(at tokenRange: NSRange, in text: String) -> Bool {
        let analysis = TextLinguistics.analyze(
            text,
            features: [.names, .wordBoundaries]
        )
        guard analysis.tokens.contains(where: {
            NSLocationInRange(tokenRange.location, $0.range) && $0.identity == .name
        }) else { return false }

        return !isFunctionRole(lowercaseRole(at: tokenRange, in: text))
    }

    /// The role of the word at `tokenRange` written in lowercase, judged by the part before any
    /// apostrophe so a contraction reads as the word it contracts.
    private func lowercaseRole(at tokenRange: NSRange, in text: String) -> LexicalRole? {
        let nsText = text as NSString
        let token = nsText.substring(with: tokenRange)
        let base = token.prefix { $0 != "'" && $0 != "’" }.lowercased()
        guard !base.isEmpty else { return nil }

        let probeText = nsText.replacingCharacters(in: tokenRange, with: base)
        let analysis = TextLinguistics.analyze(
            probeText,
            features: [.roles, .wordBoundaries]
        )
        return analysis.tokens.first(where: {
            NSLocationInRange(tokenRange.location, $0.range)
        })?.role
    }

    private func isFunctionRole(_ role: LexicalRole?) -> Bool {
        switch role {
        case .pronoun, .determiner, .preposition, .conjunction, .particle, .adverb, .verb:
            return true
        default:
            return false
        }
    }

    private func beginsRecognizedNamePhrase(at tokenRange: NSRange, in text: String) -> Bool {
        let analysis = TextLinguistics.analyze(
            text,
            features: [.names, .wordBoundaries]
        )
        guard let tokenIndex = analysis.tokens.firstIndex(where: {
            NSLocationInRange(tokenRange.location, $0.range)
        }),
        tokenIndex + 1 < analysis.tokens.count else { return false }

        let token = analysis.tokens[tokenIndex]
        let nextToken = analysis.tokens[tokenIndex + 1]
        guard case .name = token.identity,
              case .name = nextToken.identity,
              let separatorRange = Range(
                  NSRange(
                      location: NSMaxRange(token.range),
                      length: nextToken.range.location - NSMaxRange(token.range)
                  ),
                  in: text
              ) else { return false }
        return text[separatorRange].allSatisfy(\.isWhitespace)
    }

    private func isDottedAcronym(startingAt tokenRange: NSRange, in text: String) -> Bool {
        guard let tokenStringRange = Range(tokenRange, in: text) else { return false }
        return text[tokenStringRange.lowerBound...].range(
            of: #"^(?:\p{Lu}\.){2,}"#,
            options: .regularExpression
        ) != nil
    }

    private func beginsDictionaryEntry(
        at tokenRange: NSRange,
        in text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        guard let tokenStringRange = Range(tokenRange, in: text) else { return false }
        let suffix = text[tokenStringRange.lowerBound...]

        for entry in dictionaryEntries {
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty,
                  let match = suffix.range(
                      of: phrase,
                      options: [.anchored, .caseInsensitive, .diacriticInsensitive]
                  ) else {
                continue
            }

            guard match.upperBound < suffix.endIndex else { return true }
            let nextCharacter = suffix[match.upperBound]
            if !nextCharacter.isLetter, !nextCharacter.isNumber, nextCharacter != "_" {
                return true
            }
        }

        return false
    }
}
