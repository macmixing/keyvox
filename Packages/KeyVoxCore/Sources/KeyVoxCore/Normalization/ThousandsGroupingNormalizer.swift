import Foundation
import NaturalLanguage

public struct ThousandsGroupingNormalizer {
    private struct LexicalToken {
        let text: String
        let range: NSRange
        let tag: NLTag?
    }

    private static let candidateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{4}\b"#,
        options: []
    )
    private static let isoDateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{4}-\d{2}-\d{2}\b"#,
        options: []
    )
    private static let slashedOrHyphenatedDateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,
        options: []
    )
    private static let versionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d+(?:\.\d+){1,}\b"#,
        options: []
    )
    private static let phoneRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:\d{3}\s*-\s*)?\d{3}\s*-\s*\d{4}\b"#,
        options: []
    )
    private static let compactHyphenatedNumericRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,4}(?:-\d{1,4}){2,}\b"#,
        options: []
    )
    private static let plausibleYearRange = 1000...2999
    private static func makeGroupingFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter
    }

    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }
        guard text.rangeOfCharacter(from: .decimalDigits) != nil else { return text }

        let groupingFormatter = Self.makeGroupingFormatter()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let normalizedLines = lines.map { normalizeLine($0, groupingFormatter: groupingFormatter) }
        return normalizedLines.joined(separator: "\n")
    }

    private func normalizeLine(_ line: String, groupingFormatter: NumberFormatter) -> String {
        guard let candidateRegex = Self.candidateRegex else { return line }

        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        let matches = candidateRegex.matches(in: line, options: [], range: fullRange)
        guard !matches.isEmpty else { return line }

        let protectedRanges = protectedRanges(in: line, fullRange: fullRange)
        let lexicalTokens = lexicalTokens(in: line, range: fullRange)
        let mutable = NSMutableString(string: line)

        for match in matches.reversed() {
            let range = match.range
            guard !protectedRanges.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { continue }

            let digits = nsLine.substring(with: range)
            guard let value = Int(digits) else { continue }
            guard shouldGroup(value: value, range: range, tokens: lexicalTokens) else { continue }
            guard let replacement = groupingFormatter.string(from: NSNumber(value: value)) else { continue }
            mutable.replaceCharacters(in: range, with: replacement)
        }

        return mutable as String
    }

    private func protectedRanges(in line: String, fullRange: NSRange) -> [NSRange] {
        [
            Self.isoDateRegex,
            Self.slashedOrHyphenatedDateRegex,
            Self.versionRegex,
            Self.phoneRegex,
            Self.compactHyphenatedNumericRegex,
        ]
        .compactMap { $0 }
        .flatMap { $0.matches(in: line, options: [], range: fullRange).map(\.range) }
    }

    private func lexicalTokens(in line: String, range: NSRange) -> [LexicalToken] {
        guard let stringRange = Range(range, in: line) else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = line

        var tokens: [LexicalToken] = []
        tagger.enumerateTags(
            in: stringRange,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, tokenRange in
            let token = String(line[tokenRange])
            let nsTokenRange = NSRange(tokenRange, in: line)
            tokens.append(LexicalToken(text: token, range: nsTokenRange, tag: tag))
            return true
        }
        return tokens
    }

    private func shouldGroup(value: Int, range: NSRange, tokens: [LexicalToken]) -> Bool {
        if !Self.plausibleYearRange.contains(value) {
            return true
        }

        guard let tokenIndex = resolvedTokenIndex(for: range, in: tokens) else {
            return false
        }

        let previous = tokenIndex > 0 ? tokens[tokenIndex - 1] : nil
        let next = tokenIndex + 1 < tokens.count ? tokens[tokenIndex + 1] : nil
        let secondNext = tokenIndex + 2 < tokens.count ? tokens[tokenIndex + 2] : nil

        if isLikelyYearReference(
            value: value,
            previous: previous,
            next: next,
            secondNext: secondNext
        ) {
            return false
        }

        return true
    }

    private func resolvedTokenIndex(for range: NSRange, in tokens: [LexicalToken]) -> Int? {
        if let exactMatch = tokens.firstIndex(where: { NSEqualRanges($0.range, range) }) {
            return exactMatch
        }

        return tokens.firstIndex { token in
            NSIntersectionRange(token.range, range).length > 0 ||
            NSLocationInRange(range.location, token.range) ||
            NSLocationInRange(token.range.location, range)
        }
    }

    private func isLikelyYearReference(
        value: Int,
        previous: LexicalToken?,
        next: LexicalToken?,
        secondNext: LexicalToken?
    ) -> Bool {
        guard Self.plausibleYearRange.contains(value) else { return false }

        if next == nil, previous == nil {
            return false
        }

        if let nextTag = next?.tag,
           [.verb, .pronoun, .determiner, .conjunction].contains(nextTag) {
            return true
        }

        if previous?.tag == .preposition, next?.tag == .interjection {
            return true
        }

        if next == nil, previous?.tag == .adverb {
            return true
        }

        if next?.tag == .preposition {
            if let secondNextTag = secondNext?.tag,
               [.pronoun, .determiner].contains(secondNextTag) {
                return false
            }

            if previous?.tag == .preposition {
                return true
            }
        }

        if previous == nil, next?.tag == .noun {
            return true
        }

        if next == nil,
           let previousTag = previous?.tag,
           [.noun, .determiner, .preposition].contains(previousTag) {
            return true
        }

        if previous?.tag == .determiner, next?.tag == .noun {
            return true
        }

        if previous?.tag == .noun, next?.tag == .noun {
            return true
        }

        return false
    }
}
