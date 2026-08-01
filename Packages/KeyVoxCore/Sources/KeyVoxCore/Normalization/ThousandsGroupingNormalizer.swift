import Foundation
import NaturalLanguage

public struct ThousandsGroupingNormalizer {
    private struct LexicalToken {
        let text: String
        let range: NSRange
        let tag: NLTag?
        let lemma: String?
    }

    private struct WordToken {
        let text: String
        let range: NSRange
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
        pattern: #"\b(?:\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b"#,
        options: []
    )
    private static let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )
    private static let addressDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.address.rawValue
    )
    private static let calendarMonthTokens: Set<String> = {
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.calendar = Calendar(identifier: .gregorian)

        let tokenGroups = [
            monthFormatter.monthSymbols ?? [],
            monthFormatter.standaloneMonthSymbols ?? [],
        ]

        return Set(tokenGroups.flatMap { $0 }.map(normalizedCalendarMonthToken).filter { !$0.isEmpty })
    }()
    private static let wordRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\p{L}+(?:-\p{L}+)?\b"#,
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
    private static let maximumSpokenQuantityTokenCount = 8
    private static func makeGroupingFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private static func makeSpellOutFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }

    private static let subThousandSpellOutLookup: [String: Int] = {
        let formatter = makeSpellOutFormatter()
        var lookup: [String: Int] = [:]

        for value in 0...999 {
            guard let spelledOut = formatter.string(from: NSNumber(value: value)) else { continue }
            lookup[normalizeSpellOutPhrase(spelledOut)] = value
        }

        return lookup
    }()

    private static func normalizeSpellOutPhrase(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    public init() {}

    public func normalizeSpokenQuantities(in text: String) -> String {
        guard !text.isEmpty else { return text }
        guard text.rangeOfCharacter(from: .letters) != nil else { return text }

        let formatter = Self.makeSpellOutFormatter()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let normalizedLines = lines.map { normalizeSpokenQuantitiesInLine($0, formatter: formatter) }
        return normalizedLines.joined(separator: "\n")
    }

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }
        guard text.rangeOfCharacter(from: .decimalDigits) != nil else { return text }

        let groupingFormatter = Self.makeGroupingFormatter()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let normalizedLines = lines.map { normalizeLine($0, groupingFormatter: groupingFormatter) }
        return normalizedLines.joined(separator: "\n")
    }

    private func normalizeSpokenQuantitiesInLine(_ line: String, formatter: NumberFormatter) -> String {
        guard let wordRegex = Self.wordRegex else { return line }

        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        let words = wordRegex.matches(in: line, options: [], range: fullRange).map {
            WordToken(text: nsLine.substring(with: $0.range), range: $0.range)
        }
        guard !words.isEmpty else { return line }

        let lexicalTokens = lexicalTokens(in: line, range: fullRange)
        var replacements: [(range: NSRange, value: Int, isLikelyYear: Bool)] = []
        var searchIndex = 0

        while searchIndex < words.count {
            var matchedSpan: (range: NSRange, value: Int, isLikelyYear: Bool, nextIndex: Int)?
            let upperBound = min(words.count, searchIndex + Self.maximumSpokenQuantityTokenCount)

            for endIndex in stride(from: upperBound, through: searchIndex + 1, by: -1) {
                let candidateWords = Array(words[searchIndex..<endIndex])
                guard candidateWords[0].text.lowercased() != "and" else { continue }
                guard wordsAreWhitespaceSeparated(candidateWords, in: nsLine) else { continue }
                let candidateText = candidateWords.map(\.text)
                guard let value = spokenQuantityValue(for: candidateText, formatter: formatter),
                      value >= 1000 else {
                    continue
                }
                if candidateWords.count > 1,
                   let trimmedValue = spokenQuantityValue(for: candidateText.dropLast(), formatter: formatter),
                   trimmedValue == value {
                    continue
                }

                let rangeStart = candidateWords[0].range.location
                let rangeEnd = NSMaxRange(candidateWords[candidateWords.count - 1].range)
                let range = NSRange(location: rangeStart, length: rangeEnd - rangeStart)
                let context = lexicalContext(around: range, in: lexicalTokens)
                matchedSpan = (
                    range: range,
                    value: value,
                    isLikelyYear: isLikelyYearReference(
                        value: value,
                        thirdPrevious: context.thirdPrevious,
                        secondPrevious: context.secondPrevious,
                        previous: context.previous,
                        next: context.next,
                        secondNext: context.secondNext
                    ),
                    nextIndex: endIndex
                )
                break
            }

            if let matchedSpan {
                replacements.append((matchedSpan.range, matchedSpan.value, matchedSpan.isLikelyYear))
                searchIndex = matchedSpan.nextIndex
            } else {
                searchIndex += 1
            }
        }

        guard !replacements.isEmpty else { return line }

        let mutable = NSMutableString(string: line)
        let groupingFormatter = Self.makeGroupingFormatter()
        for replacement in replacements.reversed() {
            let replacementText = replacement.isLikelyYear
                ? String(replacement.value)
                : groupingFormatter.string(from: NSNumber(value: replacement.value))
            guard let replacementText else { continue }
            mutable.replaceCharacters(in: replacement.range, with: replacementText)
        }

        return mutable as String
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

    private func spokenQuantityValue(for words: [String], formatter: NumberFormatter) -> Int? {
        let normalizedWords = words.map { $0.lowercased() }
        guard normalizedWords.contains("hundred") || normalizedWords.contains("thousand") else {
            return nil
        }

        return parseSpokenQuantity(normalizedWords, formatter: formatter)
    }

    private func parseSpokenQuantity(_ words: [String], formatter: NumberFormatter) -> Int? {
        let filteredWords = words.filter { $0 != "and" }
        guard !filteredWords.isEmpty else { return nil }

        if let thousandIndex = filteredWords.firstIndex(of: "thousand") {
            let thousandsWords = Array(filteredWords[..<thousandIndex])
            let remainderWords = Array(filteredWords[(thousandIndex + 1)...])
            guard let thousandsValue = parseSpokenChunk(thousandsWords, formatter: formatter),
                  thousandsValue > 0 else {
                return nil
            }

            let remainderValue = remainderWords.isEmpty
                ? 0
                : parseSpokenQuantity(remainderWords, formatter: formatter) ?? parseSpokenChunk(remainderWords, formatter: formatter)
            guard let remainderValue, remainderValue < 1000 else { return nil }
            return (thousandsValue * 1000) + remainderValue
        }

        if let hundredIndex = filteredWords.firstIndex(of: "hundred") {
            let hundredsWords = Array(filteredWords[..<hundredIndex])
            let remainderWords = Array(filteredWords[(hundredIndex + 1)...])
            guard let hundredsValue = parseSpokenChunk(hundredsWords, formatter: formatter),
                  hundredsValue > 0 else {
                return nil
            }

            let remainderValue = remainderWords.isEmpty
                ? 0
                : parseSpokenChunk(remainderWords, formatter: formatter)
            guard let remainderValue, remainderValue < 100 else { return nil }
            return (hundredsValue * 100) + remainderValue
        }

        return parseSpokenChunk(filteredWords, formatter: formatter)
    }

    private func parseSpokenChunk(_ words: [String], formatter _: NumberFormatter) -> Int? {
        guard !words.isEmpty else { return nil }

        let normalized = Self.normalizeSpellOutPhrase(words.joined(separator: " "))
        return Self.subThousandSpellOutLookup[normalized]
    }

    private func wordsAreWhitespaceSeparated(_ words: [WordToken], in line: NSString) -> Bool {
        guard words.count > 1 else { return true }

        for pair in zip(words, words.dropFirst()) {
            let separatorRange = NSRange(
                location: NSMaxRange(pair.0.range),
                length: pair.1.range.location - NSMaxRange(pair.0.range)
            )
            guard separatorRange.length >= 0 else { return false }
            let separator = line.substring(with: separatorRange)
            guard separatorRange.length > 0,
                  separator.unicodeScalars.allSatisfy(\.properties.isWhitespace) else {
                return false
            }
        }

        return true
    }

    private func protectedRanges(in line: String, fullRange: NSRange) -> [NSRange] {
        let regexRanges = [
            Self.isoDateRegex,
            Self.slashedOrHyphenatedDateRegex,
            Self.versionRegex,
            Self.phoneRegex,
            Self.compactHyphenatedNumericRegex,
        ]
        .compactMap { $0 }
        .flatMap { $0.matches(in: line, options: [], range: fullRange).map(\.range) }

        let detectorRanges = [
            Self.dateDetector,
            Self.addressDetector,
        ]
        .compactMap { $0 }
        .flatMap { $0.matches(in: line, options: [], range: fullRange).map(\.range) }

        return regexRanges + detectorRanges
    }

    private func lexicalTokens(in line: String, range: NSRange) -> [LexicalToken] {
        guard let stringRange = Range(range, in: line) else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
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
            let lemma = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            tokens.append(LexicalToken(text: token, range: nsTokenRange, tag: tag, lemma: lemma))
            return true
        }
        return tokens
    }

    private func lexicalContext(
        around range: NSRange,
        in tokens: [LexicalToken]
    ) -> (
        thirdPrevious: LexicalToken?,
        secondPrevious: LexicalToken?,
        previous: LexicalToken?,
        next: LexicalToken?,
        secondNext: LexicalToken?
    ) {
        let previousTokens = tokens.filter { NSMaxRange($0.range) <= range.location }
        let followingTokens = tokens.filter { $0.range.location >= NSMaxRange(range) }
        return (
            thirdPrevious: previousTokens.dropLast(2).last,
            secondPrevious: previousTokens.dropLast().last,
            previous: previousTokens.last,
            next: followingTokens.first,
            secondNext: followingTokens.dropFirst().first
        )
    }

    private func shouldGroup(value: Int, range: NSRange, tokens: [LexicalToken]) -> Bool {
        if !Self.plausibleYearRange.contains(value) {
            return true
        }

        guard let tokenIndex = resolvedTokenIndex(for: range, in: tokens) else {
            return false
        }

        let secondPrevious = tokenIndex > 1 ? tokens[tokenIndex - 2] : nil
        let thirdPrevious = tokenIndex > 2 ? tokens[tokenIndex - 3] : nil
        let previous = tokenIndex > 0 ? tokens[tokenIndex - 1] : nil
        let next = tokenIndex + 1 < tokens.count ? tokens[tokenIndex + 1] : nil
        let secondNext = tokenIndex + 2 < tokens.count ? tokens[tokenIndex + 2] : nil

        if isLikelyYearReference(
            value: value,
            thirdPrevious: thirdPrevious,
            secondPrevious: secondPrevious,
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
        thirdPrevious: LexicalToken?,
        secondPrevious: LexicalToken?,
        previous: LexicalToken?,
        next: LexicalToken?,
        secondNext: LexicalToken?
    ) -> Bool {
        guard Self.plausibleYearRange.contains(value) else { return false }

        if next == nil, previous == nil {
            return false
        }

        if isCalendarMonthToken(previous) {
            return true
        }

        if let nextTag = next?.tag,
           [.verb, .pronoun, .determiner, .conjunction].contains(nextTag) {
            return true
        }

        if previous?.tag == .preposition,
           let nextTag = next?.tag,
           [.adverb, .interjection].contains(nextTag),
           secondNext == nil {
            return true
        }

        if secondPrevious?.tag == .preposition,
           let previousTag = previous?.tag,
           [.adverb, .interjection].contains(previousTag) {
            return true
        }

        if next == nil, previous?.tag == .adverb {
            return true
        }

        let hasTerminalQualifier = next == nil
            || (secondNext == nil
                && next?.tag.map { [.adverb, .interjection].contains($0) } == true)
        if hasTerminalQualifier, previous?.tag == .adjective {
            return secondPrevious?.tag == .preposition
                && thirdPrevious?.tag == .preposition
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

        if next == nil,
           let previousTag = previous?.tag,
           [.noun, .determiner, .preposition].contains(previousTag) {
            return true
        }

        if previous == nil, next?.tag == .noun {
            if isPluralInflectedNoun(next), secondNext?.tag == .verb {
                return false
            }

            return true
        }

        if previous?.tag == .determiner, next?.tag == .noun {
            if isPluralInflectedNoun(next), secondNext?.tag == .verb {
                return false
            }

            return true
        }

        if previous?.tag == .noun, next?.tag == .noun {
            return true
        }

        return false
    }

    private func isPluralInflectedNoun(_ token: LexicalToken?) -> Bool {
        guard let token, token.tag == .noun, let lemma = token.lemma else { return false }
        return token.text.compare(lemma, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
    }

    private func isCalendarMonthToken(_ token: LexicalToken?) -> Bool {
        guard let token else { return false }
        return Self.calendarMonthTokens.contains(Self.normalizedCalendarMonthToken(token.text))
    }

    private static func normalizedCalendarMonthToken(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
