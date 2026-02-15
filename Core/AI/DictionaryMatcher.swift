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
        let replacementSuffix: String
    }

    private struct ProposedReplacement {
        let tokenStart: Int
        let tokenEndExclusive: Int
        let range: NSRange
        let replacement: String
        let score: Double
    }

    private struct JoinedObservedForm {
        let normalized: String
        let singularizedSecondToken: Bool
        let replacementSuffix: String
    }

    private let lexicon: PronunciationLexiconProviding
    private let encoder: PhoneticEncoder
    private let scorer: ReplacementScorer
    private let splitJoinMinimumScore = 0.92
    private let minimumSplitTokenLength = 3
    private let possessiveStemScoreBoost = 0.06

    private var entriesByTokenCount: [Int: [CompiledEntry]] = [:]

    init(
        lexicon: PronunciationLexiconProviding,
        encoder: PhoneticEncoder,
        scorer: ReplacementScorer
    ) {
        self.lexicon = lexicon
        self.encoder = encoder
        self.scorer = scorer
    }

    convenience init() {
        self.init(
            lexicon: PronunciationLexicon.shared,
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
                let observedForms = observedFormsForWindow(
                    tokenCount: tokenCount,
                    observedNormalized: observedNormalized,
                    observedPhonetic: observedPhonetic
                )

                var best: Candidate?
                var secondBestScore = 0.0

                for candidate in candidates {
                    for form in observedForms {
                        let baseScore = scorer.score(
                            observedText: form.normalized,
                            observedPhonetic: form.phonetic,
                            candidateText: candidate.normalizedPhrase,
                            candidatePhonetic: candidate.phoneticPhrase,
                            previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                            nextToken: end < tokens.count ? tokens[end].normalized : nil
                        )

                        let boostedFinalScore = min(
                            1.0,
                            baseScore.final
                                + tokenAlignmentBoost(window: window, candidate: candidate)
                                + possessiveBonus(for: form.replacementSuffix)
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
                                best = Candidate(entry: candidate, score: score, replacementSuffix: form.replacementSuffix)
                            } else if score.final > secondBestScore {
                                secondBestScore = score.final
                            }
                        } else {
                            best = Candidate(entry: candidate, score: score, replacementSuffix: form.replacementSuffix)
                        }
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
                let effectiveThreshold: Double
                if tokenCount == 1, best.replacementSuffix == "'s" {
                    // Possessive tails add noise; allow a slightly lower gate while keeping
                    // common-word and ambiguity guards intact.
                    effectiveThreshold = max(0.82, threshold - 0.08)
                } else {
                    effectiveThreshold = threshold
                }

                guard best.score.final >= effectiveThreshold else {
                    stats.rejectedLowScore += 1
                    continue
                }

                if secondBestScore > 0,
                   (best.score.final - secondBestScore) < scorer.ambiguityMargin {
                    stats.rejectedAmbiguity += 1
                    continue
                }

                if tokenCount == 1,
                   lexicon.isCommonWord(baseTokenForCommonWordGuard(window[0].normalized)),
                   best.score.final < scorer.commonWordOverrideThreshold {
                    stats.rejectedCommonWord += 1
                    continue
                }

                let range = combinedRange(from: window)
                let observedRaw = (text as NSString).substring(with: range)
                let replacementText = best.entry.phrase + best.replacementSuffix

                // Skip if replacement text is already identical.
                if observedRaw == replacementText {
                    continue
                }

                proposed.append(
                    ProposedReplacement(
                        tokenStart: start,
                        tokenEndExclusive: end,
                        range: range,
                        replacement: replacementText,
                        score: best.score.final
                    )
                )
            }

            if let splitReplacement = proposeSplitJoinReplacement(
                start: start,
                tokens: tokens,
                text: text,
                stats: &stats
            ) {
                proposed.append(splitReplacement)
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

    private func proposeSplitJoinReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        let end = start + 2
        guard end <= tokens.count else { return nil }
        guard let oneTokenCandidates = entriesByTokenCount[1], !oneTokenCandidates.isEmpty else { return nil }

        stats.attempted += 1

        let window = Array(tokens[start..<end])
        guard window[0].normalized.count >= minimumSplitTokenLength,
              window[1].normalized.count >= minimumSplitTokenLength else {
            stats.rejectedShortToken += 1
            return nil
        }

        let forms = splitJoinForms(from: window)
        guard !forms.isEmpty else {
            stats.rejectedLowScore += 1
            return nil
        }

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in oneTokenCandidates {
            let candidateToken = candidate.tokens[0]
            let candidateIsCommonWord = lexicon.isCommonWord(candidateToken)

            for form in forms {
                // Only non-common dictionary entries can use plural-tail singularization.
                if form.singularizedSecondToken && candidateIsCommonWord {
                    continue
                }

                let observedPhonetic = encoder.signature(for: form.normalized, lexicon: lexicon)
                let score = scorer.score(
                    observedText: form.normalized,
                    observedPhonetic: observedPhonetic,
                    candidateText: candidate.normalizedPhrase,
                    candidatePhonetic: candidate.phoneticPhrase,
                    previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                    nextToken: end < tokens.count ? tokens[end].normalized : nil
                )
                let adjustedScore = ReplacementScore(
                    text: score.text,
                    phonetic: score.phonetic,
                    context: score.context,
                    final: min(1.0, score.final + possessiveBonus(for: form.replacementSuffix))
                )

                if let currentBest = best {
                    if adjustedScore.final > currentBest.score.final {
                        secondBestScore = currentBest.score.final
                        best = Candidate(
                            entry: candidate,
                            score: adjustedScore,
                            replacementSuffix: form.replacementSuffix
                        )
                    } else if adjustedScore.final > secondBestScore {
                        secondBestScore = adjustedScore.final
                    }
                } else {
                    best = Candidate(
                        entry: candidate,
                        score: adjustedScore,
                        replacementSuffix: form.replacementSuffix
                    )
                }
            }
        }

        guard let best else {
            stats.rejectedLowScore += 1
            return nil
        }

        let threshold = max(scorer.threshold(for: 2), splitJoinMinimumScore)
        guard best.score.final >= threshold else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
            return nil
        }

        if lexicon.isCommonWord(best.entry.tokens[0]),
           best.score.final < scorer.commonWordOverrideThreshold {
            stats.rejectedCommonWord += 1
            return nil
        }

        let range = combinedRange(from: window)
        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase + best.replacementSuffix
        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: end,
            range: range,
            replacement: replacementText,
            score: best.score.final
        )
    }

    private func splitJoinForms(from window: [Token]) -> [JoinedObservedForm] {
        guard window.count == 2 else { return [] }

        let first = window[0].normalized
        let second = window[1].normalized

        var forms: [JoinedObservedForm] = []
        var seen = Set<String>()

        let direct = first + second
        if !direct.isEmpty, seen.insert(direct).inserted {
            forms.append(
                JoinedObservedForm(
                    normalized: direct,
                    singularizedSecondToken: false,
                    replacementSuffix: ""
                )
            )
        }

        if second.hasSuffix("'s"), second.count > minimumSplitTokenLength {
            let stem = String(second.dropLast(2))
            if stem.count >= minimumSplitTokenLength {
                let possessiveJoin = first + stem
                if !possessiveJoin.isEmpty, seen.insert(possessiveJoin).inserted {
                    forms.append(
                        JoinedObservedForm(
                            normalized: possessiveJoin,
                            singularizedSecondToken: false,
                            replacementSuffix: "'s"
                        )
                    )
                }
            }
        }

        if second.hasSuffix("s"),
           !second.hasSuffix("'s"),
           !second.hasSuffix("s'"),
           second.count > minimumSplitTokenLength {
            let singularSecond = String(second.dropLast())
            if singularSecond.count >= minimumSplitTokenLength {
                let singularized = first + singularSecond
                if !singularized.isEmpty, seen.insert(singularized).inserted {
                    forms.append(
                        JoinedObservedForm(
                            normalized: singularized,
                            singularizedSecondToken: true,
                            replacementSuffix: ""
                        )
                    )
                }
            }
        }

        return forms
    }

    private func observedFormsForWindow(
        tokenCount: Int,
        observedNormalized: String,
        observedPhonetic: String
    ) -> [(normalized: String, phonetic: String, replacementSuffix: String)] {
        guard tokenCount == 1 else {
            return [(normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")]
        }

        var forms: [(normalized: String, phonetic: String, replacementSuffix: String)] = [
            (normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")
        ]
        var seen = Set<String>()
        seen.insert("\(observedNormalized)|")

        if observedNormalized.hasSuffix("'s"), observedNormalized.count > 3 {
            let stem = String(observedNormalized.dropLast(2))
            if stem.count >= 3 {
                let key = "\(stem)|'s"
                if seen.insert(key).inserted {
                    forms.append((
                        normalized: stem,
                        phonetic: encoder.signature(for: stem, lexicon: lexicon),
                        replacementSuffix: "'s"
                    ))
                }
            }
        }

        return forms
    }

    private func baseTokenForCommonWordGuard(_ token: String) -> String {
        if token.hasSuffix("'s"), token.count > 3 {
            return String(token.dropLast(2))
        }

        return token
    }

    private func possessiveBonus(for replacementSuffix: String) -> Double {
        replacementSuffix == "'s" ? possessiveStemScoreBoost : 0
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
