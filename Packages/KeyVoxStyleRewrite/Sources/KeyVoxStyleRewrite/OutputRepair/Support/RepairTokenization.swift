import Foundation
import NaturalLanguage

struct RepairWordToken: Equatable {
    let text: String
    let normalized: String
    let range: Range<String.Index>
}

struct RepairTaggedToken {
    let token: RepairWordToken
    let tag: NLTag?
    let lemma: String?
}

enum RepairTokenization {
    static func wordTokens(in text: String) -> [RepairWordToken] {
        var tokens: [RepairWordToken] = []
        var tokenStart: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            if isWordCharacter(text[index]) {
                if tokenStart == nil {
                    tokenStart = index
                }
            } else if let start = tokenStart {
                appendToken(in: text, range: start..<index, to: &tokens)
                tokenStart = nil
            }

            index = text.index(after: index)
        }

        if let start = tokenStart {
            appendToken(in: text, range: start..<text.endIndex, to: &tokens)
        }

        return tokens
    }

    static func taggedTokens(in text: String) -> [RepairTaggedToken] {
        let wordTokens = wordTokens(in: text)
        guard !wordTokens.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        return wordTokens.map { token in
            let tag = tagger.tag(at: token.range.lowerBound, unit: .word, scheme: .lexicalClass).0
            let lemma = tagger.tag(at: token.range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            return RepairTaggedToken(token: token, tag: tag, lemma: lemma)
        }
    }

    private static func appendToken(
        in text: String,
        range: Range<String.Index>,
        to tokens: inout [RepairWordToken]
    ) {
        let tokenText = String(text[range])
        let normalized = tokenText
            .lowercased()
            .filter { character in
                character.isLetter || character.isNumber
            }
        guard !normalized.isEmpty else { return }
        tokens.append(RepairWordToken(text: tokenText, normalized: normalized, range: range))
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter
            || character.isNumber
            || character == "'"
            || character == "’"
            || character == "‘"
    }
}
