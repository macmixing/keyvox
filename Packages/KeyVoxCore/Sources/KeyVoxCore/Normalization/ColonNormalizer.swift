import Foundation

public struct ColonNormalizer {
    private static let delimiterWrappedTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"([,;:—\-])\s*["'“”‘’\(\[\{]*\s*([A-Za-z][A-Za-z'’\-]{2,})\s*["'“”‘’\)\]\}]*\s*([,;:—\-])"#,
        options: []
    )
    private static let wordTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b[A-Za-z][A-Za-z'’\-]{2,}\b"#,
        options: []
    )
    private static let collapsedWhitespaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s{2,}"#,
        options: []
    )

    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }
        let explicitResult = normalizeExplicitDelimiterWrappedTokens(in: text)
        let associationResult = normalizeAssociationStyleTokens(in: explicitResult.text)
        let replacedSpokenColon = explicitResult.replacedSpokenColon || associationResult.replacedSpokenColon

        guard replacedSpokenColon, let collapsedWhitespaceRegex = Self.collapsedWhitespaceRegex else {
            let normalized = associationResult.text
            return stripTerminalPunctuationForShortStandaloneAssociation(in: normalized, replacedSpokenColon: replacedSpokenColon)
        }
        let normalized = associationResult.text
        let collapsedRange = NSRange(location: 0, length: (normalized as NSString).length)
        let collapsed = collapsedWhitespaceRegex.stringByReplacingMatches(
            in: normalized,
            options: [],
            range: collapsedRange,
            withTemplate: " "
        )
        return stripTerminalPunctuationForShortStandaloneAssociation(in: collapsed, replacedSpokenColon: replacedSpokenColon)
    }

    private func normalizeExplicitDelimiterWrappedTokens(in text: String) -> (text: String, replacedSpokenColon: Bool) {
        guard let regex = Self.delimiterWrappedTokenRegex else {
            return (text, false)
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else {
            return (text, false)
        }

        let mutable = NSMutableString(string: text)
        var replacedSpokenColon = false
        for match in matches.reversed() {
            let tokenRange = match.range(at: 2)
            guard tokenRange.location != NSNotFound, tokenRange.length > 0 else { continue }
            let token = nsText.substring(with: tokenRange)
            guard isLikelySpokenColon(token, in: nsText, tokenRange: tokenRange) else { continue }
            mutable.replaceCharacters(in: match.range, with: ": ")
            replacedSpokenColon = true
        }

        return (mutable as String, replacedSpokenColon)
    }

    private func normalizeAssociationStyleTokens(in text: String) -> (text: String, replacedSpokenColon: Bool) {
        guard let regex = Self.wordTokenRegex else {
            return (text, false)
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else {
            return (text, false)
        }

        let mutable = NSMutableString(string: text)
        var replacedSpokenColon = false

        for match in matches.reversed() {
            let tokenRange = match.range
            guard tokenRange.location != NSNotFound, tokenRange.length > 0 else { continue }
            let token = nsText.substring(with: tokenRange)
            guard isColonHomophone(token) else { continue }
            guard let replacementRange = associationReplacementRange(in: nsText, tokenRange: tokenRange) else { continue }
            mutable.replaceCharacters(in: replacementRange, with: ": ")
            replacedSpokenColon = true
        }

        return (mutable as String, replacedSpokenColon)
    }

    private func stripTerminalPunctuationForShortStandaloneAssociation(
        in text: String,
        replacedSpokenColon: Bool
    ) -> String {
        guard replacedSpokenColon else { return text }
        guard !text.contains("\n") else { return text }
        guard text.filter({ $0 == ":" }).count == 1 else { return text }
        guard let colonIndex = text.firstIndex(of: ":") else { return text }

        let lhs = text[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = text[text.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhs.isEmpty, !rhs.isEmpty else { return text }

        let rhsWithoutTerminalPunctuation = rhs.replacingOccurrences(
            of: #"[.!?…]+["'”’\)\]\}]*\s*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rhsWithoutTerminalPunctuation.isEmpty else { return text }

        let lhsWords = lhs.split(whereSeparator: \.isWhitespace).count
        let rhsWords = rhsWithoutTerminalPunctuation.split(whereSeparator: \.isWhitespace).count
        guard (1...4).contains(lhsWords), (1...5).contains(rhsWords) else { return text }

        return text.replacingOccurrences(
            of: #"[.!?…]+(["'”’\)\]\}]*\s*)$"#,
            with: "$1",
            options: .regularExpression
        )
    }

    private func isLikelySpokenColon(_ token: String, in fullText: NSString, tokenRange: NSRange) -> Bool {
        guard isColonHomophone(token) else { return false }
        guard !isLikelyNamedEntity(token, in: fullText, tokenRange: tokenRange) else { return false }
        return true
    }

    private func associationReplacementRange(in text: NSString, tokenRange: NSRange) -> NSRange? {
        let sentenceStart = sentenceBoundaryBefore(in: text, location: tokenRange.location)

        var replacementStart = tokenRange.location
        while replacementStart > sentenceStart {
            let codeUnitIndex = replacementStart - 1
            let scalar = unicodeScalar(in: text, at: codeUnitIndex)
            let codeUnit = text.character(at: codeUnitIndex)
            if let scalar, CharacterSet.whitespacesAndNewlines.contains(scalar) {
                replacementStart -= 1
                continue
            }
            if codeUnit == 44 {
                replacementStart -= 1
            }
            break
        }

        var replacementEnd = NSMaxRange(tokenRange)
        while replacementEnd < text.length {
            let scalar = unicodeScalar(in: text, at: replacementEnd)
            let codeUnit = text.character(at: replacementEnd)
            if codeUnit == 44 || codeUnit == 46 {
                replacementEnd += 1
                continue
            }
            if let scalar, CharacterSet.whitespacesAndNewlines.contains(scalar) {
                replacementEnd += 1
                continue
            }
            break
        }

        let sentenceEnd = sentenceBoundaryAfter(in: text, location: replacementEnd)

        let leftRange = NSRange(location: sentenceStart, length: max(0, replacementStart - sentenceStart))
        let rightRange = NSRange(location: replacementEnd, length: max(0, sentenceEnd - replacementEnd))

        let leftSegment = normalizeAssociationSegment(text.substring(with: leftRange))
        let rightSegment = normalizeAssociationSegment(text.substring(with: rightRange))

        guard isLikelyAssociationLabel(leftSegment) else { return nil }
        guard isLikelyAssociationValue(rightSegment) else { return nil }

        return NSRange(location: replacementStart, length: replacementEnd - replacementStart)
    }

    private func unicodeScalar(in text: NSString, at index: Int) -> UnicodeScalar? {
        guard index >= 0, index < text.length else { return nil }

        let codeUnit = text.character(at: index)
        if let scalar = UnicodeScalar(codeUnit) {
            return scalar
        }

        let leadSurrogateRange: ClosedRange<unichar> = 0xD800...0xDBFF
        let trailSurrogateRange: ClosedRange<unichar> = 0xDC00...0xDFFF

        if leadSurrogateRange.contains(codeUnit) {
            let nextIndex = index + 1
            guard nextIndex < text.length else { return nil }
            let trailingCodeUnit = text.character(at: nextIndex)
            guard trailSurrogateRange.contains(trailingCodeUnit) else { return nil }

            let highBits = UInt32(codeUnit) - 0xD800
            let lowBits = UInt32(trailingCodeUnit) - 0xDC00
            return UnicodeScalar(0x10000 + ((highBits << 10) | lowBits))
        }

        if trailSurrogateRange.contains(codeUnit) {
            let previousIndex = index - 1
            guard previousIndex >= 0 else { return nil }
            let leadingCodeUnit = text.character(at: previousIndex)
            guard leadSurrogateRange.contains(leadingCodeUnit) else { return nil }

            let highBits = UInt32(leadingCodeUnit) - 0xD800
            let lowBits = UInt32(codeUnit) - 0xDC00
            return UnicodeScalar(0x10000 + ((highBits << 10) | lowBits))
        }

        return nil
    }

    private func isColonHomophone(_ token: String) -> Bool {
        let letters = token.lowercased().unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let simplified = String(String.UnicodeScalarView(letters))
        guard simplified.hasPrefix("col"), simplified.hasSuffix("n") else { return false }
        guard (4...6).contains(simplified.count) else { return false }
        return levenshteinDistance(between: simplified, and: "colon") <= 1
    }

    private func isLikelyNamedEntity(_ token: String, in text: NSString, tokenRange: NSRange) -> Bool {
        guard let first = token.first, first.isUppercase else { return false }
        let lowered = token.lowercased()
        if lowered == "colon" {
            return false
        }

        guard let previousScalar = previousNonWhitespaceScalar(in: text, before: tokenRange.location) else {
            return false
        }
        return !sentenceBoundaryCharacterSet.contains(previousScalar)
    }

    private func normalizeAssociationSegment(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.;:—-")))
    }

    private func isLikelyAssociationLabel(_ text: String) -> Bool {
        let words = wordCount(in: text)
        guard (1...4).contains(words) else { return false }
        guard !text.isEmpty else { return false }

        let tags = lexicalTags(in: text)
        guard !tags.contains(.pronoun) else { return false }
        guard !tags.contains(.preposition) else { return false }
        guard !tags.contains(.interjection) else { return false }

        let verbCount = tags.filter { $0 == .verb }.count
        if verbCount == 0 {
            return true
        }

        return verbCount == 1 && words <= 2 && startsWithUppercaseWord(in: text)
    }

    private func isLikelyAssociationValue(_ text: String) -> Bool {
        let words = wordCount(in: text)
        guard (1...6).contains(words) else { return false }
        guard !text.isEmpty else { return false }

        let tags = lexicalTags(in: text)
        guard !tags.contains(.pronoun) else { return false }
        guard !tags.contains(.verb) else { return false }
        guard !tags.contains(.preposition) else { return false }
        guard !tags.contains(.interjection) else { return false }
        return true
    }

    private func lexicalTags(in text: String) -> [NSLinguisticTag] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        tagger.string = text

        var tags: [NSLinguisticTag] = []
        tagger.enumerateTags(
            in: fullRange,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, tokenRange, _ in
            let token = nsText.substring(with: tokenRange)
            guard token.rangeOfCharacter(from: .letters) != nil else { return }
            if let tag {
                tags.append(tag)
            }
        }

        return tags
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func startsWithUppercaseWord(in text: String) -> Bool {
        guard let firstWord = text.split(whereSeparator: \.isWhitespace).first,
              let firstCharacter = firstWord.first else {
            return false
        }
        return firstCharacter.isUppercase
    }

    private func sentenceBoundaryBefore(in text: NSString, location: Int) -> Int {
        guard location > 0 else { return 0 }
        var index = location - 1

        while index >= 0 {
            let scalar = text.character(at: index)
            if scalar == 10 || scalar == 46 || scalar == 33 || scalar == 63 {
                return index + 1
            }
            if index == 0 { break }
            index -= 1
        }

        return 0
    }

    private func sentenceBoundaryAfter(in text: NSString, location: Int) -> Int {
        guard location < text.length else { return text.length }
        var index = location

        while index < text.length {
            let scalar = text.character(at: index)
            if scalar == 10 || scalar == 46 || scalar == 33 || scalar == 63 {
                return index
            }
            index += 1
        }

        return text.length
    }

    private func previousNonWhitespaceScalar(in text: NSString, before location: Int) -> UnicodeScalar? {
        guard location > 0 else { return nil }
        var index = location - 1
        while index >= 0 {
            guard let scalar = UnicodeScalar(text.character(at: index)) else { return nil }
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return scalar
            }
            if index == 0 { break }
            index -= 1
        }
        return nil
    }

    private var sentenceBoundaryCharacterSet: CharacterSet {
        CharacterSet(charactersIn: ".!?…\n")
    }

    private func levenshteinDistance(between lhs: String, and rhs: String) -> Int {
        if lhs == rhs { return 0 }
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + substitutionCost
                )
            }
            swap(&previous, &current)
        }
        return previous[rhsChars.count]
    }
}
