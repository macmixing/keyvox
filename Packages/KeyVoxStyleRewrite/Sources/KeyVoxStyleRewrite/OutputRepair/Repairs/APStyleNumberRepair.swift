import Foundation

struct APStyleNumberRepair {
    private static let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    func repair(original: String, rewritten: String) -> String {
        let decimalRepaired = repairNumericSeparatorRuns(original: original, rewritten: rewritten)
        let collapsedRunRepaired = repairCollapsedAdjacentNumberRuns(original: original, rewritten: decimalRepaired)
        let lowDigitRepaired = repairLowOrdinaryDigits(original: original, rewritten: collapsedRunRepaired)
        return repairSpellOutNumberRuns(lowDigitRepaired)
    }

    private func repairCollapsedAdjacentNumberRuns(original: String, rewritten: String) -> String {
        let tokens = RepairTokenization.wordTokens(in: original)
        guard tokens.count >= 2 else { return rewritten }

        var repaired = rewritten
        var index = 0
        while index < tokens.count {
            guard let adjacentEndIndex = adjacentSingleNumberRunEnd(startingAt: index, tokens: tokens, in: original),
                  !canParseWholeRun(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens, in: original),
                  let replacement = adjacentNumberRunReplacement(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens) else {
                index += 1
                continue
            }

            let collapsedDigits = replacement.values.map(String.init).joined()
            repaired = RepairMatching.replacingMatches(
                in: repaired,
                pattern: #"(?<![\w])\#(NSRegularExpression.escapedPattern(for: collapsedDigits))-(?=[\p{L}])"#,
                options: []
            ) { _, _ in
                replacement.text + " "
            }
            index = adjacentEndIndex
        }

        return repaired
    }

    private func repairLowOrdinaryDigits(original: String, rewritten: String) -> String {
        let normalizedOriginal = original.lowercased()
        return RepairMatching.replacingMatches(
            in: rewritten,
            pattern: #"(?<![\w$])([0-9])(?![\w])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 2 else { return nil }
            let digitRange = match.range(at: 1)
            guard digitRange.location != NSNotFound else { return nil }
            let digit = nsText.substring(with: digitRange)
            guard let value = Int(digit),
                  value < RepairNumberParsing.apStyleNumeralLowerBound,
                  let word = RepairNumberParsing.spellOutString(for: value),
                  RepairMatching.containsWord(word, in: normalizedOriginal),
                  !isProtectedLowDigit(match: match, in: nsText as String) else {
                return nil
            }
            return word
        }
    }

    private func repairSpellOutNumberRuns(_ text: String) -> String {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard !tokens.isEmpty else { return text }

        var edits: [(Range<String.Index>, String)] = []
        var index = 0
        while index < tokens.count {
            if let adjacentEndIndex = adjacentSingleNumberRunEnd(startingAt: index, tokens: tokens, in: text),
               !canParseWholeRun(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens, in: text) {
                index = adjacentEndIndex
            } else if let replacement = spellOutNumberRunReplacement(startingAt: index, tokens: tokens, in: text) {
                edits.append((replacement.range, replacement.text))
                index = replacement.endIndex
            } else {
                index += 1
            }
        }

        guard !edits.isEmpty else { return text }

        var repaired = text
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func repairNumericSeparatorRuns(original: String, rewritten: String) -> String {
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
            pattern: #"(?<![\w.])([1-9]|1[0-2])\.([0-5][0-9])(?![\w.])"#,
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
            pattern: #"(?<![\w.])([1-9]|1[0-2])\.([0-5][0-9])(?![\w.])"#,
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

    private func spellOutNumberRunReplacement(
        startingAt index: Int,
        tokens: [RepairWordToken],
        in text: String
    ) -> (range: Range<String.Index>, text: String, endIndex: Int)? {
        let maximumEndIndex = contiguousCandidateEnd(startingAt: index, tokens: tokens, in: text)
        guard maximumEndIndex > index else { return nil }

        for endIndex in stride(from: maximumEndIndex, through: index + 1, by: -1) {
            let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
            let runText = String(text[runRange])
            guard let value = RepairNumberParsing.parsedSpellOutInteger(runText),
                  value >= RepairNumberParsing.apStyleNumeralLowerBound,
                  !isProtectedNumberRun(range: runRange, in: text) else {
                continue
            }
            return (runRange, String(value), endIndex)
        }

        return nil
    }

    private func adjacentNumberRunReplacement(
        startingAt index: Int,
        endingAt endIndex: Int,
        tokens: [RepairWordToken]
    ) -> (values: [Int], text: String)? {
        var values: [Int] = []
        var parts: [String] = []
        for token in tokens[index..<endIndex] {
            guard let value = RepairNumberParsing.parsedSpellOutInteger(token.text) else {
                return nil
            }
            values.append(value)
            if value >= RepairNumberParsing.apStyleNumeralLowerBound {
                parts.append(String(value))
            } else if let word = RepairNumberParsing.spellOutString(for: value) {
                parts.append(word)
            } else {
                return nil
            }
        }
        return (values, parts.joined(separator: " "))
    }

    private func contiguousCandidateEnd(startingAt index: Int, tokens: [RepairWordToken], in text: String) -> Int {
        var endIndex = index + 1
        while endIndex < tokens.count,
              RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
            endIndex += 1
        }
        return endIndex
    }

    private func adjacentSingleNumberRunEnd(startingAt index: Int, tokens: [RepairWordToken], in text: String) -> Int? {
        guard RepairNumberParsing.parsedSpellOutInteger(tokens[index].text) != nil else { return nil }

        var endIndex = index + 1
        while endIndex < tokens.count,
              RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text),
              RepairNumberParsing.parsedSpellOutInteger(tokens[endIndex].text) != nil {
            endIndex += 1
        }

        return endIndex > index + 1 ? endIndex : nil
    }

    private func canParseWholeRun(startingAt index: Int, endingAt endIndex: Int, tokens: [RepairWordToken], in text: String) -> Bool {
        let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
        return RepairNumberParsing.parsedSpellOutInteger(String(text[runRange])) != nil
    }

    private func isProtectedLowDigit(match: NSTextCheckingResult, in text: String) -> Bool {
        guard let range = Range(match.range(at: 1), in: text) else { return true }
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous == "$" || previous == ":" || previous == "/" || previous == "-" {
                return true
            }
            if previous == "." {
                return true
            }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next == ":" || next == "%" || next == "/" || next == "-" {
                return true
            }
            if next == ".",
               text.index(after: range.upperBound) < text.endIndex,
               text[text.index(after: range.upperBound)].isNumber {
                return true
            }
        }
        return false
    }

    private func isProtectedNumberRun(range: Range<String.Index>, in text: String) -> Bool {
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous == "$" || previous == ":" || previous == "/" || previous == "-" {
                return true
            }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next == ":" || next == "%" || next == "/" || next == "-" {
                return true
            }
        }

        return false
    }

    private func isTimeTerminatingAtCandidate(match: NSTextCheckingResult, in text: String) -> Bool {
        guard let dateDetector = Self.dateDetector,
              let candidateRange = Range(match.range, in: text) else {
            return false
        }

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
