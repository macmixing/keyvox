import Foundation

struct ListPatternTrailingSplitter {
    private struct SplitCandidate {
        let itemText: String
        let trailingText: String
        let score: Int
    }

    func splitLastItemAndTrailing(_ raw: String, languageCode: String?) -> (itemText: String, trailingText: String) {
        let paragraphToken = "__KVX_PARAGRAPH_BREAK__"
        let normalized = raw
            .replacingOccurrences(
                of: #"\n[ \t]*\n+"#,
                with: " \(paragraphToken) ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return ("", "")
        }

        var candidates: [SplitCandidate] = []

        if let candidate = emailCommaBoundaryCandidate(in: normalized, paragraphToken: paragraphToken, languageCode: languageCode) {
            candidates.append(candidate)
        }
        if let candidate = emailBoundaryCandidate(in: normalized, paragraphToken: paragraphToken, languageCode: languageCode) {
            candidates.append(candidate)
        }
        if let candidate = sentenceBoundaryCandidate(in: normalized, languageCode: languageCode) {
            candidates.append(candidate)
        }
        if let candidate = paragraphBoundaryCandidate(in: normalized, paragraphToken: paragraphToken, languageCode: languageCode) {
            candidates.append(candidate)
        }
        if let candidate = commaBoundaryCandidate(in: normalized, languageCode: languageCode) {
            candidates.append(candidate)
        }
        if let candidate = causalBoundaryCandidate(in: normalized, languageCode: languageCode) {
            candidates.append(candidate)
        }
        if let candidate = softBoundaryCandidate(in: normalized, languageCode: languageCode) {
            candidates.append(candidate)
        }

        if let best = bestCandidate(from: candidates) {
            return (
                restoreParagraphBreaks(in: best.itemText, paragraphToken: paragraphToken),
                restoreParagraphBreaks(in: best.trailingText, paragraphToken: paragraphToken)
            )
        }

        return (restoreParagraphBreaks(in: normalized, paragraphToken: paragraphToken), "")
    }

    private func restoreParagraphBreaks(in text: String, paragraphToken: String) -> String {
        let restored = text.replacingOccurrences(of: paragraphToken, with: "\n\n")
        return restored
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]*\n\n[ \t]*"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstRegexSplit(_ text: String, pattern: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        // Pattern variants used here always return item in group 1 and trailing tail in last group.
        let itemRange = match.range(at: 1)
        let tailRange = match.range(at: match.numberOfRanges - 1)
        guard itemRange.location != NSNotFound, tailRange.location != NSNotFound else { return nil }

        let item = nsText.substring(with: itemRange).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = nsText.substring(with: tailRange).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty, !tail.isEmpty else { return nil }
        return (item, tail)
    }

    private func bestCandidate(from candidates: [SplitCandidate]) -> SplitCandidate? {
        candidates.max { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score < rhs.score
            }
            return lhs.itemText.count > rhs.itemText.count
        }
    }

    private func makeCandidate(
        item: String,
        trailing: String,
        score: Int,
        minItemWords: Int = 2,
        minTrailingWords: Int = 3,
        requiresContinuationShape: Bool = false,
        languageCode: String?
    ) -> SplitCandidate? {
        let itemTrimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        let trailingTrimmed = trailing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemTrimmed.isEmpty, !trailingTrimmed.isEmpty else { return nil }
        guard wordCount(itemTrimmed) >= minItemWords, wordCount(trailingTrimmed) >= minTrailingWords else { return nil }
        guard !startsLikeListMarker(trailingTrimmed, languageCode: languageCode) else { return nil }
        if requiresContinuationShape && !looksLikeContinuationStart(trailingTrimmed) {
            return nil
        }
        return SplitCandidate(itemText: itemTrimmed, trailingText: trailingTrimmed, score: score)
    }

    private func emailCommaBoundaryCandidate(
        in text: String,
        paragraphToken: String,
        languageCode: String?
    ) -> SplitCandidate? {
        guard let split = firstRegexSplit(
            text,
            pattern: "(?i)^(.+?[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,})\\s*,\\s+(?:" +
                NSRegularExpression.escapedPattern(for: paragraphToken) +
                "\\s+)?(.+)$"
        ) else {
            return nil
        }

        guard wordCount(split.0) <= 4, endsWithEmail(split.0) else { return nil }
        return makeCandidate(
            item: split.0,
            trailing: split.1,
            score: 120,
            minItemWords: 1,
            requiresContinuationShape: true,
            languageCode: languageCode
        )
    }

    private func emailBoundaryCandidate(
        in text: String,
        paragraphToken: String,
        languageCode: String?
    ) -> SplitCandidate? {
        guard let split = firstRegexSplit(
            text,
            pattern: "(?i)^(.+?[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,}[.!?]?)\\s+(?:" +
                NSRegularExpression.escapedPattern(for: paragraphToken) +
                "\\s+)?(.+)$"
        ) else {
            return nil
        }

        guard wordCount(split.0) <= 4, endsWithEmail(split.0) else { return nil }
        return makeCandidate(
            item: split.0,
            trailing: split.1,
            score: 110,
            minItemWords: 1,
            requiresContinuationShape: true,
            languageCode: languageCode
        )
    }

    private func sentenceBoundaryCandidate(in text: String, languageCode: String?) -> SplitCandidate? {
        guard let split = firstRegexSplit(text, pattern: #"(?i)^(.+?[.!?])\s+(.+)$"#) else {
            return nil
        }
        return makeCandidate(item: split.0, trailing: split.1, score: 100, languageCode: languageCode)
    }

    private func paragraphBoundaryCandidate(
        in text: String,
        paragraphToken: String,
        languageCode: String?
    ) -> SplitCandidate? {
        guard let paragraphBreakRange = text.range(of: paragraphToken) else { return nil }

        let before = String(text[..<paragraphBreakRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let after = String(text[paragraphBreakRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !before.isEmpty, !after.isEmpty else { return nil }

        let looksLikeEmailBoundary = endsWithEmail(before) && wordCount(before) <= 4
        let score = looksLikeEmailBoundary ? 95 : 35
        let minItemWords = looksLikeEmailBoundary ? 1 : 2
        return makeCandidate(
            item: before,
            trailing: after,
            score: score,
            minItemWords: minItemWords,
            languageCode: languageCode
        )
    }

    private func commaBoundaryCandidate(in text: String, languageCode: String?) -> SplitCandidate? {
        guard let split = firstRegexSplit(text, pattern: #"(?i)^(.{8,}?),\s+(.+)$"#) else {
            return nil
        }
        return makeCandidate(
            item: split.0,
            trailing: split.1,
            score: 60,
            minItemWords: 3,
            requiresContinuationShape: true,
            languageCode: languageCode
        )
    }

    private func causalBoundaryCandidate(in text: String, languageCode: String?) -> SplitCandidate? {
        guard let split = firstRegexSplit(
            text,
            pattern: #"(?i)^(.{8,}?)\s+((?:and\s+)?(?:because|since|as)\b.+)$"#
        ) else {
            return nil
        }
        guard !containsInternalSentenceBoundary(split.0) else { return nil }
        return makeCandidate(
            item: split.0,
            trailing: split.1,
            score: 55,
            requiresContinuationShape: true,
            languageCode: languageCode
        )
    }

    private func softBoundaryCandidate(in text: String, languageCode: String?) -> SplitCandidate? {
        guard let split = firstRegexSplit(
            text,
            pattern: #"(?i)^(.{8,}?)\s+((?:and\s+)?(?:now|then|so|anyway|also)\b.+)$"#
        ) else {
            return nil
        }
        guard !containsInternalSentenceBoundary(split.0) else { return nil }
        return makeCandidate(
            item: split.0,
            trailing: split.1,
            score: 105,
            requiresContinuationShape: true,
            languageCode: languageCode
        )
    }

    private func endsWithEmail(_ text: String) -> Bool {
        text.range(
            of: #"(?i)[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}[.!?]?$"#,
            options: .regularExpression
        ) != nil
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func containsInternalSentenceBoundary(_ text: String) -> Bool {
        text.range(of: #"(?i)[.!?]\s+\S"#, options: .regularExpression) != nil
    }

    private func startsLikeListMarker(_ text: String, languageCode: String?) -> Bool {
        ListPatternMarkerParser.hasLeadingListMarkerPrefix(in: text, languageCode: languageCode)
    }

    private func looksLikeContinuationStart(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.range(
            of: #"^[\"'“”‘’\(\[\{]*[A-Z]"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        let lower = trimmed.lowercased()
        return lower.range(
            of: #"^(?:and|but|so|then|because|since|as|now|anyway|also|please|be|you|i|we|he|she|they|it|that|this)\b"#,
            options: .regularExpression
        ) != nil
    }
}
