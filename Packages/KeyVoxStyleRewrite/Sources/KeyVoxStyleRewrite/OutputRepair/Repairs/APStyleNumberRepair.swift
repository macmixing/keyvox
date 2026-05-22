import Foundation

struct APStyleNumberRepair {
    func repair(original: String, rewritten: String) -> String {
        let decimalRepaired = repairSpokenDecimalRuns(rewritten)
        let lowDigitRepaired = repairLowOrdinaryDigits(original: original, rewritten: decimalRepaired)
        return repairSpellOutNumberRuns(lowDigitRepaired)
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

    private func repairSpokenDecimalRuns(_ text: String) -> String {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard tokens.count >= 3 else { return text }

        var edits: [(Range<String.Index>, String)] = []
        var index = 0
        while index + 2 < tokens.count {
            guard let major = RepairNumberParsing.parsedSpellOutInteger(tokens[index].text),
                  tokens[index + 1].normalized == "point",
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

}
