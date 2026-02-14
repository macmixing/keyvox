import Foundation

struct DictionaryMatchResult {
    let text: String
    let stats: DictionaryMatcher.DebugStats
}

@MainActor
final class DictionaryMatcher {
    struct DebugStats {
        var attempted: Int = 0
        var accepted: Int = 0
        var rejectedLowScore: Int = 0
        var rejectedAmbiguity: Int = 0
        var rejectedCommonWord: Int = 0
        var rejectedShortToken: Int = 0
        var rejectedOverlap: Int = 0

        static let empty = DebugStats()
    }

    private struct Token {
        let raw: String
        let normalized: String
        let range: NSRange
        let phonetic: String
    }

    private struct CompiledEntry {
        let phrase: String
        let normalizedPhrase: String
        let tokens: [String]
        let phoneticPhrase: String
    }

    private struct Candidate {
        let entry: CompiledEntry
        let score: ReplacementScore
    }

    private struct ProposedReplacement {
        let tokenStart: Int
        let tokenEndExclusive: Int
        let range: NSRange
        let replacement: String
        let score: Double
    }

    private let lexicon: PronunciationLexicon
    private let encoder: PhoneticEncoder
    private let scorer: ReplacementScorer

    private var entriesByTokenCount: [Int: [CompiledEntry]] = [:]

    init(
        lexicon: PronunciationLexicon,
        encoder: PhoneticEncoder,
        scorer: ReplacementScorer
    ) {
        self.lexicon = lexicon
        self.encoder = encoder
        self.scorer = scorer
    }

    convenience init() {
        self.init(
            lexicon: .shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
    }

    func rebuildIndex(entries: [DictionaryEntry]) {
        var grouped: [Int: [CompiledEntry]] = [:]

        for entry in entries {
            let normalizedPhrase = TextNormalization.normalizedPhrase(entry.phrase)
            guard !normalizedPhrase.isEmpty else { continue }

            let tokens = normalizedPhrase.split(separator: " ").map(String.init)
            guard !tokens.isEmpty, tokens.count <= 4 else { continue }

            let phoneticPhrase = encoder.phraseSignature(for: tokens, lexicon: lexicon)
            let compiled = CompiledEntry(
                phrase: entry.phrase,
                normalizedPhrase: normalizedPhrase,
                tokens: tokens,
                phoneticPhrase: phoneticPhrase
            )

            grouped[tokens.count, default: []].append(compiled)
        }

        entriesByTokenCount = grouped
    }

    func apply(to text: String) -> DictionaryMatchResult {
        guard !text.isEmpty else {
            return DictionaryMatchResult(text: "", stats: .empty)
        }

        guard !entriesByTokenCount.isEmpty else {
            return DictionaryMatchResult(text: text, stats: .empty)
        }

        let tokens = tokenize(text)
        guard !tokens.isEmpty else {
            return DictionaryMatchResult(text: text, stats: .empty)
        }

        var stats = DebugStats()
        var proposed: [ProposedReplacement] = []

        for start in tokens.indices {
            for tokenCount in 1...4 {
                let end = start + tokenCount
                guard end <= tokens.count else { continue }
                guard let candidates = entriesByTokenCount[tokenCount], !candidates.isEmpty else { continue }

                stats.attempted += 1

                let window = Array(tokens[start..<end])
                let observedNormalized = window.map(\.normalized).joined(separator: " ")
                let observedPhonetic = window.map(\.phonetic).joined(separator: " ")

                var best: Candidate?
                var secondBestScore = 0.0

                for candidate in candidates {
                    let baseScore = scorer.score(
                        observedText: observedNormalized,
                        observedPhonetic: observedPhonetic,
                        candidateText: candidate.normalizedPhrase,
                        candidatePhonetic: candidate.phoneticPhrase,
                        previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                        nextToken: end < tokens.count ? tokens[end].normalized : nil
                    )

                    let boostedFinalScore = min(
                        1.0,
                        baseScore.final + tokenAlignmentBoost(window: window, candidate: candidate)
                    )
                    let score = ReplacementScore(
                        text: baseScore.text,
                        phonetic: baseScore.phonetic,
                        context: baseScore.context,
                        final: boostedFinalScore
                    )

                    if let currentBest = best {
                        if score.final > currentBest.score.final {
                            secondBestScore = currentBest.score.final
                            best = Candidate(entry: candidate, score: score)
                        } else if score.final > secondBestScore {
                            secondBestScore = score.final
                        }
                    } else {
                        best = Candidate(entry: candidate, score: score)
                    }
                }

                guard let best else { continue }

                let exactMatch = observedNormalized == best.entry.normalizedPhrase

                if tokenCount == 1,
                   window[0].normalized.count < 3,
                   !exactMatch {
                    stats.rejectedShortToken += 1
                    continue
                }

                let threshold = scorer.threshold(for: tokenCount)
                guard best.score.final >= threshold else {
                    stats.rejectedLowScore += 1
                    continue
                }

                if secondBestScore > 0,
                   (best.score.final - secondBestScore) < scorer.ambiguityMargin {
                    stats.rejectedAmbiguity += 1
                    continue
                }

                if tokenCount == 1,
                   lexicon.isCommonWord(window[0].normalized),
                   best.score.final < scorer.commonWordOverrideThreshold {
                    stats.rejectedCommonWord += 1
                    continue
                }

                let range = combinedRange(from: window)
                let observedRaw = (text as NSString).substring(with: range)

                // Skip if replacement text is already identical.
                if observedRaw == best.entry.phrase {
                    continue
                }

                proposed.append(
                    ProposedReplacement(
                        tokenStart: start,
                        tokenEndExclusive: end,
                        range: range,
                        replacement: best.entry.phrase,
                        score: best.score.final
                    )
                )
            }
        }

        guard !proposed.isEmpty else {
            return DictionaryMatchResult(text: text, stats: stats)
        }

        let selected = selectNonOverlapping(proposed: proposed, rejectedOverlapCounter: &stats.rejectedOverlap)
        guard !selected.isEmpty else {
            return DictionaryMatchResult(text: text, stats: stats)
        }

        var output = text
        for item in selected.sorted(by: { $0.range.location > $1.range.location }) {
            guard let swiftRange = Range(item.range, in: output) else { continue }
            output.replaceSubrange(swiftRange, with: item.replacement)
            stats.accepted += 1
        }

        return DictionaryMatchResult(text: output, stats: stats)
    }

    private func selectNonOverlapping(
        proposed: [ProposedReplacement],
        rejectedOverlapCounter: inout Int
    ) -> [ProposedReplacement] {
        let sorted = proposed.sorted {
            if $0.score == $1.score {
                let lhsLength = $0.tokenEndExclusive - $0.tokenStart
                let rhsLength = $1.tokenEndExclusive - $1.tokenStart
                if lhsLength == rhsLength {
                    return $0.tokenStart < $1.tokenStart
                }
                return lhsLength > rhsLength
            }
            return $0.score > $1.score
        }

        var selected: [ProposedReplacement] = []
        for candidate in sorted {
            let overlaps = selected.contains { existing in
                candidate.tokenStart < existing.tokenEndExclusive && existing.tokenStart < candidate.tokenEndExclusive
            }

            if overlaps {
                rejectedOverlapCounter += 1
                continue
            }

            selected.append(candidate)
        }

        return selected
    }

    private func tokenize(_ text: String) -> [Token] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        guard let regex = try? NSRegularExpression(pattern: "\\b[\\p{L}\\p{N}']+\\b") else {
            return []
        }

        return regex
            .matches(in: text, options: [], range: fullRange)
            .compactMap { match in
                let raw = nsText.substring(with: match.range)
                let normalized = TextNormalization.normalizedToken(raw)
                guard !normalized.isEmpty else { return nil }

                return Token(
                    raw: raw,
                    normalized: normalized,
                    range: match.range,
                    phonetic: encoder.signature(for: normalized, lexicon: lexicon)
                )
            }
    }

    private func combinedRange(from tokens: [Token]) -> NSRange {
        guard let first = tokens.first, let last = tokens.last else {
            return NSRange(location: 0, length: 0)
        }

        let start = first.range.location
        let end = last.range.location + last.range.length
        return NSRange(location: start, length: end - start)
    }

    private func tokenAlignmentBoost(window: [Token], candidate: CompiledEntry) -> Double {
        guard window.count == candidate.tokens.count else { return 0 }
        guard !window.isEmpty else { return 0 }

        let candidatePhonetics = candidate.tokens.map { encoder.signature(for: $0, lexicon: lexicon) }
        var exactMatches = 0
        var strongMatches = 0
        var firstTokenExact = false

        for index in window.indices {
            let observedToken = window[index]
            let candidateToken = candidate.tokens[index]

            let textScore = scorer.similarity(lhs: observedToken.normalized, rhs: candidateToken)
            let phoneticScore = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetics[index])
            let blendedScore = (0.55 * textScore) + (0.45 * phoneticScore)

            if textScore == 1.0 {
                exactMatches += 1
                if index == 0 {
                    firstTokenExact = true
                }
            }

            if textScore >= 0.78 || phoneticScore >= 0.78 || blendedScore >= 0.78 {
                strongMatches += 1
            }
        }

        // Name-like two-token phrases: "Dom Espicito" -> "Dom Esposito"
        if window.count == 2, firstTokenExact {
            let textTail = scorer.similarity(lhs: window[1].normalized, rhs: candidate.tokens[1])
            let phoneticTail = scorer.similarity(lhs: window[1].phonetic, rhs: candidatePhonetics[1])
            if textTail >= 0.70 || phoneticTail >= 0.72 {
                return 0.12
            }
        }

        if firstTokenExact && strongMatches == window.count {
            return 0.08
        }

        if exactMatches >= 1 && strongMatches == window.count {
            return 0.06
        }

        if strongMatches == window.count {
            return 0.04
        }

        return 0
    }
}

enum TextNormalization {
    static func normalizedPhrase(_ input: String) -> String {
        let folded = input
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        let lower = folded.lowercased()
        let spaced = lower.replacingOccurrences(of: "[^a-z0-9']+", with: " ", options: .regularExpression)
        return spaced
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func normalizedToken(_ input: String) -> String {
        let phrase = normalizedPhrase(input)
        return phrase.replacingOccurrences(of: " ", with: "")
    }
}
