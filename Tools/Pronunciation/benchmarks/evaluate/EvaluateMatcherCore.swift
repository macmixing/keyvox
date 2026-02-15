import Foundation

struct ReplacementScore {
    let text: Double
    let phonetic: Double
    let context: Double
    let final: Double
}

struct ReplacementScorer {
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

    func similarity(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.isEmpty ? 1 : 0 }
        if rhsChars.isEmpty { return 0 }

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

        let distance = previous[rhsChars.count]
        let maxLength = max(lhsChars.count, rhsChars.count)
        return max(0, 1 - (Double(distance) / Double(maxLength)))
    }

    private func contextScore(previousToken: String?, nextToken: String?) -> Double {
        var score = 0.45
        if let previousToken, !previousToken.isEmpty { score += 0.25 }
        if let nextToken, !nextToken.isEmpty { score += 0.25 }
        return min(score, 1.0)
    }
}

enum TextNormalization {
    static func normalizedPhrase(_ input: String) -> String {
        let folded = input.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let lower = folded.lowercased()
        let spaced = lower.replacingOccurrences(of: "[^a-z0-9']+", with: " ", options: .regularExpression)
        return spaced
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func normalizedToken(_ input: String) -> String {
        normalizedPhrase(input).replacingOccurrences(of: " ", with: "")
    }

    static func tokenized(_ input: String) -> [String] {
        let phrase = normalizedPhrase(input)
        guard !phrase.isEmpty else { return [] }
        return phrase.split(separator: " ").map(String.init)
    }
}

struct PhoneticEncoder {
    let lexicon: [String: String]

    func signature(for token: String) -> String {
        if let known = lexicon[token] {
            return known
        }
        return fallbackSignature(for: token)
    }

    private func fallbackSignature(for token: String) -> String {
        guard !token.isEmpty else { return "" }
        var output = ""
        var lastCode: Character?
        for char in token.lowercased() {
            guard let code = phoneticCode(for: char) else { continue }
            if output.isEmpty {
                output.append(code)
                lastCode = code
                continue
            }
            if code == "A" || code == lastCode { continue }
            output.append(code)
            lastCode = code
            if output.count >= 8 { break }
        }
        return output.isEmpty ? token : output
    }

    private func phoneticCode(for character: Character) -> Character? {
        switch character {
        case "a", "e", "i", "o", "u", "y":
            return "A"
        case "b", "p":
            return "B"
        case "c", "k", "q", "g":
            return "K"
        case "d", "t":
            return "T"
        case "f", "v":
            return "F"
        case "j":
            return "J"
        case "l":
            return "L"
        case "m", "n":
            return "N"
        case "r":
            return "R"
        case "s", "z", "x":
            return "S"
        case "h", "w":
            return nil
        case "0"..."9":
            return character
        default:
            return nil
        }
    }
}

struct CompiledEntry {
    let phrase: String
    let normalizedPhrase: String
    let tokens: [String]
    let phoneticPhrase: String
}

struct ProposedReplacement {
    let tokenStart: Int
    let tokenEndExclusive: Int
    let replacementTokens: [String]
    let score: Double
}

final class OfflineMatcher {
    private let encoder: PhoneticEncoder
    private let scorer = ReplacementScorer.balanced
    private let commonWords: Set<String>
    private var entriesByTokenCount: [Int: [CompiledEntry]] = [:]
    private var entriesByTokenCountAndPrefix: [Int: [Character: [CompiledEntry]]] = [:]

    init(lexicon: [String: String], commonWords: Set<String>) {
        self.encoder = PhoneticEncoder(lexicon: lexicon)
        self.commonWords = commonWords
    }

    func rebuild(entries: [String]) {
        var grouped: [Int: [CompiledEntry]] = [:]
        var groupedByPrefix: [Int: [Character: [CompiledEntry]]] = [:]
        for phrase in entries {
            let normalizedPhrase = TextNormalization.normalizedPhrase(phrase)
            guard !normalizedPhrase.isEmpty else { continue }
            let tokens = normalizedPhrase.split(separator: " ").map(String.init)
            guard !tokens.isEmpty, tokens.count <= 4 else { continue }
            let phoneticPhrase = tokens.map { encoder.signature(for: $0) }.joined(separator: " ")
            let compiled = CompiledEntry(
                phrase: phrase,
                normalizedPhrase: normalizedPhrase,
                tokens: tokens,
                phoneticPhrase: phoneticPhrase
            )
            grouped[tokens.count, default: []].append(compiled)
            if let first = tokens.first?.first {
                groupedByPrefix[tokens.count, default: [:]][first, default: []].append(compiled)
            }
        }
        entriesByTokenCount = grouped
        entriesByTokenCountAndPrefix = groupedByPrefix
    }

    func apply(to input: String) -> String {
        let tokens = TextNormalization.tokenized(input)
        guard !tokens.isEmpty, !entriesByTokenCount.isEmpty else {
            return TextNormalization.normalizedPhrase(input)
        }

        let phonetics = tokens.map { encoder.signature(for: $0) }
        var proposed: [ProposedReplacement] = []

        for start in tokens.indices {
            for tokenCount in 1...4 {
                let end = start + tokenCount
                guard end <= tokens.count else { continue }
                guard let allCandidates = entriesByTokenCount[tokenCount], !allCandidates.isEmpty else { continue }
                let candidates: [CompiledEntry]
                if let prefix = tokens[start].first,
                   let narrowed = entriesByTokenCountAndPrefix[tokenCount]?[prefix],
                   !narrowed.isEmpty {
                    candidates = narrowed
                } else {
                    candidates = allCandidates
                }

                let observedTokens = Array(tokens[start..<end])
                let observedNormalized = observedTokens.joined(separator: " ")
                let observedPhonetic = Array(phonetics[start..<end]).joined(separator: " ")

                var best: (CompiledEntry, ReplacementScore)?
                var secondBestScore = 0.0

                for candidate in candidates {
                    let base = scorer.score(
                        observedText: observedNormalized,
                        observedPhonetic: observedPhonetic,
                        candidateText: candidate.normalizedPhrase,
                        candidatePhonetic: candidate.phoneticPhrase,
                        previousToken: start > 0 ? tokens[start - 1] : nil,
                        nextToken: end < tokens.count ? tokens[end] : nil
                    )

                    let boosted = min(
                        1.0,
                        base.final + tokenAlignmentBoost(
                            observed: observedTokens,
                            observedPhonetics: Array(phonetics[start..<end]),
                            candidate: candidate
                        )
                    )

                    let score = ReplacementScore(
                        text: base.text,
                        phonetic: base.phonetic,
                        context: base.context,
                        final: boosted
                    )

                    if let currentBest = best {
                        if score.final > currentBest.1.final {
                            secondBestScore = currentBest.1.final
                            best = (candidate, score)
                        } else if score.final > secondBestScore {
                            secondBestScore = score.final
                        }
                    } else {
                        best = (candidate, score)
                    }
                }

                guard let winner = best else { continue }
                let observedPhrase = observedTokens.joined(separator: " ")
                let exact = observedPhrase == winner.0.normalizedPhrase

                if tokenCount == 1 && observedTokens[0].count < 3 && !exact {
                    continue
                }

                if winner.1.final < scorer.threshold(for: tokenCount) {
                    continue
                }

                if secondBestScore > 0 && (winner.1.final - secondBestScore) < scorer.ambiguityMargin {
                    continue
                }

                if tokenCount == 1,
                   commonWords.contains(observedTokens[0]),
                   winner.1.final < scorer.commonWordOverrideThreshold {
                    continue
                }

                if observedPhrase == winner.0.normalizedPhrase {
                    continue
                }

                proposed.append(
                    ProposedReplacement(
                        tokenStart: start,
                        tokenEndExclusive: end,
                        replacementTokens: winner.0.tokens,
                        score: winner.1.final
                    )
                )
            }
        }

        let selected = selectNonOverlapping(from: proposed)
        guard !selected.isEmpty else {
            return tokens.joined(separator: " ")
        }

        let byStart = Dictionary(uniqueKeysWithValues: selected.map { ($0.tokenStart, $0) })
        var output: [String] = []
        var index = 0
        while index < tokens.count {
            if let replacement = byStart[index] {
                output.append(contentsOf: replacement.replacementTokens)
                index = replacement.tokenEndExclusive
            } else {
                output.append(tokens[index])
                index += 1
            }
        }

        return output.joined(separator: " ")
    }

    private func selectNonOverlapping(from proposed: [ProposedReplacement]) -> [ProposedReplacement] {
        let sorted = proposed.sorted {
            if $0.score == $1.score {
                let lhsLen = $0.tokenEndExclusive - $0.tokenStart
                let rhsLen = $1.tokenEndExclusive - $1.tokenStart
                if lhsLen == rhsLen {
                    return $0.tokenStart < $1.tokenStart
                }
                return lhsLen > rhsLen
            }
            return $0.score > $1.score
        }

        var selected: [ProposedReplacement] = []
        for candidate in sorted {
            let overlaps = selected.contains { existing in
                candidate.tokenStart < existing.tokenEndExclusive && existing.tokenStart < candidate.tokenEndExclusive
            }
            if !overlaps {
                selected.append(candidate)
            }
        }
        return selected
    }

    private func tokenAlignmentBoost(observed: [String], observedPhonetics: [String], candidate: CompiledEntry) -> Double {
        guard observed.count == candidate.tokens.count, !observed.isEmpty else { return 0 }

        let candidatePhonetics = candidate.tokens.map { encoder.signature(for: $0) }
        var exactMatches = 0
        var strongMatches = 0
        var firstTokenExact = false

        for index in observed.indices {
            let observedToken = observed[index]
            let candidateToken = candidate.tokens[index]
            let textScore = scorer.similarity(lhs: observedToken, rhs: candidateToken)
            let phoneticScore = scorer.similarity(lhs: observedPhonetics[index], rhs: candidatePhonetics[index])
            let blended = (0.55 * textScore) + (0.45 * phoneticScore)

            if textScore == 1.0 {
                exactMatches += 1
                if index == 0 {
                    firstTokenExact = true
                }
            }

            if textScore >= 0.78 || phoneticScore >= 0.78 || blended >= 0.78 {
                strongMatches += 1
            }
        }

        if observed.count == 2, firstTokenExact {
            let textTail = scorer.similarity(lhs: observed[1], rhs: candidate.tokens[1])
            let phoneticTail = scorer.similarity(lhs: observedPhonetics[1], rhs: candidatePhonetics[1])
            if textTail >= 0.70 || phoneticTail >= 0.72 {
                return 0.12
            }
        }

        if firstTokenExact && strongMatches == observed.count { return 0.08 }
        if exactMatches >= 1 && strongMatches == observed.count { return 0.06 }
        if strongMatches == observed.count { return 0.04 }
        return 0
    }
}
