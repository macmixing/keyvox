import Foundation

enum DictionaryNumericMatching {
    struct PhraseVariant {
        let normalized: String
        let tokens: [String]
        let numericSourceTokens: [String?]
    }

    private static let numericTokenRegex = try! NSRegularExpression(
        pattern: #"^(\d+)(?:st|nd|rd|th)?$"#,
        options: []
    )

    static func isNumericToken(_ normalizedToken: String) -> Bool {
        let range = NSRange(location: 0, length: (normalizedToken as NSString).length)
        return numericTokenRegex.firstMatch(in: normalizedToken, options: [], range: range) != nil
    }

    static func tokenVariants(for normalizedToken: String) -> [String] {
        guard let spelledOut = cardinalSpelling(for: normalizedToken) else {
            return [normalizedToken]
        }

        return normalizedToken == spelledOut
            ? [normalizedToken]
            : [normalizedToken, spelledOut]
    }

    static func phraseVariants(for normalizedTokens: [String]) -> [PhraseVariant] {
        guard !normalizedTokens.isEmpty else { return [] }

        var variants = [PhraseVariant(normalized: "", tokens: [], numericSourceTokens: [])]
        for token in normalizedTokens {
            let tokenVariants = tokenVariants(for: token)
            let numericSourceToken = numericSourceToken(for: token)
            variants = variants.flatMap { prefix in
                tokenVariants.map { tokenVariant in
                    let variantTokens = tokenVariant.split(separator: " ").map(String.init)
                    let variantSourceTokens = variantTokens.map { _ in numericSourceToken }
                    let combinedTokens = prefix.tokens + variantTokens
                    return PhraseVariant(
                        normalized: combinedTokens.joined(separator: " "),
                        tokens: combinedTokens,
                        numericSourceTokens: prefix.numericSourceTokens + variantSourceTokens
                    )
                }
            }
        }

        return unique(variants)
    }

    private static func cardinalSpelling(for normalizedToken: String) -> String? {
        guard let digits = numericToken(for: normalizedToken),
              let value = Int(digits) else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        guard let spelledOut = formatter.string(from: NSNumber(value: value)) else {
            return nil
        }

        return DictionaryTextNormalization.normalizedPhrase(spelledOut)
    }

    private static func numericSourceToken(for normalizedToken: String) -> String? {
        numericToken(for: normalizedToken)
    }

    private static func numericToken(for normalizedToken: String) -> String? {
        let nsToken = normalizedToken as NSString
        let range = NSRange(location: 0, length: nsToken.length)
        guard let match = numericTokenRegex.firstMatch(in: normalizedToken, options: [], range: range) else {
            return nil
        }

        return nsToken.substring(with: match.range(at: 1))
    }

    private static func unique(_ values: [PhraseVariant]) -> [PhraseVariant] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.normalized).inserted }
    }
}
