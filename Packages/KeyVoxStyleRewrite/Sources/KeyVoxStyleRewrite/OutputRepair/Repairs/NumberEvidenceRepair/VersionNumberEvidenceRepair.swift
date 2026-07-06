import Foundation

struct VersionNumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let evidence = versionEvidence(in: original)
        guard !evidence.isEmpty else { return rewritten }

        let tokens = RepairTokenization.wordTokens(in: rewritten)
        guard tokens.count >= 3 else { return rewritten }

        var edits: [NumberEvidenceRepairSupport.Edit] = []
        var index = tokens.startIndex
        while index < tokens.endIndex {
            var matchedEndIndex: Int?
            for candidate in evidence {
                guard let match = match(candidate, in: tokens, sourceText: rewritten, startingAt: index),
                      String(rewritten[match.range]) != candidate.canonicalText else {
                    continue
                }

                edits.append((match.range, candidate.canonicalText))
                matchedEndIndex = match.endIndex
                break
            }

            if let matchedEndIndex {
                index = matchedEndIndex
            } else {
                index += 1
            }
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }

    private struct VersionEvidence {
        let segments: [String]
        let separatorTokens: Set<String>

        var canonicalText: String {
            segments.joined(separator: ".")
        }
    }

    private func versionEvidence(in text: String) -> [VersionEvidence] {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard tokens.count >= 5 else { return [] }

        var evidence: [VersionEvidence] = []
        var seenCanonicalTexts: Set<String> = []
        var index = tokens.startIndex
        while index < tokens.endIndex {
            guard let candidate = sourceCandidate(in: tokens, sourceText: text, startingAt: index) else {
                index += 1
                continue
            }

            if seenCanonicalTexts.insert(candidate.evidence.canonicalText).inserted {
                evidence.append(candidate.evidence)
            }
            index = candidate.endIndex
        }

        return evidence
    }

    private func sourceCandidate(
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> (evidence: VersionEvidence, endIndex: Int)? {
        var segments: [String] = []
        var separatorTokens: Set<String> = []
        var requiredSeparator: String?
        var index = startIndex

        while index < tokens.endIndex {
            guard let segment = numberSegment(in: tokens, sourceText: sourceText, startingAt: index) else {
                return nil
            }
            segments.append(segment.text)
            index = segment.endIndex

            guard index < tokens.endIndex,
                  isSourceSeparator(tokens[index]),
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[segment.endIndex - 1], and: tokens[index], in: sourceText),
                  index + 1 < tokens.endIndex,
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[index], and: tokens[index + 1], in: sourceText) else {
                break
            }

            let separator = tokens[index].normalized
            if let requiredSeparator, requiredSeparator != separator {
                break
            }
            requiredSeparator = separator
            separatorTokens.insert(separator)
            index += 1
        }

        guard segments.count >= 3,
              separatorTokens.count == 1 else {
            return nil
        }

        return (VersionEvidence(segments: segments, separatorTokens: separatorTokens), index)
    }

    private func match(
        _ evidence: VersionEvidence,
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> (range: Range<String.Index>, endIndex: Int)? {
        if let exactMatch = exactMatch(evidence, in: tokens, sourceText: sourceText, startingAt: startIndex) {
            return exactMatch
        }

        return shortenedMatch(evidence, in: tokens, sourceText: sourceText, startingAt: startIndex)
    }

    private func exactMatch(
        _ evidence: VersionEvidence,
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> (range: Range<String.Index>, endIndex: Int)? {
        var index = startIndex
        var lastSegmentEndIndex = startIndex

        for segmentIndex in evidence.segments.indices {
            guard let segment = matchingNumberSegment(
                evidence.segments[segmentIndex],
                in: tokens,
                sourceText: sourceText,
                startingAt: index
            ) else {
                return nil
            }

            lastSegmentEndIndex = segment
            if segmentIndex == evidence.segments.indices.last {
                let range = tokens[startIndex].range.lowerBound..<tokens[segment - 1].range.upperBound
                return (range, segment)
            }

            guard let separator = matchingSeparator(
                evidence,
                in: tokens,
                sourceText: sourceText,
                afterSegmentEndingAt: segment
            ) else {
                return nil
            }
            index = separator
        }

        let range = tokens[startIndex].range.lowerBound..<tokens[lastSegmentEndIndex - 1].range.upperBound
        return (range, lastSegmentEndIndex)
    }

    private func shortenedMatch(
        _ evidence: VersionEvidence,
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> (range: Range<String.Index>, endIndex: Int)? {
        guard let candidate = rewrittenCandidate(in: tokens, sourceText: sourceText, startingAt: startIndex),
              candidate.segments.count >= 2,
              candidate.segments.count < evidence.segments.count,
              candidate.segments.first == evidence.segments.first,
              candidateRemainingDigitCount(candidate.segments) <= sourceRemainingDigitCount(evidence.segments) else {
            return nil
        }

        let range = tokens[startIndex].range.lowerBound..<tokens[candidate.endIndex - 1].range.upperBound
        return (range, candidate.endIndex)
    }

    private func rewrittenCandidate(
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> (segments: [String], endIndex: Int)? {
        var segments: [String] = []
        var index = startIndex

        while index < tokens.endIndex {
            guard let segment = numberSegment(in: tokens, sourceText: sourceText, startingAt: index) else {
                return nil
            }
            segments.append(segment.text)
            index = segment.endIndex

            guard index < tokens.endIndex,
                  let nextIndex = anyVersionSeparatorIndex(in: tokens, sourceText: sourceText, afterSegmentEndingAt: index) else {
                break
            }
            index = nextIndex
        }

        guard segments.count >= 2 else { return nil }
        return (segments, index)
    }

    private func numberSegment(
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> (text: String, endIndex: Int)? {
        var endIndex = startIndex
        while endIndex < tokens.endIndex,
              RepairNumberParsing.numericValue(for: tokens[endIndex]) != nil {
            if endIndex > startIndex,
               !RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: sourceText) {
                break
            }
            endIndex += 1
        }

        guard endIndex > startIndex,
              let text = segmentText(for: Array(tokens[startIndex..<endIndex])) else {
            return nil
        }
        return (text, endIndex)
    }

    private func matchingNumberSegment(
        _ expectedText: String,
        in tokens: [RepairWordToken],
        sourceText: String,
        startingAt startIndex: Int
    ) -> Int? {
        var endIndex = startIndex
        while endIndex < tokens.endIndex,
              RepairNumberParsing.numericValue(for: tokens[endIndex]) != nil {
            if endIndex > startIndex,
               !RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: sourceText) {
                break
            }

            let candidateTokens = Array(tokens[startIndex...endIndex])
            if segmentText(for: candidateTokens) == expectedText {
                return endIndex + 1
            }

            endIndex += 1
        }

        return nil
    }

    private func matchingSeparator(
        _ evidence: VersionEvidence,
        in tokens: [RepairWordToken],
        sourceText: String,
        afterSegmentEndingAt segmentEndIndex: Int
    ) -> Int? {
        guard segmentEndIndex > tokens.startIndex,
              segmentEndIndex < tokens.endIndex else {
            return nil
        }

        let separatorText = sourceText[tokens[segmentEndIndex - 1].range.upperBound..<tokens[segmentEndIndex].range.lowerBound]
        if isPunctuationSeparator(separatorText) {
            return segmentEndIndex
        }

        let separatorToken = tokens[segmentEndIndex]
        guard isRewrittenSeparator(separatorToken, matching: evidence),
              segmentEndIndex + 1 < tokens.endIndex,
              RepairNumberParsing.isNumberRunSeparator(
                between: tokens[segmentEndIndex - 1],
                and: separatorToken,
                in: sourceText
              ),
              RepairNumberParsing.isNumberRunSeparator(
                between: separatorToken,
                and: tokens[segmentEndIndex + 1],
                in: sourceText
              ) else {
            return nil
        }

        return segmentEndIndex + 1
    }

    private func anyVersionSeparatorIndex(
        in tokens: [RepairWordToken],
        sourceText: String,
        afterSegmentEndingAt segmentEndIndex: Int
    ) -> Int? {
        guard segmentEndIndex > tokens.startIndex,
              segmentEndIndex < tokens.endIndex else {
            return nil
        }

        let separatorText = sourceText[tokens[segmentEndIndex - 1].range.upperBound..<tokens[segmentEndIndex].range.lowerBound]
        if isPunctuationSeparator(separatorText) {
            return segmentEndIndex
        }

        let separatorToken = tokens[segmentEndIndex]
        guard isSourceSeparator(separatorToken),
              segmentEndIndex + 1 < tokens.endIndex,
              RepairNumberParsing.isNumberRunSeparator(
                between: tokens[segmentEndIndex - 1],
                and: separatorToken,
                in: sourceText
              ),
              RepairNumberParsing.isNumberRunSeparator(
                between: separatorToken,
                and: tokens[segmentEndIndex + 1],
                in: sourceText
              ) else {
            return nil
        }

        return segmentEndIndex + 1
    }

    private func segmentText(for tokens: [RepairWordToken]) -> String? {
        if tokens.count > 1 {
            var digits = ""
            for token in tokens {
                guard let value = RepairNumberParsing.numericValue(for: token),
                      (0...9).contains(value) else {
                    digits = ""
                    break
                }
                digits += String(value)
            }
            if !digits.isEmpty {
                return digits
            }
        }

        guard let evidence = NumberEvidence.components(in: tokens),
              evidence.count == 1,
              case let .value(value) = evidence[0] else {
            return nil
        }

        if tokens.count == 1, tokens[0].text.allSatisfy(\.isNumber) {
            return tokens[0].text
        }
        return String(value)
    }

    private func isSourceSeparator(_ token: RepairWordToken) -> Bool {
        RepairNumberParsing.numericValue(for: token) == nil
    }

    private func isRewrittenSeparator(_ token: RepairWordToken, matching evidence: VersionEvidence) -> Bool {
        evidence.separatorTokens.contains(token.normalized)
            || RepairNumberParsing.isSpellOutDecimalSeparator(token)
    }

    private func isPunctuationSeparator(_ text: Substring) -> Bool {
        let punctuation = text.filter { !$0.isWhitespace }
        return punctuation == "."
    }

    private func candidateRemainingDigitCount(_ segments: [String]) -> Int {
        segments.dropFirst().joined().count
    }

    private func sourceRemainingDigitCount(_ segments: [String]) -> Int {
        segments.dropFirst().joined().count
    }
}
