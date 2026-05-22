import Foundation
import NaturalLanguage

enum StyleRewriteOutputRepair {
    static func repairDeletedSeparatorPunctuation(original: String, rewritten: String) -> String {
        let originalTokens = wordTokens(in: original)
        let rewrittenTokens = wordTokens(in: rewritten)
        guard !originalTokens.isEmpty, !rewrittenTokens.isEmpty else {
            return rewritten
        }

        let commaRemoved = removeCommaSeparatorsIntroducedByDeletion(
            originalTokens: originalTokens,
            rewrittenTokens: rewrittenTokens,
            original: original,
            rewritten: rewritten
        )
        let sentenceCommaRepaired = restoreSentenceOpeningCommasRemovedWithDeletedTokens(
            originalTokens: originalTokens,
            rewrittenTokens: wordTokens(in: commaRemoved),
            original: original,
            rewritten: commaRemoved
        )
        let percentRepaired = repairPercentSentenceSplit(sentenceCommaRepaired)
        let structuredNumericRepaired = repairStructuredNumericFacts(original: original, rewritten: percentRepaired)
        let numberEvidenceRepaired = repairDeletedNumberEvidence(original: original, rewritten: structuredNumericRepaired)
        return repairAPStyleOrdinaryNumbers(original: original, rewritten: numberEvidenceRepaired)
    }

    private struct WordToken: Equatable {
        let text: String
        let normalized: String
        let range: Range<String.Index>
    }

    private struct TaggedToken {
        let token: WordToken
        let tag: NLTag?
        let lemma: String?
    }

    private struct SourceMoneySpan {
        let majorValue: Int
        let minorValue: Int?
        let symbol: String
    }

    private static let apStyleNumeralLowerBound = 10
    private static let addressDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.address.rawValue
    )
    private static let spellOutNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }()

    private static func wordTokens(in text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        var tokenStart: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            if isWordCharacter(text[index]) {
                if tokenStart == nil {
                    tokenStart = index
                }
            } else if let start = tokenStart {
                appendToken(in: text, range: start..<index, to: &tokens)
                tokenStart = nil
            }

            index = text.index(after: index)
        }

        if let start = tokenStart {
            appendToken(in: text, range: start..<text.endIndex, to: &tokens)
        }

        return tokens
    }

    private static func taggedTokens(in text: String) -> [TaggedToken] {
        let wordTokens = wordTokens(in: text)
        guard !wordTokens.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        return wordTokens.map { token in
            let tag = tagger.tag(at: token.range.lowerBound, unit: .word, scheme: .lexicalClass).0
            let lemma = tagger.tag(at: token.range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            return TaggedToken(token: token, tag: tag, lemma: lemma)
        }
    }

    private static func repairPercentSentenceSplit(_ text: String) -> String {
        replacingMatches(
            in: text,
            pattern: #"(\d+)%\.\s+(?=[a-z])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 2 else { return nil }
            let percentRange = match.range(at: 1)
            guard percentRange.location != NSNotFound else { return nil }
            return "\(nsText.substring(with: percentRange))% "
        }
    }

    private static func repairAPStyleOrdinaryNumbers(original: String, rewritten: String) -> String {
        let decimalRepaired = repairSpokenDecimalRuns(rewritten)
        let lowDigitRepaired = repairLowOrdinaryDigits(original: original, rewritten: decimalRepaired)
        return repairSpellOutNumberRuns(lowDigitRepaired)
    }

    private static func repairStructuredNumericFacts(original: String, rewritten: String) -> String {
        let addressRepaired = repairAddressNumbers(original: original, rewritten: rewritten)
        return repairMoneyAmounts(original: original, rewritten: addressRepaired)
    }

    private static func repairDeletedNumberEvidence(original: String, rewritten: String) -> String {
        let originalTokens = wordTokens(in: original)
        let rewrittenTokens = wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 2 else { return rewritten }

        let matches = matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let rewrittenNumberValues = Set(rewrittenTokens.compactMap { numericValue(for: $0) })
        var edits: [(Range<String.Index>, String)] = []
        var index = 1

        while index < originalTokens.count - 1 {
            guard matches[index] == nil,
                  let value = numericValue(for: originalTokens[index]),
                  !rewrittenNumberValues.contains(value) else {
                index += 1
                continue
            }

            let runStart = index
            var runEnd = index + 1
            var runValues = Set([value])
            while runEnd < originalTokens.count - 1,
                  matches[runEnd] == nil,
                  let runValue = numericValue(for: originalTokens[runEnd]),
                  !rewrittenNumberValues.contains(runValue) {
                runValues.insert(runValue)
                runEnd += 1
            }

            guard !runValues.isEmpty,
                  let previousRewrittenIndex = matches[runStart - 1],
                  let nextRewrittenIndex = matches[runEnd],
                  nextRewrittenIndex == previousRewrittenIndex + 1 else {
                index = runEnd
                continue
            }

            let separatorRange = rewrittenTokens[previousRewrittenIndex].range.upperBound
                ..< rewrittenTokens[nextRewrittenIndex].range.lowerBound
            guard String(rewritten[separatorRange]).allSatisfy(\.isWhitespace) else {
                index = runEnd
                continue
            }

            let originalRunRange = originalTokens[runStart].range.lowerBound..<originalTokens[runEnd - 1].range.upperBound
            edits.append((separatorRange, " \(original[originalRunRange]) "))
            index = runEnd
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private static func repairAddressNumbers(original: String, rewritten: String) -> String {
        let originalTokens = taggedTokens(in: original)
        let rewrittenWordTokens = wordTokens(in: rewritten)
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

    private static func repairMoneyAmounts(original: String, rewritten: String) -> String {
        let sourceSpans = sourceMoneySpans(in: original)
        guard !sourceSpans.isEmpty else { return rewritten }

        let splitRepaired = repairSplitMoneyAmount(sourceSpans: sourceSpans, rewritten: rewritten)
        guard splitRepaired == rewritten else {
            return splitRepaired
        }

        return repairSingleMoneyAmountDrift(sourceSpans: sourceSpans, rewritten: rewritten)
    }

    private static func repairSplitMoneyAmount(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        replacingMatches(
            in: rewritten,
            pattern: "(\(StyleRewriteCurrencyUnits.symbolPattern))\\s*(\\d+)\\s+and(?:\\s+[\\p{L}'’]+){0,2}\\s+(\(StyleRewriteCurrencyUnits.symbolPattern))\\s*(\\d{1,2})(?!\\d|\\.\\d)",
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 5,
                  let major = Int(nsText.substring(with: match.range(at: 2))),
                  let minor = Int(nsText.substring(with: match.range(at: 4))),
                  minor < 100,
                  let sourceSpan = sourceSpans.first(where: { sourceSpan in
                    sourceSpan.majorValue == major && sourceSpan.minorValue != nil
                  }) else {
                return nil
            }

            let symbol = nsText.substring(with: match.range(at: 1))
            guard symbol == nsText.substring(with: match.range(at: 3)),
                  symbol == sourceSpan.symbol else {
                return nil
            }
            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan)
        }
    }

    private static func repairSingleMoneyAmountDrift(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard sourceSpans.count == 1, let sourceSpan = sourceSpans.first else { return rewritten }

        return replacingMatches(
            in: rewritten,
            pattern: "(\(StyleRewriteCurrencyUnits.symbolPattern))\\s*(\\d+)(?:\\.(\\d{1,2}))?(?!\\d|\\.\\d)",
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 4 else { return nil }
            let symbol = nsText.substring(with: match.range(at: 1))
            guard symbol == sourceSpan.symbol else { return nil }
            guard let major = Int(nsText.substring(with: match.range(at: 2))) else { return nil }

            let minorRange = match.range(at: 3)
            let minor = minorRange.location == NSNotFound
                ? nil
                : Int(nsText.substring(with: minorRange).padding(toLength: 2, withPad: "0", startingAt: 0))
            guard major != sourceSpan.majorValue || minor != sourceSpan.minorValue else {
                return nil
            }

            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan)
        }
    }

    private static func formattedMoneyAmount(symbol: String, sourceSpan: SourceMoneySpan) -> String {
        if let minorValue = sourceSpan.minorValue {
            return "\(symbol)\(sourceSpan.majorValue).\(String(format: "%02d", minorValue))"
        }
        return "\(symbol)\(sourceSpan.majorValue)"
    }

    private static func repairLowOrdinaryDigits(original: String, rewritten: String) -> String {
        let normalizedOriginal = original.lowercased()
        return replacingMatches(
            in: rewritten,
            pattern: #"(?<![\w$])([0-9])(?![\w])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 2 else { return nil }
            let digitRange = match.range(at: 1)
            guard digitRange.location != NSNotFound else { return nil }
            let digit = nsText.substring(with: digitRange)
            guard let value = Int(digit),
                  value < apStyleNumeralLowerBound,
                  let word = spellOutNumberFormatter.string(from: NSNumber(value: value)),
                  containsWord(word, in: normalizedOriginal),
                  !isProtectedLowDigit(match: match, in: nsText as String) else {
                return nil
            }
            return word
        }
    }

    private static func repairSpellOutNumberRuns(_ text: String) -> String {
        let tokens = wordTokens(in: text)
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

    private static func repairSpokenDecimalRuns(_ text: String) -> String {
        let tokens = wordTokens(in: text)
        guard tokens.count >= 3 else { return text }

        var edits: [(Range<String.Index>, String)] = []
        var index = 0
        while index + 2 < tokens.count {
            guard let major = parsedSpellOutInteger(tokens[index].text),
                  tokens[index + 1].normalized == "point",
                  isNumberRunSeparator(between: tokens[index], and: tokens[index + 1], in: text) else {
                index += 1
                continue
            }

            var minorDigits: [Int] = []
            var endIndex = index + 2
            while endIndex < tokens.count,
                  let digit = parsedSpellOutInteger(tokens[endIndex].text),
                  digit >= 0,
                  digit < apStyleNumeralLowerBound,
                  isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
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

    private static func spellOutNumberRunReplacement(
        startingAt index: Int,
        tokens: [WordToken],
        in text: String
    ) -> (range: Range<String.Index>, text: String, endIndex: Int)? {
        let maximumEndIndex = contiguousCandidateEnd(startingAt: index, tokens: tokens, in: text)
        guard maximumEndIndex > index else { return nil }

        for endIndex in stride(from: maximumEndIndex, through: index + 1, by: -1) {
            let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
            let runText = String(text[runRange])
            guard let value = parsedSpellOutInteger(runText),
                  value >= apStyleNumeralLowerBound,
                  !isProtectedNumberRun(range: runRange, in: text) else {
                continue
            }
            return (runRange, String(value), endIndex)
        }

        return nil
    }

    private static func contiguousCandidateEnd(startingAt index: Int, tokens: [WordToken], in text: String) -> Int {
        var endIndex = index + 1
        while endIndex < tokens.count,
              isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
            endIndex += 1
        }
        return endIndex
    }

    private static func adjacentSingleNumberRunEnd(startingAt index: Int, tokens: [WordToken], in text: String) -> Int? {
        guard parsedSpellOutInteger(tokens[index].text) != nil else { return nil }

        var endIndex = index + 1
        while endIndex < tokens.count,
              isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text),
              parsedSpellOutInteger(tokens[endIndex].text) != nil {
            endIndex += 1
        }

        return endIndex > index + 1 ? endIndex : nil
    }

    private static func canParseWholeRun(startingAt index: Int, endingAt endIndex: Int, tokens: [WordToken], in text: String) -> Bool {
        let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
        return parsedSpellOutInteger(String(text[runRange])) != nil
    }

    private static func isProtectedLowDigit(match: NSTextCheckingResult, in text: String) -> Bool {
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

    private static func isProtectedNumberRun(range: Range<String.Index>, in text: String) -> Bool {
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

    private static func isNumberRunSeparator(between left: WordToken, and right: WordToken, in text: String) -> Bool {
        let separator = text[left.range.upperBound..<right.range.lowerBound]
        return separator.allSatisfy { $0.isWhitespace || $0 == "-" }
    }

    private static func parsedSpellOutInteger(_ text: String) -> Int? {
        let candidates = [
            text,
            text.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression),
        ]

        for candidate in candidates {
            guard let number = spellOutNumberFormatter.number(from: candidate),
                  let value = integerValue(from: number),
                  spellOutMatches(candidate, value: value) else {
                continue
            }
            return value
        }

        return nil
    }

    private static func numericValue(for token: WordToken) -> Int? {
        if token.text.allSatisfy(\.isNumber) {
            return Int(token.text)
        }
        return parsedSpellOutInteger(token.text)
    }

    private static func integerValue(from number: NSNumber) -> Int? {
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite,
              doubleValue.rounded() == doubleValue,
              doubleValue >= Double(Int.min),
              doubleValue <= Double(Int.max) else {
            return nil
        }
        return Int(doubleValue)
    }

    private static func spellOutMatches(_ text: String, value: Int) -> Bool {
        guard let spellOut = spellOutNumberFormatter.string(from: NSNumber(value: value)) else {
            return false
        }

        return normalizedSpellOut(text) == normalizedSpellOut(spellOut)
    }

    private static func detectedAddressRanges(in text: String) -> [Range<String.Index>] {
        guard let addressDetector else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return addressDetector
            .matches(in: text, options: [], range: nsRange)
            .compactMap { Range($0.range, in: text) }
    }

    private static func hasDetectedAddress(overlapping index: String.Index, in text: String) -> Bool {
        detectedAddressRanges(in: text).contains { $0.contains(index) }
    }

    private static func timeMatches(in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}\b"#) else {
            return []
        }
        return regex.matches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    private static func sourceAddressNumber(beforeSuffix suffix: [WordToken], in sourceTokens: [TaggedToken]) -> String? {
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

    private static func parsedAddressNumber(endingBefore endIndex: Int, in tokens: [TaggedToken]) -> Int? {
        guard endIndex > 0 else { return nil }
        let lowerBound = max(0, endIndex - 6)

        for startIndex in stride(from: lowerBound, through: endIndex - 1, by: 1) {
            let candidateTokens = Array(tokens[startIndex..<endIndex])
            guard candidateTokens.allSatisfy(isNumericToken) else { continue }
            guard let value = parsedAddressNumber(from: candidateTokens), value >= 10 else { continue }
            return value
        }

        return nil
    }

    private static func parsedAddressNumber(from tokens: [TaggedToken]) -> Int? {
        let tokenTexts = tokens.map(\.token.text)

        if tokenTexts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return Int(tokenTexts.joined())
        }

        if let value = parsedSpellOutInteger(tokenTexts.joined(separator: " ")), value >= 100 {
            return value
        }

        if let digitSequence = parsedDigitSequence(from: tokenTexts) {
            return digitSequence
        }

        if tokens.count > 1 {
            for splitIndex in 1..<tokens.count {
                let leadingText = tokenTexts[..<splitIndex].joined(separator: " ")
                let trailingText = tokenTexts[splitIndex...].joined(separator: " ")
                guard let leadingValue = parsedSpellOutInteger(leadingText),
                      let trailingValue = parsedSpellOutInteger(trailingText),
                      (1...99).contains(leadingValue),
                      (0...99).contains(trailingValue) else {
                    continue
                }
                return (leadingValue * 100) + trailingValue
            }
        }

        return nil
    }

    private static func parsedDigitSequence(from tokenTexts: [String]) -> Int? {
        var digits = ""
        for text in tokenTexts {
            guard let value = parsedSpellOutInteger(text), (0...9).contains(value) else {
                return nil
            }
            digits += String(value)
        }
        return Int(digits)
    }

    private static func isNumericToken(_ token: TaggedToken) -> Bool {
        token.tag == .number
            || token.token.text.allSatisfy(\.isNumber)
            || parsedSpellOutInteger(token.token.text) != nil
    }

    private static func sourceMoneySpans(in text: String) -> [SourceMoneySpan] {
        let tokens = taggedTokens(in: text)
        guard !tokens.isEmpty else { return [] }

        var spans: [SourceMoneySpan] = []
        var index = tokens.startIndex
        while index < tokens.endIndex {
            guard let majorRun = numericRun(startingAt: index, in: tokens),
                  majorRun.endIndex < tokens.endIndex,
                  let majorValue = parsedNumericRun(Array(tokens[majorRun.range])),
                  let majorUnit = StyleRewriteCurrencyUnits.unit(for: tokens[majorRun.endIndex].lemma),
                  majorUnit.scale == .major else {
                index += 1
                continue
            }

            var minorValue: Int?
            var nextIndex = majorRun.endIndex + 1
            if nextIndex < tokens.endIndex,
               tokens[nextIndex].tag == .conjunction,
               let minorStartIndex = minorStartIndex(afterConjunctionAt: nextIndex, in: tokens),
               let minorRun = numericRun(startingAt: minorStartIndex, in: tokens),
               minorRun.endIndex < tokens.endIndex,
               let parsedMinorValue = parsedNumericRun(Array(tokens[minorRun.range])),
               parsedMinorValue < 100,
               let minorUnit = StyleRewriteCurrencyUnits.unit(for: tokens[minorRun.endIndex].lemma),
               minorUnit.scale == .minor {
                minorValue = parsedMinorValue
                nextIndex = minorRun.endIndex + 1
            }

            spans.append(SourceMoneySpan(
                majorValue: majorValue,
                minorValue: minorValue,
                symbol: majorUnit.symbol
            ))
            index = nextIndex
        }

        return spans
    }

    private static func minorStartIndex(afterConjunctionAt conjunctionIndex: Int, in tokens: [TaggedToken]) -> Int? {
        let maximumSkippedTokens = 2
        var index = conjunctionIndex + 1
        var skippedTokens = 0

        while index < tokens.endIndex {
            if isNumericToken(tokens[index]) {
                return index
            }
            if StyleRewriteCurrencyUnits.unit(for: tokens[index].lemma) != nil {
                return nil
            }
            guard skippedTokens < maximumSkippedTokens else {
                return nil
            }
            skippedTokens += 1
            index += 1
        }

        return nil
    }

    private static func numericRun(startingAt index: Int, in tokens: [TaggedToken]) -> (range: Range<Int>, endIndex: Int)? {
        guard index < tokens.endIndex, isNumericToken(tokens[index]) else { return nil }

        var endIndex = index + 1
        while endIndex < tokens.endIndex, isNumericToken(tokens[endIndex]) {
            endIndex += 1
        }
        return (index..<endIndex, endIndex)
    }

    private static func parsedNumericRun(_ tokens: [TaggedToken]) -> Int? {
        let texts = tokens.map(\.token.text)
        if texts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return Int(texts.joined())
        }
        if let digitSequence = parsedDigitSequence(from: texts) {
            return digitSequence
        }
        return parsedSpellOutInteger(texts.joined(separator: " "))
    }

    private static func replacingSubrange(
        _ range: Range<String.Index>,
        in text: String,
        with replacement: String
    ) -> String {
        var repaired = text
        repaired.replaceSubrange(range, with: replacement)
        return repaired
    }

    private static func normalizedSpellOut(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func containsWord(_ word: String, in normalizedText: String) -> Bool {
        let pattern = #"(?<![A-Za-z0-9])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![A-Za-z0-9])"#
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
            .firstMatch(
                in: normalizedText,
                options: [],
                range: NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)
            ) != nil
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options,
        replacement: (NSTextCheckingResult, NSString) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )
        guard !matches.isEmpty else { return text }

        var repaired = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: repaired),
                  let replacementText = replacement(match, nsText) else {
                continue
            }
            repaired.replaceSubrange(range, with: replacementText)
        }
        return repaired
    }

    private static func appendToken(
        in text: String,
        range: Range<String.Index>,
        to tokens: inout [WordToken]
    ) {
        let tokenText = String(text[range])
        let normalized = tokenText
            .lowercased()
            .filter { character in
                character.isLetter || character.isNumber
            }
        guard !normalized.isEmpty else { return }
        tokens.append(WordToken(text: tokenText, normalized: normalized, range: range))
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter
            || character.isNumber
            // Accept ASCII apostrophe plus right/left single quotation marks.
            || character == "'"
            || character == "’"
            || character == "‘"
    }

    private static func matchOriginalTokens(
        _ originalTokens: [WordToken],
        to rewrittenTokens: [WordToken]
    ) -> [Int: Int] {
        let originalCount = originalTokens.count
        let rewrittenCount = rewrittenTokens.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: rewrittenCount + 1),
            count: originalCount + 1
        )

        if originalCount > 0, rewrittenCount > 0 {
            for originalIndex in stride(from: originalCount - 1, through: 0, by: -1) {
                for rewrittenIndex in stride(from: rewrittenCount - 1, through: 0, by: -1) {
                    if originalTokens[originalIndex].normalized == rewrittenTokens[rewrittenIndex].normalized {
                        lengths[originalIndex][rewrittenIndex] = lengths[originalIndex + 1][rewrittenIndex + 1] + 1
                    } else {
                        lengths[originalIndex][rewrittenIndex] = max(
                            lengths[originalIndex + 1][rewrittenIndex],
                            lengths[originalIndex][rewrittenIndex + 1]
                        )
                    }
                }
            }
        }

        var matches: [Int: Int] = [:]
        var originalIndex = 0
        var rewrittenIndex = 0
        while originalIndex < originalCount, rewrittenIndex < rewrittenCount {
            if originalTokens[originalIndex].normalized == rewrittenTokens[rewrittenIndex].normalized {
                matches[originalIndex] = rewrittenIndex
                originalIndex += 1
                rewrittenIndex += 1
            } else if lengths[originalIndex + 1][rewrittenIndex] >= lengths[originalIndex][rewrittenIndex + 1] {
                originalIndex += 1
            } else {
                rewrittenIndex += 1
            }
        }

        return matches
    }

    private static func removeCommaSeparatorsIntroducedByDeletion(
        originalTokens: [WordToken],
        rewrittenTokens: [WordToken],
        original: String,
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let originalIndexByRewrittenIndex = Dictionary(
            uniqueKeysWithValues: matches.map { ($0.value, $0.key) }
        )
        var edits: [Range<String.Index>] = []

        for rewrittenIndex in rewrittenTokens.indices.dropLast() {
            let nextRewrittenIndex = rewrittenIndex + 1
            guard rewrittenIndex > rewrittenTokens.startIndex,
                  let originalIndex = originalIndexByRewrittenIndex[rewrittenIndex],
                  let nextOriginalIndex = originalIndexByRewrittenIndex[nextRewrittenIndex],
                  nextOriginalIndex > originalIndex + 1 else {
                continue
            }

            let separatorRange = rewrittenTokens[rewrittenIndex].range.upperBound
                ..< rewrittenTokens[nextRewrittenIndex].range.lowerBound
            let separator = String(rewritten[separatorRange])
            guard isCommaWhitespaceSeparator(separator) else {
                continue
            }

            let originalGapRange = originalTokens[originalIndex].range.upperBound
                ..< originalTokens[nextOriginalIndex].range.lowerBound
            let originalGap = String(original[originalGapRange])
            guard originalGap.contains(","), !wordTokens(in: originalGap).isEmpty else {
                continue
            }

            edits.append(separatorRange)
        }

        guard !edits.isEmpty else {
            return rewritten
        }

        var repaired = rewritten
        for range in edits.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            repaired.replaceSubrange(range, with: " ")
        }
        return repaired
    }

    private static func restoreSentenceOpeningCommasRemovedWithDeletedTokens(
        originalTokens: [WordToken],
        rewrittenTokens: [WordToken],
        original: String,
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let originalIndexByRewrittenIndex = Dictionary(
            uniqueKeysWithValues: matches.map { ($0.value, $0.key) }
        )
        var edits: [Range<String.Index>] = []

        for rewrittenIndex in rewrittenTokens.indices.dropLast() {
            let nextRewrittenIndex = rewrittenIndex + 1
            guard let originalIndex = originalIndexByRewrittenIndex[rewrittenIndex],
                  let nextOriginalIndex = originalIndexByRewrittenIndex[nextRewrittenIndex],
                  nextOriginalIndex > originalIndex + 1,
                  isSentenceOpeningToken(originalTokens[originalIndex], in: original) else {
                continue
            }

            let separatorRange = rewrittenTokens[rewrittenIndex].range.upperBound
                ..< rewrittenTokens[nextRewrittenIndex].range.lowerBound
            guard String(rewritten[separatorRange]).allSatisfy(\.isWhitespace) else {
                continue
            }

            let originalGapRange = originalTokens[originalIndex].range.upperBound
                ..< originalTokens[nextOriginalIndex].range.lowerBound
            guard startsWithComma(String(original[originalGapRange])),
                  !wordTokens(in: String(original[originalGapRange])).isEmpty else {
                continue
            }

            edits.append(separatorRange)
        }

        guard !edits.isEmpty else {
            return rewritten
        }

        var repaired = rewritten
        for range in edits.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            repaired.replaceSubrange(range, with: ", ")
        }
        return repaired
    }

    private static func startsWithComma(_ text: String) -> Bool {
        text.drop(while: \.isWhitespace).first == ","
    }

    private static func isSentenceOpeningToken(_ token: WordToken, in text: String) -> Bool {
        var index = token.range.lowerBound
        while index > text.startIndex {
            let previous = text.index(before: index)
            if text[previous].isWhitespace {
                index = previous
                continue
            }
            return text[previous] == "." || text[previous] == "?" || text[previous] == "!"
        }
        return true
    }

    private static func isCommaWhitespaceSeparator(_ text: String) -> Bool {
        var hasComma = false
        for character in text {
            if character == "," {
                hasComma = true
            } else if !character.isWhitespace {
                return false
            }
        }
        return hasComma
    }
}
