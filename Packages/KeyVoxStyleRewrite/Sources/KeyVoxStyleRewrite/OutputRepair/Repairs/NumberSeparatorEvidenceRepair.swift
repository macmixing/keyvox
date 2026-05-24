import Foundation

struct NumberSeparatorEvidenceRepair {
    private static let dotSeparatedCandidatePattern = #"(?<![\w.])([1-9]|1[0-2])\.([0-5][0-9])(?![\w]|\.[\w])"#

    private static let maximumInterveningWordTokenCount = 4

    private static let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    func repair(original: String, rewritten: String) -> String {
        let separatorEvidence = numericSeparatorEvidence(in: original)
        let colonSeparatedRepaired = RepairMatching.replacingMatches(
            in: rewritten,
            pattern: #"(?<![\w:])([1-9]|1[0-2]):([0-5][0-9])(?![\w:])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 3 else {
                return nil
            }

            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            let decimal = "\(hour).\(minute)"
            guard separatorEvidence.decimalSeparatedRuns.contains(decimal) else {
                return nil
            }

            return decimal
        }

        let dotSeparatedRepaired = RepairMatching.replacingMatches(
            in: colonSeparatedRepaired,
            pattern: Self.dotSeparatedCandidatePattern,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 3,
                  separatorEvidence.timeSeparatedRuns.contains(nsText.substring(with: match.range)),
                  !separatorEvidence.decimalSeparatedRuns.contains(nsText.substring(with: match.range)) else {
                return nil
            }

            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute)"
        }

        let text = dotSeparatedRepaired
        let tokens = RepairTokenization.wordTokens(in: text)
        guard tokens.count >= 3 else { return text }

        var edits: [(Range<String.Index>, String)] = []
        var index = 0
        while index + 2 < tokens.count {
            guard let major = RepairNumberParsing.parsedSpellOutInteger(tokens[index].text),
                  RepairNumberParsing.isSpellOutDecimalSeparator(tokens[index + 1]),
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[index], and: tokens[index + 1], in: text) else {
                index += 1
                continue
            }

            var minorDigits: [Int] = []
            var endIndex = index + 2
            while endIndex < tokens.count,
                  let digit = RepairNumberParsing.parsedSpellOutInteger(tokens[endIndex].text),
                  digit >= 0,
                  digit < RepairNumberParsing.apStyleNumeralLowerBound,
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
                minorDigits.append(digit)
                endIndex += 1
            }

            guard !minorDigits.isEmpty else {
                index += 1
                continue
            }

            let range = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
            let minor = minorDigits.map(String.init).joined()
            edits.append((range, "\(major).\(minor)"))
            index = endIndex
        }

        guard !edits.isEmpty else { return text }

        var repaired = text
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func numericSeparatorEvidence(in text: String) -> (
        decimalSeparatedRuns: Set<String>,
        timeSeparatedRuns: Set<String>
    ) {
        var decimalSeparatedRuns = spokenDecimalRuns(in: text)
        var timeSeparatedRuns: Set<String> = []

        RepairMatching.inspectingMatches(
            in: text,
            pattern: Self.dotSeparatedCandidatePattern,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 3 else { return }
            let separatorRun = nsText.substring(with: match.range)
            if isTimeTerminatingAtCandidate(match: match, in: nsText as String) {
                timeSeparatedRuns.insert(separatorRun)
            } else {
                decimalSeparatedRuns.insert(separatorRun)
            }
        }

        RepairMatching.inspectingMatches(
            in: text,
            pattern: #"(?<![\w:])([1-9]|1[0-2]):([0-5][0-9])(?![\w:])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 3 else { return }
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            timeSeparatedRuns.insert("\(hour).\(minute)")
        }

        return (decimalSeparatedRuns, timeSeparatedRuns)
    }

    private func spokenDecimalRuns(in text: String) -> Set<String> {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard tokens.count >= 3 else { return [] }

        var decimalRuns: Set<String> = []
        var index = 0
        while index + 2 < tokens.count {
            guard let major = RepairNumberParsing.parsedSpellOutInteger(tokens[index].text),
                  RepairNumberParsing.isSpellOutDecimalSeparator(tokens[index + 1]),
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[index], and: tokens[index + 1], in: text) else {
                index += 1
                continue
            }

            var minorDigits: [Int] = []
            var endIndex = index + 2
            while endIndex < tokens.count,
                  let digit = RepairNumberParsing.parsedSpellOutInteger(tokens[endIndex].text),
                  digit >= 0,
                  digit < RepairNumberParsing.apStyleNumeralLowerBound,
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
                minorDigits.append(digit)
                endIndex += 1
            }

            if minorDigits.isEmpty {
                index += 1
            } else {
                decimalRuns.insert("\(major).\(minorDigits.map(String.init).joined())")
                index = endIndex
            }
        }

        return decimalRuns
    }

    private func isTimeTerminatingAtCandidate(match: NSTextCheckingResult, in text: String) -> Bool {
        guard let dateDetector = Self.dateDetector,
              let candidateRange = Range(match.range, in: text) else {
            return false
        }

        if isDetectedTime(candidateRange: candidateRange, in: text, using: dateDetector) {
            return true
        }

        return isDetectedTimeAfterElidingInterveningWords(
            candidateRange: candidateRange,
            in: text,
            using: dateDetector
        )
    }

    private func isDetectedTimeAfterElidingInterveningWords(
        candidateRange: Range<String.Index>,
        in text: String,
        using dateDetector: NSDataDetector
    ) -> Bool {
        let tokens = RepairTokenization.wordTokens(in: text)
        let precedingTokens = tokens.filter { $0.range.upperBound <= candidateRange.lowerBound }
        guard !precedingTokens.isEmpty else { return false }

        var suffixStartIndex = precedingTokens.count
        var currentBoundary = candidateRange.lowerBound
        var elidedTokenCount = 0
        while suffixStartIndex > 0,
              elidedTokenCount < Self.maximumInterveningWordTokenCount {
            let token = precedingTokens[suffixStartIndex - 1]
            guard RepairNumberParsing.numericValue(for: token) == nil,
                  text[token.range.upperBound..<currentBoundary].allSatisfy(\.isWhitespace) else {
                break
            }

            suffixStartIndex -= 1
            elidedTokenCount += 1
            currentBoundary = token.range.lowerBound

            let removalRange = token.range.lowerBound..<candidateRange.lowerBound
            if isDetectedTimeAfterEliding(
                removalRange: removalRange,
                candidateRange: candidateRange,
                in: text,
                using: dateDetector
            ) {
                return true
            }
        }

        return false
    }

    private func isDetectedTimeAfterEliding(
        removalRange: Range<String.Index>,
        candidateRange: Range<String.Index>,
        in text: String,
        using dateDetector: NSDataDetector
    ) -> Bool {
        let prefix = String(text[..<removalRange.lowerBound])
        let candidateText = String(text[candidateRange])
        let suffix = String(text[candidateRange.upperBound...])
        let probe = prefix + candidateText + suffix
        let probeCandidateStart = probe.index(probe.startIndex, offsetBy: prefix.count)
        let probeCandidateEnd = probe.index(probeCandidateStart, offsetBy: candidateText.count)
        return isDetectedTime(
            candidateRange: probeCandidateStart..<probeCandidateEnd,
            in: probe,
            using: dateDetector
        )
    }

    private func isDetectedTime(
        candidateRange: Range<String.Index>,
        in text: String,
        using dateDetector: NSDataDetector
    ) -> Bool {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return dateDetector.matches(in: text, options: [], range: nsRange).contains { dateMatch in
            guard dateMatch.date != nil,
                  let detectedRange = Range(dateMatch.range, in: text) else {
                return false
            }

            // Accept explicit time context such as "at 2.30" while rejecting bare date-parser guesses like "2.23 yesterday".
            return detectedRange.contains(candidateRange.lowerBound)
                && (detectedRange.upperBound == candidateRange.upperBound
                    || detectedRange.lowerBound < candidateRange.lowerBound)
        }
    }
}
