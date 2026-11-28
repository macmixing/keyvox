import Foundation
import KeyVoxTypingSimulation

/// The typeable words of one sentence, in order, lowercased.
///
/// A sentence contributes only when every token is a letter word (apostrophes
/// allowed), so the preceding-word context handed to the engine is never
/// broken by numbers, symbols, or other tokens the harness cannot type. Without a
/// layout the letters are the English ones, ASCII; with a typing language's layout they
/// are the letters its keys type or its held popups offer.
struct SentenceWords {
    let words: [String]
    /// The words as the sentence writes them, with their capitals.
    let written: [String]

    init?(sentence: String, layout: KeyboardLayoutModel? = nil) {
        let tokens = Self.tokens(in: sentence)
        guard tokens.isEmpty == false,
              tokens.allSatisfy({ Self.isTypeableWord($0, layout: layout) }) else {
            return nil
        }
        words = tokens.map { $0.lowercased() }
        written = tokens
    }

    /// The sentence's whitespace-separated tokens with the characters other than letters around
    /// them trimmed, as written, typographic apostrophes straightened; tokens of no letters are
    /// left out.
    static func tokens(in sentence: String) -> [String] {
        sentence
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                token.trimmingCharacters(in: CharacterSet.letters.inverted)
            }
            .filter { $0.isEmpty == false }
    }

    /// Up to three earlier words, newest first, matching the engine's context window.
    func previousWords(before index: Int) -> [String] {
        Array(words[..<index].reversed().prefix(3))
    }

    private static func isTypeableWord(_ token: String, layout: KeyboardLayoutModel?) -> Bool {
        if let layout {
            return token.lowercased().allSatisfy { $0 == "'" || layout.types($0) }
        }
        return token.unicodeScalars.allSatisfy { scalar in
            (scalar.isASCII && CharacterSet.letters.contains(scalar)) || scalar == "'"
        }
    }
}
