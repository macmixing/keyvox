import Foundation

enum RepairMatching {
    static func matchOriginalTokens(
        _ originalTokens: [RepairWordToken],
        to rewrittenTokens: [RepairWordToken]
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

    static func containsWord(_ word: String, in normalizedText: String) -> Bool {
        let pattern = #"(?<![A-Za-z0-9])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![A-Za-z0-9])"#
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
            .firstMatch(
                in: normalizedText,
                options: [],
                range: NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)
            ) != nil
    }

    static func replacingMatches(
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
}
