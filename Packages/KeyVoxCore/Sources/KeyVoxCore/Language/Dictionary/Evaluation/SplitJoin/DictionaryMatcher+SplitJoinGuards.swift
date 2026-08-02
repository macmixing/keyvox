import Foundation
import NaturalLanguage

extension DictionaryMatcher {
    private static let domainLabelTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        // Generic DNS label shape (no hardcoded TLD list).
        pattern: #"(?i)^[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?$"#,
        options: []
    )

    func isAnchoredStylizedSplitJoin(window: [Token], candidateToken: String) -> Bool {
        guard window.count == 2 else { return false }
        let observedFirst = window[0].normalized
        guard observedFirst.count >= 3 else { return false }
        return candidateToken.hasPrefix(observedFirst)
    }

    func shouldInferSplitJoinPossessiveSuffix(
        observedCombined: String,
        observedTail: String,
        candidate: String,
        nextToken: Token?
    ) -> Bool {
        guard let nextToken else { return false }
        guard !candidate.hasSuffix("s") else { return false }
        guard nextToken.lexicalClass == .noun else { return false }
        let hasPossessiveSoundEnding =
            hasPossessiveLikeEnding(observedCombined)
            || hasPossessiveLikeEnding(observedTail)
        return hasPossessiveSoundEnding
    }

    private func hasPossessiveLikeEnding(_ token: String) -> Bool {
        token.hasSuffix("s")
            || token.hasSuffix("x")
            || token.hasSuffix("z")
            || token.hasSuffix("xe")
            || token.hasSuffix("ce")
            || token.hasSuffix("se")
            || token.hasSuffix("ze")
    }

    func isLikelyDomainTokenSplit(window: [Token], text: String) -> Bool {
        guard window.count >= 2 else { return false }
        guard let regex = Self.domainLabelTokenRegex else { return false }

        let nsText = text as NSString
        return window.dropFirst().contains { token in
            guard token.normalized.count >= 2 else { return false }
            let tokenRange = NSRange(location: 0, length: (token.normalized as NSString).length)
            guard regex.firstMatch(in: token.normalized, options: [], range: tokenRange) != nil else {
                return false
            }
            return token.range.location > 0
                && nsText.substring(with: NSRange(location: token.range.location - 1, length: 1)) == "."
        }
    }

    func isExplicitHyphenDelimitedSplit(window: [Token], text: String) -> Bool {
        guard window.count == 2 else { return false }
        let firstEnd = window[0].range.location + window[0].range.length
        let secondStart = window[1].range.location
        guard secondStart > firstEnd else { return false }

        let nsText = text as NSString
        let between = nsText.substring(with: NSRange(location: firstEnd, length: secondStart - firstEnd))
        let trimmed = between.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "-" || trimmed == "‑" || trimmed == "–"
    }

    func isWhitespaceDelimitedSplit(window: [Token], text: String) -> Bool {
        guard window.count == 2 else { return false }
        let firstEnd = window[0].range.location + window[0].range.length
        let secondStart = window[1].range.location
        guard secondStart > firstEnd else { return false }

        let nsText = text as NSString
        let between = nsText.substring(with: NSRange(location: firstEnd, length: secondStart - firstEnd))
        return !between.isEmpty
            && between.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    func hasShortTokenSplitContext(start: Int, end: Int, tokens: [Token]) -> Bool {
        guard start > 0, end < tokens.count else { return false }
        let precedingClass = tokens[start - 1].lexicalClass
        return (precedingClass == .noun || precedingClass == .particle)
            && tokens[end].lexicalClass == .adverb
    }
}
