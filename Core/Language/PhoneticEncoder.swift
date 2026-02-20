import Foundation

struct PhoneticEncoder {
    @MainActor
    func signature(for normalizedToken: String, lexicon: PronunciationLexiconProviding) -> String {
        if let known = lexicon.pronunciation(for: normalizedToken) {
            return known
        }

        return fallbackSignature(for: normalizedToken)
    }

    @MainActor
    func phraseSignature(for tokens: [String], lexicon: PronunciationLexiconProviding) -> String {
        tokens
            .map { signature(for: $0, lexicon: lexicon) }
            .joined(separator: " ")
    }

    @MainActor
    func scoringSignature(for normalizedToken: String, lexicon: PronunciationLexiconProviding) -> String {
        fallbackSignature(for: signature(for: normalizedToken, lexicon: lexicon))
    }

    @MainActor
    func scoringPhraseSignature(for tokens: [String], lexicon: PronunciationLexiconProviding) -> String {
        tokens
            .map { scoringSignature(for: $0, lexicon: lexicon) }
            .joined(separator: " ")
    }

    func fallbackSignature(for token: String) -> String {
        guard !token.isEmpty else { return "" }

        let lowered = token.lowercased()
        let characters = Array(lowered)
        var output = ""
        var lastCode: Character?

        for index in characters.indices {
            let char = characters[index]
            let code = phoneticCode(for: char)
            guard let code else { continue }

            // Preserve the first non-empty code even if it is vowel-like.
            if output.isEmpty {
                output.append(code)
                lastCode = code
                continue
            }

            // Remove vowels and duplicate groups after first symbol.
            if code == "A" || code == lastCode {
                continue
            }

            output.append(code)
            lastCode = code

            if output.count >= 8 {
                break
            }
        }

        return output.isEmpty ? lowered : output
    }

    private func phoneticCode(for character: Character) -> Character? {
        switch character {
        case "a", "e", "i", "o", "u", "y":
            return "A"
        case "b", "p":
            return "B"
        case "c", "k", "q", "g":
            return "K"
        case "d", "t":
            return "T"
        case "f", "v":
            return "F"
        case "j":
            return "J"
        case "l":
            return "L"
        case "m", "n":
            return "N"
        case "r":
            return "R"
        case "s", "z", "x":
            return "S"
        case "h", "w":
            return nil
        case "0"..."9":
            return character
        default:
            return nil
        }
    }
}
