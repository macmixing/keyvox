import Foundation

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
        guard nextToken != nil else { return false }
        guard !candidate.hasSuffix("s") else { return false }
        let hasPossessiveSoundEnding =
            hasPossessiveLikeEnding(observedCombined)
            || hasPossessiveLikeEnding(observedTail)
        return hasPossessiveSoundEnding
    }

    private func hasPossessiveLikeEnding(_ token: String) -> Bool {
        token.hasSuffix("s")
            || token.hasSuffix("x")
            || token.hasSuffix("z")
            || token.hasSuffix("ss")
            || token.hasSuffix("xe")
            || token.hasSuffix("ce")
            || token.hasSuffix("se")
            || token.hasSuffix("ze")
    }

    func isLikelyDomainTokenSplit(window: [Token], text: String) -> Bool {
        guard window.count == 2 else { return false }
        let second = window[1].normalized
        guard second.count >= 2 else { return false }
        guard let regex = Self.domainLabelTokenRegex else { return false }
        let secondRange = NSRange(location: 0, length: (second as NSString).length)
        guard regex.firstMatch(in: second, options: [], range: secondRange) != nil else { return false }

        let nsText = text as NSString
        let dotBeforeSecond = window[1].range.location > 0
            && nsText.substring(with: NSRange(location: window[1].range.location - 1, length: 1)) == "."
        return dotBeforeSecond
    }
}
