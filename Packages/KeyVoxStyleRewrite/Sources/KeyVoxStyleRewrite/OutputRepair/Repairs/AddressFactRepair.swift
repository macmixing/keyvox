import Foundation

struct AddressFactRepair {
    private struct SourceAddressEvidence {
        let number: String
        let suffixEdits: [(Range<String.Index>, String)]
    }

    private struct SourceAddressEvidenceCandidate {
        let evidence: SourceAddressEvidence
        let sourceSuffixLength: Int
    }

    private static let addressDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.address.rawValue
    )

    func repair(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.taggedTokens(in: original)
        let rewrittenWordTokens = RepairTokenization.wordTokens(in: rewritten)
        guard !originalTokens.isEmpty, !rewrittenWordTokens.isEmpty else { return rewritten }

        var edits: [(Range<String.Index>, String)] = []

        for addressRange in detectedAddressRanges(in: rewritten) {
            let addressTokens = rewrittenWordTokens.filter { addressRange.overlaps($0.range) }
            guard addressTokens.count > 1,
                  let leadingToken = addressTokens.first,
                  leadingToken.text.allSatisfy(\.isNumber),
                  let sourceEvidence = sourceAddressEvidence(
                    beforeSuffix: Array(addressTokens.dropFirst()),
                    in: originalTokens
                  ),
                  sourceEvidence.number != leadingToken.text || !sourceEvidence.suffixEdits.isEmpty else {
                continue
            }

            let candidateEdits = [(leadingToken.range, sourceEvidence.number)] + sourceEvidence.suffixEdits
            let candidate = applying(edits: candidateEdits, to: rewritten)
            guard hasDetectedAddress(overlapping: leadingToken.range.lowerBound, in: candidate) else {
                continue
            }
            edits.append(contentsOf: candidateEdits)
        }

        for timeMatch in timeMatches(in: rewritten) {
            guard let timeRange = Range(timeMatch.range, in: rewritten) else { continue }
            let followingTokens = rewrittenWordTokens.filter { $0.range.lowerBound >= timeRange.upperBound }
            guard !followingTokens.isEmpty else { continue }

            let maximumSuffixLength = min(4, followingTokens.count)
            for suffixLength in stride(from: maximumSuffixLength, through: 1, by: -1) {
                let suffix = Array(followingTokens.prefix(suffixLength))
                guard let sourceEvidence = sourceAddressEvidence(beforeSuffix: suffix, in: originalTokens) else {
                    continue
                }

                let candidateEdits = [(timeRange, sourceEvidence.number)] + sourceEvidence.suffixEdits
                let candidate = applying(edits: candidateEdits, to: rewritten)
                guard hasDetectedAddress(overlapping: timeRange.lowerBound, in: candidate) else {
                    continue
                }
                edits.append(contentsOf: candidateEdits)
                break
            }
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func detectedAddressRanges(in text: String) -> [Range<String.Index>] {
        guard let addressDetector = Self.addressDetector else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return addressDetector
            .matches(in: text, options: [], range: nsRange)
            .compactMap { Range($0.range, in: text) }
    }

    private func hasDetectedAddress(overlapping index: String.Index, in text: String) -> Bool {
        detectedAddressRanges(in: text).contains { $0.contains(index) }
    }

    private func timeMatches(in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}\b"#) else {
            return []
        }
        return regex.matches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    private func sourceAddressEvidence(
        beforeSuffix suffix: [RepairWordToken],
        in sourceTokens: [RepairTaggedToken]
    ) -> SourceAddressEvidence? {
        guard !suffix.isEmpty else { return nil }

        var candidates: [SourceAddressEvidenceCandidate] = []

        for suffixStartIndex in sourceTokens.indices {
            let maximumSuffixLength = min(suffix.count + 2, sourceTokens.count - suffixStartIndex)
            guard suffix.count <= maximumSuffixLength else { continue }

            for sourceSuffixLength in suffix.count...maximumSuffixLength {
                let sourceSuffix = sourceTokens[suffixStartIndex..<(suffixStartIndex + sourceSuffixLength)]
                guard let suffixEdits = suffixEdits(sourceSuffix: Array(sourceSuffix), rewrittenSuffix: suffix) else {
                    continue
                }
                guard let value = parsedAddressNumber(endingBefore: suffixStartIndex, in: sourceTokens) else {
                    continue
                }
                let evidence = SourceAddressEvidence(number: String(value), suffixEdits: suffixEdits)
                candidates.append(SourceAddressEvidenceCandidate(evidence: evidence, sourceSuffixLength: sourceSuffixLength))
            }
        }

        return candidates
            .sorted {
                if $0.evidence.suffixEdits.count != $1.evidence.suffixEdits.count {
                    return $0.evidence.suffixEdits.count < $1.evidence.suffixEdits.count
                }
                return $0.sourceSuffixLength > $1.sourceSuffixLength
            }
            .first?
            .evidence
    }

    private func suffixEdits(sourceSuffix: [RepairTaggedToken], rewrittenSuffix: [RepairWordToken]) -> [(Range<String.Index>, String)]? {
        var edits: [(Range<String.Index>, String)] = []
        var sourceIndex = sourceSuffix.startIndex
        var rewrittenIndex = rewrittenSuffix.startIndex

        while sourceIndex < sourceSuffix.endIndex, rewrittenIndex < rewrittenSuffix.endIndex {
            let sourceToken = sourceSuffix[sourceIndex]
            let rewrittenToken = rewrittenSuffix[rewrittenIndex]
            if sourceToken.token.normalized == rewrittenToken.normalized {
                if let sourceOrdinal = RepairNumberParsing.parsedOrdinalInteger(sourceToken.token.text),
                   let replacement = RepairNumberParsing.ordinalString(for: sourceOrdinal),
                   rewrittenToken.text != replacement {
                    edits.append((rewrittenToken.range, replacement))
                }
                sourceIndex += 1
                rewrittenIndex += 1
                continue
            }

            guard let sourceOrdinalRun = sourceOrdinalRun(startingAt: sourceIndex, in: sourceSuffix),
                  RepairNumberParsing.parsedOrdinalInteger(rewrittenToken.text) != nil,
                  let replacement = RepairNumberParsing.ordinalString(for: sourceOrdinalRun.value) else {
                return nil
            }
            edits.append((rewrittenToken.range, replacement))
            sourceIndex = sourceOrdinalRun.endIndex
            rewrittenIndex += 1
        }

        guard sourceIndex == sourceSuffix.endIndex, rewrittenIndex == rewrittenSuffix.endIndex else { return nil }
        return edits
    }

    private func sourceOrdinalRun(
        startingAt startIndex: Int,
        in sourceSuffix: [RepairTaggedToken]
    ) -> (value: Int, endIndex: Int)? {
        let maximumEndIndex = min(sourceSuffix.endIndex, startIndex + 3)
        guard startIndex < maximumEndIndex else { return nil }

        for endIndex in stride(from: maximumEndIndex, through: startIndex + 1, by: -1) {
            let text = sourceSuffix[startIndex..<endIndex]
                .map(\.token.text)
                .joined(separator: " ")
            guard let value = RepairNumberParsing.parsedOrdinalInteger(text) else {
                continue
            }
            return (value, endIndex)
        }

        return nil
    }

    private func parsedAddressNumber(endingBefore endIndex: Int, in tokens: [RepairTaggedToken]) -> Int? {
        guard endIndex > 0 else { return nil }
        let lowerBound = max(0, endIndex - 6)

        for startIndex in stride(from: lowerBound, through: endIndex - 1, by: 1) {
            let candidateTokens = Array(tokens[startIndex..<endIndex])
            guard candidateTokens.allSatisfy(RepairNumberParsing.isNumericToken) else { continue }
            guard let value = parsedAddressNumber(from: candidateTokens), value >= 10 else { continue }
            return value
        }

        return nil
    }

    private func parsedAddressNumber(from tokens: [RepairTaggedToken]) -> Int? {
        let tokenTexts = tokens.map(\.token.text)

        if tokenTexts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return Int(tokenTexts.joined())
        }

        if let value = RepairNumberParsing.parsedSpellOutInteger(tokenTexts.joined(separator: " ")), value >= 100 {
            return value
        }

        if let digitSequence = RepairNumberParsing.parsedDigitSequence(from: tokenTexts) {
            return digitSequence
        }

        if tokens.count > 1 {
            for splitIndex in 1..<tokens.count {
                let leadingText = tokenTexts[..<splitIndex].joined(separator: " ")
                let trailingText = tokenTexts[splitIndex...].joined(separator: " ")
                guard let leadingValue = RepairNumberParsing.parsedSpellOutInteger(leadingText),
                      let trailingValue = RepairNumberParsing.parsedSpellOutInteger(trailingText),
                      (1...99).contains(leadingValue),
                      (0...99).contains(trailingValue) else {
                    continue
                }
                return (leadingValue * 100) + trailingValue
            }
        }

        return nil
    }

    private func replacingSubrange(
        _ range: Range<String.Index>,
        in text: String,
        with replacement: String
    ) -> String {
        var repaired = text
        repaired.replaceSubrange(range, with: replacement)
        return repaired
    }

    private func applying(edits: [(Range<String.Index>, String)], to text: String) -> String {
        var repaired = text
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }
}
