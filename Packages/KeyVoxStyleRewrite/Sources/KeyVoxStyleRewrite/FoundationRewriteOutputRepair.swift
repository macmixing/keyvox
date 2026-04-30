import Foundation

enum FoundationRewriteOutputRepair {
    private static let protectedSuffix = "ing"

    struct Result: Equatable {
        let text: String
        let rejectedProtectedRemoval: Bool
    }

    static func repair(original: String, rewritten: String) -> Result {
        let originalTokens = wordTokens(in: original)
        let rewrittenTokens = wordTokens(in: rewritten)
        guard !originalTokens.isEmpty, !rewrittenTokens.isEmpty else {
            return Result(text: rewritten, rejectedProtectedRemoval: false)
        }

        let collapsedRewritten = collapseAdjacentProtectedDuplicates(in: rewritten, tokens: rewrittenTokens)
        let outputTokens = wordTokens(in: collapsedRewritten)
        let matches = matchOriginalTokens(originalTokens, to: outputTokens)
        let protectedIndexes = Set(originalTokens.indices.filter { index in
            matches[index] == nil
                && isProtectedToken(originalTokens[index])
                && !isAdjacentDuplicateRemovalAllowed(
                    at: index,
                    originalTokens: originalTokens,
                    matchedRewrittenIndexes: matches
                )
        })

        guard !protectedIndexes.isEmpty else {
            return Result(text: collapsedRewritten, rejectedProtectedRemoval: false)
        }

        let edits = replacementEdits(
            originalTokens: originalTokens,
            rewrittenTokens: outputTokens,
            matchedRewrittenIndexes: matches,
            protectedIndexes: protectedIndexes,
            text: collapsedRewritten
        )
        guard !edits.isEmpty else {
            log(
                "action=fallbackOriginal protected=\(debugList(protectedIndexes.map { originalTokens[$0].text }))"
            )
            return Result(text: original, rejectedProtectedRemoval: true)
        }

        logRepair(edits)

        return Result(
            text: apply(edits: edits, to: collapsedRewritten),
            rejectedProtectedRemoval: true
        )
    }

    private struct WordToken: Equatable {
        let text: String
        let normalized: String
        let range: Range<String.Index>
    }

    private struct ReplacementEdit {
        let range: Range<String.Index>
        let text: String
        let originalGap: String
        let replacedText: String
        let protectedTokens: [String]
    }

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

    private static func isProtectedToken(_ token: WordToken) -> Bool {
        token.normalized.hasSuffix(protectedSuffix)
    }

    private static func collapseAdjacentProtectedDuplicates(
        in text: String,
        tokens: [WordToken]
    ) -> String {
        let ranges = tokens.indices.dropFirst().compactMap { index -> Range<String.Index>? in
            let token = tokens[index]
            let previous = tokens[index - 1]
            guard token.normalized == previous.normalized, isProtectedToken(token) else {
                return nil
            }
            return token.range
        }

        return remove(ranges: ranges, from: text)
    }

    private static func remove(
        ranges: [Range<String.Index>],
        from text: String
    ) -> String {
        var repaired = text
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            let start = removalStart(for: range, in: repaired)
            let end = removalEnd(for: range, in: repaired)
            repaired.replaceSubrange(start..<end, with: replacementSpace(for: start..<end, in: repaired))
        }
        return repaired
    }

    private static func removalStart(
        for range: Range<String.Index>,
        in text: String
    ) -> String.Index {
        var index = range.lowerBound
        while index > text.startIndex {
            let previous = text.index(before: index)
            guard text[previous].isWhitespace else { break }
            index = previous
        }
        return index
    }

    private static func removalEnd(
        for range: Range<String.Index>,
        in text: String
    ) -> String.Index {
        var index = range.upperBound
        while index < text.endIndex {
            guard text[index].isWhitespace else { break }
            index = text.index(after: index)
        }
        return index
    }

    private static func replacementSpace(
        for range: Range<String.Index>,
        in text: String
    ) -> String {
        range.lowerBound > text.startIndex && range.upperBound < text.endIndex ? " " : ""
    }

    private static func isAdjacentDuplicateRemovalAllowed(
        at index: Int,
        originalTokens: [WordToken],
        matchedRewrittenIndexes: [Int: Int]
    ) -> Bool {
        let token = originalTokens[index]
        let previousDuplicateSurvived = index > originalTokens.startIndex
            && originalTokens[index - 1].normalized == token.normalized
            && matchedRewrittenIndexes[index - 1] != nil
        let nextDuplicateSurvived = index < originalTokens.index(before: originalTokens.endIndex)
            && originalTokens[index + 1].normalized == token.normalized
            && matchedRewrittenIndexes[index + 1] != nil
        return previousDuplicateSurvived || nextDuplicateSurvived
    }

    private static func replacementEdits(
        originalTokens: [WordToken],
        rewrittenTokens: [WordToken],
        matchedRewrittenIndexes: [Int: Int],
        protectedIndexes: Set<Int>,
        text: String
    ) -> [ReplacementEdit] {
        let matchedOriginalIndexes = matchedRewrittenIndexes.keys.sorted()
        var edits: [ReplacementEdit] = []
        var previousOriginalIndex: Int?
        var previousRewrittenIndex: Int?

        for nextOriginalIndex in matchedOriginalIndexes + [originalTokens.endIndex] {
            let gapStart = previousOriginalIndex.map { $0 + 1 } ?? originalTokens.startIndex
            let gapEnd = nextOriginalIndex
            if gapStart < gapEnd, protectedIndexes.contains(where: { gapStart <= $0 && $0 < gapEnd }) {
                let nextRewrittenIndex = matchedRewrittenIndexes[nextOriginalIndex]
                let rangeStart = previousRewrittenIndex.map { rewrittenTokens[$0].range.upperBound } ?? text.startIndex
                let rangeEnd = nextRewrittenIndex.map { rewrittenTokens[$0].range.lowerBound } ?? text.endIndex
                let originalGapTokens = Array(originalTokens[gapStart..<gapEnd])
                let replacedText = String(text[rangeStart..<rangeEnd])
                let protectedTokens = originalGapTokens
                    .indices
                    .filter { protectedIndexes.contains(gapStart + $0) }
                    .map { originalGapTokens[$0] }
                let restoredTokens = wordTokens(in: replacedText).isEmpty
                    ? protectedTokens
                    : originalGapTokens
                edits.append(ReplacementEdit(
                    range: rangeStart..<rangeEnd,
                    text: replacementText(
                        originalTokens: restoredTokens,
                        hasPreviousBoundary: previousRewrittenIndex != nil,
                        hasNextBoundary: nextRewrittenIndex != nil
                    ),
                    originalGap: originalGapTokens.map(\.text).joined(separator: " "),
                    replacedText: replacedText,
                    protectedTokens: protectedTokens.map(\.text)
                ))
            }

            if nextOriginalIndex < originalTokens.endIndex {
                previousOriginalIndex = nextOriginalIndex
                previousRewrittenIndex = matchedRewrittenIndexes[nextOriginalIndex]
            }
        }

        return edits
    }

    private static func replacementText(
        originalTokens: [WordToken],
        hasPreviousBoundary: Bool,
        hasNextBoundary: Bool
    ) -> String {
        let text = originalTokens.map(\.text).joined(separator: " ")
        switch (hasPreviousBoundary, hasNextBoundary) {
        case (true, true):
            return " " + text + " "
        case (true, false):
            return " " + text
        case (false, true):
            return text + " "
        case (false, false):
            return text
        }
    }

    private static func apply(edits: [ReplacementEdit], to text: String) -> String {
        var repaired = text
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            repaired.replaceSubrange(edit.range, with: edit.text)
        }
        return repaired
    }

    private static func logRepair(_ edits: [ReplacementEdit]) {
        #if DEBUG
        for edit in edits {
            NSLog(
                "[StyleRewriteRepair] protected=%@ replaced=\"%@\" restored=\"%@\" originalGap=\"%@\"",
                debugList(edit.protectedTokens),
                debugText(edit.replacedText),
                debugText(edit.text),
                debugText(edit.originalGap)
            )
        }
        #endif
    }

    private static func log(_ message: String) {
        #if DEBUG
        NSLog("[StyleRewriteRepair] %@", message)
        #endif
    }

    private static func debugList(_ values: [String]) -> String {
        "[" + values.map(debugText).joined(separator: ",") + "]"
    }

    private static func debugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
