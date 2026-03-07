import Foundation

public struct ColonNormalizer {
    private static let delimiterWrappedTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"([,;:—\-])\s*["'“”‘’\(\[\{]*\s*([A-Za-z][A-Za-z'’\-]{2,})\s*["'“”‘’\)\]\}]*\s*([,;:—\-])"#,
        options: []
    )
    private static let collapsedWhitespaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s{2,}"#,
        options: []
    )

    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let regex = Self.delimiterWrappedTokenRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

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

        guard replacedSpokenColon, let collapsedWhitespaceRegex = Self.collapsedWhitespaceRegex else {
            let normalized = mutable as String
            return stripTerminalPunctuationForShortStandaloneAssociation(in: normalized, replacedSpokenColon: replacedSpokenColon)
        }
        let normalized = mutable as String
        let collapsedRange = NSRange(location: 0, length: (normalized as NSString).length)
        let collapsed = collapsedWhitespaceRegex.stringByReplacingMatches(
            in: normalized,
            options: [],
            range: collapsedRange,
            withTemplate: " "
        )
        return stripTerminalPunctuationForShortStandaloneAssociation(in: collapsed, replacedSpokenColon: replacedSpokenColon)
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
