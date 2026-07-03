import Foundation

enum NumberEvidenceRunAnalysis {
    static func sourceDecimalTexts(in text: String) -> [(text: String, major: String, minor: String)] {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard tokens.count >= 3 else { return [] }

        var decimals: [(text: String, major: String, minor: String)] = []
        for index in tokens.indices {
            guard let decimalRun = decimalRunStarting(at: index, in: tokens, sourceText: text),
                  let evidence = NumberEvidence.components(in: Array(tokens[decimalRun])),
                  let decimalText = NumberEvidence.decimalReplacementText(
                    evidence: evidence,
                    tokens: Array(tokens[decimalRun])
                  ),
                  let separatorIndex = decimalText.firstIndex(of: ".") else {
                continue
            }

            decimals.append((
                text: decimalText,
                major: String(decimalText[..<separatorIndex]),
                minor: String(decimalText[decimalText.index(after: separatorIndex)...])
            ))
        }

        return decimals
    }

    static func decimalRunStarting(
        at index: Int,
        in tokens: [RepairWordToken],
        sourceText: String
    ) -> Range<Int>? {
        guard index + 2 < tokens.count,
              RepairNumberParsing.numericValue(for: tokens[index]) != nil,
              RepairNumberParsing.isSpellOutDecimalSeparator(tokens[index + 1]),
              RepairNumberParsing.isNumberRunSeparator(between: tokens[index], and: tokens[index + 1], in: sourceText) else {
            return nil
        }

        var endIndex = index + 2
        while endIndex < tokens.count,
              RepairNumberParsing.numericValue(for: tokens[endIndex]) != nil,
              RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: sourceText) {
            endIndex += 1
        }

        return index..<endIndex
    }

    static func nextMatchedOriginalIndex(after index: Int, matches: [Int: Int]) -> Int? {
        matches.keys.filter { $0 > index }.min()
    }

    static func nextMatchedRewrittenIndex(after index: Int, matches: [Int: Int]) -> Int? {
        matches.values.filter { $0 > index }.min()
    }

    static func originalEvidenceRun(
        in tokens: [RepairWordToken],
        matching rewrittenEvidence: [NumberEvidence.Component],
        sourceText: String,
        rewrittenRun: [RepairWordToken],
        rewrittenText: String
    ) -> (tokens: [RepairWordToken], evidence: [NumberEvidence.Component])? {
        let candidates = contiguousNumberRuns(in: tokens, sourceText: sourceText)
        for candidate in candidates {
            guard let evidence = NumberEvidence.components(in: candidate),
                  NumberEvidence.isEquivalent(
                    evidence,
                    rewrittenEvidence,
                    leftRun: candidate,
                    rightRun: rewrittenRun,
                    leftText: sourceText,
                    rightText: rewrittenText
                  ) else {
                continue
            }
            return (candidate, evidence)
        }

        guard let evidence = NumberEvidence.components(in: tokens) else {
            return nil
        }
        return (tokens, evidence)
    }

    static func contiguousNumberRuns(in tokens: [RepairWordToken], sourceText: String) -> [[RepairWordToken]] {
        var runs: [[RepairWordToken]] = []
        var index = 0

        while index < tokens.count {
            guard RepairNumberParsing.numericValue(for: tokens[index]) != nil else {
                index += 1
                continue
            }

            var endIndex = index + 1
            while endIndex < tokens.count,
                  RepairNumberParsing.numericValue(for: tokens[endIndex]) != nil,
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: sourceText) {
                endIndex += 1
            }

            runs.append(Array(tokens[index..<endIndex]))
            index = endIndex
        }

        return runs
    }

    static func singleNumberEvidenceRun(
        in tokens: [RepairWordToken],
        sourceText: String
    ) -> (tokens: [RepairWordToken], evidence: [NumberEvidence.Component])? {
        if let evidence = NumberEvidence.components(in: tokens) {
            return (tokens, evidence)
        }

        let runs = contiguousNumberRuns(in: tokens, sourceText: sourceText)
        guard runs.count == 1,
              let evidence = NumberEvidence.components(in: runs[0]) else {
            return nil
        }
        return (runs[0], evidence)
    }

    static func containsNumberEvidence(in tokens: [RepairWordToken], sourceText: String) -> Bool {
        NumberEvidence.components(in: tokens) != nil
            || contiguousNumberRuns(in: tokens, sourceText: sourceText).isEmpty == false
    }

    static func shouldPreserveOriginalSurface(tokens: [RepairWordToken], fullRun: [RepairWordToken], in text: String) -> Bool {
        if fullRun.count > tokens.count,
           fullRun.allSatisfy({ RepairNumberParsing.numericValue(for: $0) != nil }) {
            return true
        }

        return tokens.count == 1 && tokens.contains { token in
            isPunctuationTerminatedNumberCue(token: token, in: text)
        }
    }

    static func preservedSurfaceRange(
        leftAnchor: RepairWordToken,
        tokens: [RepairWordToken],
        fullRun: [RepairWordToken],
        rightAnchor: RepairWordToken
    ) -> Range<String.Index> {
        let start = leftAnchor.range.upperBound
        if fullRun.count > tokens.count,
           let nextRunToken = fullRun.first(where: { $0.range.lowerBound >= tokens[tokens.count - 1].range.upperBound }) {
            return start..<nextRunToken.range.lowerBound
        }
        return start..<rightAnchor.range.lowerBound
    }

    private static func isPunctuationTerminatedNumberCue(token: RepairWordToken, in text: String) -> Bool {
        guard !isOrderedListMarker(token: token, in: text),
              token.range.upperBound < text.endIndex else {
            return false
        }

        let next = text[token.range.upperBound]
        return next == "." || next == ","
    }

    private static func isOrderedListMarker(token: RepairWordToken, in text: String) -> Bool {
        guard isStartOfLine(token.range.lowerBound, in: text),
              token.range.upperBound < text.endIndex,
              text[token.range.upperBound] == "." else {
            return false
        }

        let afterPeriod = text.index(after: token.range.upperBound)
        return afterPeriod == text.endIndex || text[afterPeriod].isWhitespace
    }

    private static func isStartOfLine(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        return text[text.index(before: index)].isNewline
    }
}
