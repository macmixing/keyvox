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

    private static let cardinalSpellingsByNumericToken: [String: String] = {
        let formatter = makeSpellOutFormatter()
        var lookup: [String: String] = [:]
        for value in 0...999 {
            guard let spelledOut = spelledOutCardinal(for: value, using: formatter) else { continue }
            lookup[String(value)] = spelledOut
        }
        return lookup
    }()

    private static let cardinalNumericLookup: [String: String] = {
        cardinalSpellingsByNumericToken.reduce(into: [:]) { lookup, form in
            lookup[form.value] = form.key
        }
    }()

    private static let compactCardinalSpellingLookup: [String: String] = {
        cardinalSpellingsByNumericToken.values.reduce(into: [:]) { lookup, spelling in
            lookup[spelling.replacingOccurrences(of: " ", with: "")] = spelling
        }
    }()

    static func isNumericToken(_ normalizedToken: String) -> Bool {
        let range = NSRange(location: 0, length: (normalizedToken as NSString).length)
        return numericTokenRegex.firstMatch(in: normalizedToken, options: [], range: range) != nil
    }

    static func tokenVariants(for normalizedToken: String) -> [String] {
        if let spelledOut = cardinalSpelling(for: normalizedToken) {
            return normalizedToken == spelledOut
                ? [normalizedToken]
                : [normalizedToken, spelledOut]
        }

        if let expandedSpelling = compactCardinalSpellingLookup[normalizedToken],
           expandedSpelling != normalizedToken {
            return [normalizedToken, expandedSpelling]
        }

        return [normalizedToken]
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

        return unique(variants.flatMap(variantsWithCardinalAliases))
    }

    private static func variantsWithCardinalAliases(_ variant: PhraseVariant) -> [PhraseVariant] {
        let spans = cardinalSpans(for: variant)
        guard !spans.isEmpty else { return [variant] }

        func build(
            spanIndex: Int,
            tokenIndex: Int,
            tokens: [String],
            numericSourceTokens: [String?]
        ) -> [PhraseVariant] {
            guard tokenIndex < variant.tokens.count else {
                return [PhraseVariant(
                    normalized: tokens.joined(separator: " "),
                    tokens: tokens,
                    numericSourceTokens: numericSourceTokens
                )]
            }

            guard spanIndex < spans.count, spans[spanIndex].start == tokenIndex else {
                return build(
                    spanIndex: spanIndex,
                    tokenIndex: tokenIndex + 1,
                    tokens: tokens + [variant.tokens[tokenIndex]],
                    numericSourceTokens: numericSourceTokens + [variant.numericSourceTokens[tokenIndex]]
                )
            }

            let span = spans[spanIndex]
            let originalTokens = Array(variant.tokens[span.start..<span.end])
            let originalSources = Array(variant.numericSourceTokens[span.start..<span.end])
            let kept = build(
                spanIndex: spanIndex + 1,
                tokenIndex: span.end,
                tokens: tokens + originalTokens,
                numericSourceTokens: numericSourceTokens + originalSources
            )
            let collapsed = build(
                spanIndex: spanIndex + 1,
                tokenIndex: span.end,
                tokens: tokens + [span.source],
                numericSourceTokens: numericSourceTokens + [span.source]
            )
            return kept + collapsed
        }

        return build(spanIndex: 0, tokenIndex: 0, tokens: [], numericSourceTokens: [])
    }

    private static func cardinalSpans(
        for variant: PhraseVariant
    ) -> [(start: Int, end: Int, source: String)] {
        var spans: [(start: Int, end: Int, source: String)] = []
        var index = 0

        while index < variant.tokens.count {
            guard variant.numericSourceTokens[index] == nil else {
                index += 1
                continue
            }

            var phrase = ""
            var best: (start: Int, end: Int, source: String)?
            for end in index..<variant.tokens.count {
                phrase = phrase.isEmpty
                    ? variant.tokens[end]
                    : "\(phrase) \(variant.tokens[end])"
                if let source = cardinalNumericLookup[phrase] {
                    best = (start: index, end: end + 1, source: source)
                }
            }

            guard let best else {
                index += 1
                continue
            }

            spans.append(best)
            index = best.end
        }

        return spans
    }

    private static func cardinalSpelling(for normalizedToken: String) -> String? {
        guard let digits = numericToken(for: normalizedToken),
              let value = Int(digits) else {
            return nil
        }

        if let cachedSpelling = cardinalSpellingsByNumericToken[digits] {
            return cachedSpelling
        }

        return spelledOutCardinal(for: value, using: makeSpellOutFormatter())
    }

    private static func makeSpellOutFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }

    private static func spelledOutCardinal(for value: Int, using formatter: NumberFormatter) -> String? {
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

        let digits = nsToken.substring(with: match.range(at: 1))
        return Int(digits).map(String.init) ?? digits
    }

    private static func unique(_ values: [PhraseVariant]) -> [PhraseVariant] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.normalized).inserted }
    }
}
