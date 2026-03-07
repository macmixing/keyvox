import Foundation

public struct ReplacementScore {
    let text: Double
    let phonetic: Double
    let context: Double
    let final: Double
}

public struct ReplacementScorer {
    static let balanced = ReplacementScorer(
        textWeight: 0.50,
        phoneticWeight: 0.40,
        contextWeight: 0.10,
        ambiguityMargin: 0.05,
        commonWordOverrideThreshold: 0.94
    )

    let textWeight: Double
    let phoneticWeight: Double
    let contextWeight: Double
    let ambiguityMargin: Double
    let commonWordOverrideThreshold: Double

    func threshold(for tokenCount: Int) -> Double {
        switch tokenCount {
        case 1:
            return 0.90
        case 2:
            return 0.80
        default:
            return 0.78
        }
    }

    func score(
        observedText: String,
        observedPhonetic: String,
        candidateText: String,
        candidatePhonetic: String,
        previousToken: String?,
        nextToken: String?
    ) -> ReplacementScore {
        let textScore = similarity(lhs: observedText, rhs: candidateText)
        let phoneticScore = similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        let contextScore = contextScore(previousToken: previousToken, nextToken: nextToken)

        let finalScore = (textWeight * textScore)
            + (phoneticWeight * phoneticScore)
            + (contextWeight * contextScore)

        return ReplacementScore(
            text: textScore,
            phonetic: phoneticScore,
            context: contextScore,
            final: finalScore
        )
    }

    private func contextScore(previousToken: String?, nextToken: String?) -> Double {
        var score = 0.45

        if let previousToken, !previousToken.isEmpty {
            score += 0.25
        }

        if let nextToken, !nextToken.isEmpty {
            score += 0.25
        }

        return min(score, 1.0)
    }

    func similarity(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }

        let distance = levenshtein(lhs, rhs)
        let maxLength = max(lhs.count, rhs.count)
        guard maxLength > 0 else { return 0 }

        return max(0, 1 - (Double(distance) / Double(maxLength)))
    }

    private func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + substitutionCost
                )
            }
            swap(&previous, &current)
        }

        return previous[rhsChars.count]
    }
}
