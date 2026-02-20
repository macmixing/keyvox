import Foundation

extension DictionaryMatcher {
    func proposeMiddleInitialThreeTokenReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        let end = start + 3
        guard end <= tokens.count else { return nil }
        guard let twoTokenCandidates = entriesByTokenCount[2], !twoTokenCandidates.isEmpty else { return nil }

        let window = Array(tokens[start..<end])
        let observedFirst = window[0].normalized
        let observedMiddle = window[1].normalized
        let observedLastRaw = window[2].normalized

        guard observedMiddle.count == 1 else { return nil }
        stats.attempted += 1

        let possessive = normalizedPossessiveStem(for: observedLastRaw)
        let observedLastStem = possessive.stem
        guard observedLastStem.count >= 4 else {
            stats.rejectedLowScore += 1
            return nil
        }

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in twoTokenCandidates {
            guard candidate.tokens.count == 2 else { continue }
            let candidateFirst = candidate.tokens[0]
            let candidateLast = candidate.tokens[1]

            guard observedFirst == candidateFirst else { continue }
            guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateLast)) else { continue }

            let observedLastPhonetic = encoder.signature(for: observedLastStem, lexicon: lexicon)
            let candidateLastPhonetic = encoder.signature(for: candidateLast, lexicon: lexicon)
            let lastTextSimilarity = scorer.similarity(lhs: observedLastStem, rhs: candidateLast)
            let lastPhoneticSimilarity = scorer.similarity(lhs: observedLastPhonetic, rhs: candidateLastPhonetic)
            let requiresPossessiveRecovery = possessive.suffix == "'s"
            let minimumTailTextSimilarity = requiresPossessiveRecovery ? 0.34 : 0.56
            let minimumTailPhoneticSimilarity = requiresPossessiveRecovery ? 0.38 : 0.60
            guard lastTextSimilarity >= minimumTailTextSimilarity || lastPhoneticSimilarity >= minimumTailPhoneticSimilarity else {
                continue
            }

            let observedNormalized = "\(observedFirst) \(observedLastStem)"
            let observedPhonetic = encoder.phraseSignature(for: [observedFirst, observedLastStem], lexicon: lexicon)
            let baseScore = scorer.score(
                observedText: observedNormalized,
                observedPhonetic: observedPhonetic,
                candidateText: candidate.normalizedPhrase,
                candidatePhonetic: candidate.phoneticPhrase,
                previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                nextToken: end < tokens.count ? tokens[end].normalized : nil
            )

            let anchorBonus = 0.10
            let tailBonus = (lastTextSimilarity >= 0.68 || lastPhoneticSimilarity >= 0.72) ? 0.08 : 0.04
            let score = ReplacementScore(
                text: baseScore.text,
                phonetic: baseScore.phonetic,
                context: baseScore.context,
                final: min(1.0, baseScore.final + anchorBonus + tailBonus + possessiveBonus(for: possessive.suffix))
            )

            let replacementSuffix = resolvedPossessiveSuffix(basePhrase: candidate.phrase, desiredSuffix: possessive.suffix)
            if let currentBest = best {
                if score.final > currentBest.score.final {
                    secondBestScore = currentBest.score.final
                    best = Candidate(entry: candidate, score: score, replacementSuffix: replacementSuffix)
                } else if score.final > secondBestScore {
                    secondBestScore = score.final
                }
            } else {
                best = Candidate(entry: candidate, score: score, replacementSuffix: replacementSuffix)
            }
        }

        guard let best else {
            stats.rejectedLowScore += 1
            return nil
        }

        guard best.score.final >= 0.58 else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
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

    func proposeCompressedTailThreeTokenReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        let end = start + 3
        guard end <= tokens.count else { return nil }
        guard let twoTokenCandidates = entriesByTokenCount[2], !twoTokenCandidates.isEmpty else { return nil }

        let window = Array(tokens[start..<end])
        let observedFirst = window[0].normalized
        let observedMid = window[1].normalized
        let observedTail = window[2].normalized

        guard observedMid.count >= 3, observedTail.count >= 2 else { return nil }
        stats.attempted += 1

        let observedCombined = observedMid + observedTail
        let observedCombinedPhonetic = encoder.signature(for: observedCombined, lexicon: lexicon)

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in twoTokenCandidates {
            guard candidate.tokens.count == 2 else { continue }
            let candidateFirst = candidate.tokens[0]
            let candidateSecond = candidate.tokens[1]
            guard candidateSecond.count >= observedTail.count else { continue }

            let firstTextSimilarity = scorer.similarity(lhs: observedFirst, rhs: candidateFirst)
            let firstPhoneticSimilarity = scorer.similarity(
                lhs: window[0].phonetic,
                rhs: encoder.signature(for: candidateFirst, lexicon: lexicon)
            )
            guard firstTextSimilarity >= 0.20 || firstPhoneticSimilarity >= 0.42 else { continue }

            let combinedTextSimilarity = scorer.similarity(lhs: observedCombined, rhs: candidateSecond)
            let combinedPhoneticSimilarity = scorer.similarity(
                lhs: observedCombinedPhonetic,
                rhs: encoder.signature(for: candidateSecond, lexicon: lexicon)
            )
            guard combinedTextSimilarity >= 0.66 || combinedPhoneticSimilarity >= 0.68 else { continue }

            let candidateTail = String(candidateSecond.suffix(observedTail.count))
            let tailSimilarity = scorer.similarity(lhs: observedTail, rhs: candidateTail)
            guard tailSimilarity >= 0.66 else { continue }

            let observedNormalized = "\(observedFirst) \(observedCombined)"
            let observedPhonetic = "\(window[0].phonetic) \(observedCombinedPhonetic)"
            let baseScore = scorer.score(
                observedText: observedNormalized,
                observedPhonetic: observedPhonetic,
                candidateText: candidate.normalizedPhrase,
                candidatePhonetic: candidate.phoneticPhrase,
                previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                nextToken: end < tokens.count ? tokens[end].normalized : nil
            )

            let bonus = 0.10 + ((combinedTextSimilarity >= 0.76 || combinedPhoneticSimilarity >= 0.78) ? 0.08 : 0.04)
            let score = ReplacementScore(
                text: baseScore.text,
                phonetic: baseScore.phonetic,
                context: baseScore.context,
                final: min(1.0, baseScore.final + bonus)
            )

            if let currentBest = best {
                if score.final > currentBest.score.final {
                    secondBestScore = currentBest.score.final
                    best = Candidate(entry: candidate, score: score, replacementSuffix: "")
                } else if score.final > secondBestScore {
                    secondBestScore = score.final
                }
            } else {
                best = Candidate(entry: candidate, score: score, replacementSuffix: "")
            }
        }

        guard let best else {
            stats.rejectedLowScore += 1
            return nil
        }

        guard best.score.final >= 0.62 else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
            return nil
        }

        let range = combinedRange(from: window)
        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase
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

    func proposeMergedTokenReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        guard start < tokens.count else { return nil }
        let observed = tokens[start]
        guard observed.normalized.count >= minimumSplitTokenLength else { return nil }

        stats.attempted += 1

        var best: Candidate?
        var secondBestScore = 0.0

        for tokenCount in 2...4 {
            guard let candidates = entriesByTokenCount[tokenCount], !candidates.isEmpty else { continue }
            for candidate in candidates {
                guard let tail = candidate.tokens.last else { continue }
                guard observed.normalized.count > tail.count, observed.normalized.hasSuffix(tail) else { continue }

                let mergedCandidate = candidate.tokens.joined()
                let mergedCandidatePhonetic = encoder.signature(for: mergedCandidate, lexicon: lexicon)
                let baseScore = scorer.score(
                    observedText: observed.normalized,
                    observedPhonetic: observed.phonetic,
                    candidateText: mergedCandidate,
                    candidatePhonetic: mergedCandidatePhonetic,
                    previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                    nextToken: start + 1 < tokens.count ? tokens[start + 1].normalized : nil
                )

                let observedHead = String(observed.normalized.dropLast(tail.count))
                let candidateHead = String(mergedCandidate.dropLast(tail.count))
                let observedHeadPhonetic = encoder.signature(for: observedHead, lexicon: lexicon)
                let candidateHeadPhonetic = encoder.signature(for: candidateHead, lexicon: lexicon)
                let headTextSimilarity = scorer.similarity(lhs: observedHead, rhs: candidateHead)
                let headPhoneticSimilarity = scorer.similarity(lhs: observedHeadPhonetic, rhs: candidateHeadPhonetic)

                // Keep this path conservative: only allow merged-token expansion
                // when the non-tail prefix is still reasonably similar.
                guard max(headTextSimilarity, headPhoneticSimilarity) >= 0.40 else { continue }

                let tailExactBonus: Double
                if observed.normalized == mergedCandidate {
                    tailExactBonus = 0.10
                } else if observedHead.count <= 3 {
                    // Allow abbreviated merged heads like "mr" -> "mister" when
                    // the trailing token anchor matches exactly.
                    tailExactBonus = 0.14
                } else {
                    tailExactBonus = 0.06
                }
                let score = ReplacementScore(
                    text: baseScore.text,
                    phonetic: baseScore.phonetic,
                    context: baseScore.context,
                    final: min(1.0, baseScore.final + tailExactBonus)
                )

                if let currentBest = best {
                    if score.final > currentBest.score.final {
                        secondBestScore = currentBest.score.final
                        best = Candidate(entry: candidate, score: score, replacementSuffix: "")
                    } else if score.final > secondBestScore {
                        secondBestScore = score.final
                    }
                } else {
                    best = Candidate(entry: candidate, score: score, replacementSuffix: "")
                }
            }
        }

        guard let best else {
            return nil
        }

        let threshold = 0.72
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

        let range = observed.range
        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase
        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: start + 1,
            range: range,
            replacement: replacementText,
            score: best.score.final
        )
    }

    func proposeStandardReplacement(
        start: Int,
        tokenCount: Int,
        tokens: [Token],
        text: String,
        candidates: [CompiledEntry],
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        stats.attempted += 1

        let end = start + tokenCount
        let window = Array(tokens[start..<end])
        let observedNormalized = window.map(\.normalized).joined(separator: " ")
        let observedPhonetic = window.map(\.phonetic).joined(separator: " ")
        let observedForms = observedFormsForWindow(
            tokenCount: tokenCount,
            window: window,
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

                let fallbackPhoneticSimilarity = stylizedFallbackPhoneticSimilarity(
                    tokenCount: tokenCount,
                    observedNormalized: form.normalized,
                    observedPhonetic: form.phonetic,
                    candidate: candidate
                )
                let allowStylizedFallbackBySurface =
                    tokenCount != 1
                    || !isStylizedSingleTokenEntry(candidate)
                    || allowStylizedFallbackForCommonObservedToken(
                        token: window[0],
                        tokenIndex: start,
                        totalTokens: tokens.count
                    )
                let gatedFallbackPhoneticSimilarity =
                    allowStylizedFallbackBySurface ? fallbackPhoneticSimilarity : 0
                let phoneticDelta = max(0, gatedFallbackPhoneticSimilarity - baseScore.phonetic)
                let adjustedBaseFinal = min(1.0, baseScore.final + (scorer.phoneticWeight * phoneticDelta))
                let adjustedPhoneticScore = max(baseScore.phonetic, gatedFallbackPhoneticSimilarity)

                let boostedFinalScore = min(
                    1.0,
                    adjustedBaseFinal
                        + tokenAlignmentBoost(window: window, candidate: candidate)
                        + possessiveBonus(for: form.replacementSuffix)
                )
                let score = ReplacementScore(
                    text: baseScore.text,
                    phonetic: adjustedPhoneticScore,
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

        guard let best else { return nil }

        let exactMatch = observedNormalized == best.entry.normalizedPhrase

        if tokenCount == 1,
           window[0].normalized.count < 3,
           !exactMatch {
            stats.rejectedShortToken += 1
            return nil
        }

        let threshold = scorer.threshold(for: tokenCount)
        var effectiveThreshold: Double
        if tokenCount == 1, best.replacementSuffix == "'s" {
            // Possessive tails add noise; allow a slightly lower gate while keeping
            // common-word and ambiguity guards intact.
            effectiveThreshold = max(0.82, threshold - 0.08)
        } else if tokenCount == 2, best.replacementSuffix == "'s" {
            // Two-token possessive near-misses can lose apostrophes in Whisper output.
            // Keep this tighter than single-token possessives but allow a modest lift.
            effectiveThreshold = max(0.70, threshold - 0.10)
        } else {
            effectiveThreshold = threshold
        }

        if tokenCount == 1 {
            let observedToken = window[0]
            let candidateToken = best.entry.tokens[0]
            let candidatePhonetic = encoder.signature(for: candidateToken, lexicon: lexicon)
            let textSimilarity = scorer.similarity(lhs: observedToken.normalized, rhs: candidateToken)
            let phoneticSimilarity = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetic)
            let isCommonWord = lexicon.isCommonWord(baseTokenForCommonWordGuard(observedToken.normalized))
            let stylizedSingleTokenEntry = isStylizedSingleTokenEntry(best.entry)
            let allowStylizedFallbackBySurface =
                allowStylizedFallbackForCommonObservedToken(
                    token: observedToken,
                    tokenIndex: start,
                    totalTokens: tokens.count
                )
            if stylizedSingleTokenEntry,
               !allowStylizedFallbackBySurface,
               textSimilarity < 0.82 {
                stats.rejectedLowScore += 1
                return nil
            }

            if stylizedSingleTokenEntry,
               observedToken.normalized.count >= 4,
               candidateToken.count >= 5 {
                if hasStrongStylizedTextEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    textSimilarity: textSimilarity
                ) {
                    // Runtime lexicon pronunciations can disagree on letter-level
                    // edits (e.g. one-character brand near-misses). If stylized
                    // text evidence is very strong, avoid over-penalizing phonetics.
                    effectiveThreshold = min(effectiveThreshold, 0.50)
                } else if textSimilarity >= 0.82 {
                    // Runtime lexicon coverage can vary; keep stylized single-token
                    // brand corrections resilient when text evidence is strong.
                    effectiveThreshold = min(effectiveThreshold, 0.72)
                } else if hasStrongStylizedFallbackPhoneticEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    observedPhonetic: observedToken.phonetic,
                    candidatePhonetic: candidatePhonetic,
                    textSimilarity: textSimilarity
                ), allowStylizedFallbackBySurface {
                    // Runtime lexicon phonemes for proper nouns can be sparse or absent.
                    // If fallback grapheme-phonetic evidence is very strong, permit a
                    // lower gate for stylized dictionary terms.
                    effectiveThreshold = min(effectiveThreshold, 0.60)
                } else if hasModerateStylizedFallbackPhoneticEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    observedPhonetic: observedToken.phonetic,
                    candidatePhonetic: candidatePhonetic,
                    textSimilarity: textSimilarity
                ), allowStylizedFallbackBySurface {
                    // Allow an additional conservative lane for all-caps/near-miss
                    // stylized tokens that preserve start anchoring and fallback shape.
                    effectiveThreshold = min(effectiveThreshold, 0.55)
                }
            }

            // Generic hardening for proper-noun-like single tokens when hinting is absent:
            // require longer non-common tokens plus strong text/phonetic agreement.
            if !isCommonWord,
               observedToken.normalized.count >= 5,
               candidateToken.count >= 5,
               max(textSimilarity, phoneticSimilarity) >= 0.80,
               ((0.6 * textSimilarity) + (0.4 * phoneticSimilarity)) >= 0.74 {
                effectiveThreshold = min(effectiveThreshold, 0.78)
            }
        } else if tokenCount == 2,
                  best.entry.tokens.count == 2 {
            if hasStrongAnchoredTwoTokenEvidence(window: window, candidate: best.entry) {
                // Runtime pronunciations for proper nouns can be sparse. When the first
                // token anchors exactly and the second token is strongly similar, allow
                // the match through a slightly lower gate.
                effectiveThreshold = min(effectiveThreshold, 0.72)
            } else if hasModerateAnchoredTwoTokenEvidence(window: window, candidate: best.entry) {
                // Some near-miss surname variants are close in spelling shape but can
                // diverge in runtime lexicon phonetics. Keep this fallback conservative
                // with exact first-token anchoring and non-common long-tail requirements.
                effectiveThreshold = min(effectiveThreshold, 0.55)
            }
        }

        guard best.score.final >= effectiveThreshold else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
            return nil
        }

        if tokenCount == 1,
           lexicon.isCommonWord(baseTokenForCommonWordGuard(window[0].normalized)) {
            var stylizedBrandBypass =
                isStylizedSingleTokenEntry(best.entry)
                && best.score.final >= 0.82
            if !stylizedBrandBypass,
               isStylizedSingleTokenEntry(best.entry),
               allowStylizedFallbackForCommonObservedToken(
                   token: window[0],
                   tokenIndex: start,
                   totalTokens: tokens.count
               ),
               let candidateToken = best.entry.tokens.first {
                let textSimilarity = scorer.similarity(lhs: window[0].normalized, rhs: candidateToken)
                let candidatePhonetic = encoder.signature(for: candidateToken, lexicon: lexicon)
                if hasStrongStylizedFallbackPhoneticEvidence(
                    observed: window[0].normalized,
                    candidate: candidateToken,
                    observedPhonetic: window[0].phonetic,
                    candidatePhonetic: candidatePhonetic,
                    textSimilarity: textSimilarity
                ), best.score.final >= 0.58 {
                    stylizedBrandBypass = true
                }
            }
            if !stylizedBrandBypass,
               best.score.final < scorer.commonWordOverrideThreshold {
                stats.rejectedCommonWord += 1
                return nil
            }
        }

        var tokenEndExclusive = end
        var range = combinedRange(from: window)
        if shouldConsumeSplitTailToken(window: window, candidate: best.entry, nextToken: end < tokens.count ? tokens[end] : nil) {
            tokenEndExclusive = end + 1
            range = combinedRange(from: Array(tokens[start..<tokenEndExclusive]))
        }

        var replacementSuffix = best.replacementSuffix
        if replacementSuffix.isEmpty,
           tokenCount == 1,
           isStylizedSingleTokenEntry(best.entry),
           let candidateToken = best.entry.tokens.first {
            let nextToken = end < tokens.count ? tokens[end] : nil
            if shouldInferPossessiveSuffix(
                observed: window[0].normalized,
                observedPhonetic: window[0].phonetic,
                candidate: candidateToken,
                nextToken: nextToken
            ) {
                replacementSuffix = "'s"
            }
        }

        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase + replacementSuffix

        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: tokenEndExclusive,
            range: range,
            replacement: replacementText,
            score: best.score.final
        )
    }

    private func shouldConsumeSplitTailToken(
        window: [Token],
        candidate: CompiledEntry,
        nextToken: Token?
    ) -> Bool {
        guard window.count == candidate.tokens.count, window.count > 1 else { return false }
        guard let nextToken else { return false }

        // Guard a specific false-positive shape where Whisper splits the end of the
        // final dictionary token into a separate trailing token (e.g. "pinup ca").
        let sharedPrefixCount = window.count - 1
        for index in 0..<sharedPrefixCount where window[index].normalized != candidate.tokens[index] {
            return false
        }

        guard let observedLast = window.last?.normalized, let candidateLast = candidate.tokens.last else {
            return false
        }
        guard candidateLast.count > observedLast.count, candidateLast.hasPrefix(observedLast) else {
            return false
        }

        let trailingSuffix = String(candidateLast.dropFirst(observedLast.count))
        guard trailingSuffix.count >= 2 else { return false }
        return nextToken.normalized == trailingSuffix
    }

    func observedFormsForWindow(
        tokenCount: Int,
        window: [Token],
        observedNormalized: String,
        observedPhonetic: String
    ) -> [(normalized: String, phonetic: String, replacementSuffix: String)] {
        guard tokenCount == 1 || tokenCount == 2 else {
            return [(normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")]
        }

        var forms: [(normalized: String, phonetic: String, replacementSuffix: String)] = [
            (normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")
        ]
        var seen = Set<String>()
        seen.insert("\(observedNormalized)|")

        if tokenCount == 1 {
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

        guard tokenCount == 2, window.count == 2 else { return forms }
        let first = window[0].normalized
        let second = window[1].normalized

        if second.hasSuffix("'s"), second.count > minimumSplitTokenLength {
            let stem = String(second.dropLast(2))
            if stem.count >= minimumSplitTokenLength {
                let normalized = "\(first) \(stem)"
                let key = "\(normalized)|'s"
                if seen.insert(key).inserted {
                    forms.append((
                        normalized: normalized,
                        phonetic: encoder.phraseSignature(for: [first, stem], lexicon: lexicon),
                        replacementSuffix: "'s"
                    ))
                }
            }
        } else if second.hasSuffix("s"),
                  !second.hasSuffix("s'"),
                  second.count > minimumSplitTokenLength {
            // Whisper often emits possessive names without apostrophes: "Especitos".
            let stem = String(second.dropLast())
            if stem.count >= minimumSplitTokenLength {
                let normalized = "\(first) \(stem)"
                let key = "\(normalized)|'s"
                if seen.insert(key).inserted {
                    forms.append((
                        normalized: normalized,
                        phonetic: encoder.phraseSignature(for: [first, stem], lexicon: lexicon),
                        replacementSuffix: "'s"
                    ))
                }
            }
        }

        return forms
    }

    func baseTokenForCommonWordGuard(_ token: String) -> String {
        if token.hasSuffix("'s"), token.count > 3 {
            return String(token.dropLast(2))
        }

        return token
    }

    func isStylizedSingleTokenEntry(_ entry: CompiledEntry) -> Bool {
        guard entry.tokens.count == 1 else { return false }
        guard !entry.phrase.contains(" ") else { return false }
        let firstScalar = entry.phrase.unicodeScalars.first
        return entry.phrase.unicodeScalars.contains { scalar in
            guard scalar.properties.isUppercase else { return false }
            return scalar != firstScalar
        }
    }

    private func hasStrongStylizedTextEvidence(
        observed: String,
        candidate: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.83 else { return false }
        guard observed.unicodeScalars.first == candidate.unicodeScalars.first else { return false }
        guard observed.unicodeScalars.last == candidate.unicodeScalars.last else { return false }
        return true
    }

    private func stylizedFallbackPhoneticSimilarity(
        tokenCount: Int,
        observedNormalized: String,
        observedPhonetic: String,
        candidate: CompiledEntry
    ) -> Double {
        guard tokenCount == 1, candidate.tokens.count == 1 else { return 0 }
        guard isStylizedSingleTokenEntry(candidate) else { return 0 }
        guard observedNormalized.count >= 4, candidate.tokens[0].count >= 5 else { return 0 }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidate.tokens[0])) else { return 0 }

        let observedFallback = encoder.fallbackSignature(for: observedNormalized)
        let candidateFallback = encoder.fallbackSignature(for: candidate.tokens[0])
        guard !observedFallback.isEmpty, !candidateFallback.isEmpty else { return 0 }

        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidate.phoneticPhrase)
        return max(fallbackSimilarity, runtimeSimilarity)
    }

    private func hasStrongStylizedFallbackPhoneticEvidence(
        observed: String,
        candidate: String,
        observedPhonetic: String,
        candidatePhonetic: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.22 else { return false }
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        return max(fallbackSimilarity, runtimeSimilarity) >= 0.88
    }

    private func hasModerateStylizedFallbackPhoneticEvidence(
        observed: String,
        candidate: String,
        observedPhonetic: String,
        candidatePhonetic: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.42 else { return false }
        guard let observedFirst = observed.first?.lowercased(),
              let candidateFirst = candidate.first?.lowercased(),
              observedFirst == candidateFirst else { return false }
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        return max(fallbackSimilarity, runtimeSimilarity) >= 0.66
    }

    private func allowStylizedFallbackForCommonObservedToken(
        token: Token,
        tokenIndex: Int,
        totalTokens: Int
    ) -> Bool {
        guard let first = token.raw.first else { return false }
        guard String(first).uppercased() == String(first) else { return false }
        if token.raw.dropFirst().contains(where: { String($0).uppercased() == String($0) }) {
            return true
        }

        // Avoid sentence-start capitalization false positives in prose.
        if tokenIndex == 0, totalTokens > 1 {
            return false
        }

        return true
    }

    private func shouldInferPossessiveSuffix(
        observed: String,
        observedPhonetic: String,
        candidate: String,
        nextToken: Token?
    ) -> Bool {
        guard nextToken != nil else { return false }
        guard !candidate.hasSuffix("s") else { return false }
        guard observed.hasSuffix("s") || observed.hasSuffix("x") || observed.hasSuffix("z") else { return false }

        let candidatePhonetic = encoder.signature(for: candidate, lexicon: lexicon)
        let candidateWithS = "\(candidate)s"
        let candidateWithSPhonetic = encoder.signature(for: candidateWithS, lexicon: lexicon)
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let candidateWithSFallback = encoder.fallbackSignature(for: candidateWithS)

        let baseSimilarity = max(
            scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic),
            scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        )
        let possessiveSimilarity = max(
            scorer.similarity(lhs: observedPhonetic, rhs: candidateWithSPhonetic),
            scorer.similarity(lhs: observedFallback, rhs: candidateWithSFallback)
        )

        return possessiveSimilarity >= baseSimilarity + 0.08
    }

    private func hasStrongAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= 5, candidateSecond.count >= 5 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }

        let candidateSecondPhonetic = encoder.signature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        return secondTextSimilarity >= 0.70 || secondPhoneticSimilarity >= 0.72
    }

    private func hasModerateAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= 6, candidateSecond.count >= 6 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }
        guard observedSecond.first == candidateSecond.first else { return false }
        guard observedSecond.last == candidateSecond.last else { return false }

        let candidateSecondPhonetic = encoder.signature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        // Favor text shape for this fallback because runtime lexicon coverage can
        // under-represent proper-name variants. Keep phonetic as an alternate path.
        return secondTextSimilarity >= 0.60 || secondPhoneticSimilarity >= 0.68
    }

    func possessiveBonus(for replacementSuffix: String) -> Double {
        replacementSuffix == "'s" ? possessiveStemScoreBoost : 0
    }

    private func normalizedPossessiveStem(for token: String) -> (stem: String, suffix: String) {
        if token.hasSuffix("'s"), token.count > 3 {
            return (String(token.dropLast(2)), "'s")
        }

        if token.hasSuffix("s"), !token.hasSuffix("s'"), token.count > 3 {
            return (String(token.dropLast(1)), "'s")
        }

        return (token, "")
    }

    private func resolvedPossessiveSuffix(basePhrase: String, desiredSuffix: String) -> String {
        guard desiredSuffix == "'s" else { return "" }
        return basePhrase.lowercased().hasSuffix("'s") ? "" : "'s"
    }

    func tokenAlignmentBoost(window: [Token], candidate: CompiledEntry) -> Double {
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
            if textTail >= 0.60 || phoneticTail >= 0.68 {
                return 0.08
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
