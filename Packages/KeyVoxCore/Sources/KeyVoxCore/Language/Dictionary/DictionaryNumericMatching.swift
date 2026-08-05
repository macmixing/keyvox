import Foundation

enum DictionaryNumericMatching {
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

    static func phraseVariants(for normalizedTokens: [String]) -> [String] {
        guard !normalizedTokens.isEmpty else { return [] }

        var variants = [""]
        for token in normalizedTokens {
            let tokenVariants = tokenVariants(for: token)
            variants = variants.flatMap { prefix in
                tokenVariants.map { tokenVariant in
                    [prefix, tokenVariant]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                }
            }
        }

        return unique(variants)
    }

    private static func cardinalSpelling(for normalizedToken: String) -> String? {
        let nsToken = normalizedToken as NSString
        let range = NSRange(location: 0, length: nsToken.length)
        guard let match = numericTokenRegex.firstMatch(in: normalizedToken, options: [], range: range) else {
            return nil
        }

        let digits = nsToken.substring(with: match.range(at: 1))
        guard let value = Int(digits) else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        guard let spelledOut = formatter.string(from: NSNumber(value: value)) else {
            return nil
        }

        return DictionaryTextNormalization.normalizedPhrase(spelledOut)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
