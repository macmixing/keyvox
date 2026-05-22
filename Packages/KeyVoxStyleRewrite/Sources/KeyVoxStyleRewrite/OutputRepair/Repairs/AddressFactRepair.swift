import Foundation

struct AddressFactRepair {
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
                  let sourceNumber = sourceAddressNumber(
                    beforeSuffix: Array(addressTokens.dropFirst()),
                    in: originalTokens
                  ),
                  sourceNumber != leadingToken.text else {
                continue
            }

            let candidate = replacingSubrange(leadingToken.range, in: rewritten, with: sourceNumber)
            guard hasDetectedAddress(overlapping: leadingToken.range.lowerBound, in: candidate) else {
                continue
            }
            edits.append((leadingToken.range, sourceNumber))
        }

        for timeMatch in timeMatches(in: rewritten) {
            guard let timeRange = Range(timeMatch.range, in: rewritten) else { continue }
            let followingTokens = rewrittenWordTokens.filter { $0.range.lowerBound >= timeRange.upperBound }
            guard !followingTokens.isEmpty else { continue }

            for suffixLength in 1...min(4, followingTokens.count) {
                let suffix = Array(followingTokens.prefix(suffixLength))
                guard let sourceNumber = sourceAddressNumber(beforeSuffix: suffix, in: originalTokens) else {
                    continue
                }

                let candidate = replacingSubrange(timeRange, in: rewritten, with: sourceNumber)
                guard hasDetectedAddress(overlapping: timeRange.lowerBound, in: candidate) else {
                    continue
                }
                edits.append((timeRange, sourceNumber))
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

    private func sourceAddressNumber(beforeSuffix suffix: [RepairWordToken], in sourceTokens: [RepairTaggedToken]) -> String? {
        guard !suffix.isEmpty else { return nil }
        let suffixNormalizations = suffix.map(\.normalized)

        for suffixStartIndex in sourceTokens.indices {
            guard suffixStartIndex + suffixNormalizations.count <= sourceTokens.count else { continue }
            let sourceSuffix = sourceTokens[suffixStartIndex..<(suffixStartIndex + suffixNormalizations.count)]
            guard Array(sourceSuffix.map(\.token.normalized)) == suffixNormalizations else {
                continue
            }
            guard let value = parsedAddressNumber(endingBefore: suffixStartIndex, in: sourceTokens) else {
                continue
            }
            return String(value)
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
}
