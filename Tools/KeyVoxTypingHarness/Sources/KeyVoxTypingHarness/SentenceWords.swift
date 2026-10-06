import Foundation

/// The typeable words of one sentence, in order, lowercased.
///
/// A sentence contributes only when every token is a letter word (apostrophes
/// allowed), so the preceding-word context handed to the engine is never
/// broken by numbers, symbols, or other tokens the harness cannot type.
struct SentenceWords {
    let words: [String]

    init?(sentence: String) {
        let tokens = sentence
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                token.trimmingCharacters(in: CharacterSet.letters.inverted)
            }
            .filter { $0.isEmpty == false }
        guard tokens.isEmpty == false,
              tokens.allSatisfy(Self.isTypeableWord) else {
            return nil
        }
        words = tokens.map { $0.lowercased() }
    }

    /// Up to three earlier words, newest first, matching the engine's context window.
    func previousWords(before index: Int) -> [String] {
        Array(words[..<index].reversed().prefix(3))
    }

    private static func isTypeableWord(_ token: String) -> Bool {
        token.unicodeScalars.allSatisfy { scalar in
            (scalar.isASCII && CharacterSet.letters.contains(scalar)) || scalar == "'"
        }
    }
}
